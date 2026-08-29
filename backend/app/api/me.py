"""E9 authenticated endpoints — everything under /api/v1/me.

`current_customer_id()` reads the JWT identity claim (a stringified
customer id — flask-jwt-extended 4.x expects strings, so we cast on
mint + on read).
"""
from flask import abort, jsonify, request
from flask_jwt_extended import get_jwt_identity, jwt_required

from app.extensions import db
from app.models import Customer, Order, SavedAddress

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
