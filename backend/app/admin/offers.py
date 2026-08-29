"""Admin CRUD for offers (E7 US7.1)."""
from datetime import datetime, timezone

from flask import flash, redirect, render_template, request, url_for
from flask_login import login_required

from app.extensions import db
from app.models import Item, Offer
from app.uploads import save_image

from . import admin_bp


def _parse_dt(raw: str | None):
    if not raw:
        return None
    try:
        dt = datetime.fromisoformat(raw)
        if dt.tzinfo is None:
            dt = dt.replace(tzinfo=timezone.utc)
        return dt
    except ValueError:
        return None


def _apply_form(offer: Offer) -> tuple[bool, str | None]:
    title = (request.form.get("title_ar") or "").strip()
    if not title:
        return False, "العنوان بالعربي إجباري"
    offer.title_ar = title
    offer.description_ar = (request.form.get("description_ar") or "").strip() or None

    starts_at = _parse_dt(request.form.get("starts_at"))
    ends_at = _parse_dt(request.form.get("ends_at"))
    if starts_at is None or ends_at is None:
        return False, "تاريخا البداية والنهاية إجباريان"
    if ends_at <= starts_at:
        return False, "تاريخ النهاية يجب أن يكون بعد تاريخ البداية"
    offer.starts_at = starts_at
    offer.ends_at = ends_at

    raw_linked = (request.form.get("linked_item_id") or "").strip()
    if raw_linked:
        try:
            offer.linked_item_id = int(raw_linked)
        except ValueError:
            return False, "الصنف المرتبط غير صحيح"
    else:
        offer.linked_item_id = None

    try:
        offer.sort_order = int(request.form.get("sort_order") or 0)
    except ValueError:
        offer.sort_order = 0

    offer.is_active = "is_active" in request.form

    image = save_image(request.files.get("image"), "offers")
    if image:
        offer.image_path = image

    return True, None


@admin_bp.get("/offers")
@login_required
def offers_list():
    offers = (
        db.session.query(Offer)
        .order_by(Offer.is_active.desc(), Offer.starts_at.desc())
        .all()
    )
    return render_template("offers/list.html", offers=offers)


@admin_bp.route("/offers/new", methods=["GET", "POST"])
@login_required
def offers_new():
    items = db.session.query(Item).filter_by(is_active=True).order_by(Item.name_ar.asc()).all()
    if request.method == "POST":
        # Pre-fill required datetimes so _apply_form validates properly on retry
        offer = Offer(title_ar="", starts_at=datetime.now(timezone.utc), ends_at=datetime.now(timezone.utc))
        ok, err = _apply_form(offer)
        if not ok:
            flash(err, "danger")
            return render_template("offers/form.html", offer=offer, items=items)
        db.session.add(offer)
        db.session.commit()
        flash("تم إنشاء العرض", "success")
        return redirect(url_for("admin.offers_list"))
    return render_template("offers/form.html", offer=None, items=items)


@admin_bp.route("/offers/<int:offer_id>/edit", methods=["GET", "POST"])
@login_required
def offers_edit(offer_id: int):
    offer = db.session.get(Offer, offer_id)
    if offer is None:
        flash("العرض غير موجود", "warning")
        return redirect(url_for("admin.offers_list"))
    items = db.session.query(Item).filter_by(is_active=True).order_by(Item.name_ar.asc()).all()
    if request.method == "POST":
        ok, err = _apply_form(offer)
        if not ok:
            flash(err, "danger")
            return render_template("offers/form.html", offer=offer, items=items)
        db.session.commit()
        flash("تم حفظ التعديلات", "success")
        return redirect(url_for("admin.offers_list"))
    return render_template("offers/form.html", offer=offer, items=items)


@admin_bp.post("/offers/<int:offer_id>/toggle")
@login_required
def offers_toggle(offer_id: int):
    offer = db.session.get(Offer, offer_id)
    if offer is not None:
        offer.is_active = not offer.is_active
        db.session.commit()
        flash("تم تحديث حالة العرض", "success")
    return redirect(url_for("admin.offers_list"))


@admin_bp.post("/offers/<int:offer_id>/delete")
@login_required
def offers_delete(offer_id: int):
    offer = db.session.get(Offer, offer_id)
    if offer is not None:
        db.session.delete(offer)
        db.session.commit()
        flash("تم حذف العرض", "info")
    return redirect(url_for("admin.offers_list"))
