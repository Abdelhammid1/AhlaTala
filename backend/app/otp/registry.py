"""Return the configured OTP sender (env `OTP_SENDER=logging|sms`, default logging)."""
import os

from .sender import LoggingSender, Sender, SmsSender


def get_sender() -> Sender:
    backend = (os.getenv("OTP_SENDER") or "logging").strip().lower()
    if backend == "sms":
        return SmsSender()
    return LoggingSender()
