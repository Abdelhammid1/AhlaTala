"""Payment providers — the seam between order creation and money movement.

E3 ships two implementations that share the same interface:
    * `cash.CashProvider`      — US3.1 (immediate confirmation, no gateway)
    * `stub_gateway.StubGatewayProvider` — US3.2's shape (redirect+callback)
      without needing real Moyasar/HyperPay/Tap credentials.

When a real Saudi gateway is picked, add e.g. `moyasar.MoyasarProvider`
implementing the same protocol and register it in `registry.get_provider`.
Nothing else in the app changes.
"""
from .cash import CashProvider  # noqa: F401
from .provider import PaymentProvider, PaymentStartResult, PaymentStatus  # noqa: F401
from .registry import get_provider  # noqa: F401
from .stub_gateway import StubGatewayProvider  # noqa: F401
