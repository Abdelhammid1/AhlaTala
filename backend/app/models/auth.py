"""E9 auth-related models: OTP codes + saved addresses.

`OtpCode.code_hash` stores a `werkzeug.security` hash of the plaintext
6-digit code so a DB dump never leaks live codes. `attempts` is bumped
on every wrong-code verify; the third wrong try destroys the row.
"""
from datetime import datetime, timezone

from app.extensions import db


class OtpCode(db.Model):
    __tablename__ = "otp_codes"

    id = db.Column(db.Integer, primary_key=True)
    phone = db.Column(db.String(40), nullable=False, index=True)
    code_hash = db.Column(db.String(255), nullable=False)
    attempts = db.Column(db.Integer, nullable=False, default=0, server_default="0")
    expires_at = db.Column(db.DateTime(timezone=True), nullable=False)
    consumed_at = db.Column(db.DateTime(timezone=True), nullable=True)
    created_at = db.Column(db.DateTime(timezone=True), default=lambda: datetime.now(timezone.utc))


class SavedAddress(db.Model):
    __tablename__ = "saved_addresses"

    id = db.Column(db.Integer, primary_key=True)
    customer_id = db.Column(
        db.Integer, db.ForeignKey("customers.id", ondelete="CASCADE"), nullable=False, index=True
    )
    label = db.Column(db.String(60), nullable=False)          # e.g. "المنزل", "العمل"
    address_text = db.Column(db.String(500), nullable=False)
    is_default = db.Column(db.Boolean, nullable=False, default=False, server_default="false")
    sort_order = db.Column(db.Integer, nullable=False, default=0, server_default="0")
    created_at = db.Column(db.DateTime(timezone=True), default=lambda: datetime.now(timezone.utc))
    updated_at = db.Column(
        db.DateTime(timezone=True),
        default=lambda: datetime.now(timezone.utc),
        onupdate=lambda: datetime.now(timezone.utc),
    )

    customer = db.relationship("Customer", backref=db.backref(
        "saved_addresses", cascade="all, delete-orphan", passive_deletes=True,
        order_by="SavedAddress.is_default.desc(), SavedAddress.sort_order.asc()",
    ))
