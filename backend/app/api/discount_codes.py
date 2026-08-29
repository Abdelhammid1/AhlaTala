"""E6 — POST /api/v1/discount-codes/preview.

Public, no auth (matches guest posture). Returns a 200 with the computed
discount, or a 422 with `{error, message}` where `error` is a stable slug
and `message` is the Arabic user-facing string.
"""
from decimal import Decimal, InvalidOperation

from flask import jsonify, request

from app.discounts import DiscountError, preview

from . import api_bp


@api_bp.post("/discount-codes/preview")
def preview_discount_code():
    body = request.get_json(silent=True) or {}
    code = body.get("code")
    try:
        subtotal = Decimal(str(body.get("subtotal") or "0"))
    except InvalidOperation:
        return jsonify(error="validation_error", message="subtotal غير صحيح"), 422

    # If the client is also redeeming points, we preview against the post-points subtotal.
    try:
        points_discount = Decimal(str(body.get("points_discount") or "0"))
    except InvalidOperation:
        points_discount = Decimal("0")
    subtotal_after_points = subtotal - points_discount
    if subtotal_after_points < Decimal("0"):
        subtotal_after_points = Decimal("0")

    try:
        result = preview(code or "", subtotal_after_points)
    except DiscountError as e:
        return jsonify(error=e.slug, message=e.message), 422

    return jsonify({
        "code_id": result.code_id,
        "code": result.code,
        "kind": result.kind,
        "value": str(result.value),
        "discount_amount": str(result.discount_amount),
    })
