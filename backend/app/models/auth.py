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
    """A customer's saved delivery address.

    The Stitch redesign (screens _2 / _3) turns the flat address_text field
    into a structured record: a pin on a map (lat/lng), a Google-provided
    formatted string, a typed label (home/office/hotel/rest/other), a
    handful of building-scoped fields (district, apt, floor, extras), and
    a set of driver instructions the customer can toggle in the form.

    Every new column is nullable so pre-Stitch rows still load — the
    legacy `address_text` remains the canonical free-form fallback.
    """
    __tablename__ = "saved_addresses"

    id = db.Column(db.Integer, primary_key=True)
    customer_id = db.Column(
        db.Integer, db.ForeignKey("customers.id", ondelete="CASCADE"), nullable=False, index=True
    )
    # Legacy: free-form label chosen by the customer (e.g. "منزل خالد").
    label = db.Column(db.String(60), nullable=False)
    # Legacy: free-form address the customer can always still edit.
    address_text = db.Column(db.String(500), nullable=False)
    is_default = db.Column(db.Boolean, nullable=False, default=False, server_default="false")
    sort_order = db.Column(db.Integer, nullable=False, default=0, server_default="0")

    # ---- Stitch _3 fields (all nullable so legacy rows still load) ----
    # Typed category so the UI can pick the right icon on both the picker
    # sheet and the address card. One of: home, office, hotel, rest, other.
    label_type = db.Column(db.String(20), nullable=True)
    district_name = db.Column(db.String(120), nullable=True)
    apt_number = db.Column(db.String(40), nullable=True)
    floor = db.Column(db.String(40), nullable=True)
    extra_details = db.Column(db.String(500), nullable=True)
    contact_phone = db.Column(db.String(40), nullable=True)
    # Driver instructions surfaced as icon toggle tiles on the form.
    leave_at_door = db.Column(db.Boolean, nullable=False, default=False, server_default="false")
    dont_ring_bell = db.Column(db.Boolean, nullable=False, default=False, server_default="false")
    photo_url = db.Column(db.String(500), nullable=True)
    # ---- Map picker (Google Maps _2) ----
    lat = db.Column(db.Float, nullable=True)
    lng = db.Column(db.Float, nullable=True)
    # Reverse-geocoded formatted address (Google's canonical string) so a
    # future admin panel / driver app can display the same string Google
    # would render on a map — separate from the free-form address_text.
    formatted_address = db.Column(db.String(500), nullable=True)

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

    # Constrain label_type to the known five values without an enum type
    # (keeps the column expandable — a future "office_hq" doesn't need a
    # migration to add to the enum universe, just a value check).
    __table_args__ = (
        db.CheckConstraint(
            "label_type IS NULL OR label_type IN ('home','office','hotel','rest','other')",
            name="ck_saved_addresses_label_type",
        ),
    )
