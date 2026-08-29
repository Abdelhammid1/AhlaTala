"""Admin views for orders (E4)."""
from datetime import datetime, timezone

from flask import abort, flash, redirect, render_template, request, url_for
from flask_login import login_required

from app.extensions import db
from app.models import (
    FulfillmentType,
    Order,
    OrderStatus,
)

from . import admin_bp


def _unseen_new_count() -> int:
    """How many confirmed orders the admin hasn't opened yet — drives the nav badge."""
    return (
        db.session.query(Order)
        .filter(Order.status == OrderStatus.confirmed, Order.admin_seen_at.is_(None))
        .count()
    )


@admin_bp.app_context_processor
def _inject_unread():
    # Only run for authenticated admin pages — Flask-Login guards routes,
    # but this processor fires for every render; keep it cheap.
    try:
        return {"unseen_orders_count": _unseen_new_count()}
    except Exception:
        return {"unseen_orders_count": 0}


# ------------- list -------------


@admin_bp.get("/orders")
@login_required
def orders_list():
    status_filter = (request.args.get("status") or "").strip()
    q = db.session.query(Order)
    if status_filter:
        try:
            s = OrderStatus(status_filter)
            q = q.filter(Order.status == s)
        except ValueError:
            pass

    orders = q.order_by(Order.created_at.desc(), Order.id.desc()).limit(200).all()
    return render_template(
        "orders/list.html",
        orders=orders,
        status_filter=status_filter,
        statuses=list(OrderStatus),
    )


# ------------- detail -------------


@admin_bp.get("/orders/<int:order_id>")
@login_required
def orders_detail(order_id: int):
    order = db.session.get(Order, order_id)
    if order is None:
        flash("الطلب غير موجود", "warning")
        return redirect(url_for("admin.orders_list"))

    # Mark as seen once — clears the "جديد" badge for everyone.
    if order.admin_seen_at is None:
        order.admin_seen_at = datetime.now(timezone.utc)
        db.session.commit()

    return render_template("orders/detail.html", order=order)


# ------------- transition -------------


@admin_bp.post("/orders/<int:order_id>/transition")
@login_required
def orders_transition(order_id: int):
    order = db.session.get(Order, order_id)
    if order is None:
        abort(404)

    raw = (request.form.get("to_status") or "").strip()
    try:
        target = OrderStatus(raw)
    except ValueError:
        flash("الحالة المطلوبة غير صحيحة", "danger")
        return redirect(url_for("admin.orders_detail", order_id=order_id))

    if target not in order.next_valid_statuses():
        flash("لا يمكن الانتقال إلى هذه الحالة من الحالة الحالية", "danger")
        return redirect(url_for("admin.orders_detail", order_id=order_id))

    order.status = target
    if target == OrderStatus.delivered and order.confirmed_at is None:
        # Rare edge: a delivered order should already have been confirmed;
        # keep the guarantee anyway.
        order.confirmed_at = datetime.now(timezone.utc)
    db.session.commit()

    flash(f"تم تحديث الحالة إلى: {target.value}", "success")
    return redirect(url_for("admin.orders_detail", order_id=order_id))


@admin_bp.post("/orders/<int:order_id>/cancel")
@login_required
def orders_cancel(order_id: int):
    order = db.session.get(Order, order_id)
    if order is None:
        abort(404)
    if OrderStatus.cancelled not in order.next_valid_statuses():
        flash("لا يمكن إلغاء الطلب في حالته الحالية", "danger")
        return redirect(url_for("admin.orders_detail", order_id=order_id))
    order.status = OrderStatus.cancelled
    db.session.commit()
    flash("تم إلغاء الطلب", "info")
    return redirect(url_for("admin.orders_detail", order_id=order_id))


# ------------- template helpers (Jinja globals) -------------


_STATUS_AR = {
    OrderStatus.created: "قيد التأكيد",
    OrderStatus.confirmed: "مؤكد",
    OrderStatus.preparing: "قيد التجهيز",
    OrderStatus.on_the_way: "في الطريق",
    OrderStatus.ready_for_pickup: "جاهز للاستلام",
    OrderStatus.delivered: "تم التسليم",
    OrderStatus.cancelled: "ملغى",
    OrderStatus.failed: "فشل الدفع",
}

_STATUS_BADGE = {
    OrderStatus.created: "secondary",
    OrderStatus.confirmed: "primary",
    OrderStatus.preparing: "warning text-dark",
    OrderStatus.on_the_way: "info text-dark",
    OrderStatus.ready_for_pickup: "info text-dark",
    OrderStatus.delivered: "success",
    OrderStatus.cancelled: "secondary",
    OrderStatus.failed: "danger",
}


def _status_ar(status) -> str:
    return _STATUS_AR.get(status, str(status))


def _status_badge_class(status) -> str:
    return _STATUS_BADGE.get(status, "secondary")


@admin_bp.app_template_filter("status_ar")
def _filter_status_ar(status):
    return _status_ar(status)


@admin_bp.app_template_filter("status_badge")
def _filter_status_badge(status):
    return _status_badge_class(status)


@admin_bp.app_template_filter("ful_ar")
def _filter_ful_ar(ftype):
    return "توصيل" if ftype == FulfillmentType.delivery else "استلام من الفرع"


@admin_bp.app_template_filter("pay_ar")
def _filter_pay_ar(pm):
    return {"cash": "كاش عند الاستلام", "apple_pay": "Apple Pay", "gateway_stub": "بوابة تجريبية"}.get(
        pm.value if hasattr(pm, "value") else pm, str(pm)
    )
