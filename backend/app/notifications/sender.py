"""Notification senders (E8) — pluggable via `get_sender()`.

E8 ships `LoggingSender` (writes an INFO line per delivery). A stubbed
`FcmSender` is provided so the seam is documented for the later Epic
that provisions Firebase.
"""
from __future__ import annotations

import logging
from typing import Protocol, TYPE_CHECKING

from app.extensions import db

if TYPE_CHECKING:
    from app.models import Notification, NotificationDelivery

_log = logging.getLogger("notifications")


class Sender(Protocol):
    def send(self, notification: "Notification", deliveries: list["NotificationDelivery"]) -> int:
        """Deliver the notification to all listed deliveries. Returns the number
        the sender considers delivered (some backends can fail per-device)."""


class LoggingSender:
    """Ships in E8 — writes a log line per delivery, bumps delivered_count.

    Delivery to the customer happens through the app's polling loop (foreground
    local notifications). Real out-of-process push arrives when FcmSender is
    wired.
    """

    def send(self, notification, deliveries) -> int:
        count = len(deliveries)
        for d in deliveries:
            _log.info(
                "[notif] delivered notification_id=%s customer_id=%s title=%r",
                notification.id, d.customer_id, notification.title_ar,
            )
        notification.delivered_count = count
        db.session.add(notification)
        return count


class FcmSender:
    """Stub — placeholder for the Firebase Cloud Messaging integration.

    When Firebase is provisioned:
        1. `pip install firebase-admin`
        2. Init `firebase_admin.initialize_app(cert)` in create_app.
        3. Replace this body with `messaging.send_multicast(...)`, gather
           per-token success/fail, and update delivered_count accordingly.
    Nothing else in the codebase needs to change — the registry swap in
    `.env` (`SENDER=fcm`) is the only touch.
    """

    def send(self, notification, deliveries) -> int:
        _log.warning(
            "FcmSender: no FCM credentials — falling back to logging behaviour "
            "for notification_id=%s (%d deliveries)",
            notification.id, len(deliveries),
        )
        return LoggingSender().send(notification, deliveries)
