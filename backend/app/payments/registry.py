"""Map PaymentMethod -> concrete PaymentProvider instance."""
from app.models import PaymentMethod

from .cash import CashProvider
from .provider import PaymentProvider
from .stub_gateway import StubGatewayProvider


def get_provider(method: PaymentMethod) -> PaymentProvider:
    if method == PaymentMethod.cash:
        return CashProvider()
    # Both apple_pay and gateway_stub route to the stub in E3.
    # Post-MVP: PaymentMethod.apple_pay -> real gateway (Moyasar/HyperPay/Tap).
    return StubGatewayProvider()
