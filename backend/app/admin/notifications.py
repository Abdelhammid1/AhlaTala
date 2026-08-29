"""Admin — compose + send notifications (E8 US8.1)."""
from datetime import datetime, timezone

from flask import flash, redirect, render_template, request, url_for
from flask_login import current_user, login_required

from app.extensions import db
from app.models import (
    Customer,
    Notification,
    NotificationDelivery,
    NotificationTarget,
)
from app.notifications import get_sender, resolve_target

from . import admin_bp


@admin_bp.get("/notifications")
@login_required
def notifications_list():
    items = (
        db.session.query(Notification)
        .order_by(Notification.created_at.desc())
        .limit(200)
        .all()
    )
    return render_template("notifications/list.html", notifications=items)


@admin_bp.route("/notifications/new", methods=["GET", "POST"])
@login_required
def notifications_new():
    if request.method == "POST":
        title = (request.form.get("title_ar") or "").strip()
        body = (request.form.get("body_ar") or "").strip()
        target_raw = (request.form.get("target") or "all").strip()

        if not title or not body:
            flash("العنوان والنص إجباريان", "danger")
            return render_template("notifications/form.html")

        try:
            target = NotificationTarget(target_raw)
        except ValueError:
            flash("الشريحة المطلوبة غير صحيحة", "danger")
            return render_template("notifications/form.html")

        customer_ids = resolve_target(target)
        if not customer_ids:
            flash("لا يوجد عملاء في هذه الشريحة — لم يتم إرسال الإشعار", "warning")
            return render_template("notifications/form.html")

        notif = Notification(
            title_ar=title,
            body_ar=body,
            target=target,
            target_snapshot=customer_ids,
            sent_by_admin_id=(current_user.id if current_user.is_authenticated else None),
        )
        db.session.add(notif)
        db.session.flush()

        deliveries = [
            NotificationDelivery(notification_id=notif.id, customer_id=cid)
            for cid in customer_ids
        ]
        db.session.add_all(deliveries)
        db.session.flush()

        get_sender().send(notif, deliveries)
        db.session.commit()

        flash(f"تم إرسال الإشعار إلى {len(customer_ids)} عميل", "success")
        return redirect(url_for("admin.notifications_detail", notif_id=notif.id))

    return render_template("notifications/form.html")


@admin_bp.get("/notifications/<int:notif_id>")
@login_required
def notifications_detail(notif_id: int):
    notif = db.session.get(Notification, notif_id)
    if notif is None:
        flash("الإشعار غير موجود", "warning")
        return redirect(url_for("admin.notifications_list"))
    # Deliveries + customer info for the recipients list
    deliveries = (
        db.session.query(NotificationDelivery, Customer)
        .join(Customer, Customer.id == NotificationDelivery.customer_id)
        .filter(NotificationDelivery.notification_id == notif.id)
        .order_by(NotificationDelivery.created_at.asc())
        .limit(500)
        .all()
    )
    read_count = sum(1 for d, _c in deliveries if d.read_at is not None)
    return render_template(
        "notifications/detail.html",
        notif=notif, deliveries=deliveries, read_count=read_count,
    )


# ---------- template filters ----------


_TARGET_AR = {
    "all": "الجميع",
    "inactive_30d": "لم يطلبوا منذ 30 يوم",
    "has_ordered": "طلبوا مسبقاً",
}


@admin_bp.app_template_filter("target_ar")
def _target_ar(t):
    val = t.value if hasattr(t, "value") else t
    return _TARGET_AR.get(val, val)
