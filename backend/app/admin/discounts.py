"""Admin CRUD for discount codes (E6 US6.1)."""
from datetime import datetime, timezone
from decimal import Decimal, InvalidOperation

from flask import flash, redirect, render_template, request, url_for
from flask_login import login_required

from app.discounts import normalise
from app.extensions import db
from app.models import DiscountCode, DiscountKind

from . import admin_bp


def _apply_form(dc: DiscountCode) -> tuple[bool, str | None]:
    code = normalise(request.form.get("code"))
    if not code:
        return False, "الكود إجباري"
    if len(code) > 40:
        return False, "الكود طويل جداً"
    # Uniqueness (skip self)
    other = db.session.query(DiscountCode).filter_by(code=code).first()
    if other is not None and other.id != dc.id:
        return False, "هذا الكود موجود بالفعل"
    dc.code = code

    try:
        dc.kind = DiscountKind(request.form.get("kind") or "percent")
    except ValueError:
        return False, "نوع الخصم غير صحيح"

    try:
        dc.value = Decimal(request.form.get("value") or "0")
    except InvalidOperation:
        return False, "قيمة الخصم غير صحيحة"
    if dc.value < 0:
        return False, "القيمة يجب أن تكون موجبة"
    if dc.kind == DiscountKind.percent and dc.value > 100:
        return False, "النسبة يجب أن تكون بين 0 و 100"

    raw_min = (request.form.get("min_subtotal") or "").strip()
    if raw_min:
        try:
            dc.min_subtotal = Decimal(raw_min)
        except InvalidOperation:
            return False, "الحد الأدنى غير صحيح"
    else:
        dc.min_subtotal = None

    raw_max = (request.form.get("max_uses") or "").strip()
    if raw_max:
        try:
            dc.max_uses = int(raw_max)
        except ValueError:
            return False, "عدد مرات الاستخدام غير صحيح"
        if dc.max_uses < 0:
            return False, "عدد مرات الاستخدام يجب أن يكون موجباً"
    else:
        dc.max_uses = None

    raw_exp = (request.form.get("expires_at") or "").strip()
    if raw_exp:
        try:
            # Native datetime-local input: "YYYY-MM-DDTHH:MM"
            dt = datetime.fromisoformat(raw_exp)
            if dt.tzinfo is None:
                dt = dt.replace(tzinfo=timezone.utc)
            dc.expires_at = dt
        except ValueError:
            return False, "تاريخ الصلاحية غير صحيح"
    else:
        dc.expires_at = None

    dc.is_active = "is_active" in request.form
    dc.notes = (request.form.get("notes") or "").strip() or None
    return True, None


@admin_bp.get("/discounts")
@login_required
def discounts_list():
    codes = (
        db.session.query(DiscountCode)
        .order_by(DiscountCode.is_active.desc(), DiscountCode.updated_at.desc())
        .limit(200)
        .all()
    )
    return render_template("discounts/list.html", codes=codes)


@admin_bp.route("/discounts/new", methods=["GET", "POST"])
@login_required
def discounts_new():
    if request.method == "POST":
        dc = DiscountCode(kind=DiscountKind.percent, value=Decimal("0"))
        ok, err = _apply_form(dc)
        if not ok:
            flash(err, "danger")
            return render_template("discounts/form.html", dc=dc)
        db.session.add(dc)
        db.session.commit()
        flash("تم إنشاء الكود", "success")
        return redirect(url_for("admin.discounts_list"))
    return render_template("discounts/form.html", dc=None)


@admin_bp.route("/discounts/<int:code_id>/edit", methods=["GET", "POST"])
@login_required
def discounts_edit(code_id: int):
    dc = db.session.get(DiscountCode, code_id)
    if dc is None:
        flash("الكود غير موجود", "warning")
        return redirect(url_for("admin.discounts_list"))
    if request.method == "POST":
        ok, err = _apply_form(dc)
        if not ok:
            flash(err, "danger")
            return render_template("discounts/form.html", dc=dc)
        db.session.commit()
        flash("تم حفظ التعديلات", "success")
        return redirect(url_for("admin.discounts_list"))
    return render_template("discounts/form.html", dc=dc)


@admin_bp.post("/discounts/<int:code_id>/toggle")
@login_required
def discounts_toggle(code_id: int):
    dc = db.session.get(DiscountCode, code_id)
    if dc is None:
        return redirect(url_for("admin.discounts_list"))
    dc.is_active = not dc.is_active
    db.session.commit()
    flash("تم تحديث الحالة", "success")
    return redirect(url_for("admin.discounts_list"))


@admin_bp.post("/discounts/<int:code_id>/delete")
@login_required
def discounts_delete(code_id: int):
    dc = db.session.get(DiscountCode, code_id)
    if dc is None:
        return redirect(url_for("admin.discounts_list"))
    if (dc.uses_count or 0) > 0:
        flash("لا يمكن الحذف — الكود مستخدم في طلبات سابقة. استخدم الإيقاف بدلاً من الحذف.", "warning")
        return redirect(url_for("admin.discounts_list"))
    db.session.delete(dc)
    db.session.commit()
    flash("تم حذف الكود", "info")
    return redirect(url_for("admin.discounts_list"))


# ---------- template helpers ----------


@admin_bp.app_template_filter("kind_ar")
def _kind_ar(k):
    val = k.value if hasattr(k, "value") else k
    return {"percent": "نسبة", "fixed": "مبلغ ثابت"}.get(val, val)
