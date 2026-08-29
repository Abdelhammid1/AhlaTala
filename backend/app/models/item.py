"""Item — a menu item that belongs to a Category and may have Option Groups.

`display_price_from` is a denormalized cache used by the categories/items list endpoint so
we don't have to walk option groups per row. It's recomputed by the observer in
`app/observers.py` on any Option / OptionGroup change.
"""
from datetime import datetime, timezone
from decimal import Decimal

from app.extensions import db


class Item(db.Model):
    __tablename__ = "items"

    id = db.Column(db.Integer, primary_key=True)
    category_id = db.Column(
        db.Integer,
        db.ForeignKey("categories.id", ondelete="CASCADE"),
        nullable=False,
        index=True,
    )

    name_ar = db.Column(db.String(160), nullable=False)
    name_en = db.Column(db.String(160), nullable=True)
    description_ar = db.Column(db.Text, nullable=True)
    description_en = db.Column(db.Text, nullable=True)
    image_path = db.Column(db.String(255), nullable=True)

    base_price = db.Column(db.Numeric(8, 2), nullable=False, default=Decimal("0.00"))
    calories = db.Column(db.Integer, nullable=True)  # kcal, optional

    # Denormalized: base_price + min(price_delta) across variant/size groups whose options carry
    # different price_deltas. NULL when the item has no variable-price group (list UI then shows
    # base_price directly). See app/observers.py.
    display_price_from = db.Column(db.Numeric(8, 2), nullable=True)
    price_is_variable = db.Column(db.Boolean, nullable=False, default=False, server_default="false")

    is_active = db.Column(db.Boolean, nullable=False, default=True, server_default="true")
    sort_order = db.Column(db.Integer, nullable=False, default=0, server_default="0")

    created_at = db.Column(db.DateTime(timezone=True), default=lambda: datetime.now(timezone.utc))
    updated_at = db.Column(
        db.DateTime(timezone=True),
        default=lambda: datetime.now(timezone.utc),
        onupdate=lambda: datetime.now(timezone.utc),
    )

    category = db.relationship("Category", back_populates="items")
    option_groups = db.relationship(
        "OptionGroup",
        back_populates="item",
        cascade="all, delete-orphan",
        passive_deletes=True,
        order_by="OptionGroup.sort_order",
    )

    # Cross-sell links (E2): outgoing = items shown as recommendations for THIS item;
    # incoming = items that recommend this one. Only outgoing is used by the mobile app.
    cross_sells = db.relationship(
        "ItemCrossSell",
        foreign_keys="ItemCrossSell.item_id",
        back_populates="item",
        cascade="all, delete-orphan",
        passive_deletes=True,
        order_by="ItemCrossSell.sort_order",
    )
    recommended_for = db.relationship(
        "ItemCrossSell",
        foreign_keys="ItemCrossSell.recommended_item_id",
        back_populates="recommended",
        cascade="all, delete-orphan",
        passive_deletes=True,
    )

    def __repr__(self) -> str:  # pragma: no cover
        return f"<Item #{self.id} {self.name_ar!r}>"
