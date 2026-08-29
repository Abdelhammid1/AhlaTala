"""Import the printed أحلى طلة menu into the DB.

Usage:
    flask import-menu            # add categories + items alongside whatever's there
    flask import-menu --wipe     # delete existing categories + items first (KEEPS orders/customers/loyalty/etc.)

The transcription is best-effort from the printed menu photo. Please review
each price and item name in `/admin/items` after running — some Arabic
words on the print were partially obscured (marked with a `# TODO` comment
below).

Every item is imported flat (no option groups). Once satisfied with prices
and names, use `/admin/items/<id>/edit` to add size / variant / add / remove
groups where relevant (e.g. shawarma sizes, "بدون بصل" for sandwiches, etc.).
"""
from __future__ import annotations

from decimal import Decimal

import click
from flask import Flask

from app.extensions import db
from app.models import Category, Item

# -----------------------------------------------------------------------------
# The menu — flat dict of (category_ar, description_hint) -> list[(name, price)]
# All prices in SAR. Prices are Decimal-strings so DB precision is exact.
# -----------------------------------------------------------------------------

MENU: dict[str, list[tuple[str, str]]] = {
    "ركن الشاورما": [
        ("صاروخ", "10"),
        ("عربي كبير", "24"),
        ("عربي صغير", "12"),
        ("توشكا", "20"),
        ("مرينا", "20"),
        ("تشيكن فرايز", "20"),
        ("دايناميت فرايز", "20"),
        ("شاورما أحلى طلة", "15"),
        ("عربي عائلي كبير", "70"),
        ("عربي عائلي صغير", "45"),
    ],
    "الكوكتيل": [
        ("طبقات", "8"),
        ("فخفخينا", "10"),
        ("فياجرا", "10"),
        ("كوكتيل أحلى طلة", "10"),
        ("كوكتيل الموسم", "10"),
        ("سعودي كوكتيل", "10"),
        ("جالون كبير", "25"),
        ("جالون صغير", "18"),
        ("سعودي مانجو", "8"),
        ("سعودي فراولة", "8"),
        ("سعودي نعناع", "8"),
        ("سعودي رمان", "8"),
        ("جالون أفوكادو كبير", "30"),
        ("جالون أفوكادو صغير", "22"),
    ],
    "المشويات": [
        ("نفر كباب لحم", "28"),
        ("نفر أوصال لحم", "35"),
        ("نفر ريش", "44"),
        ("نفر ربر", "30"),
        ("نفر كبدة ضاني", "24"),
        ("نفر أحلى طلة دجاج", "22"),
        ("نفر كباب دجاج", "18"),
        ("نفر شيش طاووق", "26"),
        ("نفر لحم على الفحم", "13"),
        ("سمان", "24"),
    ],
    "مشكلات لحم": [
        ("نفر مشكل لحم", "32"),
        ("نفر أحلى طلة لحم", "50"),
        ("نص كيلو مشكل لحم", "65"),
        ("كيلو مشكل لحم", "130"),
    ],
    "مشكلات دجاج": [
        ("نفر مشكل دجاج", "24"),
        ("نفر أحلى طلة دجاج", "36"),
        ("نص كيلو مشكل دجاج", "48"),
        ("كيلو مشكل دجاج", "95"),
    ],
    "مشكل لحم ودجاج": [
        ("مشكل مميز", "45"),
        ("نص كيلو مشكل", "60"),
        ("كيلو مشكل", "120"),
        ("مشكل عائلي", "215"),
    ],
    "السندوشات": [
        ("حواوشي", "15"),
        ("حواوشي بالجبنة", "18"),
        ("ساندوتش كباب لحم", "24"),
        ("ساندوتش أوصال لحم", "18"),
        ("ساندوتش كباب دجاج", "22"),
        ("ساندوتش أوصال دجاج", "15"),
        ("ساندوتش طرب", "12"),
        ("ساندوتش كبدة إسكندراني", "12"),
        ("ساندوتش سجق إسكندراني", "12"),
    ],
    "الطواجن": [
        ("طاجن خضار باللحم", "25"),
        ("طاجن بامية باللحم", "20"),
        ("طاجن بطاطس بالدجاج", "14"),
        ("طاجن مكرونة باللحم المفروم", "25"),
        ("طاجن كوارع بورق العنب", "14"),
        ("طاجن لحم بالبصل", "25"),
    ],
    "أطباق جانبية وإضافات": [
        ("بشاميل", "14"),
        ("محشي مشكل", "40"),
        ("حبة حمام", "30"),
        ("حبة دجاج فرن", "15"),
        ("نص حبة فرن", "40"),  # TODO: verify — could be "نص حبة دجاج فرن"
        ("ربع بط", "28"),
        ("موزة", "25"),
        ("ورقة لحمة", "28"),
        ("كبدة إسكندراني", "25"),
        ("سجق إسكندراني", "25"),
        ("خضار مشكل", "15"),
        ("بامية", "8"),
        ("مسقعة", "8"),
        ("ملوخية", "8"),
    ],
    "الرز": [
        ("رز مصري بالشعرية", "7"),
        ("رز أوزي", "8"),
        ("رز أحلى طلة", "7"),
        ("مكرونة بالصلصة", "10"),
    ],
    "الشوربة": [
        ("شوربة لسان عصفور", "5"),
        ("شوربة عدس", "5"),
        ("شوربة كريمة دجاج", "10"),
    ],
    "السلطات": [
        ("حمص", "7"),
        ("متبل", "7"),
        ("تبولة", "7"),
        ("فتوش", "7"),
        ("خيار زبادي", "7"),
        ("سلطة خضراء", "8"),
        ("ورق عنب بارد", "10"),
        ("سلطة مشكل", "10"),
    ],
    "العصائر": [
        # Left column of the print
        ("عصير بطيخ", "8"),
        ("عصير شمام", "8"),
        ("عصير كيوي", "10"),
        ("عصير جزر", "8"),
        ("عصير تفاح أحمر", "8"),
        ("عصير تفاح أخضر", "10"),
        ("عصير برقوق", "8"),
        ("عصير تمر بالحليب", "10"),
        # Right column
        ("عصير مانجو", "8"),
        ("عصير جوافة", "8"),
        ("عصير فراولة", "8"),
        ("عصير رمان", "8"),  # TODO: verify — could be "عنب"
        ("عصير ليمون", "8"),
        ("عصير ليمون نعناع", "8"),
        ("عصير جرجير", "8"),
        ("عصير موز", "8"),
        ("عصير برتقال", "8"),
    ],
    "المشروبات الغازية": [
        ("بيبسي", "3"),
        ("بيبسي دايت", "3"),
        ("حمضيات", "3"),
        ("ديو", "3"),
        ("ميرندا برتقال", "3"),
        ("ميرندا تفاح", "3"),
        ("مياه", "1"),
        ("لبن", "2"),
    ],
    "الحلا": [
        ("أم علي", "8"),
        ("أرز بالحليب", "8"),
        ("كواع (يوم الجمعة)", "35"),
        ("عصبار (يوم الجمعة)", "25"),
    ],
}

