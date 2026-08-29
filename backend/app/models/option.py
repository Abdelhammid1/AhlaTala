"""Option — one selectable choice inside an OptionGroup."""
from datetime import datetime, timezone
from decimal import Decimal

from app.extensions import db


class Option(db.Model):
    __tablename__ = "options"

    id = db.Column(db.Integer, primary_key=True)
    option_group_id = db.Column(
        db.Integer,
        db.ForeignKey("option_groups.id", ondelete="CASCADE"),
        nullable=False,
        index=True,
    )

    name_ar = db.Column(db.String(120), nullable=False)
    name_en = db.Column(db.String(120), nullable=True)
    image_path = db.Column(db.String(255), nullable=True)  # overrides item image when selected (variant)
    price_delta = db.Column(db.Numeric(8, 2), nullable=False, default=Decimal("0.00"))

    is_default = db.Column(db.Boolean, nullable=False, default=False, server_default="false")
    is_active = db.Column(db.Boolean, nullable=False, default=True, server_default="true")
    sort_order = db.Column(db.Integer, nullable=False, default=0, server_default="0")

    created_at = db.Column(db.DateTime(timezone=True), default=lambda: datetime.now(timezone.utc))
    updated_at = db.Column(
        db.DateTime(timezone=True),
        default=lambda: datetime.now(timezone.utc),
        onupdate=lambda: datetime.now(timezone.utc),
    )

    group = db.relationship("OptionGroup", back_populates="options")

    def __repr__(self) -> str:  # pragma: no cover
        return f"<Option #{self.id} {self.name_ar!r} +{self.price_delta}>"
