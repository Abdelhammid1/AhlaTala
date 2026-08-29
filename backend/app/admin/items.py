"""Admin CRUD for Items. Item edit page also lists the item's OptionGroups inline."""
from decimal import Decimal, InvalidOperation

from flask import flash, redirect, render_template, request, url_for
from flask_login import login_required

from app.extensions import db
from app.models import Category, Item
from app.uploads import save_image

from . import admin_bp


def _parse_decimal(raw: str | None) -> Decimal:
    try:
        return Decimal(raw or "0")
    except InvalidOperation:
        return Decimal("0")


def _parse_int_or_none(raw: str | None) -> int | None:
    if raw in (None, ""):
        return None
    try:
        return int(raw)
    except ValueError:
        return None


def _apply_form(item: Item) -> None:
    item.name_ar = (request.form.get("name_ar") or "").strip()
    item.name_en = (request.form.get("name_en") or "").strip() or None
    item.description_ar = (request.form.get("description_ar") or "").strip() or None
    item.description_en = (request.form.get("description_en") or "").strip() or None
    item.category_id = int(request.form.get("category_id") or 0)
    item.base_price = _parse_decimal(request.form.get("base_price"))
    item.calories = _parse_int_or_none(request.form.get("calories"))
    item.sort_order = int(request.form.get("sort_order") or 0)
    item.is_active = "is_active" in request.form
    image = save_image(request.files.get("image"), "items")
    if image:
        item.image_path = image


@admin_bp.get("/items")
@login_required
def items_list():
    cat_filter = _parse_int_or_none(request.args.get("category"))
    q = db.session.query(Item)
    if cat_filter:
        q = q.filter(Item.category_id == cat_filter)
    items = q.order_by(Item.category_id.asc(), Item.sort_order.asc(), Item.id.asc()).all()
    cats = db.session.query(Category).order_by(Category.sort_order.asc()).all()
    return render_template(
        "items/list.html", items=items, categories=cats, cat_filter=cat_filter
    )


@admin_bp.route("/items/new", methods=["GET", "POST"])
@login_required
def items_new():
    cats = db.session.query(Category).order_by(Category.sort_order.asc()).all()
    if not cats:
        flash("أنشئ فئة أولاً قبل إضافة صنف", "warning")
        return redirect(url_for("admin.categories_list"))

    if request.method == "POST":
        item = Item()
        _apply_form(item)
        if not item.name_ar or not item.category_id:
            flash("الاسم بالعربي والفئة إجباريان", "danger")
            return render_template("items/form.html", item=item, categories=cats)
        db.session.add(item)
        db.session.commit()
        flash("تم إنشاء الصنف", "success")
        return redirect(url_for("admin.items_edit", item_id=item.id))

    return render_template("items/form.html", item=None, categories=cats)


@admin_bp.route("/items/<int:item_id>/edit", methods=["GET", "POST"])
@login_required
def items_edit(item_id: int):
    item = db.session.get(Item, item_id)
    if item is None:
        flash("الصنف غير موجود", "warning")
        return redirect(url_for("admin.items_list"))
    cats = db.session.query(Category).order_by(Category.sort_order.asc()).all()

    if request.method == "POST":
        _apply_form(item)
        db.session.commit()
        flash("تم حفظ التعديلات", "success")
        return redirect(url_for("admin.items_edit", item_id=item.id))

    # Candidates for the cross-sell picker: active items other than this one,
    # not already linked.
    already_linked = {link.recommended_item_id for link in item.cross_sells}
    already_linked.add(item.id)
    cross_sell_candidates = (
        db.session.query(Item)
        .filter(Item.is_active.is_(True), Item.id.notin_(already_linked))
        .order_by(Item.category_id.asc(), Item.name_ar.asc())
        .all()
    )

    return render_template(
        "items/form.html",
        item=item,
        categories=cats,
        cross_sell_candidates=cross_sell_candidates,
    )


@admin_bp.post("/items/<int:item_id>/delete")
@login_required
def items_delete(item_id: int):
    item = db.session.get(Item, item_id)
    if item is not None:
        db.session.delete(item)
        db.session.commit()
        flash("تم حذف الصنف", "info")
    return redirect(url_for("admin.items_list"))
