"""ItemCrossSell — one directed link "customers who added X often add Y".

Directed on purpose: linking pizza → coke does NOT auto-suggest pizza when
someone adds coke (US2.4 talks about suggestions "when the item is added",
per-item, and US2.6 talks about linking recommendations FOR a specific item).
If reciprocal recommendations are ever wanted, the admin can add the reverse
link explicitly.
"""
from datetime import datetime, timezone

from sqlalchemy import CheckConstraint, UniqueConstraint

from app.extensions import db


class ItemCrossSell(db.Model):
    __tablename__ = "item_cross_sells"
    __table_args__ = (
        UniqueConstraint("item_id", "recommended_item_id", name="uq_item_cross_sells_pair"),
        CheckConstraint("item_id <> recommended_item_id", name="ck_item_cross_sells_no_self"),
    )

    id = db.Column(db.Integer, primary_key=True)
    item_id = db.Column(
        db.Integer, db.ForeignKey("items.id", ondelete="CASCADE"), nullable=False, index=True,
    )
    recommended_item_id = db.Column(
        db.Integer, db.ForeignKey("items.id", ondelete="CASCADE"), nullable=False, index=True,
    )
    sort_order = db.Column(db.Integer, nullable=False, default=0, server_default="0")
    created_at = db.Column(db.DateTime(timezone=True), default=lambda: datetime.now(timezone.utc))

    item = db.relationship(
        "Item", foreign_keys=[item_id], back_populates="cross_sells"
    )
    recommended = db.relationship(
        "Item", foreign_keys=[recommended_item_id], back_populates="recommended_for"
    )

    def __repr__(self) -> str:  # pragma: no cover
        return f"<ItemCrossSell #{self.id} {self.item_id} -> {self.recommended_item_id}>"
