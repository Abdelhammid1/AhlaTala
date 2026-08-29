"""OTP senders (E9) — pluggable via `get_sender()`.

`LoggingSender` writes the code to the Flask console so E9 works in dev
without an SMS provider. `SmsSender` is a stub ready for
Unifonic/Msegat/Twilio.
"""
from __future__ import annotations

import logging
from typing import Protocol

_log = logging.getLogger("otp")


class Sender(Protocol):
    def send(self, phone: str, code: str) -> None: ...


class LoggingSender:
    def send(self, phone: str, code: str) -> None:
        # WARNING is on by default in Flask dev; INFO would be quiet.
        _log.warning("[OTP] phone=%s code=%s", phone, code)


class SmsSender:
    """Stub. Replace `send` with the real SMS provider call:

        - Unifonic:   POST https://api.unifonic.com/rest/SMS/messages
        - Msegat:     POST https://www.msegat.com/gw/sendsms.php
        - Twilio:     twilio.rest.Client(...).messages.create(...)

    Nothing else needs to change — the endpoints hand `(phone, code)` in.
    """

    def send(self, phone: str, code: str) -> None:
        _log.warning(
            "SmsSender: no SMS credentials — falling back to log for phone=%s code=%s",
            phone, code,
        )
