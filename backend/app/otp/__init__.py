"""OTP delivery + verification (E9)."""
from .registry import get_sender  # noqa: F401
from .sender import LoggingSender, Sender, SmsSender  # noqa: F401
from .service import (  # noqa: F401
    MAX_ATTEMPTS_PER_CODE,
    MAX_CODES_PER_HOUR,
    OTP_TTL_SECONDS,
    OtpError,
    generate_and_send,
    verify,
)
