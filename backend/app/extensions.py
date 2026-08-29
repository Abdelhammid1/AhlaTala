"""Shared Flask extension singletons. Imported by app factory and by any module that needs them."""
from flask_jwt_extended import JWTManager
from flask_login import LoginManager
from flask_migrate import Migrate
from flask_sqlalchemy import SQLAlchemy

db = SQLAlchemy()
migrate = Migrate()
jwt = JWTManager()
login_manager = LoginManager()
login_manager.login_view = "admin.login"
login_manager.login_message = "الرجاء تسجيل الدخول أولاً"
