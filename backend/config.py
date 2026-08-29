"""Configuration objects — loaded from environment variables via python-dotenv."""
import os
from pathlib import Path

from dotenv import load_dotenv

# Load .env once, at import time
BASE_DIR = Path(__file__).resolve().parent
load_dotenv(BASE_DIR / ".env")


class Config:
    SECRET_KEY = os.getenv("SECRET_KEY", "dev-secret")
    JWT_SECRET_KEY = os.getenv("JWT_SECRET_KEY", SECRET_KEY)

    SQLALCHEMY_DATABASE_URI = os.getenv(
        "DATABASE_URL",
        "postgresql+psycopg://ahla_tolla:changeme@127.0.0.1:5432/ahla_tolla",
    )
    SQLALCHEMY_TRACK_MODIFICATIONS = False

    # Uploads
    UPLOAD_ROOT = os.getenv("UPLOAD_ROOT", "uploads")  # under app/static/
    MAX_CONTENT_LENGTH = 8 * 1024 * 1024  # 8 MB per upload

    # Admin seed
    ADMIN_EMAIL = os.getenv("ADMIN_EMAIL", "admin@ahlatolla.local")
    ADMIN_PASSWORD = os.getenv("ADMIN_PASSWORD", "admin")

    # E2 — checkout settings
    DELIVERY_FEE = os.getenv("DELIVERY_FEE", "15.00")
    CURRENCY = os.getenv("CURRENCY", "SAR")


class DevConfig(Config):
    DEBUG = True


class ProdConfig(Config):
    DEBUG = False
