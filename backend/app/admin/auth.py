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
    from app.models import Category, Item, OptionGroup, Option
    counts = {
        "categories": db.session.query(Category).count(),
        "items": db.session.query(Item).count(),
        "option_groups": db.session.query(OptionGroup).count(),
        "options": db.session.query(Option).count(),
    }
    return render_template("dashboard.html", counts=counts)
