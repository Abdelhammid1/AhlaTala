"""Cash on delivery (US3.1). Marks the order confirmed on start."""
from datetime import datetime, timezone

from app.extensions import db
from app.models import Order, OrderStatus

from .provider import PaymentStartResult, PaymentStatus


class CashProvider:
    """No gateway. The order confirms immediately."""

    def start(self, order: Order) -> PaymentStartResult:
        order.status = OrderStatus.confirmed
        order.confirmed_at = datetime.now(timezone.utc)
        order.payment_reference = f"cash-{order.id}"
        db.session.add(order)
        return PaymentStartResult(
            status=PaymentStatus.confirmed,
            reference=order.payment_reference,
        )
