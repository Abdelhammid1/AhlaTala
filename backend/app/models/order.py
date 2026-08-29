"""Order + OrderLine + OrderLineSelection — the first server-side representation
of a purchase (E1 and E2 were client-side only).

Everything price / name / image related is SNAPSHOTTED at order-creation time
so future admin edits to the source items don't rewrite past orders.

`order_number` (human-facing, e.g. AT-2026-000123) is generated in the
`before_insert` observer using the assigned PK. Registered in app/observers.py.
"""
from datetime import datetime, timezone
from decimal import Decimal
from enum import Enum

from app.extensions import db


class OrderStatus(str, Enum):
    # payment-flow states (E3)
    created = "created"                    # order placed, awaiting gateway callback
    confirmed = "confirmed"                # cash-immediate or gateway-callback success
    failed = "failed"                      # gateway declined / errored
    # workflow states (E4 — set by admin)
    preparing = "preparing"                # قيد التجهيز
    on_the_way = "on_the_way"              # في الطريق (delivery only)
    ready_for_pickup = "ready_for_pickup"  # جاهز للاستلام (pickup only)
    delivered = "delivered"                # تم التسليم / تم الاستلام
    # terminal-cancel
    cancelled = "cancelled"


# Terminal statuses — nothing follows.
_TERMINAL_STATUSES: set[OrderStatus] = {
    OrderStatus.delivered,
    OrderStatus.cancelled,
    OrderStatus.failed,
}


class FulfillmentType(str, Enum):
    delivery = "delivery"
    pickup = "pickup"


class PaymentMethod(str, Enum):
    cash = "cash"
    apple_pay = "apple_pay"
    gateway_stub = "gateway_stub"


class Order(db.Model):
    __tablename__ = "orders"

    id = db.Column(db.Integer, primary_key=True)
    order_number = db.Column(db.String(32), unique=True, nullable=True, index=True)

    status = db.Column(
        db.Enum(OrderStatus, name="order_status"),
        nullable=False,
        default=OrderStatus.created,
    )

    fulfillment_type = db.Column(
        db.Enum(FulfillmentType, name="order_fulfillment_type"), nullable=False
    )
    delivery_address = db.Column(db.String(500), nullable=True)

    customer_name = db.Column(db.String(120), nullable=False)
    customer_phone = db.Column(db.String(40), nullable=False)
    # E5 — set at order-create by upserting the phone. Nullable so old E1–E4 orders (no customer row) stay valid.
    customer_id = db.Column(
        db.Integer, db.ForeignKey("customers.id", ondelete="SET NULL"), nullable=True, index=True
    )

    subtotal = db.Column(db.Numeric(10, 2), nullable=False, default=Decimal("0"))
    delivery_fee = db.Column(db.Numeric(10, 2), nullable=False, default=Decimal("0"))
    discount_amount = db.Column(db.Numeric(10, 2), nullable=False, default=Decimal("0"), server_default="0")
    total = db.Column(db.Numeric(10, 2), nullable=False, default=Decimal("0"))

    # E5 loyalty
    points_redeemed = db.Column(db.Integer, nullable=False, default=0, server_default="0")
    points_earned = db.Column(db.Integer, nullable=False, default=0, server_default="0")
    points_discount = db.Column(
        db.Numeric(10, 2), nullable=False, default=Decimal("0"), server_default="0"
    )

    # E6 discount code
    code_discount = db.Column(
        db.Numeric(10, 2), nullable=False, default=Decimal("0"), server_default="0"
    )
    discount_code_id = db.Column(
        db.Integer, db.ForeignKey("discount_codes.id", ondelete="SET NULL"), nullable=True
    )
    # Snapshot so a later-deleted code still shows on the receipt.
    discount_code_snapshot = db.Column(db.String(40), nullable=True)

    payment_method = db.Column(
        db.Enum(PaymentMethod, name="order_payment_method"), nullable=False
    )
    payment_reference = db.Column(db.String(120), nullable=True)

    notes = db.Column(db.Text, nullable=True)

    created_at = db.Column(db.DateTime(timezone=True), default=lambda: datetime.now(timezone.utc))
    confirmed_at = db.Column(db.DateTime(timezone=True), nullable=True)
    # E4 — set the first time an admin opens this order's detail page. Drives
    # the "جديد" badge + row highlight on the orders list.
    admin_seen_at = db.Column(db.DateTime(timezone=True), nullable=True)
    updated_at = db.Column(
        db.DateTime(timezone=True),
        default=lambda: datetime.now(timezone.utc),
        onupdate=lambda: datetime.now(timezone.utc),
    )

    lines = db.relationship(
        "OrderLine",
        back_populates="order",
        cascade="all, delete-orphan",
        passive_deletes=True,
        order_by="OrderLine.sort_order",
    )
    customer = db.relationship("Customer")

    def __repr__(self) -> str:  # pragma: no cover
        return f"<Order #{self.id} {self.order_number} {self.status.value} total={self.total}>"

    # ---- E4 workflow helpers ----

    def next_valid_statuses(self) -> list[OrderStatus]:
        """Statuses the admin may transition to from the current one.

        Enforces the "logical order only" rule from US4.2. The admin UI
        renders one button per entry here; the transition endpoint validates
        against the same list (belt-and-braces).
        """
        s = self.status
        if s == OrderStatus.confirmed:
            return [OrderStatus.preparing, OrderStatus.cancelled]
        if s == OrderStatus.preparing:
            if self.fulfillment_type == FulfillmentType.delivery:
                return [OrderStatus.on_the_way, OrderStatus.cancelled]
            return [OrderStatus.ready_for_pickup, OrderStatus.cancelled]
        if s == OrderStatus.on_the_way or s == OrderStatus.ready_for_pickup:
            return [OrderStatus.delivered, OrderStatus.cancelled]
        # created/failed/delivered/cancelled: nothing admin-transitionable
        return []

    def is_terminal(self) -> bool:
        return self.status in _TERMINAL_STATUSES


