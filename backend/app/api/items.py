"""GET /api/v1/items/<id> — full item with nested option groups + options.
GET /api/v1/items/<id>/cross_sells — sibling items recommended alongside this one (E2 US2.4).
"""
from flask import abort, jsonify

from app.extensions import db
from app.models import Item, ItemCrossSell

from . import api_bp
from .schemas import ItemDetailSchema, ItemListSchema


@api_bp.get("/items/<int:item_id>")
def item_detail(item_id: int):
    item = db.session.get(Item, item_id)
    if item is None or not item.is_active:
        abort(404, description="Item not found")
    return jsonify(ItemDetailSchema().dump(item))


@api_bp.get("/items/<int:item_id>/cross_sells")
def item_cross_sells(item_id: int):
    item = db.session.get(Item, item_id)
    if item is None or not item.is_active:
        abort(404, description="Item not found")
    # Skip inactive recommendations so the mobile side never has to.
    recs = [
        link.recommended
        for link in sorted(item.cross_sells, key=lambda l: l.sort_order)
        if link.recommended is not None and link.recommended.is_active
    ]
    return jsonify(ItemListSchema(many=True).dump(recs))
