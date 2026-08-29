"""GET /api/v1/categories  and  GET /api/v1/categories/<id>/items"""
from flask import abort, jsonify

from app.extensions import db
from app.models import Category, Item

from . import api_bp
from .schemas import CategoryListSchema, ItemListSchema


@api_bp.get("/categories")
def list_categories():
    cats = (
        db.session.query(Category)
        .filter(Category.is_active.is_(True))
        .order_by(Category.sort_order.asc(), Category.id.asc())
        .all()
    )
    return jsonify(CategoryListSchema(many=True).dump(cats))


@api_bp.get("/categories/<int:category_id>/items")
def list_items_in_category(category_id: int):
    cat = db.session.get(Category, category_id)
    if cat is None or not cat.is_active:
        abort(404, description="Category not found")

    items = (
        db.session.query(Item)
        .filter(Item.category_id == category_id, Item.is_active.is_(True))
        .order_by(Item.sort_order.asc(), Item.id.asc())
        .all()
    )
    return jsonify(ItemListSchema(many=True).dump(items))
