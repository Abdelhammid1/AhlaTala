"""Customer + loyalty tables (E5).

Customers are keyed by phone. E5 upserts on order creation; E9 will layer
OTP authentication on top of the same rows — a phone-authed session will
resolve to the same Customer row, so no rework will be needed.
"""
from datetime import datetime, timezone
from decimal import Decimal
from enum import Enum

from app.extensions import db


class Customer(db.Model):
    __tablename__ = "customers"

    id = db.Column(db.Integer, primary_key=True)
    phone = db.Column(db.String(40), nullable=False, unique=True, index=True)
    name = db.Column(db.String(120), nullable=True)  # last-seen name from order forms
    points_balance = db.Column(db.Integer, nullable=False, default=0, server_default="0")
    # E9 — set on first successful OTP verify. Distinguishes an anonymous phone-keyed
    # row (created by guest checkout) from a real account.
    verified_at = db.Column(db.DateTime(timezone=True), nullable=True)
    created_at = db.Column(db.DateTime(timezone=True), default=lambda: datetime.now(timezone.utc))
    updated_at = db.Column(
        db.DateTime(timezone=True),
        default=lambda: datetime.now(timezone.utc),
        onupdate=lambda: datetime.now(timezone.utc),
    )

    ledger = db.relationship(
        "LoyaltyLedger",
        back_populates="customer",
        cascade="all, delete-orphan",
        passive_deletes=True,
        order_by="LoyaltyLedger.created_at.desc()",
    )

    def __repr__(self) -> str:  # pragma: no cover
        return f"<Customer #{self.id} {self.phone} pts={self.points_balance}>"


class LedgerReason(str, Enum):
    earned = "earned"        # + on delivered
    redeemed = "redeemed"    # - at checkout
    adjustment = "adjustment"  # ± manual admin correction


class LoyaltyLedger(db.Model):
    __tablename__ = "loyalty_ledger"

    id = db.Column(db.Integer, primary_key=True)
    customer_id = db.Column(
        db.Integer, db.ForeignKey("customers.id", ondelete="CASCADE"), nullable=False, index=True,
    )
    # SET NULL so we keep the history even if the order is later deleted.
    order_id = db.Column(db.Integer, db.ForeignKey("orders.id", ondelete="SET NULL"), nullable=True, index=True)
    delta = db.Column(db.Integer, nullable=False)  # signed
    reason = db.Column(db.Enum(LedgerReason, name="loyalty_ledger_reason"), nullable=False)
    note = db.Column(db.String(200), nullable=True)
    created_at = db.Column(db.DateTime(timezone=True), default=lambda: datetime.now(timezone.utc))

    customer = db.relationship("Customer", back_populates="ledger")


class LoyaltySettings(db.Model):
    """Single-row config table. id is always 1."""
    __tablename__ = "loyalty_settings"

    id = db.Column(db.Integer, primary_key=True)
    points_per_riyal = db.Column(db.Numeric(6, 3), nullable=False, default=Decimal("1.000"))
    riyal_per_point = db.Column(db.Numeric(6, 3), nullable=False, default=Decimal("0.100"))
    min_redeem_points = db.Column(db.Integer, nullable=False, default=100)
    updated_at = db.Column(
        db.DateTime(timezone=True),
        default=lambda: datetime.now(timezone.utc),
        onupdate=lambda: datetime.now(timezone.utc),
    )

    @classmethod
    def instance(cls) -> "LoyaltySettings":
        """Get the single row, creating it with defaults if absent."""
        s = db.session.get(cls, 1)
        if s is None:
            s = cls(id=1)
            db.session.add(s)
            db.session.flush()
        return s
