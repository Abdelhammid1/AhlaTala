"""E9 authenticated endpoints — everything under /api/v1/me.

`current_customer_id()` reads the JWT identity claim (a stringified
customer id — flask-jwt-extended 4.x expects strings, so we cast on
mint + on read).
"""
from datetime import datetime, timezone

from flask import abort, jsonify, request
from flask_jwt_extended import get_jwt_identity, jwt_required

from app.extensions import db
from app.models import Customer, Order, OrderStatus, SavedAddress

from . import api_bp
from .order_schemas import OrderSchema


def _current() -> Customer:
    ident = get_jwt_identity()
    try:
        cid = int(ident)
    except (TypeError, ValueError):
        abort(401)
    c = db.session.get(Customer, cid)
    if c is None:
        abort(401)
    return c


def _customer_dto(c: Customer) -> dict:
    return {
        "customer_id": c.id,
        "phone": c.phone,
        "name": c.name,
        "points_balance": c.points_balance,
        "verified_at": c.verified_at.isoformat() if c.verified_at else None,
    }


def _address_dto(a: SavedAddress) -> dict:
    return {
        "id": a.id,
        "label": a.label,
        "address_text": a.address_text,
        "is_default": bool(a.is_default),
        "sort_order": a.sort_order,
    }


# ---------- profile ----------


@api_bp.get("/me")
@jwt_required()
def me():
    return jsonify(_customer_dto(_current()))


@api_bp.patch("/me")
@jwt_required()
def update_me():
    c = _current()
    body = request.get_json(silent=True) or {}
    name = body.get("name")
    if name is not None:
        name = str(name).strip()
        if len(name) < 2 or len(name) > 120:
            return jsonify(error="validation_error", message="الاسم يجب أن يكون بين 2 و 120 حرف"), 422
        c.name = name
    db.session.commit()
    return jsonify(_customer_dto(c))


# ---------- order history ----------


@api_bp.get("/me/orders")
@jwt_required()
def my_orders():
    c = _current()
    orders = (
        db.session.query(Order)
        .filter(Order.customer_id == c.id)
        .order_by(Order.created_at.desc())
        .limit(100)
        .all()
    )
    return jsonify(OrderSchema(many=True).dump(orders))


# ---------- post-delivery rating ----------


@api_bp.post("/me/orders/<int:order_id>/rating")
@jwt_required()
def rate_order(order_id: int):
    """Submit a 1-5 star rating + optional tags + comment for one of the
    caller's own delivered orders. One-shot — a re-submit returns 409.

    Payload:
      {
        "rating":  int 1-5           (required),
        "tags":    [str, ...]        (optional, capped at 10 items, each ≤ 60 chars),
        "comment": str               (optional, ≤ 500 chars)
      }
    """
    c = _current()
    o = db.session.get(Order, order_id)
    if o is None or o.customer_id != c.id:
        # 404 not 403 — don't leak whether the id exists for someone else.
        abort(404)
    if o.status != OrderStatus.delivered:
        return jsonify(error="not_deliverable",
                       message="التقييم متاح فقط للطلبات التي تم تسليمها"), 422
    if o.rating is not None:
        return jsonify(error="already_rated",
                       message="سبق أن قيّمت هذا الطلب — التقييم لا يعدَّل"), 409

    body = request.get_json(silent=True) or {}
    try:
        rating = int(body.get("rating"))
    except (TypeError, ValueError):
        return jsonify(error="validation_error", message="التقييم مطلوب (رقم من 1 إلى 5)"), 422
    if rating < 1 or rating > 5:
        return jsonify(error="validation_error", message="التقييم يجب أن يكون بين 1 و 5"), 422

    tags_raw = body.get("tags")
    tags: list[str] | None = None
    if tags_raw is not None:
        if not isinstance(tags_raw, list):
            return jsonify(error="validation_error", message="tags يجب أن تكون قائمة نصية"), 422
        clean = []
        for t in tags_raw[:10]:
            s = str(t).strip()
            if s:
                clean.append(s[:60])
        tags = clean or None

    comment = body.get("comment")
    if comment is not None:
        comment = str(comment).strip()
        if len(comment) > 500:
            return jsonify(error="validation_error", message="التعليق أطول من 500 حرف"), 422
        if not comment:
            comment = None

    o.rating = rating
    o.rating_tags = tags
    o.rating_comment = comment
    o.rating_submitted_at = datetime.now(timezone.utc)
    db.session.commit()

    return jsonify({
        "ok": True,
        "rating": o.rating,
        "tags": o.rating_tags,
        "comment": o.rating_comment,
        "submitted_at": o.rating_submitted_at.isoformat(),
    })


