"""Account suspension, reactivation, and admin-driven soft deletion."""

from __future__ import annotations

from fastapi import HTTPException, status
from sqlalchemy import delete as sql_delete, select
from sqlalchemy.ext.asyncio import AsyncSession

from app.models import (
    AuthToken,
    Conversation,
    Favorite,
    Message,
    Notification,
    RecentlyViewed,
    Review,
    SavedSearch,
    SellerFollow,
    SellerProfile,
    Subscription,
    SubscriptionStatus,
    User,
    UserRole,
    UserStatus,
)
from app.services.audit import log_security_event
from app.services.security import revoke_all_refresh_tokens

PROTECTED_STAFF_ROLES = frozenset(
    {UserRole.SUPER_ADMIN, UserRole.ADMIN, UserRole.MODERATOR, UserRole.SUPPORT}
)


def assert_can_moderate_user(actor: User, target: User, *, status_value: UserStatus) -> None:
    if actor.id == target.id:
        raise HTTPException(status_code=400, detail="You cannot change your own account status")

    if target.role == UserRole.SUPER_ADMIN and status_value in {
        UserStatus.SUSPENDED,
        UserStatus.DELETED,
    }:
        raise HTTPException(status_code=400, detail="Cannot suspend or delete a super admin")

    if (
        target.role in PROTECTED_STAFF_ROLES
        and actor.role != UserRole.SUPER_ADMIN
        and status_value in {UserStatus.SUSPENDED, UserStatus.DELETED}
    ):
        raise HTTPException(
            status_code=403,
            detail="Only a super admin can suspend or delete staff accounts",
        )

    if target.status == UserStatus.DELETED and status_value != UserStatus.DELETED:
        raise HTTPException(status_code=400, detail="Deleted accounts cannot be reactivated")


async def _cancel_paid_subscriptions(session: AsyncSession, user: User) -> None:
    from app.config import settings

    subs = (
        await session.execute(
            select(Subscription).where(
                Subscription.user_id == user.id,
                Subscription.status.in_(
                    [
                        SubscriptionStatus.ACTIVE,
                        SubscriptionStatus.TRIALING,
                        SubscriptionStatus.PAST_DUE,
                    ]
                ),
            )
        )
    ).scalars().all()

    for sub in subs:
        sub.status = SubscriptionStatus.CANCELED
        if sub.stripe_subscription_id and settings.stripe_enabled:
            import stripe

            stripe.api_key = settings.stripe_secret_key
            try:
                stripe.Subscription.delete(sub.stripe_subscription_id)
            except Exception:
                pass

    user.is_premium = False
    user.premium_until = None


async def _set_seller_active(session: AsyncSession, user_id: UUID, *, active: bool) -> None:
    seller = (
        await session.execute(select(SellerProfile).where(SellerProfile.user_id == user_id))
    ).scalar_one_or_none()
    if seller is not None:
        seller.is_active = active
        if not active:
            seller.is_premium = False


async def suspend_user(session: AsyncSession, user: User) -> None:
    await _cancel_paid_subscriptions(session, user)
    await _set_seller_active(session, user.id, active=False)
    user.status = UserStatus.SUSPENDED
    await revoke_all_refresh_tokens(session, user.id)


async def reactivate_user(session: AsyncSession, user: User) -> None:
    user.status = UserStatus.ACTIVE


async def soft_delete_user(session: AsyncSession, user: User) -> None:
    """Irreversible account removal — same guarantees as self-serve DELETE /auth/me."""
    await _cancel_paid_subscriptions(session, user)

    profile = (
        await session.execute(select(SellerProfile).where(SellerProfile.user_id == user.id))
    ).scalar_one_or_none()

    await session.execute(sql_delete(Message).where(Message.sender_id == user.id))
    peer_conversations = (
        await session.execute(
            select(Conversation.id).where(
                (Conversation.participant_a_id == user.id)
                | (Conversation.participant_b_id == user.id)
            )
        )
    ).scalars().all()
    if peer_conversations:
        await session.execute(sql_delete(Message).where(Message.conversation_id.in_(peer_conversations)))
        await session.execute(sql_delete(Conversation).where(Conversation.id.in_(peer_conversations)))

    if profile is not None:
        from app.models import Product, SellerCategory, Service

        await session.execute(sql_delete(SellerCategory).where(SellerCategory.seller_id == profile.id))
        await session.execute(sql_delete(Product).where(Product.seller_id == profile.id))
        await session.execute(sql_delete(Service).where(Service.seller_id == profile.id))
        await session.execute(sql_delete(Review).where(Review.seller_id == profile.id))
        await session.delete(profile)

    for model, column in (
        (Favorite, Favorite.user_id),
        (SellerFollow, SellerFollow.user_id),
        (SavedSearch, SavedSearch.user_id),
        (RecentlyViewed, RecentlyViewed.user_id),
        (Notification, Notification.user_id),
        (Subscription, Subscription.user_id),
        (AuthToken, AuthToken.user_id),
        (Review, Review.buyer_id),
    ):
        await session.execute(sql_delete(model).where(column == user.id))

    await revoke_all_refresh_tokens(session, user.id)
    user.status = UserStatus.DELETED
    user.email = f"deleted+{user.id}@invalid.local"
    user.display_name = "Deleted user"
    user.password_hash = None
    user.is_premium = False
    user.premium_until = None
    if user.role in PROTECTED_STAFF_ROLES:
        user.role = UserRole.BUYER

    log_security_event("account_deleted", user_id=str(user.id))


async def apply_user_status(
    session: AsyncSession,
    *,
    actor: User,
    target: User,
    status_value: UserStatus,
) -> dict:
    assert_can_moderate_user(actor, target, status_value=status_value)

    previous = {"status": target.status.value}
    if status_value == UserStatus.SUSPENDED:
        await suspend_user(session, target)
    elif status_value == UserStatus.DELETED:
        await soft_delete_user(session, target)
    elif status_value == UserStatus.ACTIVE:
        await reactivate_user(session, target)
    else:
        raise HTTPException(status_code=400, detail="Unsupported account status")

    return {
        "previous": previous,
        "new": {"status": target.status.value},
    }
