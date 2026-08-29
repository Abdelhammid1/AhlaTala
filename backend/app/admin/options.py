"""Admin CRUD for Options — always scoped to a specific OptionGroup.

Server-side rules (from US1.4 / US1.6):
    - if the parent group is `remove`, price_delta MUST be 0
    - in a `single` group, at most one Option can have is_default=True
"""
from decimal import Decimal, InvalidOperation

from flask import flash, redirect, render_template, request, url_for
from flask_login import login_required

from app.extensions import db
from app.models import Option, OptionGroup, OptionGroupKind, SelectionType
from app.uploads import save_image

from . import admin_bp


def _apply_form(opt: Option, group: OptionGroup) -> tuple[bool, str | None]:
    opt.name_ar = (request.form.get("name_ar") or "").strip()
    opt.name_en = (request.form.get("name_en") or "").strip() or None

    raw_price = request.form.get("price_delta") or "0"
    try:
        opt.price_delta = Decimal(raw_price)
    except InvalidOperation:
        return False, "قيمة السعر غير صحيحة"

    if group.kind == OptionGroupKind.remove and opt.price_delta != 0:
        return False, "خيارات مجموعة الحذف يجب أن تكون بسعر إضافي = 0"

    opt.is_default = "is_default" in request.form
    opt.is_active = "is_active" in request.form
    opt.sort_order = int(request.form.get("sort_order") or 0)

    image = save_image(request.files.get("image"), "options")
    if image:
        opt.image_path = image

    if not opt.name_ar:
        return False, "الاسم بالعربي إجباري"

    # If single-select group, unset any other default before setting this one
    if opt.is_default and group.selection_type == SelectionType.single:
        for sibling in group.options:
            if sibling is not opt:
                sibling.is_default = False

    return True, None


@admin_bp.route("/items/<int:item_id>/groups/<int:group_id>/options/new", methods=["GET", "POST"])
@login_required
def options_new(item_id: int, group_id: int):
    group = db.session.get(OptionGroup, group_id)
    if group is None or group.item_id != item_id:
        flash("مجموعة الاختيارات غير موجودة", "warning")
        return redirect(url_for("admin.items_edit", item_id=item_id))

    if request.method == "POST":
        opt = Option(option_group_id=group.id)
        ok, err = _apply_form(opt, group)
        if not ok:
            flash(err, "danger")
            return render_template("options/form.html", item_id=item_id, group=group, option=opt)
        db.session.add(opt)
        db.session.commit()
        flash("تم إنشاء الخيار", "success")
        return redirect(url_for("admin.option_groups_edit", item_id=item_id, group_id=group.id))

    return render_template("options/form.html", item_id=item_id, group=group, option=None)


@admin_bp.route(
    "/items/<int:item_id>/groups/<int:group_id>/options/<int:option_id>/edit",
    methods=["GET", "POST"],
)
@login_required
def options_edit(item_id: int, group_id: int, option_id: int):
    group = db.session.get(OptionGroup, group_id)
    opt = db.session.get(Option, option_id)
    if group is None or opt is None or group.item_id != item_id or opt.option_group_id != group.id:
        flash("الخيار غير موجود", "warning")
        return redirect(url_for("admin.items_edit", item_id=item_id))

    if request.method == "POST":
        ok, err = _apply_form(opt, group)
        if not ok:
            flash(err, "danger")
            return render_template("options/form.html", item_id=item_id, group=group, option=opt)
        db.session.commit()
        flash("تم حفظ التعديلات", "success")
        return redirect(url_for("admin.option_groups_edit", item_id=item_id, group_id=group.id))

    return render_template("options/form.html", item_id=item_id, group=group, option=opt)


@admin_bp.post("/items/<int:item_id>/groups/<int:group_id>/options/<int:option_id>/delete")
@login_required
def options_delete(item_id: int, group_id: int, option_id: int):
    opt = db.session.get(Option, option_id)
    if opt is not None and opt.option_group_id == group_id:
        db.session.delete(opt)
        db.session.commit()
        flash("تم حذف الخيار", "info")
    return redirect(url_for("admin.option_groups_edit", item_id=item_id, group_id=group_id))
