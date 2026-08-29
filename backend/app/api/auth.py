"""E9 — POST /auth/otp/request and /auth/otp/verify."""
from flask import current_app, jsonify, request

from app.otp import OTP_TTL_SECONDS, OtpError, generate_and_send, verify

from . import api_bp


@api_bp.post("/auth/otp/request")
def request_otp():
    body = request.get_json(silent=True) or {}
    phone = (body.get("phone") or "").strip()
    try:
        _, code = generate_and_send(phone)
    except OtpError as e:
        return jsonify(error=e.slug, message=e.message), 422

    payload = {
        "sent_to": phone,
        "expires_in": OTP_TTL_SECONDS,
        "note": "دفع الكود إلى سجل الخادم (LoggingSender). سيتم استبداله بموفر SMS لاحقاً.",
    }
    # Dev convenience: include the code in the response body when we're
    # running with an insecure sender AND debug is on. Turns off automatically
    # the moment an SMS provider is configured (OTP_SENDER=sms) or DEBUG=0.
    import os
    if current_app.debug and (os.getenv("OTP_SENDER") or "logging").lower() == "logging":
        payload["dev_code"] = code
    return jsonify(payload)


@api_bp.post("/auth/otp/verify")
def verify_otp():
    body = request.get_json(silent=True) or {}
    phone = (body.get("phone") or "").strip()
    code = (body.get("code") or "").strip()
    try:
        customer, token = verify(phone, code)
    except OtpError as e:
        return jsonify(error=e.slug, message=e.message), 422
    return jsonify({
        "access_token": token,
        "customer": {
            "customer_id": customer.id,
            "phone": customer.phone,
            "name": customer.name,
            "points_balance": customer.points_balance,
            "verified_at": customer.verified_at.isoformat() if customer.verified_at else None,
        },
    })