class OrderLine(db.Model):
    __tablename__ = "order_lines"

    id = db.Column(db.Integer, primary_key=True)
    order_id = db.Column(
        db.Integer, db.ForeignKey("orders.id", ondelete="CASCADE"), nullable=False, index=True
    )
    # SET NULL on delete so an item deletion doesn't erase order history.
    item_id = db.Column(db.Integer, db.ForeignKey("items.id", ondelete="SET NULL"), nullable=True, index=True)

    name_ar_snapshot = db.Column(db.String(160), nullable=False)
    image_path_snapshot = db.Column(db.String(255), nullable=True)
    base_price_snapshot = db.Column(db.Numeric(10, 2), nullable=False)

    quantity = db.Column(db.Integer, nullable=False, default=1)
    unit_price = db.Column(db.Numeric(10, 2), nullable=False)  # base + all deltas
    line_price = db.Column(db.Numeric(10, 2), nullable=False)  # unit_price * quantity

    sort_order = db.Column(db.Integer, nullable=False, default=0)

    order = db.relationship("Order", back_populates="lines")
    selections = db.relationship(
        "OrderLineSelection",
        back_populates="line",
        cascade="all, delete-orphan",
        passive_deletes=True,
    )


class OrderLineSelection(db.Model):
    __tablename__ = "order_line_selections"

    id = db.Column(db.Integer, primary_key=True)
    order_line_id = db.Column(
        db.Integer,
        db.ForeignKey("order_lines.id", ondelete="CASCADE"),
        nullable=False,
        index=True,
    )

    group_id_snapshot = db.Column(db.Integer, nullable=False)
    group_name_ar_snapshot = db.Column(db.String(120), nullable=False)
    group_kind_snapshot = db.Column(db.String(20), nullable=False)  # 'variant'|'size'|'remove'|'add'
    option_id_snapshot = db.Column(db.Integer, nullable=False)
    option_name_ar_snapshot = db.Column(db.String(120), nullable=False)
    price_delta_snapshot = db.Column(db.Numeric(10, 2), nullable=False, default=Decimal("0"))

    line = db.relationship("OrderLine", back_populates="selections")
