"""Assign real food photos to items + categories so the app looks polished
while the shop's own photography is being shot.

Photos come from **Unsplash's static image CDN** (`images.unsplash.com`).
Each URL is a specific hand-picked photo pinned by its Unsplash photo id,
so results are stable across calls, safe to ship in Play Store screenshots,
and 99.99% uptime. Loremflickr was flaky (500s in ~half of requests) and
kept surfacing the "broken image" fallback in the UI.

Two photos are cycled per category so items in the same category aren't
identical thumbnails. Items are pinned to one of the two by `id % 2`.

Usage:
    flask mock-images            # fill in missing images only
    flask mock-images --force    # overwrite existing image_paths (real
                                 # uploads made via /admin later still
                                 # win because they set image_path to a
                                 # relative /uploads/... instead of a URL)
"""
from __future__ import annotations

import click
from flask import Flask

from app.extensions import db
from app.models import Category, Item, Offer

# Direct Unsplash CDN URLs, tuned to 800×800 (item / category thumbnail
# aspect) and 1600×800 (offer banner) with q=70 to keep bytes small on
# 4G. Two photos per category so item tiles don't all look identical.
_ITEM_QS = "?auto=format&fit=crop&w=800&h=800&q=70"
_HERO_QS = "?auto=format&fit=crop&w=1600&h=800&q=70"

# name_ar → [photo_id, photo_id]
CATEGORY_PHOTOS: dict[str, list[str]] = {
    "ركن الشاورما": ["photo-1633321702518-7feccafb94d5", "photo-1561651823-34feb02250e4"],
    "المشويات": ["photo-1544025162-d76694265947", "photo-1529193591184-b1d58069ecdd"],
    "مشكل لحم ودجاج": ["photo-1544025162-d76694265947", "photo-1567620832903-9fc6debc209f"],
    "مشكلات لحم": ["photo-1529193591184-b1d58069ecdd", "photo-1544025162-d76694265947"],
    "مشكلات دجاج": ["photo-1567620832903-9fc6debc209f", "photo-1598515214211-89d3c73ae83b"],
    "الطواجن": ["photo-1544378730-8b5104b18790", "photo-1547592180-85f173990554"],
    "السندوشات": ["photo-1528735602780-2552fd46c7af", "photo-1568901346375-23c9450c58cd"],
    "أطباق جانبية وإضافات": ["photo-1512058564366-18510be2db19", "photo-1517244683847-7456b63c5969"],
    "الرز": ["photo-1512058564366-18510be2db19", "photo-1596797038530-2c107229654b"],
    "الشوربة": ["photo-1547592180-85f173990554", "photo-1548943487-a2e4e43b4853"],
    "السلطات": ["photo-1512621776951-a57141f2eefd", "photo-1540420773420-3366772f4999"],
    "الحلا": ["photo-1551024506-0bccd828d307", "photo-1587314168485-3236d6710814"],
    "الكوكتيل": ["photo-1544145945-f90425340c7e", "photo-1546171753-97d7676e4602"],
    "العصائر": ["photo-1546173159-315724a31696", "photo-1613478223719-2ab802602423"],
    "المشروبات الغازية": ["photo-1550505095-81378a674395", "photo-1581636625402-29b2a704ef13"],
}

# Fallback pool for any category the map above forgets.
_FALLBACK = ["photo-1504674900247-0877df9cc836", "photo-1546069901-ba9599a7e63c"]

# Rotating hero banners for offers.
OFFER_PHOTOS = [
    "photo-1565299624946-b28f40a0ae38",  # pizza spread
    "photo-1571091718767-18b5b1457add",  # burger meal
    "photo-1546069901-ba9599a7e63c",     # colourful bowl
    "photo-1567620832903-9fc6debc209f",  # grilled chicken plate
]


def _unsplash(photo_id: str, hero: bool = False) -> str:
    return f"https://images.unsplash.com/{photo_id}{_HERO_QS if hero else _ITEM_QS}"


def _url_for_item(item: Item) -> str:
    key = item.category.name_ar if item.category else ""
    pool = CATEGORY_PHOTOS.get(key, _FALLBACK)
    return _unsplash(pool[item.id % len(pool)])


def _url_for_category(cat: Category) -> str:
    pool = CATEGORY_PHOTOS.get(cat.name_ar, _FALLBACK)
    return _unsplash(pool[0])


def _url_for_offer(offer: Offer) -> str:
    return _unsplash(OFFER_PHOTOS[offer.id % len(OFFER_PHOTOS)], hero=True)


def register_cli(app: Flask) -> None:
    @app.cli.command("mock-images")
    @click.option("--force", is_flag=True, help="Overwrite existing image_paths (including any that already point to a URL).")
    def mock_images_cmd(force: bool) -> None:
        """Fill items / categories / offers with curated Unsplash food photos."""
        items = db.session.query(Item).all()
        cats = db.session.query(Category).all()
        offers = db.session.query(Offer).all()

        # A real admin upload writes a relative path like "menu/xyz.jpg",
        # never a URL. So "starts with http" is a safe way to spot our
        # own mock entries and refresh only those on a non-forced run —
        # real photography stays put.
        def _is_mock(path: str | None) -> bool:
            return bool(path and path.startswith("http"))

        i_touched = c_touched = o_touched = 0
        for it in items:
            if it.image_path and not force and not _is_mock(it.image_path):
                continue
            it.image_path = _url_for_item(it)
            i_touched += 1
        for c in cats:
            if c.image_path and not force and not _is_mock(c.image_path):
                continue
            c.image_path = _url_for_category(c)
            c_touched += 1
        for o in offers:
            if o.image_path and not force and not _is_mock(o.image_path):
                continue
            o.image_path = _url_for_offer(o)
            o_touched += 1
        db.session.commit()
        click.echo(f"OK - photos assigned: items={i_touched}, categories={c_touched}, offers={o_touched}")
        click.echo("     (real /admin uploads always win; run with --force to also refresh those)")
