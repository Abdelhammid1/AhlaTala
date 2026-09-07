"""Admin auth — session-based login for staff (Flask-Login)."""
from flask import flash, redirect, render_template, request, url_for
from flask_login import current_user, login_required, login_user, logout_user

from app.extensions import db, login_manager
from app.models import AdminUser

from . import admin_bp


@login_manager.user_loader
def _load_user(user_id: str):
    return db.session.get(AdminUser, int(user_id))


@admin_bp.route("/login", methods=["GET", "POST"])
def login():
    if current_user.is_authenticated:
        return redirect(url_for("admin.dashboard"))

    if request.method == "POST":
        email = (request.form.get("email") or "").strip().lower()
        password = request.form.get("password") or ""
        user = db.session.query(AdminUser).filter_by(email=email).first()
        if user and user.check_password(password) and user.is_active:
            login_user(user)
            return redirect(url_for("admin.dashboard"))
        flash("بيانات الدخول غير صحيحة", "danger")

    return render_template("auth/login.html")


@admin_bp.post("/logout")
@login_required
def logout():
    logout_user()
    return redirect(url_for("admin.login"))


@admin_bp.get("/")
@login_required
def dashboard():
    """Real KPIs + a 30-day revenue series + top-selling items + latest orders.

    Everything here is server-side aggregation — no client-side loops over
    thousands of rows. The revenue series is bucketed by day in a single
    GROUP BY query and back-filled with zeros so the SVG line chart in the
    template has a stable 30-point x-axis regardless of how many days had
    orders.
    """
    from datetime import datetime, timedelta, timezone
    from decimal import Decimal
    from sqlalchemy import func, cast, Date
    from app.models import Order, OrderLine, OrderStatus, Customer

    now = datetime.now(timezone.utc)
    today = now.date()
    yesterday = today - timedelta(days=1)

    # "Real" revenue = anything that isn't cancelled/failed. Confirmed and
    # in-flight orders count too — cash-on-delivery is real revenue the
    # moment it's confirmed.
    revenue_status_filter = ~Order.status.in_([OrderStatus.cancelled, OrderStatus.failed])

    # ---------- KPI tiles ----------
    orders_today_count = db.session.query(func.count(Order.id)).filter(
        cast(Order.created_at, Date) == today
    ).scalar() or 0

    revenue_today = db.session.query(func.coalesce(func.sum(Order.total), 0)).filter(
        cast(Order.created_at, Date) == today,
        revenue_status_filter,
    ).scalar() or Decimal("0")

    orders_yesterday_count = db.session.query(func.count(Order.id)).filter(
        cast(Order.created_at, Date) == yesterday
    ).scalar() or 0

    revenue_yesterday = db.session.query(func.coalesce(func.sum(Order.total), 0)).filter(
        cast(Order.created_at, Date) == yesterday,
        revenue_status_filter,
    ).scalar() or Decimal("0")

    total_customers = db.session.query(func.count(Customer.id)).scalar() or 0

    # AOV = total revenue today / paying orders today (fall back to 0 when there are none)
    aov_today = (revenue_today / orders_today_count) if orders_today_count else Decimal("0")

    def _pct_delta(now_val, prev_val):
        """Percentage change, guarded against divide-by-zero. Returns None
        when there's no baseline (first-day-of-life)."""
        if not prev_val:
            return None
        try:
            return round(((float(now_val) - float(prev_val)) / float(prev_val)) * 100.0, 1)
        except (ZeroDivisionError, TypeError):
            return None

    kpis = {
        "orders_today": orders_today_count,
        "orders_delta_pct": _pct_delta(orders_today_count, orders_yesterday_count),
        "revenue_today": float(revenue_today),
        "revenue_delta_pct": _pct_delta(revenue_today, revenue_yesterday),
        "total_customers": total_customers,
        "aov_today": float(aov_today),
    }

    # ---------- 30-day revenue series ----------
    thirty_days_ago = today - timedelta(days=29)  # inclusive of today = 30 points
    rows = db.session.query(
        cast(Order.created_at, Date).label("day"),
        func.coalesce(func.sum(Order.total), 0).label("revenue"),
    ).filter(
        cast(Order.created_at, Date) >= thirty_days_ago,
        revenue_status_filter,
    ).group_by(cast(Order.created_at, Date)).all()

    by_day = {r.day: float(r.revenue) for r in rows}
    revenue_series = []
    for i in range(30):
        d = thirty_days_ago + timedelta(days=i)
        revenue_series.append({"day": d, "revenue": by_day.get(d, 0.0)})

    revenue_month_total = sum(p["revenue"] for p in revenue_series)

    # ---------- Top-selling items (last 30 days by units sold) ----------
    top_items_rows = db.session.query(
        OrderLine.name_ar_snapshot.label("name"),
        func.sum(OrderLine.quantity).label("qty"),
    ).join(Order, Order.id == OrderLine.order_id).filter(
        cast(Order.created_at, Date) >= thirty_days_ago,
        revenue_status_filter,
    ).group_by(OrderLine.name_ar_snapshot).order_by(func.sum(OrderLine.quantity).desc()).limit(6).all()

    top_items_max = max((r.qty for r in top_items_rows), default=1) or 1
    top_items = [
        {"name": r.name, "qty": int(r.qty), "pct": round(int(r.qty) * 100 / top_items_max)}
        for r in top_items_rows
    ]

    # ---------- Latest 5 orders ----------
    latest_orders = db.session.query(Order).order_by(Order.created_at.desc()).limit(5).all()

    return render_template(
        "dashboard.html",
        kpis=kpis,
        revenue_series=revenue_series,
        revenue_month_total=revenue_month_total,
        top_items=top_items,
        latest_orders=latest_orders,
    )
