"""Image upload helper — saves an incoming FileStorage to app/static/uploads/<bucket>/."""
from __future__ import annotations

import uuid
from pathlib import Path

from flask import current_app
from werkzeug.datastructures import FileStorage
from werkzeug.utils import secure_filename

ALLOWED_EXTS = {"jpg", "jpeg", "png", "webp"}


def _bucket_dir(bucket: str) -> Path:
    root = Path(current_app.static_folder) / current_app.config["UPLOAD_ROOT"] / bucket
    root.mkdir(parents=True, exist_ok=True)
    return root


def save_image(file: FileStorage | None, bucket: str) -> str | None:
    """Save `file` under uploads/<bucket>/. Returns the path relative to static/, or None."""
    if not file or not file.filename:
        return None

    ext = file.filename.rsplit(".", 1)[-1].lower()
    if ext not in ALLOWED_EXTS:
        return None

    fname = f"{uuid.uuid4().hex}.{ext}"
    # Keep the original human-readable stem around for debugging (optional)
    stem = secure_filename(Path(file.filename).stem)[:40] or "img"
    fname = f"{stem}-{fname}"

    target = _bucket_dir(bucket) / fname
    file.save(target)
    # Return path relative to /static (matches Item.image_path etc.)
    return f"{current_app.config['UPLOAD_ROOT']}/{bucket}/{fname}"


def absolute_url(rel_path: str | None, request_host_url: str) -> str | None:
    """Build a full URL from a stored relative path so mobile clients can load it.

    If the stored value is already a full http(s) URL (e.g. a mock image on
    loremflickr / picsum), return it as-is instead of prefixing /static.
    """
    if not rel_path:
        return None
    if rel_path.startswith(("http://", "https://")):
        return rel_path
    host = request_host_url.rstrip("/")
    # Flask serves the static/ folder at /static by default
    return f"{host}/static/{rel_path.lstrip('/')}"
