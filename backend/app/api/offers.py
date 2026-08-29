"""E7 — GET /api/v1/offers  and  GET /api/v1/most-ordered."""
from datetime import datetime, timezone

from flask import jsonify, request
from marshmallow import Schema, fields
from sqlalchemy import func

from app.extensions import db
from app.models import Item, Offer, Order, OrderLine, OrderStatus
from app.uploads import absolute_url

from . import api_bp
from .schemas import ItemListSchema


class OfferSchema(Schema):
    id = fields.Int()
    title_ar = fields.Str()
    description_ar = fields.Str(allow_none=True)
    image_url = fields.Method("get_image_url")
    starts_at = fields.DateTime()
    ends_at = fields.DateTime()
    linked_item_id = fields.Int(allow_none=True)
    sort_order = fields.Int()

    def get_image_url(self, obj):
        if not obj.image_path:
            return None
        return absolute_url(obj.image_path, request.host_url)


@api_bp.get("/offers")
def list_offers():
    now = datetime.now(timezone.utc)
    offers = (
        db.session.query(Offer)
        .filter(
            Offer.is_active.is_(True),
            Offer.starts_at <= now,
            Offer.ends_at >= now,
        )
        .order_by(Offer.sort_order.asc(), Offer.starts_at.asc())
        .all()
    )
    return jsonify(OfferSchema(many=True).dump(offers))


@api_bp.get("/most-ordered")
def most_ordered():
    """Top items by summed order-line quantity across delivered orders.

    Aggregates in SQL so the mobile app doesn't page through orders. Only
    counts `delivered` — an in-flight or cancelled order shouldn't inflate
    the list. Items that were deleted (item_id IS NULL on the line) are
    naturally excluded by the inner join.
    """
    try:
        limit = int(request.args.get("limit") or 8)
    except ValueError:
        limit = 8
    limit = max(1, min(limit, 20))

    total_qty = func.sum(OrderLine.quantity).label("total_qty")
    rows = (
        db.session.query(Item, total_qty)
        .join(OrderLine, OrderLine.item_id == Item.id)
        .join(Order, Order.id == OrderLine.order_id)
        .filter(Order.status == OrderStatus.delivered, Item.is_active.is_(True))
        .group_by(Item.id)
        .order_by(total_qty.desc(), Item.id.asc())
        .limit(limit)
        .all()
    )
    items = [row[0] for row in rows]
    return jsonify(ItemListSchema(many=True).dump(items))
