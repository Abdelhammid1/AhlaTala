"""PaymentProvider protocol — every payment method implements this."""
from __future__ import annotations

from dataclasses import dataclass
from enum import Enum
from typing import Protocol, TYPE_CHECKING

if TYPE_CHECKING:
    from app.models import Order


class PaymentStatus(str, Enum):
    confirmed = "confirmed"  # money is already in-hand (cash) or captured
    redirect = "redirect"    # the client must complete an off-app flow
    failed = "failed"


@dataclass
class PaymentStartResult:
    status: PaymentStatus
    redirect_url: str | None = None  # populated when status == redirect
    reference: str | None = None     # gateway txn id or a stub id
    message: str | None = None       # human-readable when failed

    def to_json(self) -> dict:
        return {
            "status": self.status.value,
            "redirect_url": self.redirect_url,
            "reference": self.reference,
            "message": self.message,
        }


class PaymentProvider(Protocol):
    """Every provider must implement start(); most also want confirm()/fail()."""

    def start(self, order: "Order") -> PaymentStartResult: ...
