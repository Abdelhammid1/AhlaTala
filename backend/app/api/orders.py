"""E3 — Orders + Payments API.

POST /api/v1/orders            — create an order from a cart-shaped body.
GET  /api/v1/orders/<id>       — read one order (for the confirmation screen).
POST /api/v1/orders/<id>/confirm — mark order confirmed (stub-gateway callback,
                                    real-gateway webhook, or return URL).
POST /api/v1/orders/<id>/fail    — mark order failed.
GET  /api/v1/payments/stub/<id> — a tiny redirect_url target for the stub
                                    provider so the client always sees a valid
                                    URL in the response.

Price authority is server-side: the client sends only item ids + option ids +
quantities; every currency figure is recomputed against active DB rows.
"""
from datetime import datetime, timezone
from decimal import Decimal

from flask import abort, current_app, jsonify, request
from flask_jwt_extended import get_jwt_identity, verify_jwt_in_request
from marshmallow import ValidationError

from app.extensions import db
from app.discounts import DiscountError, apply as apply_discount, preview as preview_discount
from app.loyalty import preview_redemption, redeem, upsert_customer
from app.models import (
    FulfillmentType,
    Item,
    Option,
    Order,
    OrderLine,
    OrderLineSelection,
    OrderStatus,
    PaymentMethod,
    SelectionType,
)
from app.payments import PaymentStatus, get_provider

from . import api_bp
from .order_schemas import OrderCreateSchema, OrderSchema


# ---------- POST /api/v1/orders ----------


@api_bp.post("/orders")
def create_order():
    try:
        payload = OrderCreateSchema().load(request.get_json(silent=True) or {})
    except ValidationError as e:
        return jsonify(error="validation_error", details=e.messages), 422

    # Enum coercion (marshmallow keeps them as strings by design)
    try:
        ful_type = FulfillmentType(payload["fulfillment_type"])
        pay_method = PaymentMethod(payload["payment_method"])
    except ValueError:
        return jsonify(error="validation_error", details="bad enum"), 422

    if ful_type == FulfillmentType.delivery:
        address = (payload.get("delivery_address") or "").strip()
        if len(address) < 5:
            return jsonify(error="validation_error", details="delivery_address required"), 422
    else:
        address = None

    lines_payload = payload.get("lines") or []
    if not lines_payload:
        return jsonify(error="validation_error", details="cart is empty"), 422

    # ---- server-side price authority + validation ----
    order_lines: list[OrderLine] = []
    subtotal = Decimal("0.00")

    for idx, ln in enumerate(lines_payload):
        item = db.session.get(Item, ln["item_id"])
        if item is None or not item.is_active:
            return jsonify(error="validation_error", details=f"item {ln['item_id']} unavailable"), 422

        quantity = int(ln.get("quantity") or 1)
        if quantity < 1:
            return jsonify(error="validation_error", details=f"line {idx}: bad quantity"), 422

        selections_snapshot: list[OrderLineSelection] = []
        picked_by_group: dict[int, list[int]] = {}

        for sel in ln.get("selections") or []:
            option = db.session.get(Option, sel["option_id"])
            if option is None or not option.is_active:
                return jsonify(error="validation_error", details=f"option {sel['option_id']} unavailable"), 422
            group = option.group
            if group is None or group.item_id != item.id:
                return jsonify(error="validation_error", details="option/item mismatch"), 422
            if sel.get("group_id") is not None and int(sel["group_id"]) != group.id:
                return jsonify(error="validation_error", details="option/group mismatch"), 422

            picked_by_group.setdefault(group.id, []).append(option.id)
            selections_snapshot.append(OrderLineSelection(
                group_id_snapshot=group.id,
                group_name_ar_snapshot=group.name_ar,
                group_kind_snapshot=group.kind.value,
                option_id_snapshot=option.id,
                option_name_ar_snapshot=option.name_ar,
                price_delta_snapshot=option.price_delta,
            ))

        # Required groups on the DB item must all be satisfied
        for g in item.option_groups:
            if not g.is_required:
                continue
            if not picked_by_group.get(g.id):
                return jsonify(
                    error="validation_error",
                    details=f"required option group '{g.name_ar}' not selected",
                ), 422
            if g.selection_type == SelectionType.single and len(picked_by_group[g.id]) > 1:
                return jsonify(error="validation_error", details=f"group '{g.name_ar}' expects one choice"), 422

        unit_price = item.base_price + sum(
            (sel.price_delta_snapshot for sel in selections_snapshot), Decimal("0.00")
        )
        line_price = unit_price * quantity
        subtotal += line_price

        order_line = OrderLine(
            item_id=item.id,
            name_ar_snapshot=item.name_ar,
            image_path_snapshot=item.image_path,
            base_price_snapshot=item.base_price,
            quantity=quantity,
            unit_price=unit_price,
            line_price=line_price,
            sort_order=idx,
            selections=selections_snapshot,
        )
        order_lines.append(order_line)

    delivery_fee = (
        Decimal(str(current_app.config["DELIVERY_FEE"]))
        if ful_type == FulfillmentType.delivery
        else Decimal("0.00")
    )

    # E5 — upsert customer, then evaluate any redemption request against the DB.
    # E9: if the client sent a JWT, use that identity directly so an
    # authenticated customer's orders always land on the right row (no risk
    # of a typo in the phone field re-routing history to someone else).
    customer = None
    try:
        verify_jwt_in_request(optional=True)
        ident = get_jwt_identity()
        if ident is not None:
            from app.models import Customer  # local import to keep top clean
            customer = db.session.get(Customer, int(ident))
    except Exception:
        customer = None
    if customer is None:
        customer = upsert_customer(
            payload["customer_phone"].strip(), payload["customer_name"].strip()
        )
    requested_points = int(payload.get("points_to_redeem") or 0)
    applied_points, points_discount = preview_redemption(
        customer, subtotal, requested_points
    )

    # E6 — optional discount code. Applied against the post-points subtotal so
    # the two stack without double-dipping on the loyalty-discounted portion.
    code_discount = Decimal("0.00")
    code_preview = None
    raw_code = (payload.get("discount_code") or "").strip()
    if raw_code:
        subtotal_after_points = subtotal - points_discount
        if subtotal_after_points < Decimal("0"):
            subtotal_after_points = Decimal("0")
        try:
            code_preview = preview_discount(raw_code, subtotal_after_points)
            code_discount = code_preview.discount_amount
        except DiscountError as e:
            return jsonify(error=e.slug, message=e.message), 422

    total_discount = points_discount + code_discount
    if total_discount > subtotal:
        total_discount = subtotal
    total = subtotal + delivery_fee - total_discount

    order = Order(
        status=OrderStatus.created,
        fulfillment_type=ful_type,
        delivery_address=address,
        customer_name=payload["customer_name"].strip(),
        customer_phone=payload["customer_phone"].strip(),
        customer_id=customer.id,
        subtotal=subtotal,
        delivery_fee=delivery_fee,
        discount_amount=total_discount,
        points_discount=points_discount,
        code_discount=code_discount,
        total=total,
        points_redeemed=applied_points,
        payment_method=pay_method,
        notes=(payload.get("notes") or None),
        lines=order_lines,
    )
    db.session.add(order)
    db.session.flush()  # get order.id assigned so the payment provider can reference it

    if applied_points > 0:
        redeem(customer, order, applied_points)
    if code_preview is not None:
        apply_discount(code_preview.code_id, order, code_discount)

    # Start payment (mutates order.status for cash)
    provider = get_provider(pay_method)
    result = provider.start(order)

    db.session.commit()

    return jsonify({
        "order": OrderSchema().dump(order),
        "payment": result.to_json(),
    }), 201


