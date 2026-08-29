"""Discount codes (E6).

Codes are normalised (upper + trim) at both save and lookup so "abc 123"
and "ABC123" resolve to the same row. `uses_count` is bumped inside the
same transaction that persists the order — see `app/discounts.apply()`.
"""
from datetime import datetime, timezone
from decimal import Decimal
from enum import Enum

from app.extensions import db


class DiscountKind(str, Enum):
    percent = "percent"  # value is 0-100 (%)
    fixed = "fixed"      # value is a riyal amount


class DiscountCode(db.Model):
    __tablename__ = "discount_codes"

    id = db.Column(db.Integer, primary_key=True)
    code = db.Column(db.String(40), nullable=False, unique=True, index=True)
    kind = db.Column(db.Enum(DiscountKind, name="discount_code_kind"), nullable=False)
    value = db.Column(db.Numeric(10, 2), nullable=False)
    min_subtotal = db.Column(db.Numeric(10, 2), nullable=True)  # e.g. "requires 100 SAR cart"
    max_uses = db.Column(db.Integer, nullable=True)             # NULL = unlimited
    uses_count = db.Column(db.Integer, nullable=False, default=0, server_default="0")
    expires_at = db.Column(db.DateTime(timezone=True), nullable=True)
    is_active = db.Column(db.Boolean, nullable=False, default=True, server_default="true")
    notes = db.Column(db.Text, nullable=True)
    created_at = db.Column(db.DateTime(timezone=True), default=lambda: datetime.now(timezone.utc))
    updated_at = db.Column(
        db.DateTime(timezone=True),
        default=lambda: datetime.now(timezone.utc),
        onupdate=lambda: datetime.now(timezone.utc),
    )

    def __repr__(self) -> str:  # pragma: no cover
        return f"<DiscountCode {self.code} {self.kind.value}={self.value}>"

    @property
    def is_exhausted(self) -> bool:
        return self.max_uses is not None and self.uses_count >= self.max_uses

    @property
    def is_expired(self) -> bool:
        if self.expires_at is None:
            return False
        # Both sides tz-aware
        return self.expires_at <= datetime.now(timezone.utc)
