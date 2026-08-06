"""Purchase order calculations, fulfillment, and receipts."""

from __future__ import annotations

import secrets
from datetime import UTC, datetime
from uuid import UUID, uuid4

from sqlalchemy import select
from sqlalchemy.ext.asyncio import AsyncSession

from app.config import settings
from app.models import (
    Product,
    ProductDeliveryMode,
    PurchaseOrder,
    PurchaseOrderStatus,
    PurchasePaymentStatus,
    SellerProfile,
    User,
)
from app.schemas import CheckoutPreviewIn, PurchaseReceiptOut


class PurchaseValidationError(ValueError):
    pass


def _round_mad(value: float) -> float:
    return round(float(value), 2)


def calculate_totals(
    product: Product,
    *,
    quantity: int,
    delivery_method: str,
) -> dict[str, float | bool | str]:
    if not product.is_purchasable:
        raise PurchaseValidationError("Product is not available for purchase")
    if not product.is_available or product.is_hidden or product.is_paused:
        raise PurchaseValidationError("Product is not currently available")
    if product.price_mad is None or product.price_mad <= 0:
        raise PurchaseValidationError("Product has no purchase price")
    if quantity < 1:
        raise PurchaseValidationError("Invalid quantity")
    if product.stock_quantity < quantity:
        raise PurchaseValidationError("Insufficient stock")

    pickup_only = product.delivery_mode == ProductDeliveryMode.PICKUP_ONLY
    delivery_available = product.delivery_mode == ProductDeliveryMode.PROVIDER_DELIVERY

    if delivery_method == "delivery" and pickup_only:
        raise PurchaseValidationError("This product is pickup only")
    if delivery_method not in {"pickup", "delivery"}:
        raise PurchaseValidationError("Invalid delivery method")

    unit_price = float(product.price_mad)
    subtotal = _round_mad(unit_price * quantity)

    delivery_fee = 0.0
    if delivery_method == "delivery" and delivery_available:
        fee = float(product.delivery_fee_mad or 0)
        threshold = product.free_delivery_threshold_mad
        if threshold is not None and subtotal >= float(threshold):
            delivery_fee = 0.0
        else:
            delivery_fee = fee

    tax = 0.0
    if product.tax_enabled and settings.purchase_tax_rate_percent > 0:
        taxable = subtotal + delivery_fee
        tax = _round_mad(taxable * settings.purchase_tax_rate_percent / 100.0)

    total = _round_mad(subtotal + delivery_fee + tax)
    return {
        "unit_price_mad": unit_price,
        "subtotal_mad": subtotal,
        "delivery_fee_mad": delivery_fee,
        "tax_mad": tax,
        "total_mad": total,
        "delivery_available": delivery_available,
        "pickup_only": pickup_only,
        "tax_enabled": product.tax_enabled,
    }


async def get_product_for_purchase(session: AsyncSession, product_id: UUID) -> Product:
    product = await session.get(Product, product_id)
    if product is None:
        raise PurchaseValidationError("Product not found")
    return product


def generate_order_number() -> str:
    stamp = datetime.now(UTC).strftime("%Y%m%d")
    suffix = secrets.token_hex(3).upper()
    return f"MGE-{stamp}-{suffix}"


def generate_receipt_number(order_number: str) -> str:
    return f"RCPT-{order_number}"


async def create_pending_order(
    session: AsyncSession,
    *,
    buyer: User,
    product: Product,
    payload: CheckoutPreviewIn,
    totals: dict,
) -> PurchaseOrder:
    seller = await session.get(SellerProfile, product.seller_id)
    if seller is None:
        raise PurchaseValidationError("Seller not found")
    if seller.user_id == buyer.id:
        raise PurchaseValidationError("You cannot purchase your own product")

    if payload.delivery_method == "delivery":
        if not payload.buyer_name.strip() or not payload.buyer_phone.strip() or not payload.buyer_address.strip():
            raise PurchaseValidationError("Delivery requires name, phone, and address")

    order = PurchaseOrder(
        id=uuid4(),
        order_number=generate_order_number(),
        buyer_id=buyer.id,
        seller_id=product.seller_id,
        product_id=product.id,
        product_name=product.name,
        quantity=payload.quantity,
        unit_price_mad=totals["unit_price_mad"],
        subtotal_mad=totals["subtotal_mad"],
        delivery_fee_mad=totals["delivery_fee_mad"],
        tax_mad=totals["tax_mad"],
        total_mad=totals["total_mad"],
        delivery_method=payload.delivery_method,
        buyer_name=payload.buyer_name.strip(),
        buyer_phone=payload.buyer_phone.strip(),
        buyer_address=payload.buyer_address.strip(),
        payment_status=PurchasePaymentStatus.PENDING,
        order_status=PurchaseOrderStatus.PREPARING,
        created_at=datetime.now(UTC),
        updated_at=datetime.now(UTC),
    )
    session.add(order)
    await session.flush()
    return order


