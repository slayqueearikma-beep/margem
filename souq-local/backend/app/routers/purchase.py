"""Product purchase checkout, orders, and Stripe webhooks."""

from __future__ import annotations

import logging
from uuid import UUID

from fastapi import APIRouter, Depends, HTTPException, Request, status
from sqlalchemy import select
from sqlalchemy.ext.asyncio import AsyncSession

from app.auth import get_current_user, require_seller, require_verified_email
from app.database import get_db
from app.limiter import limiter
from app.models import (
    PurchaseOrder,
    PurchaseOrderStatus,
    PurchasePaymentStatus,
    SellerProfile,
    User,
)
from app.schemas import (
    CheckoutPreviewIn,
    CheckoutPreviewOut,
    CheckoutSessionIn,
    CheckoutSessionOut,
    PurchaseOrderOut,
    PurchaseOrderStatusUpdate,
    PurchaseReceiptOut,
)
from app.services.email import email_service
from app.services.notifications import notify_user
from app.services.purchase import (
    PurchaseValidationError,
    build_receipt,
    calculate_totals,
    complete_paid_order,
    create_pending_order,
    get_product_for_purchase,
)
from app.services.stripe_service import (
    StripeNotConfiguredError,
    construct_webhook_event,
    create_checkout_session,
)

logger = logging.getLogger("margem.purchase")

router = APIRouter(prefix="/purchase", tags=["purchase"])


def _order_out(order: PurchaseOrder, *, seller_name: str | None = None, buyer_email: str | None = None) -> PurchaseOrderOut:
    return PurchaseOrderOut(
        id=order.id,
        order_number=order.order_number,
        buyer_id=order.buyer_id,
        seller_id=order.seller_id,
        product_id=order.product_id,
        product_name=order.product_name,
        quantity=order.quantity,
        unit_price_mad=float(order.unit_price_mad),
        subtotal_mad=float(order.subtotal_mad),
        delivery_fee_mad=float(order.delivery_fee_mad),
        tax_mad=float(order.tax_mad),
        total_mad=float(order.total_mad),
        delivery_method=order.delivery_method,
        buyer_name=order.buyer_name,
        buyer_phone=order.buyer_phone,
        buyer_address=order.buyer_address,
        payment_status=order.payment_status.value,
        order_status=order.order_status.value,
        stripe_payment_intent_id=order.stripe_payment_intent_id,
        receipt_number=order.receipt_number,
        paid_at=order.paid_at,
        created_at=order.created_at,
        updated_at=order.updated_at,
        seller_business_name=seller_name,
        buyer_email=buyer_email,
    )


async def _notify_purchase_success(
    session: AsyncSession,
    order: PurchaseOrder,
    buyer: User,
    seller_profile: SellerProfile,
    seller_user: User,
) -> None:
    delivery_label = "Pickup" if order.delivery_method == "pickup" else "Delivery"
    await notify_user(
        session,
        user_id=buyer.id,
        title="Order confirmed",
        body=f"Your purchase of {order.product_name} was successful.",
        kind="order",
        data={"order_id": str(order.id), "order_number": order.order_number},
    )
    await notify_user(
        session,
        user_id=seller_user.id,
        title="New order received",
        body=f"{buyer.display_name or buyer.email} purchased {order.product_name} ({delivery_label}).",
        kind="order",
        data={
            "order_id": str(order.id),
            "order_number": order.order_number,
            "buyer_name": order.buyer_name or buyer.display_name,
            "buyer_phone": order.buyer_phone or buyer.phone,
        },
    )
    email_service.send(
        to=buyer.email,
        subject=f"MABRID order confirmation {order.order_number}",
        text_body=(
            f"Thank you for your purchase.\n\n"
            f"Order: {order.order_number}\n"
            f"Receipt: {order.receipt_number}\n"
            f"Product: {order.product_name}\n"
            f"Total: {order.total_mad:.2f} MAD\n"
            f"Delivery: {delivery_label}\n"
        ),
    )
    if seller_user.email:
        email_service.send(
            to=seller_user.email,
            subject=f"New MABRID order {order.order_number}",
            text_body=(
                f"You received a new order.\n\n"
                f"Order: {order.order_number}\n"
                f"Product: {order.product_name}\n"
                f"Buyer: {order.buyer_name or buyer.display_name}\n"
                f"Phone: {order.buyer_phone or buyer.phone}\n"
                f"Delivery: {delivery_label}\n"
                f"Total paid: {order.total_mad:.2f} MAD\n"
            ),
        )