# ---------- GET /api/v1/orders/<id> ----------


@api_bp.get("/orders/<int:order_id>")
def get_order(order_id: int):
    order = db.session.get(Order, order_id)
    if order is None:
        abort(404, description="Order not found")
    return jsonify(OrderSchema().dump(order))


# ---------- POST /api/v1/orders/<id>/confirm ----------


@api_bp.post("/orders/<int:order_id>/confirm")
def confirm_order(order_id: int):
    order = db.session.get(Order, order_id)
    if order is None:
        abort(404, description="Order not found")
    if order.status == OrderStatus.confirmed:
        # Idempotent — real gateways deliver webhooks more than once
        return jsonify(OrderSchema().dump(order))
    if order.status in (OrderStatus.cancelled, OrderStatus.failed):
        return jsonify(error="conflict", message=f"order status={order.status.value}"), 409

    body = request.get_json(silent=True) or {}
    ref = (body.get("reference") or "").strip() or None

    order.status = OrderStatus.confirmed
    order.confirmed_at = datetime.now(timezone.utc)
    if ref:
        order.payment_reference = ref
    db.session.commit()
    return jsonify(OrderSchema().dump(order))


# ---------- POST /api/v1/orders/<id>/fail ----------


@api_bp.post("/orders/<int:order_id>/fail")
def fail_order(order_id: int):
    order = db.session.get(Order, order_id)
    if order is None:
        abort(404, description="Order not found")
    if order.status == OrderStatus.confirmed:
        return jsonify(error="conflict", message="order already confirmed"), 409

    order.status = OrderStatus.failed
    db.session.commit()
    return jsonify(OrderSchema().dump(order))


# ---------- GET /api/v1/payments/stub/<id> ----------


@api_bp.get("/payments/stub/<int:order_id>")
def payment_stub_page(order_id: int):
    """Tiny landing so the redirect_url the stub provider returns is a live URL."""
    return jsonify({
        "order_id": order_id,
        "message": "بوابة الدفع (محاكاة). التطبيق يعرض شاشة المحاكاة داخلياً.",
    })
