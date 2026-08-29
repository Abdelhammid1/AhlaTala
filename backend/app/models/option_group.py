"""OptionGroup — a set of choices attached to an Item.

Four kinds cover every case in E1 (US1.6):
    - variant : choose type (e.g., cheese/pepperoni pizza). single-select, usually required,
                can change price + item image + display name.
    - size    : choose size. single-select, usually required, changes price.
    - remove  : ingredients the customer can remove. multi-select, optional, price_delta MUST be 0.
    - add     : extra ingredients. multi-select, optional, price_delta > 0.

`kind` is a semantic hint driving the mobile UI and the "starting from" list price.
The runtime engine (price calculation, required-groups gating) uses only `selection_type`,
`is_required`, and `price_delta` — so behaviour stays generic across kinds.
"""
from datetime import datetime, timezone
from enum import Enum

from app.extensions import db


class OptionGroupKind(str, Enum):
    variant = "variant"
    size = "size"
    remove = "remove"
    add = "add"


class SelectionType(str, Enum):
    single = "single"
    multi = "multi"


class OptionGroup(db.Model):
    __tablename__ = "option_groups"

    id = db.Column(db.Integer, primary_key=True)
    item_id = db.Column(
        db.Integer,
        db.ForeignKey("items.id", ondelete="CASCADE"),
        nullable=False,
        index=True,
    )
    name_ar = db.Column(db.String(120), nullable=False)
    name_en = db.Column(db.String(120), nullable=True)

    kind = db.Column(
        db.Enum(OptionGroupKind, name="option_group_kind"),
        nullable=False,
        default=OptionGroupKind.size,
    )
    selection_type = db.Column(
        db.Enum(SelectionType, name="selection_type"),
        nullable=False,
        default=SelectionType.single,
    )
    is_required = db.Column(db.Boolean, nullable=False, default=False, server_default="false")
    sort_order = db.Column(db.Integer, nullable=False, default=0, server_default="0")

    created_at = db.Column(db.DateTime(timezone=True), default=lambda: datetime.now(timezone.utc))
    updated_at = db.Column(
        db.DateTime(timezone=True),
        default=lambda: datetime.now(timezone.utc),
        onupdate=lambda: datetime.now(timezone.utc),
    )

    item = db.relationship("Item", back_populates="option_groups")
    options = db.relationship(
        "Option",
        back_populates="group",
        cascade="all, delete-orphan",
        passive_deletes=True,
        order_by="Option.sort_order",
    )

    def __repr__(self) -> str:  # pragma: no cover
        return f"<OptionGroup #{self.id} {self.kind.value}/{self.selection_type.value} {self.name_ar!r}>"