@router.post("/checkout/preview", response_model=CheckoutPreviewOut)
@limiter.limit("60/minute")
async def checkout_preview(
    request: Request,
    payload: CheckoutPreviewIn,
    user: User = Depends(require_verified_email),
    session: AsyncSession = Depends(get_db),
):
    product = await get_product_for_purchase(session, payload.product_id)
    totals = calculate_totals(product, quantity=payload.quantity, delivery_method=payload.delivery_method)
    return CheckoutPreviewOut(
        product_id=product.id,
        product_name=product.name,
        quantity=payload.quantity,
        unit_price_mad=float(totals["unit_price_mad"]),
        subtotal_mad=float(totals["subtotal_mad"]),
        delivery_fee_mad=float(totals["delivery_fee_mad"]),
        tax_mad=float(totals["tax_mad"]),
        total_mad=float(totals["total_mad"]),
        delivery_method=payload.delivery_method,
        delivery_available=bool(totals["delivery_available"]),
        pickup_only=bool(totals["pickup_only"]),
        tax_enabled=bool(totals["tax_enabled"]),
        stock_available=product.stock_quantity,
    )


@router.post("/checkout/session", response_model=CheckoutSessionOut)
@limiter.limit("30/minute")
async def create_checkout_session_endpoint(
    request: Request,
    payload: CheckoutSessionIn,
    user: User = Depends(require_verified_email),
    session: AsyncSession = Depends(get_db),
):
    product = await get_product_for_purchase(session, payload.product_id)
    try:
        totals = calculate_totals(
            product, quantity=payload.quantity, delivery_method=payload.delivery_method
        )
        order = await create_pending_order(session, buyer=user, product=product, payload=payload, totals=totals)
        stripe_session = create_checkout_session(
            order_id=str(order.id),
            order_number=order.order_number,
            product_name=product.name,
            quantity=payload.quantity,
            subtotal_mad=float(totals["subtotal_mad"]),
            delivery_fee_mad=float(totals["delivery_fee_mad"]),
            tax_mad=float(totals["tax_mad"]),
            total_mad=float(totals["total_mad"]),
            buyer_email=user.email,
            success_url=payload.success_url,
            cancel_url=payload.cancel_url,
            metadata={
                "product_id": str(product.id),
                "buyer_id": str(user.id),
            },
        )
        order.stripe_checkout_session_id = stripe_session["session_id"]
        await session.commit()
        return CheckoutSessionOut(
            order_id=order.id,
            checkout_url=stripe_session["checkout_url"],
            session_id=stripe_session["session_id"],
        )
    except PurchaseValidationError as exc:
        await session.rollback()
        raise HTTPException(status_code=status.HTTP_400_BAD_REQUEST, detail=str(exc)) from exc
    except StripeNotConfiguredError as exc:
        await session.rollback()
        raise HTTPException(status_code=status.HTTP_503_SERVICE_UNAVAILABLE, detail=str(exc)) from exc


@router.get("/orders/me", response_model=list[PurchaseOrderOut])
async def list_my_orders(
    user: User = Depends(get_current_user),
    session: AsyncSession = Depends(get_db),
):
    result = await session.execute(
        select(PurchaseOrder)
        .where(PurchaseOrder.buyer_id == user.id)
        .order_by(PurchaseOrder.created_at.desc())
    )
    orders = result.scalars().all()
    seller_ids = {o.seller_id for o in orders}
    sellers: dict[UUID, str] = {}
    if seller_ids:
        seller_rows = await session.execute(
            select(SellerProfile.id, SellerProfile.business_name).where(SellerProfile.id.in_(seller_ids))
        )
        sellers = {row[0]: row[1] for row in seller_rows.all()}
    return [_order_out(o, seller_name=sellers.get(o.seller_id)) for o in orders]


@router.get("/orders/{order_id}", response_model=PurchaseOrderOut)
async def get_order(
    order_id: UUID,
    user: User = Depends(get_current_user),
    session: AsyncSession = Depends(get_db),
):
    order = await session.get(PurchaseOrder, order_id)
    if order is None:
        raise HTTPException(status_code=404, detail="Order not found")
    seller = await session.get(SellerProfile, order.seller_id)
    if order.buyer_id != user.id and (seller is None or seller.user_id != user.id):
        raise HTTPException(status_code=404, detail="Order not found")
    buyer = await session.get(User, order.buyer_id)
    return _order_out(
        order,
        seller_name=seller.business_name if seller else None,
        buyer_email=buyer.email if buyer else None,
    )


