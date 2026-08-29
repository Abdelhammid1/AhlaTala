"""Time-boxed promotional offers (E7).

Auto-hidden once `now > ends_at` or `is_active=false`. `linked_item_id`
is optional — when present, tapping the offer on mobile deep-links to
that item.
"""
from datetime import datetime, timezone

from app.extensions import db


class Offer(db.Model):
    __tablename__ = "offers"

    id = db.Column(db.Integer, primary_key=True)
    title_ar = db.Column(db.String(160), nullable=False)
    description_ar = db.Column(db.Text, nullable=True)
    image_path = db.Column(db.String(255), nullable=True)  # under app/static/uploads/offers/

    starts_at = db.Column(db.DateTime(timezone=True), nullable=False)
    ends_at = db.Column(db.DateTime(timezone=True), nullable=False)

    is_active = db.Column(db.Boolean, nullable=False, default=True, server_default="true")
    linked_item_id = db.Column(
        db.Integer, db.ForeignKey("items.id", ondelete="SET NULL"), nullable=True, index=True
    )
    sort_order = db.Column(db.Integer, nullable=False, default=0, server_default="0")

    created_at = db.Column(db.DateTime(timezone=True), default=lambda: datetime.now(timezone.utc))
    updated_at = db.Column(
        db.DateTime(timezone=True),
        default=lambda: datetime.now(timezone.utc),
        onupdate=lambda: datetime.now(timezone.utc),
    )

    linked_item = db.relationship("Item")

    def __repr__(self) -> str:  # pragma: no cover
        return f"<Offer #{self.id} {self.title_ar!r} active={self.is_current}>"

    @property
    def is_current(self) -> bool:
        if not self.is_active:
            return False
        now = datetime.now(timezone.utc)
        return self.starts_at <= now <= self.ends_at

    @property
    def is_expired(self) -> bool:
        return self.ends_at < datetime.now(timezone.utc)
