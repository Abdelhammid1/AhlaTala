"""Marshmallow schemas for the E3 order endpoints."""
from __future__ import annotations

from flask import request
from marshmallow import Schema, fields, validate

from app.uploads import absolute_url


def _to_absolute(rel: str | None) -> str | None:
    if not rel:
        return None
    return absolute_url(rel, request.host_url)


# ---------- Request ----------


class OrderCreateSelectionSchema(Schema):
    group_id = fields.Int(required=False, allow_none=True)
    option_id = fields.Int(required=True)


class OrderCreateLineSchema(Schema):
    item_id = fields.Int(required=True)
    quantity = fields.Int(load_default=1, validate=validate.Range(min=1))
    selections = fields.List(fields.Nested(OrderCreateSelectionSchema), load_default=list)


class OrderCreateSchema(Schema):
    customer_name = fields.Str(required=True, validate=validate.Length(min=2, max=120))
    customer_phone = fields.Str(required=True, validate=validate.Length(min=4, max=40))
    fulfillment_type = fields.Str(required=True, validate=validate.OneOf(["delivery", "pickup"]))
    delivery_address = fields.Str(load_default=None, allow_none=True)
    payment_method = fields.Str(
        required=True, validate=validate.OneOf(["cash", "apple_pay", "gateway_stub"])
    )
    notes = fields.Str(load_default=None, allow_none=True)
    lines = fields.List(fields.Nested(OrderCreateLineSchema), required=True)
    # E5 — loyalty redemption request; the server clamps and returns the applied amount.
    points_to_redeem = fields.Int(load_default=0, validate=validate.Range(min=0))
    # E6 — optional discount code. Server re-validates and 422s on invalid.
    discount_code = fields.Str(load_default=None, allow_none=True)


# ---------- Response ----------


class OrderLineSelectionSchema(Schema):
    group_id = fields.Method("g_gid")
    group_name_ar = fields.Method("g_gname")
    group_kind = fields.Method("g_gkind")
    option_id = fields.Method("g_oid")
    option_name_ar = fields.Method("g_oname")
    price_delta = fields.Method("g_pd")

    def g_gid(self, o): return o.group_id_snapshot
    def g_gname(self, o): return o.group_name_ar_snapshot
    def g_gkind(self, o): return o.group_kind_snapshot
    def g_oid(self, o): return o.option_id_snapshot
    def g_oname(self, o): return o.option_name_ar_snapshot
    def g_pd(self, o): return str(o.price_delta_snapshot)


class OrderLineSchema(Schema):
    id = fields.Int()
    item_id = fields.Int(allow_none=True)
    name_ar = fields.Method("g_name")
    image_url = fields.Method("g_image")
    base_price = fields.Method("g_base")
    quantity = fields.Int()
    unit_price = fields.Method("g_unit")
    line_price = fields.Method("g_line")
    sort_order = fields.Int()
    selections = fields.List(fields.Nested(OrderLineSelectionSchema))

    def g_name(self, l): return l.name_ar_snapshot
    def g_image(self, l): return _to_absolute(l.image_path_snapshot)
    def g_base(self, l): return str(l.base_price_snapshot)
    def g_unit(self, l): return str(l.unit_price)
    def g_line(self, l): return str(l.line_price)


class OrderSchema(Schema):
    id = fields.Int()
    order_number = fields.Str(allow_none=True)
    status = fields.Method("g_status")
    fulfillment_type = fields.Method("g_ftype")
    delivery_address = fields.Str(allow_none=True)
    customer_name = fields.Str()
    customer_phone = fields.Str()
    customer_id = fields.Int(allow_none=True)
    subtotal = fields.Method("g_sub")
    delivery_fee = fields.Method("g_fee")
    discount_amount = fields.Method("g_disc")
    total = fields.Method("g_total")
    payment_method = fields.Method("g_pay")
    payment_reference = fields.Str(allow_none=True)
    # E5 loyalty
    points_redeemed = fields.Int()
    points_earned = fields.Int()
    points_discount = fields.Method("g_pdisc")
    # E6 discount code
    code_discount = fields.Method("g_cdisc")
    discount_code = fields.Method("g_code")
    notes = fields.Str(allow_none=True)
    created_at = fields.DateTime()
    confirmed_at = fields.DateTime(allow_none=True)
    lines = fields.List(fields.Nested(OrderLineSchema))

    def g_status(self, o): return o.status.value if hasattr(o.status, "value") else o.status
    def g_ftype(self, o): return o.fulfillment_type.value if hasattr(o.fulfillment_type, "value") else o.fulfillment_type
    def g_pay(self, o): return o.payment_method.value if hasattr(o.payment_method, "value") else o.payment_method
    def g_sub(self, o): return str(o.subtotal)
    def g_fee(self, o): return str(o.delivery_fee)
    def g_disc(self, o): return str(o.discount_amount or 0)
    def g_total(self, o): return str(o.total)
    def g_pdisc(self, o): return str(o.points_discount or 0)
    def g_cdisc(self, o): return str(o.code_discount or 0)
    def g_code(self, o): return o.discount_code_snapshot