@router.get("/orders/{order_id}/receipt", response_model=PurchaseReceiptOut)
async def get_order_receipt(
    order_id: UUID,
    user: User = Depends(get_current_user),
    session: AsyncSession = Depends(get_db),
):
    order = await session.get(PurchaseOrder, order_id)
    if order is None or order.payment_status != PurchasePaymentStatus.PAID:
        raise HTTPException(status_code=404, detail="Receipt not found")
    seller = await session.get(SellerProfile, order.seller_id)
    buyer = await session.get(User, order.buyer_id)
    if buyer is None or seller is None:
        raise HTTPException(status_code=404, detail="Receipt not found")
    if order.buyer_id != user.id and seller.user_id != user.id:
        raise HTTPException(status_code=404, detail="Receipt not found")
    return build_receipt(order, buyer, seller)


@router.get("/seller/orders", response_model=list[PurchaseOrderOut])
async def list_seller_orders(
    user: User = Depends(require_seller),
    session: AsyncSession = Depends(get_db),
):
    seller = await session.scalar(select(SellerProfile).where(SellerProfile.user_id == user.id))
    if seller is None:
        raise HTTPException(status_code=404, detail="Seller profile not found")
    result = await session.execute(
        select(PurchaseOrder)
        .where(PurchaseOrder.seller_id == seller.id, PurchaseOrder.payment_status == PurchasePaymentStatus.PAID)
        .order_by(PurchaseOrder.created_at.desc())
    )
    orders = result.scalars().all()
    out: list[PurchaseOrderOut] = []
    for order in orders:
        buyer = await session.get(User, order.buyer_id)
        out.append(
            _order_out(
                order,
                seller_name=seller.business_name,
                buyer_email=buyer.email if buyer else None,
            )
        )
    return out


@router.patch("/seller/orders/{order_id}/status", response_model=PurchaseOrderOut)
async def update_seller_order_status(
    order_id: UUID,
    payload: PurchaseOrderStatusUpdate,
    user: User = Depends(require_seller),
    session: AsyncSession = Depends(get_db),
):
    seller = await session.scalar(select(SellerProfile).where(SellerProfile.user_id == user.id))
    if seller is None:
        raise HTTPException(status_code=404, detail="Seller profile not found")
    order = await session.get(PurchaseOrder, order_id)
    if order is None or order.seller_id != seller.id:
        raise HTTPException(status_code=404, detail="Order not found")
    if order.payment_status != PurchasePaymentStatus.PAID:
        raise HTTPException(status_code=400, detail="Order is not paid")
    order.order_status = PurchaseOrderStatus(payload.order_status)
    await notify_user(
        session,
        user_id=order.buyer_id,
        title="Order status updated",
        body=f"Your order {order.order_number} is now {payload.order_status}.",
        kind="order",
        data={"order_id": str(order.id), "order_status": payload.order_status},
    )
    await session.commit()
    await session.refresh(order)
    buyer = await session.get(User, order.buyer_id)
    return _order_out(order, seller_name=seller.business_name, buyer_email=buyer.email if buyer else None)


@router.post("/webhooks/stripe", include_in_schema=False)
async def stripe_webhook(request: Request, session: AsyncSession = Depends(get_db)):
    payload = await request.body()
    signature = request.headers.get("stripe-signature", "")
    try:
        event = construct_webhook_event(payload, signature)
    except Exception as exc:
        logger.warning("stripe_webhook_invalid: %s", exc)
        raise HTTPException(status_code=400, detail="Invalid webhook") from exc

    if event["type"] == "checkout.session.completed":
        data = event["data"]["object"]
        order_id = data.get("metadata", {}).get("order_id")
        if not order_id:
            return {"ok": True}
        order = await session.get(PurchaseOrder, UUID(order_id))
        if order is None:
            return {"ok": True}
        payment_intent = data.get("payment_intent", "")
        try:
            await complete_paid_order(
                session,
                order,
                payment_intent_id=str(payment_intent or ""),
                checkout_session_id=data.get("id", ""),
            )
            buyer = await session.get(User, order.buyer_id)
            seller_profile = await session.get(SellerProfile, order.seller_id)
            seller_user = None
            if seller_profile:
                seller_user = await session.get(User, seller_profile.user_id)
            if buyer and seller_profile and seller_user:
                await _notify_purchase_success(session, order, buyer, seller_profile, seller_user)
            await session.commit()
        except PurchaseValidationError as exc:
            await session.rollback()
            logger.error("order_completion_failed order_id=%s error=%s", order_id, exc)

    elif event["type"] == "checkout.session.expired":
        data = event["data"]["object"]
        order_id = data.get("metadata", {}).get("order_id")
        if order_id:
            order = await session.get(PurchaseOrder, UUID(order_id))
            if order and order.payment_status == PurchasePaymentStatus.PENDING:
                order.payment_status = PurchasePaymentStatus.FAILED
                order.order_status = PurchaseOrderStatus.CANCELLED
                await session.commit()

    return {"ok": True}
