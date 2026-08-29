"""Admin CRUD for cross-sell links (E2 US2.6).

Scoped to the parent item. All actions land back on the item edit page so the
staff sees the updated list right away.
"""
from flask import flash, redirect, request, url_for
from flask_login import login_required

from app.extensions import db
from app.models import Item, ItemCrossSell

from . import admin_bp


@admin_bp.post("/items/<int:item_id>/cross_sells/add")
@login_required
def cross_sells_add(item_id: int):
    parent = db.session.get(Item, item_id)
    if parent is None:
        flash("الصنف غير موجود", "warning")
        return redirect(url_for("admin.items_list"))

    raw = (request.form.get("recommended_item_id") or "").strip()
    try:
        rec_id = int(raw)
    except ValueError:
        flash("اختر صنفاً صحيحاً", "danger")
        return redirect(url_for("admin.items_edit", item_id=item_id))

    if rec_id == parent.id:
        flash("لا يمكن ربط الصنف بنفسه", "danger")
        return redirect(url_for("admin.items_edit", item_id=item_id))

    rec = db.session.get(Item, rec_id)
    if rec is None or not rec.is_active:
        flash("الصنف المقترح غير موجود أو غير مفعّل", "danger")
        return redirect(url_for("admin.items_edit", item_id=item_id))

    already = (
        db.session.query(ItemCrossSell)
        .filter_by(item_id=parent.id, recommended_item_id=rec.id)
        .first()
    )
    if already is not None:
        flash("هذا الترشيح مضاف مسبقاً", "warning")
        return redirect(url_for("admin.items_edit", item_id=item_id))

    sort_order = 0
    raw_sort = request.form.get("sort_order")
    if raw_sort:
        try:
            sort_order = int(raw_sort)
        except ValueError:
            sort_order = 0

    link = ItemCrossSell(
        item_id=parent.id, recommended_item_id=rec.id, sort_order=sort_order
    )
    db.session.add(link)
    db.session.commit()
    flash("تم إضافة الترشيح", "success")
    return redirect(url_for("admin.items_edit", item_id=item_id))


@admin_bp.post("/items/<int:item_id>/cross_sells/<int:link_id>/remove")
@login_required
def cross_sells_remove(item_id: int, link_id: int):
    link = db.session.get(ItemCrossSell, link_id)
    if link is not None and link.item_id == item_id:
        db.session.delete(link)
        db.session.commit()
        flash("تم حذف الترشيح", "info")
    return redirect(url_for("admin.items_edit", item_id=item_id))


@admin_bp.post("/items/<int:item_id>/cross_sells/<int:link_id>/reorder")
@login_required
def cross_sells_reorder(item_id: int, link_id: int):
    link = db.session.get(ItemCrossSell, link_id)
    if link is None or link.item_id != item_id:
        return redirect(url_for("admin.items_edit", item_id=item_id))
    try:
        link.sort_order = int(request.form.get("sort_order") or 0)
        db.session.commit()
        flash("تم تحديث الترتيب", "success")
    except ValueError:
        flash("قيمة ترتيب غير صحيحة", "danger")
    return redirect(url_for("admin.items_edit", item_id=item_id))
