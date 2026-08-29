"""Return the configured sender (env `SENDER=logging|fcm`, default logging)."""
import os

from .sender import FcmSender, LoggingSender, Sender


def get_sender() -> Sender:
    backend = (os.getenv("SENDER") or "logging").strip().lower()
    if backend == "fcm":
        return FcmSender()
    return LoggingSender()
