"""Marshmallow schemas for the public API — one schema per shape we ship.

We DON'T use the SQLAlchemy auto-schema because we want tight control over
- field naming (snake_case that mirrors the Flutter models exactly),
- image URL rewriting (relative paths → absolute URLs the phone can hit),
- what's included in the "list" shape vs the "detail" shape.
"""
from __future__ import annotations

from flask import request
from marshmallow import Schema, fields, post_dump

from app.uploads import absolute_url


def _to_absolute(rel: str | None) -> str | None:
    if not rel:
        return None
    return absolute_url(rel, request.host_url)


# ---------- Categories ----------


class CategoryListSchema(Schema):
    id = fields.Int()
    name_ar = fields.Str()
    name_en = fields.Str(allow_none=True)
    image_url = fields.Method("get_image_url")
    items_count = fields.Method("get_items_count")

    def get_image_url(self, obj):
        return _to_absolute(obj.image_path)

    def get_items_count(self, obj):
        return sum(1 for it in obj.items if it.is_active)


# ---------- Items — list shape (inside a category) ----------


class ItemListSchema(Schema):
    id = fields.Int()
    name_ar = fields.Str()
    name_en = fields.Str(allow_none=True)
    image_url = fields.Method("get_image_url")
    base_price = fields.Decimal(as_string=True)
    display_price_from = fields.Decimal(as_string=True, allow_none=True)
    price_is_variable = fields.Bool()
    calories = fields.Int(allow_none=True)

    def get_image_url(self, obj):
        return _to_absolute(obj.image_path)


# ---------- Options / OptionGroups / Item detail ----------


class OptionSchema(Schema):
    id = fields.Int()
    name_ar = fields.Str()
    name_en = fields.Str(allow_none=True)
    image_url = fields.Method("get_image_url")
    price_delta = fields.Decimal(as_string=True)
    is_default = fields.Bool()
    is_active = fields.Bool()
    sort_order = fields.Int()

    def get_image_url(self, obj):
        return _to_absolute(obj.image_path)


class OptionGroupSchema(Schema):
    id = fields.Int()
    name_ar = fields.Str()
    name_en = fields.Str(allow_none=True)
    kind = fields.Method("get_kind")            # str: variant|size|remove|add
    selection_type = fields.Method("get_sel")   # str: single|multi
    is_required = fields.Bool()
    sort_order = fields.Int()
    options = fields.List(fields.Nested(OptionSchema))

    def get_kind(self, obj):
        return obj.kind.value if hasattr(obj.kind, "value") else obj.kind

    def get_sel(self, obj):
        return obj.selection_type.value if hasattr(obj.selection_type, "value") else obj.selection_type


class ItemDetailSchema(Schema):
    id = fields.Int()
    category_id = fields.Int()
    name_ar = fields.Str()
    name_en = fields.Str(allow_none=True)
    description_ar = fields.Str(allow_none=True)
    description_en = fields.Str(allow_none=True)
    image_url = fields.Method("get_image_url")
    base_price = fields.Decimal(as_string=True)
    display_price_from = fields.Decimal(as_string=True, allow_none=True)
    price_is_variable = fields.Bool()
    calories = fields.Int(allow_none=True)
    option_groups = fields.List(fields.Nested(OptionGroupSchema))

    def get_image_url(self, obj):
        return _to_absolute(obj.image_path)

    @post_dump
    def _only_active_options(self, data, **_kwargs):
        # Trim inactive options so the app never has to render them
        for og in data.get("option_groups", []):
            og["options"] = [o for o in og["options"] if o.get("is_active")]
        return data