# Category sort order (visual order on the printed menu, roughly top-to-bottom by importance)
CATEGORY_ORDER = [
    "ركن الشاورما",
    "المشويات",
    "مشكل لحم ودجاج",
    "مشكلات لحم",
    "مشكلات دجاج",
    "الطواجن",
    "السندوشات",
    "أطباق جانبية وإضافات",
    "الرز",
    "الشوربة",
    "السلطات",
    "الحلا",
    "الكوكتيل",
    "العصائر",
    "المشروبات الغازية",
]


def register_cli(app: Flask) -> None:
    @app.cli.command("import-menu")
    @click.option("--wipe", is_flag=True, help="Delete existing categories + items first.")
    def import_menu_cmd(wipe: bool) -> None:
        """Import the printed أحلى طلة menu."""
        if wipe:
            # Only wipes menu (categories cascade to items/groups/options).
            # Orders/customers/loyalty/discounts/offers/notifications are UNTOUCHED.
            deleted_items = db.session.query(Item).delete()
            deleted_cats = db.session.query(Category).delete()
            db.session.commit()
            click.echo(f"🧹 Wiped {deleted_cats} categories and {deleted_items} items")

        total_items = 0
        for order_idx, cat_name in enumerate(CATEGORY_ORDER, start=1):
            entries = MENU.get(cat_name, [])
            if not entries:
                continue
            # Find-or-create the category
            cat = db.session.query(Category).filter_by(name_ar=cat_name).first()
            if cat is None:
                cat = Category(name_ar=cat_name, sort_order=order_idx, is_active=True)
                db.session.add(cat)
                db.session.flush()
                click.echo(f"➕ Category: {cat_name}")

            existing_names = {i.name_ar for i in cat.items}
            for i_idx, (name, price) in enumerate(entries, start=1):
                if name in existing_names:
                    click.echo(f"   ↷ Skipping (exists): {name}")
                    continue
                item = Item(
                    category_id=cat.id,
                    name_ar=name,
                    base_price=Decimal(price),
                    sort_order=i_idx,
                    is_active=True,
                )
                db.session.add(item)
                total_items += 1
        db.session.commit()
        click.echo(f"✅ Import done — added {total_items} items")
