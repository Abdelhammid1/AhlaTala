"""Admin blueprint — mounted at /admin. Server-rendered Jinja + Bootstrap 5 RTL."""
from flask import Blueprint

admin_bp = Blueprint("admin", __name__, url_prefix="/admin", template_folder="../templates/admin")

# Register routes
from . import auth, categories, cross_sells, discounts, items, loyalty, notifications, offers, option_groups, options, orders  # noqa: E402,F401
