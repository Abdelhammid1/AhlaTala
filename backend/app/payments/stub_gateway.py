"""Stub gateway — same shape as a real Saudi gateway (Moyasar/HyperPay/Tap).

Returns a redirect_url. The mobile client opens it (or renders an in-app
simulation), then POSTs to `/api/v1/orders/<id>/confirm` on success or
`/fail` on cancel. When a real gateway lands, this class is swapped for one
whose `start` calls the gateway SDK and returns the gateway's hosted URL.
"""
from flask import url_for

from app.models import Order

from .provider import PaymentStartResult, PaymentStatus


class StubGatewayProvider:
    def start(self, order: Order) -> PaymentStartResult:
        # A URL the mobile "gateway stub" screen can present as its target.
        # Not actually followed by the app — the app renders the simulation
        # itself and calls /confirm|/fail. The URL is here only to match
        # the real-gateway response shape.
        try:
            redirect_url = url_for(
                "api.payment_stub_page", order_id=order.id, _external=True
            )
        except Exception:
            redirect_url = f"/api/v1/payments/stub/{order.id}"

        return PaymentStartResult(
            status=PaymentStatus.redirect,
            redirect_url=redirect_url,
            reference=f"stub-{order.id}",
        )
