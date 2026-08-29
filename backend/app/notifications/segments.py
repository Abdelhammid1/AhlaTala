"""Segment resolvers for notification targets (E8 US8.1)."""
from datetime import datetime, timedelta, timezone

from sqlalchemy import func

from app.extensions import db
from app.models import Customer, NotificationTarget, Order


def _all() -> list[int]:
    return [c.id for c in db.session.query(Customer.id).all()]


def _has_ordered() -> list[int]:
    rows = (
        db.session.query(Customer.id)
        .join(Order, Order.customer_id == Customer.id)
        .distinct()
        .all()
    )
    return [r.id for r in rows]


def _inactive_30d() -> list[int]:
    """Customers whose most recent order is 30+ days old, plus customers with zero orders."""
    cutoff = datetime.now(timezone.utc) - timedelta(days=30)
    latest = (
        db.session.query(Order.customer_id, func.max(Order.created_at).label("latest"))
        .filter(Order.customer_id.isnot(None))
        .group_by(Order.customer_id)
        .subquery()
    )
    rows = (
        db.session.query(Customer.id)
        .outerjoin(latest, latest.c.customer_id == Customer.id)
        .filter((latest.c.latest.is_(None)) | (latest.c.latest < cutoff))
        .all()
    )
    return [r.id for r in rows]


_RESOLVERS = {
    NotificationTarget.all: _all,
    NotificationTarget.has_ordered: _has_ordered,
    NotificationTarget.inactive_30d: _inactive_30d,
}


def resolve_target(target: NotificationTarget) -> list[int]:
    fn = _RESOLVERS.get(target)
    if fn is None:
        return []
    return fn()
