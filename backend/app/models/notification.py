"""Notifications (E8) — broadcasts + per-customer deliveries + device tokens.

The sender is pluggable (see app/notifications/sender.py). In E8 the
`LoggingSender` ships; the `FcmSender` slot is ready for a later Epic
that provisions Firebase.
"""
from datetime import datetime, timezone
from enum import Enum

from sqlalchemy import UniqueConstraint
from sqlalchemy.dialects.postgresql import JSONB

from app.extensions import db


class NotificationTarget(str, Enum):
    all = "all"
    inactive_30d = "inactive_30d"
    has_ordered = "has_ordered"


class DevicePlatform(str, Enum):
    android = "android"
    ios = "ios"
    web = "web"


class Notification(db.Model):
    __tablename__ = "notifications"

    id = db.Column(db.Integer, primary_key=True)
    title_ar = db.Column(db.String(160), nullable=False)
    body_ar = db.Column(db.Text, nullable=False)
    target = db.Column(db.Enum(NotificationTarget, name="notification_target"), nullable=False)
    # JSONB: array of customer_ids resolved at send-time. Audit trail so a later
    # admin view shows *exactly* who received this broadcast, even if segment
    # membership drifts after the fact.
    target_snapshot = db.Column(JSONB, nullable=False, default=list, server_default="[]")
    sent_by_admin_id = db.Column(
        db.Integer, db.ForeignKey("admin_users.id", ondelete="SET NULL"), nullable=True
    )
    delivered_count = db.Column(db.Integer, nullable=False, default=0, server_default="0")
    created_at = db.Column(db.DateTime(timezone=True), default=lambda: datetime.now(timezone.utc))

    deliveries = db.relationship(
        "NotificationDelivery",
        back_populates="notification",
        cascade="all, delete-orphan",
        passive_deletes=True,
    )

    def __repr__(self) -> str:  # pragma: no cover
        return f"<Notification #{self.id} {self.title_ar!r} target={self.target.value}>"


class NotificationDelivery(db.Model):
    __tablename__ = "notification_deliveries"
    __table_args__ = (
        UniqueConstraint("notification_id", "customer_id", name="uq_notification_deliveries_pair"),
    )

    id = db.Column(db.Integer, primary_key=True)
    notification_id = db.Column(
        db.Integer, db.ForeignKey("notifications.id", ondelete="CASCADE"), nullable=False, index=True
    )
    customer_id = db.Column(
        db.Integer, db.ForeignKey("customers.id", ondelete="CASCADE"), nullable=False, index=True
    )
    read_at = db.Column(db.DateTime(timezone=True), nullable=True)
    created_at = db.Column(db.DateTime(timezone=True), default=lambda: datetime.now(timezone.utc))

    notification = db.relationship("Notification", back_populates="deliveries")
    customer = db.relationship("Customer")


class DeviceToken(db.Model):
    """Registered mobile device — future FCM/APNs target."""
    __tablename__ = "device_tokens"

    id = db.Column(db.Integer, primary_key=True)
    customer_id = db.Column(
        db.Integer, db.ForeignKey("customers.id", ondelete="CASCADE"), nullable=True, index=True
    )
    phone = db.Column(db.String(40), nullable=True, index=True)
    token = db.Column(db.String(500), nullable=False, unique=True, index=True)
    platform = db.Column(db.Enum(DevicePlatform, name="device_platform"), nullable=False)
    last_seen_at = db.Column(db.DateTime(timezone=True), default=lambda: datetime.now(timezone.utc))
    created_at = db.Column(db.DateTime(timezone=True), default=lambda: datetime.now(timezone.utc))
