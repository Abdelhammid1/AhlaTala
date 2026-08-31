"""Flask application factory."""
from __future__ import annotations

from flask import Flask, jsonify

from config import Config, DevConfig


def create_app(config_class: type[Config] = DevConfig) -> Flask:
    app = Flask(__name__, static_folder="static", static_url_path="/static")
    app.config.from_object(config_class)

    # --- Extensions ---
    from app.extensions import db, jwt, login_manager, migrate

    db.init_app(app)
    migrate.init_app(app, db)
    jwt.init_app(app)
    login_manager.init_app(app)

    # CORS — allow Flutter Web (running on any localhost port) to hit /api/v1/*.
    # The admin panel is same-origin so it doesn't need CORS.
    from flask_cors import CORS
    CORS(app, resources={r"/api/*": {"origins": "*"}}, supports_credentials=False)

    # --- Models must be imported so Alembic can see them ---
    from app import models  # noqa: F401

    # --- Observers (SQLAlchemy events) ---
    from app.observers import register_observers

    register_observers()

    # --- Blueprints ---
    from app.admin import admin_bp
    from app.api import api_bp

    app.register_blueprint(api_bp)
    app.register_blueprint(admin_bp)

    # --- Public marketing / legal pages ---
    @app.get("/")
    def _root():
        from flask import redirect, url_for
        return redirect(url_for("_privacy"))

    @app.get("/privacy")
    def _privacy():
        from flask import render_template
        from datetime import date
        return render_template(
            "privacy.html",
            updated_at=date.today().isoformat(),
            year=date.today().year,
        )

    @app.get("/account/delete")
    def _account_delete():
        """Public account-deletion instructions page required by Google Play's
        Data Safety declaration. Reachable without login and without the app."""
        from flask import render_template
        return render_template("account_delete.html")

    # --- Error handlers for API JSON responses ---
    @app.errorhandler(404)
    def _404(err):
        if _wants_json(err):
            return jsonify(error="not_found", message=str(err.description)), 404
        return err

    @app.errorhandler(400)
    def _400(err):
        if _wants_json(err):
            return jsonify(error="bad_request", message=str(err.description)), 400
        return err

    # --- CLI: `flask seed` + `flask import-menu` + `flask mock-images` ---
    from seed import register_cli
    register_cli(app)

    from import_menu import register_cli as register_import_cli
    register_import_cli(app)

    from mock_images import register_cli as register_mock_cli
    register_mock_cli(app)

    return app


def _wants_json(err) -> bool:
    from flask import request
    return request.path.startswith("/api/") or request.accept_mimetypes.best == "application/json"
