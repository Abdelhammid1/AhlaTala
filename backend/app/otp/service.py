"""OTP business logic (E9).

- `generate_and_send(phone)` writes an `OtpCode` row (with hashed code)
  and hands the plaintext to the configured sender.
- `verify(phone, code)` looks up the latest fresh code for that phone,
  clamps attempts, marks consumed, upserts the customer as verified,
  and returns `(customer, access_token)`.
"""
from __future__ import annotations

import os
import secrets
from datetime import datetime, timedelta, timezone

from flask_jwt_extended import create_access_token
from werkzeug.security import check_password_hash, generate_password_hash

from app.extensions import db
from app.loyalty import upsert_customer
from app.models import Customer, OtpCode

from .registry import get_sender

OTP_TTL_SECONDS = 300           # 5 minutes
MAX_ATTEMPTS_PER_CODE = 3       # third wrong try destroys the row
MAX_CODES_PER_HOUR = 5          # per phone


__all__ = [
    "OTP_TTL_SECONDS", "MAX_ATTEMPTS_PER_CODE", "MAX_CODES_PER_HOUR",
    "OtpError", "generate_and_send", "verify",
]


class OtpError(Exception):
    def __init__(self, slug: str, message: str) -> None:
        super().__init__(slug)
        self.slug = slug
        self.message = message


def _normalise_phone(phone: str | None) -> str:
    return (phone or "").strip()


def _random_code() -> str:
    """6-digit numeric code, cryptographically random. Leading zeros preserved."""
    return f"{secrets.randbelow(1_000_000):06d}"


def _reviewer_bypass_phone() -> str | None:
    """Reviewer bypass — a specific phone/code combination that skips
    the real OTP flow so Apple App Review + Google Play Review can sign
    in without an SMS provider being wired up.

    Both env vars must be set for the bypass to activate:
      REVIEWER_PHONE = 0500000099
      REVIEWER_OTP   = 123456
    In production these are set on the app server; if either is missing,
    the bypass silently disables and every phone goes through the real
    OTP flow. This means the escape hatch never accidentally ships to a
    dev machine that forgot to unset the env vars.
    """
    p = os.getenv("REVIEWER_PHONE")
    c = os.getenv("REVIEWER_OTP")
    if not p or not c:
        return None
    return _normalise_phone(p)


def _reviewer_bypass_code() -> str | None:
    p = os.getenv("REVIEWER_PHONE")
    c = os.getenv("REVIEWER_OTP")
    if not p or not c:
        return None
    return c.strip()


def generate_and_send(phone: str) -> tuple[int, str]:
    """Create + hash + persist + send. Returns (row_id, plaintext_code).

    The plaintext code is only surfaced to the API layer for dev-mode
    convenience (a `dev_code` field in the response so testers don't have to
    watch the Flask console). Production disables this by design — see
    `api/auth.py`.
    """
    phone = _normalise_phone(phone)
    if len(phone) < 4:
        raise OtpError("bad_phone", "رقم الجوال غير صحيح")

    # Reviewer bypass — pretend we sent an SMS but do nothing. The verify
    # step accepts the fixed REVIEWER_OTP for this phone regardless of
    # DB state, so we don't need to persist an OtpCode row.
    if phone == _reviewer_bypass_phone():
        return 0, _reviewer_bypass_code() or ""

    # Soft flood control
    now = datetime.now(timezone.utc)
    recent = (
        db.session.query(OtpCode)
        .filter(OtpCode.phone == phone, OtpCode.created_at >= now - timedelta(hours=1))
        .count()
    )
    if recent >= MAX_CODES_PER_HOUR:
        raise OtpError("too_many", "لقد تم إرسال عدد كبير من الأكواد. حاول لاحقاً")

    code = _random_code()
    row = OtpCode(
        phone=phone,
        code_hash=generate_password_hash(code),
        expires_at=now + timedelta(seconds=OTP_TTL_SECONDS),
    )
    db.session.add(row)
    db.session.commit()

    get_sender().send(phone, code)
    return row.id, code


def verify(phone: str, code: str) -> tuple[Customer, str]:
    """Verify + mint JWT. Raises `OtpError` on any failure."""
    phone = _normalise_phone(phone)
    code = (code or "").strip()
    if not (phone and code):
        raise OtpError("bad_input", "الحقول ناقصة")

    now = datetime.now(timezone.utc)

    # Reviewer bypass — accept the fixed code for the fixed phone,
    # skipping every OTP DB check, so App Review can log in stably.
    # Everything downstream (customer upsert, JWT minting) still runs
    # the real path, so the reviewer's session is indistinguishable
    # from a real signed-in customer.
    rp = _reviewer_bypass_phone()
    rc = _reviewer_bypass_code()
    if rp and rc and phone == rp and code == rc:
        customer = upsert_customer(phone, None)
        if customer.name is None:
            customer.name = "App Review"
        if customer.verified_at is None:
            customer.verified_at = now
        db.session.commit()
        token = create_access_token(
            identity=str(customer.id),
            additional_claims={"phone": customer.phone},
            expires_delta=timedelta(days=30),
        )
        return customer, token

    row = (
        db.session.query(OtpCode)
        .filter(
            OtpCode.phone == phone,
            OtpCode.consumed_at.is_(None),
            OtpCode.expires_at >= now,
        )
        .order_by(OtpCode.created_at.desc())
        .first()
    )
    if row is None:
        raise OtpError("not_found", "الكود منتهي أو غير موجود — اطلب كوداً جديداً")

    if not check_password_hash(row.code_hash, code):
        row.attempts = int(row.attempts or 0) + 1
        if row.attempts >= MAX_ATTEMPTS_PER_CODE:
            db.session.delete(row)
        db.session.commit()
        raise OtpError("wrong_code", "الكود غير صحيح")

    # Success — mark consumed + upsert the customer + mark verified.
    row.consumed_at = now
    customer = upsert_customer(phone, None)
    if customer.verified_at is None:
        customer.verified_at = now
    db.session.commit()

    token = create_access_token(
        identity=str(customer.id),
        additional_claims={"phone": customer.phone},
        expires_delta=timedelta(days=30),
    )
    return customer, token
