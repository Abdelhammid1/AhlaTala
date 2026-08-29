"""Admin views for loyalty (E5): settings + customers/ledger."""
from decimal import Decimal, InvalidOperation

from flask import flash, redirect, render_template, request, url_for
from flask_login import login_required

from app.extensions import db
from app.models import Customer, LoyaltyLedger, LoyaltySettings

from . import admin_bp


# ---------- /admin/loyalty ----------


@admin_bp.route("/loyalty", methods=["GET", "POST"])
@login_required
def loyalty_settings():
    s = LoyaltySettings.instance()

    if request.method == "POST":
        try:
            ppr = Decimal(request.form.get("points_per_riyal") or "0")
            rpp = Decimal(request.form.get("riyal_per_point") or "0")
            mp = int(request.form.get("min_redeem_points") or 0)
        except (InvalidOperation, ValueError):
            flash("قيم غير صحيحة", "danger")
            return render_template("loyalty/settings.html", s=s)

        if ppr < 0 or rpp < 0 or mp < 0:
            flash("القيم يجب أن تكون موجبة", "danger")
            return render_template("loyalty/settings.html", s=s)

        s.points_per_riyal = ppr
        s.riyal_per_point = rpp
        s.min_redeem_points = mp
        db.session.commit()
        flash("تم حفظ إعدادات الولاء", "success")
        return redirect(url_for("admin.loyalty_settings"))

    return render_template("loyalty/settings.html", s=s)


# ---------- /admin/customers ----------


@admin_bp.get("/customers")
@login_required
def customers_list():
    q = (request.args.get("q") or "").strip()
    query = db.session.query(Customer)
    if q:
        query = query.filter((Customer.phone.ilike(f"%{q}%")) | (Customer.name.ilike(f"%{q}%")))
    customers = query.order_by(Customer.updated_at.desc()).limit(200).all()
    return render_template("customers/list.html", customers=customers, q=q)


@admin_bp.get("/customers/<int:customer_id>")
@login_required
def customers_detail(customer_id: int):
    c = db.session.get(Customer, customer_id)
    if c is None:
        flash("العميل غير موجود", "warning")
        return redirect(url_for("admin.customers_list"))
    entries = (
        db.session.query(LoyaltyLedger)
        .filter_by(customer_id=c.id)
        .order_by(LoyaltyLedger.created_at.desc())
        .limit(200)
        .all()
    )
    return render_template("customers/detail.html", customer=c, entries=entries)


# ---------- template filters ----------


_REASON_AR = {
    "earned": "كسب من طلب",
    "redeemed": "استبدال",
    "adjustment": "تعديل يدوي",
}


@admin_bp.app_template_filter("reason_ar")
def _reason_ar(r):
    val = r.value if hasattr(r, "value") else r
    return _REASON_AR.get(val, val)
