"""Notification senders + segment resolver (E8)."""
from .registry import get_sender  # noqa: F401
from .segments import resolve_target  # noqa: F401
from .sender import LoggingSender, Sender  # noqa: F401
