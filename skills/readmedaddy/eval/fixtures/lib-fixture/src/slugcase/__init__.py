"""slugcase — deterministic, Unicode-aware string-to-slug conversion.

Public API:
    slugify(text, *, sep="-", max_length=None) -> str
    is_slug(text) -> bool
"""
from __future__ import annotations

import re
import unicodedata

__all__ = ["slugify", "is_slug"]
__version__ = "1.2.0"

_NON_WORD = re.compile(r"[^a-z0-9]+")


def slugify(text: str, *, sep: str = "-", max_length: int | None = None) -> str:
    """Return a lowercase, URL-safe slug for ``text``.

    Accents are folded to ASCII, runs of non-word characters collapse to a
    single ``sep``, and the result is trimmed of leading/trailing separators.

    >>> slugify("Crème Brûlée, 2024!")
    'creme-brulee-2024'
    >>> slugify("  hello   world  ", sep="_")
    'hello_world'
    """
    normalized = unicodedata.normalize("NFKD", text)
    ascii_text = normalized.encode("ascii", "ignore").decode("ascii").lower()
    slug = _NON_WORD.sub(sep, ascii_text).strip(sep)
    if max_length is not None and len(slug) > max_length:
        slug = slug[:max_length].rstrip(sep)
    return slug


def is_slug(text: str, *, sep: str = "-") -> bool:
    """Return ``True`` if ``text`` is already a normalized slug."""
    return bool(text) and slugify(text, sep=sep) == text
