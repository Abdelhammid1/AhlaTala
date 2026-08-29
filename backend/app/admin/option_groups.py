"""Admin CRUD for OptionGroups. Always scoped to a specific Item.

Server-side validation enforces the doc's rules (US1.4/1.6):
    - remove-kind group -> is_required must be False, and every option's price_delta must be 0
    - required single-select group must have at least 1 option (checked at option list level)
"""
from flask import flash, redirect, render_template, request, url_for
from flask_login import login_required

from app.extensions import db
from app.models import Item, OptionGroup, OptionGroupKind, SelectionType

from . import admin_bp


def _apply_form(og: OptionGroup) -> tuple[bool, str | None]:
    og.name_ar = (request.form.get("name_ar") or "").strip()
    og.name_en = (request.form.get("name_en") or "").strip() or None
    kind_raw = request.form.get("kind") or "size"
    sel_raw = request.form.get("selection_type") or "single"
    try:
        og.kind = OptionGroupKind(kind_raw)
        og.selection_type = SelectionType(sel_raw)
    except ValueError:
        return False, "قيمة النوع أو نوع الاختيار غير صحيحة"

    og.is_required = "is_required" in request.form
    og.sort_order = int(request.form.get("sort_order") or 0)

    # Rule: remove-kind cannot be required
    if og.kind == OptionGroupKind.remove and og.is_required:
        return False, "مجموعة الحذف لا يمكن أن تكون إجبارية"
    # Rule: remove-kind must be multi
    if og.kind == OptionGroupKind.remove and og.selection_type != SelectionType.multi:
        return False, "مجموعة الحذف يجب أن تكون اختيار متعدد"

    if not og.name_ar:
        return False, "الاسم بالعربي إجباري"

    return True, None


@admin_bp.route("/items/<int:item_id>/groups/new", methods=["GET", "POST"])
@login_required
def option_groups_new(item_id: int):
    item = db.session.get(Item, item_id)
    if item is None:
        flash("الصنف غير موجود", "warning")
        return redirect(url_for("admin.items_list"))

    if request.method == "POST":
        og = OptionGroup(item_id=item.id)
        ok, err = _apply_form(og)
        if not ok:
            flash(err, "danger")
            return render_template("option_groups/form.html", item=item, group=og)
        db.session.add(og)
        db.session.commit()
        flash("تم إنشاء مجموعة الاختيارات", "success")
        return redirect(url_for("admin.option_groups_edit", item_id=item.id, group_id=og.id))

    return render_template("option_groups/form.html", item=item, group=None)


@admin_bp.route("/items/<int:item_id>/groups/<int:group_id>/edit", methods=["GET", "POST"])
@login_required
def option_groups_edit(item_id: int, group_id: int):
    item = db.session.get(Item, item_id)
    og = db.session.get(OptionGroup, group_id)
    if item is None or og is None or og.item_id != item.id:
        flash("مجموعة الاختيارات غير موجودة", "warning")
        return redirect(url_for("admin.items_edit", item_id=item_id))

    if request.method == "POST":
        ok, err = _apply_form(og)
        if not ok:
            flash(err, "danger")
            return render_template("option_groups/form.html", item=item, group=og)
        db.session.commit()
        flash("تم حفظ التعديلات", "success")
        return redirect(url_for("admin.option_groups_edit", item_id=item.id, group_id=og.id))

    return render_template("option_groups/form.html", item=item, group=og)


@admin_bp.post("/items/<int:item_id>/groups/<int:group_id>/delete")
@login_required
def option_groups_delete(item_id: int, group_id: int):
    og = db.session.get(OptionGroup, group_id)
    if og is not None and og.item_id == item_id:
        db.session.delete(og)
        db.session.commit()
        flash("تم حذف مجموعة الاختيارات", "info")
    return redirect(url_for("admin.items_edit", item_id=item_id))
