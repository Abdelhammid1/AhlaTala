"""Assign mock food images to items + categories so the app looks full while
real photography is still being shot.

Uses **loremflickr.com** — a free service that returns a random food photo
keyed by a stable `lock` id, so each item gets its own image that never
changes between calls.

Usage:
    flask mock-images            # fill in missing images only
    flask mock-images --force    # overwrite any image_path (even real uploads)
"""
from __future__ import annotations

import click
from flask import Flask

from app.extensions import db
from app.models import Category, Item, Offer


# Food keywords per category — keeps the visual roughly on-theme.
CATEGORY_KEYWORDS = {
    "ركن الشاورما": "shawarma",
    "المشويات": "grill,kebab",
    "مشكل لحم ودجاج": "grill,meat",
    "مشكلات لحم": "meat,kebab",
    "مشكلات دجاج": "chicken,grill",
    "الطواجن": "tagine,stew",
    "السندوشات": "sandwich",
    "أطباق جانبية وإضافات": "arabic,food",
    "الرز": "rice",
    "الشوربة": "soup",
    "السلطات": "salad",
    "الحلا": "dessert,arabic",
    "الكوكتيل": "cocktail,juice",
    "العصائر": "juice,fruit",
    "المشروبات الغازية": "soda,drink",
}


def _url_for_item(item: Item) -> str:
    kw = CATEGORY_KEYWORDS.get(item.category.name_ar if item.category else "", "food")
    return f"https://loremflickr.com/600/600/{kw}?lock={item.id}"


def _url_for_category(cat: Category) -> str:
    kw = CATEGORY_KEYWORDS.get(cat.name_ar, "food")
    return f"https://loremflickr.com/800/500/{kw}?lock=cat{cat.id}"


def _url_for_offer(offer: Offer) -> str:
    return f"https://loremflickr.com/1200/600/food,restaurant?lock=offer{offer.id}"


def register_cli(app: Flask) -> None:
    @app.cli.command("mock-images")
    @click.option("--force", is_flag=True, help="Overwrite existing image_paths (even real uploads).")
    def mock_images_cmd(force: bool) -> None:
        """Fill items / categories / offers with placeholder food photos."""
        items = db.session.query(Item).all()
        cats = db.session.query(Category).all()
        offers = db.session.query(Offer).all()

        i_touched = c_touched = o_touched = 0
        for it in items:
            if it.image_path and not force:
                continue
            it.image_path = _url_for_item(it)
            i_touched += 1
        for c in cats:
            if c.image_path and not force:
                continue
            c.image_path = _url_for_category(c)
            c_touched += 1
        for o in offers:
            if o.image_path and not force:
                continue
            o.image_path = _url_for_offer(o)
            o_touched += 1
        db.session.commit()
        click.echo(f"✅ Mock images assigned — items:{i_touched}, categories:{c_touched}, offers:{o_touched}")
        click.echo("   (real photos uploaded via /admin later will replace these; pass --force to override)")
