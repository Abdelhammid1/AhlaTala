"""Discount-code engine (E6).

Mirrors `loyalty.py`'s shape: a couple of pure helpers + a mutator called
inside the order-creation transaction. Every non-success returns an error
slug + Arabic message so the API layer and mobile client render the same
thing.
"""
from __future__ import annotations

from dataclasses import dataclass
from decimal import Decimal

from app.extensions import db
from app.models import DiscountCode, DiscountKind, Order


# ---------- errors ----------


ERROR_MESSAGES = {
    "not_found": "الكود غير صحيح",
    "inactive": "الكود موقوف مؤقتاً",
    "expired": "انتهت صلاحية الكود",
    "exhausted": "تم استخدام الكود بالحد الأقصى",
    "below_min_subtotal": "لا يمكن استخدام الكود، الحد الأدنى للطلب لم يتم بلوغه",
    "no_effect": "الكود لا ينتج عنه خصم في هذا الطلب",
}


class DiscountError(Exception):
    """Raised inside the order-creation flow to translate into a 422."""

    def __init__(self, slug: str) -> None:
        super().__init__(slug)
        self.slug = slug
        self.message = ERROR_MESSAGES.get(slug, slug)


@dataclass
class PreviewResult:
    code_id: int
    code: str
    kind: str
    value: Decimal
    discount_amount: Decimal


# ---------- helpers ----------


def normalise(code: str | None) -> str:
    return (code or "").strip().upper()


def lookup(code_str: str) -> DiscountCode | None:
    normalised = normalise(code_str)
    if not normalised:
        return None
    return db.session.query(DiscountCode).filter_by(code=normalised).first()


def _compute_discount(code: DiscountCode, subtotal_after_points: Decimal) -> Decimal:
    """Money value of this code applied to a subtotal. Capped at the subtotal."""
    if code.kind == DiscountKind.percent:
        raw = (subtotal_after_points * Decimal(code.value) / Decimal("100"))
    else:
        raw = Decimal(code.value)
    raw = raw.quantize(Decimal("0.01"))
    if raw > subtotal_after_points:
        raw = subtotal_after_points
    if raw < Decimal("0"):
        raw = Decimal("0")
    return raw


# ---------- preview / apply ----------


def preview(code_str: str, subtotal_after_points: Decimal) -> PreviewResult:
    """Look up + validate. Raises `DiscountError` with a slug on failure.

    `subtotal_after_points` is the post-loyalty subtotal (delivery excluded).
    Codes don't stack with delivery fees.
    """
    code = lookup(code_str)
    if code is None:
        raise DiscountError("not_found")
    if not code.is_active:
        raise DiscountError("inactive")
    if code.is_expired:
        raise DiscountError("expired")
    if code.is_exhausted:
        raise DiscountError("exhausted")
    if code.min_subtotal is not None and subtotal_after_points < Decimal(code.min_subtotal):
        raise DiscountError("below_min_subtotal")

    amount = _compute_discount(code, subtotal_after_points)
    if amount <= Decimal("0"):
        # e.g. subtotal is already zero via points, or code value is 0.
        raise DiscountError("no_effect")

    return PreviewResult(
        code_id=code.id,
        code=code.code,
        kind=code.kind.value,
        value=Decimal(code.value),
        discount_amount=amount,
    )


def apply(code_id: int, order: Order, discount_amount: Decimal) -> None:
    """Bump uses_count + snapshot on the order. Called inside the create-order transaction."""
    code = db.session.get(DiscountCode, code_id)
    if code is None:
        return  # shouldn't happen — preview() succeeded
    code.uses_count = int(code.uses_count or 0) + 1
    order.discount_code_id = code.id
    order.discount_code_snapshot = code.code
    order.code_discount = discount_amount