# ---------- saved addresses ----------


@api_bp.get("/me/addresses")
@jwt_required()
def list_addresses():
    c = _current()
    return jsonify([_address_dto(a) for a in c.saved_addresses])


@api_bp.post("/me/addresses")
@jwt_required()
def create_address():
    c = _current()
    body = request.get_json(silent=True) or {}
    label = (body.get("label") or "").strip()
    text = (body.get("address_text") or "").strip()
    if not label or not text:
        return jsonify(error="validation_error", message="التسمية والعنوان إجباريان"), 422
    a = SavedAddress(
        customer_id=c.id,
        label=label,
        address_text=text,
        is_default=bool(body.get("is_default", False)),
        sort_order=int(body.get("sort_order") or 0),
    )
    if a.is_default:
        # Only one default at a time.
        for other in c.saved_addresses:
            if other.is_default:
                other.is_default = False
    db.session.add(a)
    db.session.commit()
    return jsonify(_address_dto(a)), 201


@api_bp.patch("/me/addresses/<int:address_id>")
@jwt_required()
def update_address(address_id: int):
    c = _current()
    a = db.session.get(SavedAddress, address_id)
    if a is None or a.customer_id != c.id:
        abort(404)
    body = request.get_json(silent=True) or {}
    if "label" in body:
        a.label = str(body["label"]).strip()
    if "address_text" in body:
        a.address_text = str(body["address_text"]).strip()
    if "sort_order" in body:
        try:
            a.sort_order = int(body["sort_order"])
        except ValueError:
            pass
    if body.get("is_default") is True:
        for other in c.saved_addresses:
            if other.id != a.id and other.is_default:
                other.is_default = False
        a.is_default = True
    elif body.get("is_default") is False:
        a.is_default = False
    db.session.commit()
    return jsonify(_address_dto(a))


@api_bp.delete("/me/addresses/<int:address_id>")
@jwt_required()
def delete_address(address_id: int):
    c = _current()
    a = db.session.get(SavedAddress, address_id)
    if a is None or a.customer_id != c.id:
        abort(404)
    db.session.delete(a)
    db.session.commit()
    return jsonify({"ok": True})


# ---------- account deletion (GDPR-style right to erasure) ----------


@api_bp.delete("/me")
@jwt_required()
def delete_account():
    """Delete the caller's account.

    What actually happens under Saudi tax + invoicing law (5-year invoice
    retention): personal identifiers are scrubbed from every past order
    but the order rows themselves stay for accounting. Everything else
    that ties the account to a person is destroyed:

      * saved addresses  → cascade-deleted by the customer FK
      * OTP codes for the phone → deleted (invalidates any pending code)
      * loyalty ledger rows → cascade-deleted by the customer FK
      * customer row → deleted (orders.customer_id nulls out via FK)
      * orders.customer_name / customer_phone / delivery_address
        → overwritten with "محذوف" / random synthetic phone so the row
        stays queryable for invoicing but the person is no longer
        identifiable through it

    The response is 204 No Content; the client must clear its local
    session and route home. A 30-day soft-delete window is not
    implemented — deletion is immediate and irreversible, matching what
    the /account/delete page promises to the customer.
    """
    from app.models import LoyaltyLedger, OtpCode

    c = _current()
    cid = c.id
    cphone = c.phone

    # Scrub PII from historical orders (retention required, identity is not).
    for o in db.session.query(Order).filter(Order.customer_id == cid).all():
        o.customer_name = "عميل محذوف"
        o.customer_phone = f"deleted-{cid}"
        o.delivery_address = None
        o.notes = None
        # rating comment could be PII too — safest to clear
        o.rating_comment = None

    # Kill pending OTP codes for the phone so the number can't be reused
    # to log back into this (now-deleted) identity.
    db.session.query(OtpCode).filter(OtpCode.phone == cphone).delete(synchronize_session=False)

    # Explicit loyalty ledger cleanup — the FK is CASCADE, but being
    # explicit here documents intent + survives a future FK change.
    db.session.query(LoyaltyLedger).filter(LoyaltyLedger.customer_id == cid).delete(synchronize_session=False)

    # Saved addresses cascade from the customer FK; explicit delete
    # is still cheap and clearer than relying on FK behaviour.
    db.session.query(SavedAddress).filter(SavedAddress.customer_id == cid).delete(synchronize_session=False)

    # Finally the customer row itself. orders.customer_id nulls out via
    # its own SET NULL FK, so historical rows are preserved.
    db.session.delete(c)
    db.session.commit()

    # 204 No Content — the client discards its JWT + local state.
    return ("", 204)
