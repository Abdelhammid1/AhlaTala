"""GET /api/v1/settings — thin exposure of runtime knobs the mobile app needs.

Started life in E2 with delivery_fee + currency. E5 added loyalty rates so
the client-side redemption widget can preview a discount before hitting the
server.
"""
from flask import current_app, jsonify

from app.models import LoyaltySettings

from . import api_bp


@api_bp.get("/settings")
def get_settings():
    loyalty = LoyaltySettings.instance()
    return jsonify({
        "delivery_fee": str(current_app.config["DELIVERY_FEE"]),
        "currency": current_app.config["CURRENCY"],
        "points_per_riyal": str(loyalty.points_per_riyal),
        "riyal_per_point": str(loyalty.riyal_per_point),
        "min_redeem_points": loyalty.min_redeem_points,
    })
