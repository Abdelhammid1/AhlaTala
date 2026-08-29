"""Public API blueprint — mounted at /api/v1."""
from flask import Blueprint

api_bp = Blueprint("api", __name__, url_prefix="/api/v1")

# Import route modules to register handlers on the blueprint.
from . import auth, categories, customers, discount_codes, items, me, offers, orders, settings  # noqa: E402,F401
