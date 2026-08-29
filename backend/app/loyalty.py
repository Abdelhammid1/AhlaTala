"""Loyalty engine (E5).

Kept as free functions rather than methods so the E3 order-creation code and
the E4 status-transition observer can both call them without pulling model
imports into each other. All state changes go through here so the ledger and
the running balance stay in lockstep.
"""
from __future__ import annotations

from decimal import Decimal, ROUND_DOWN

from app.extensions import db
from app.models import (
    Customer,
    LedgerReason,
    LoyaltyLedger,
    LoyaltySettings,
    Order,
    OrderStatus,
)


# ---------- customer upsert ----------


def upsert_customer(phone: str, name: str | None) -> Customer:
    """Find-or-create by phone. `name` (from the current order form) replaces the
    stored name on every hit so admin sees the latest self-reported identity."""
    phone = (phone or "").strip()
    customer = db.session.query(Customer).filter_by(phone=phone).first()
    if customer is None:
        customer = Customer(phone=phone, name=(name or "").strip() or None, points_balance=0)
        db.session.add(customer)
        db.session.flush()
    elif name and customer.name != name.strip():
        customer.name = name.strip()
    return customer


# ---------- redemption ----------


def preview_redemption(
    customer: Customer, subtotal: Decimal, requested_points: int
) -> tuple[int, Decimal]:
    """Clamp a redemption request against balance / min / subtotal.

    Returns (points_actually_applied, discount_amount_in_riyals).
    Never raises — caller decides whether to complain about a clamp.
    """
    if requested_points <= 0 or customer is None:
        return 0, Decimal("0.00")

    settings = LoyaltySettings.instance()
    min_pts = int(settings.min_redeem_points or 0)
    if requested_points < min_pts:
        return 0, Decimal("0.00")

    per_point = Decimal(settings.riyal_per_point)
    if per_point <= 0:
        return 0, Decimal("0.00")

    # Cap 1: can't redeem more than they have.
    capped = min(requested_points, int(customer.points_balance or 0))
    # Cap 2: discount can't exceed subtotal (item price floor).
    max_points_by_subtotal = int((subtotal / per_point).to_integral_value(rounding=ROUND_DOWN))
    capped = min(capped, max_points_by_subtotal)

    if capped < min_pts:
        return 0, Decimal("0.00")

    discount = (Decimal(capped) * per_point).quantize(Decimal("0.01"))
    return capped, discount


def redeem(customer: Customer, order: Order, points: int) -> None:
    """Mutate balance + write ledger. Assumed to have been preview_redemption()'d already."""
    if points <= 0:
        return
    customer.points_balance = int(customer.points_balance or 0) - points
    db.session.add(LoyaltyLedger(
        customer_id=customer.id,
        order_id=order.id,
        delta=-points,
        reason=LedgerReason.redeemed,
        note=f"استبدال في الطلب {order.order_number or order.id}",
    ))


# ---------- earn (on delivered) ----------


def award(customer: Customer, order: Order) -> int:
    """Compute + apply earned points for a delivered order. Idempotent —
    an existing 'earned' ledger row for this order short-circuits.

    Returns the number of points awarded (0 if idempotent short-circuit or no rule).
    """
    if customer is None or order is None:
        return 0

    already = (
        db.session.query(LoyaltyLedger)
        .filter_by(customer_id=customer.id, order_id=order.id, reason=LedgerReason.earned)
        .first()
    )
    if already is not None:
        return 0

    settings = LoyaltySettings.instance()
    rate = Decimal(settings.points_per_riyal or 0)
    if rate <= 0:
        return 0

    # Use subtotal (before delivery + before discount) — points reward the food itself.
    pts = int((Decimal(order.subtotal or 0) * rate).to_integral_value(rounding=ROUND_DOWN))
    if pts <= 0:
        return 0

    customer.points_balance = int(customer.points_balance or 0) + pts
    order.points_earned = pts
    db.session.add(LoyaltyLedger(
        customer_id=customer.id,
        order_id=order.id,
        delta=pts,
        reason=LedgerReason.earned,
        note=f"طلب مكتمل {order.order_number or order.id}",
    ))
    return pts