async def lock_product_stock(session: AsyncSession, product_id: UUID) -> Product:
    result = await session.execute(
        select(Product).where(Product.id == product_id).with_for_update()
    )
    product = result.scalar_one_or_none()
    if product is None:
        raise PurchaseValidationError("Product not found")
    return product


async def complete_paid_order(
    session: AsyncSession,
    order: PurchaseOrder,
    *,
    payment_intent_id: str,
    checkout_session_id: str,
) -> PurchaseOrder:
    if order.payment_status == PurchasePaymentStatus.PAID:
        return order

    product = await lock_product_stock(session, order.product_id)
    if product.stock_quantity < order.quantity:
        order.payment_status = PurchasePaymentStatus.FAILED
        order.order_status = PurchaseOrderStatus.CANCELLED
        order.updated_at = datetime.now(UTC)
        raise PurchaseValidationError("Insufficient stock at payment completion")

    product.stock_quantity -= order.quantity
    order.payment_status = PurchasePaymentStatus.PAID
    order.order_status = PurchaseOrderStatus.PREPARING
    order.stripe_payment_intent_id = payment_intent_id
    order.stripe_checkout_session_id = checkout_session_id
    order.receipt_number = generate_receipt_number(order.order_number)
    order.paid_at = datetime.now(UTC)
    order.updated_at = datetime.now(UTC)
    return order


def build_receipt(order: PurchaseOrder, buyer: User, seller: SellerProfile) -> PurchaseReceiptOut:
    issued_at = order.paid_at or order.created_at
    delivery_label = "Pickup" if order.delivery_method == "pickup" else "Delivery"
    lines = [
        "MABRID / MarGem — Purchase Receipt",
        f"Receipt: {order.receipt_number}",
        f"Order: {order.order_number}",
        f"Issued: {issued_at.isoformat()}",
        "",
        f"Buyer: {order.buyer_name or buyer.display_name}",
        f"Email: {buyer.email}",
        f"Phone: {order.buyer_phone or buyer.phone}",
        "",
        f"Seller: {seller.business_name}",
        f"Product: {order.product_name}",
        f"Quantity: {order.quantity}",
        f"Unit price: {order.unit_price_mad:.2f} MAD",
        f"Subtotal: {order.subtotal_mad:.2f} MAD",
        f"Delivery fee: {order.delivery_fee_mad:.2f} MAD",
        f"Tax: {order.tax_mad:.2f} MAD",
        f"Total paid: {order.total_mad:.2f} MAD",
        f"Delivery method: {delivery_label}",
        f"Payment status: {order.payment_status.value}",
        f"Stripe payment: {order.stripe_payment_intent_id}",
    ]
    if order.delivery_method == "delivery" and order.buyer_address:
        lines.append(f"Delivery address: {order.buyer_address}")

    return PurchaseReceiptOut(
        receipt_number=order.receipt_number,
        order_number=order.order_number,
        issued_at=issued_at,
        buyer_name=order.buyer_name or buyer.display_name,
        buyer_email=buyer.email,
        seller_name=seller.business_name,
        product_name=order.product_name,
        quantity=order.quantity,
        unit_price_mad=float(order.unit_price_mad),
        subtotal_mad=float(order.subtotal_mad),
        delivery_fee_mad=float(order.delivery_fee_mad),
        tax_mad=float(order.tax_mad),
        total_mad=float(order.total_mad),
        delivery_method=order.delivery_method,
        payment_status=order.payment_status.value,
        stripe_payment_intent_id=order.stripe_payment_intent_id,
        receipt_text="\n".join(lines),
    )
