"""Admin CRUD for Categories."""
from flask import flash, redirect, render_template, request, url_for
from flask_login import login_required

from app.extensions import db
from app.models import Category
from app.uploads import save_image

from . import admin_bp


@admin_bp.get("/categories")
@login_required
def categories_list():
    cats = db.session.query(Category).order_by(Category.sort_order.asc(), Category.id.asc()).all()
    return render_template("categories/list.html", categories=cats)


@admin_bp.route("/categories/new", methods=["GET", "POST"])
@login_required
def categories_new():
    if request.method == "POST":
        cat = Category(
            name_ar=(request.form.get("name_ar") or "").strip(),
            name_en=(request.form.get("name_en") or "").strip() or None,
            sort_order=int(request.form.get("sort_order") or 0),
            is_active="is_active" in request.form,
        )
        if not cat.name_ar:
            flash("الاسم بالعربي إجباري", "danger")
            return render_template("categories/form.html", category=cat)

        image = save_image(request.files.get("image"), "categories")
        if image:
            cat.image_path = image

        db.session.add(cat)
        db.session.commit()
        flash("تم إنشاء الفئة", "success")
        return redirect(url_for("admin.categories_list"))

    return render_template("categories/form.html", category=None)


@admin_bp.route("/categories/<int:cat_id>/edit", methods=["GET", "POST"])
@login_required
def categories_edit(cat_id: int):
    cat = db.session.get(Category, cat_id)
    if cat is None:
        flash("الفئة غير موجودة", "warning")
        return redirect(url_for("admin.categories_list"))

    if request.method == "POST":
        cat.name_ar = (request.form.get("name_ar") or "").strip()
        cat.name_en = (request.form.get("name_en") or "").strip() or None
        cat.sort_order = int(request.form.get("sort_order") or 0)
        cat.is_active = "is_active" in request.form
        image = save_image(request.files.get("image"), "categories")
        if image:
            cat.image_path = image
        db.session.commit()
        flash("تم حفظ التعديلات", "success")
        return redirect(url_for("admin.categories_list"))

    return render_template("categories/form.html", category=cat)


@admin_bp.post("/categories/<int:cat_id>/delete")
@login_required
def categories_delete(cat_id: int):
    cat = db.session.get(Category, cat_id)
    if cat is not None:
        db.session.delete(cat)
        db.session.commit()
        flash("تم حذف الفئة", "info")
    return redirect(url_for("admin.categories_list"))
