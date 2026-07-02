# slugcase

Turn any string into a clean, URL-safe slug — accents folded, output deterministic, zero dependencies.

![Python 3.9+](https://img.shields.io/badge/python-3.9%2B-blue) ![License: MIT](https://img.shields.io/badge/license-MIT-green) ![Typed](https://img.shields.io/badge/types-py.typed-informational)

One import, two functions:

```python
>>> from slugcase import slugify, is_slug
>>> slugify("Crème Brûlée, 2024!")
'creme-brulee-2024'
>>> slugify("  hello   world  ", sep="_")
'hello_world'
>>> is_slug("already-a-slug")
True
```

## Install

Not yet on PyPI. Install from a checkout:

```sh
pip install .
```

Requires Python 3.9+. No runtime dependencies — stdlib only.

## Why slugcase

- **Deterministic** — the same input always yields the same slug; pure functions over stdlib `unicodedata` and `re`, no locale or environment influence.
- **Unicode-aware** — accented characters are NFKD-folded to ASCII (`Crème` → `creme`) before slugging.
- **Zero dependencies** — nothing to pin, nothing to audit.
- **Fully typed** — ships a `py.typed` marker; `slugify` and `is_slug` are annotated end to end.
- **Clean truncation** — `max_length` never leaves a dangling separator: `slugify("one two three", max_length=7)` returns `'one-two'`, not `'one-two-'`.

## API

### `slugify(text, *, sep="-", max_length=None) -> str`

Return a lowercase, URL-safe slug for `text`.

| Parameter | Type | Default | Meaning |
|---|---|---|---|
| `text` | `str` | — | The string to slug. |
| `sep` | `str` | `"-"` | Separator that replaces each run of non-word characters. |
| `max_length` | `int \| None` | `None` | If set, truncate the slug to this length, then strip any trailing separator. |

Accents are folded to ASCII, runs of non-word characters collapse to a single `sep`, and the result is trimmed of leading and trailing separators.

### `is_slug(text, *, sep="-") -> bool`

Return `True` if `text` is already a normalized slug — that is, non-empty and unchanged by `slugify` with the same `sep`.

```python
>>> is_slug("Not A Slug")
False
```

## How it works

1. NFKD-normalize the input (`unicodedata.normalize`).
2. Encode to ASCII, dropping anything that doesn't fold, and lowercase.
3. Collapse every run of characters outside `[a-z0-9]` to a single `sep`.
4. Strip leading/trailing separators; if `max_length` is set, truncate and strip again.

## Limitations

- **ASCII output only.** Characters with no ASCII decomposition — Cyrillic, CJK, emoji — are dropped, not transliterated: `slugify("北京")` returns `''`. If you need transliteration, use a dedicated library.
- **Not reversible.** Slugging discards information by design; there is no `unslugify`.

## Development

```sh
pip install -e ".[test]"
pytest
```

The test suite covers basic slugging, Unicode folding, custom separators, clean `max_length` truncation, and the `is_slug` round-trip.

## License

MIT