"""E5 — customer lookup + ledger read.
E8 — inbox + mark-read + device-register.

No auth (matches E1–E7 guest posture). E9 will layer session auth.
"""
from datetime import datetime, timezone

from flask import abort, jsonify, request

from app.extensions import db
from app.models import (
    Customer,
    DevicePlatform,
    DeviceToken,
    LoyaltyLedger,
    Notification,
    NotificationDelivery,
)

from . import api_bp


def _unread_count_for(customer_id: int) -> int:
    return (
        db.session.query(NotificationDelivery)
        .filter_by(customer_id=customer_id, read_at=None)
        .count()
    )


@api_bp.get("/customers/lookup")
def customers_lookup():
    phone = (request.args.get("phone") or "").strip()
    if len(phone) < 4:
        abort(400, description="phone required")
    c = db.session.query(Customer).filter_by(phone=phone).first()
    if c is None:
        abort(404, description="unknown customer")
    return jsonify({
        "customer_id": c.id,
        "phone": c.phone,
        "name": c.name,
        "points_balance": c.points_balance,
        "unread_notifications": _unread_count_for(c.id),
    })


@api_bp.get("/customers/<int:customer_id>/ledger")
def customers_ledger(customer_id: int):
    c = db.session.get(Customer, customer_id)
    if c is None:
        abort(404, description="unknown customer")
    entries = (
        db.session.query(LoyaltyLedger)
        .filter_by(customer_id=c.id)
        .order_by(LoyaltyLedger.created_at.desc())
        .limit(50)
        .all()
    )
    return jsonify([
        {
            "id": e.id,
            "delta": e.delta,
            "reason": e.reason.value if hasattr(e.reason, "value") else e.reason,
            "order_id": e.order_id,
            "note": e.note,
            "created_at": e.created_at.isoformat() if e.created_at else None,
        }
        for e in entries
    ])


# ---------- E8 inbox ----------


@api_bp.get("/customers/<int:customer_id>/notifications")
def customers_inbox(customer_id: int):
    c = db.session.get(Customer, customer_id)
    if c is None:
        abort(404, description="unknown customer")
    try:
        limit = int(request.args.get("limit") or 50)
    except ValueError:
        limit = 50
    limit = max(1, min(limit, 50))

    rows = (
        db.session.query(NotificationDelivery, Notification)
        .join(Notification, Notification.id == NotificationDelivery.notification_id)
        .filter(NotificationDelivery.customer_id == c.id)
        .order_by(NotificationDelivery.created_at.desc())
        .limit(limit)
        .all()
    )
    return jsonify([
        {
            "delivery_id": d.id,
            "notification_id": n.id,
            "title": n.title_ar,
            "body": n.body_ar,
            "sent_at": n.created_at.isoformat() if n.created_at else None,
            "read_at": d.read_at.isoformat() if d.read_at else None,
        }
        for d, n in rows
    ])


@api_bp.post("/customers/<int:customer_id>/notifications/<int:delivery_id>/read")
def customers_mark_read(customer_id: int, delivery_id: int):
    d = db.session.get(NotificationDelivery, delivery_id)
    if d is None or d.customer_id != customer_id:
        abort(404, description="delivery not found")
    if d.read_at is None:
        d.read_at = datetime.now(timezone.utc)
        db.session.commit()
    return jsonify({"delivery_id": d.id, "read_at": d.read_at.isoformat()})


# ---------- E8 device registration (future FCM) ----------


@api_bp.post("/devices/register")
def register_device():
    body = request.get_json(silent=True) or {}
    token = (body.get("token") or "").strip()
    if not token:
        abort(400, description="token required")
    try:
        platform = DevicePlatform((body.get("platform") or "android").lower())
    except ValueError:
        platform = DevicePlatform.android

    phone = (body.get("phone") or "").strip() or None
    cust_id = body.get("customer_id")

    # Upsert by token
    existing = db.session.query(DeviceToken).filter_by(token=token).first()
    if existing is None:
        dt = DeviceToken(
            token=token, platform=platform, phone=phone,
            customer_id=cust_id if isinstance(cust_id, int) else None,
        )
        db.session.add(dt)
    else:
        existing.platform = platform
        existing.phone = phone or existing.phone
        if isinstance(cust_id, int):
            existing.customer_id = cust_id
        existing.last_seen_at = datetime.now(timezone.utc)
    db.session.commit()
    return jsonify({"ok": True})
