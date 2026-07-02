from slugcase import is_slug, slugify


def test_basic_slug():
    assert slugify("Hello, World!") == "hello-world"


def test_unicode_folding():
    assert slugify("Crème Brûlée") == "creme-brulee"


def test_custom_separator():
    assert slugify("hello world", sep="_") == "hello_world"


def test_max_length_trims_cleanly():
    assert slugify("one two three", max_length=7) == "one-two"


def test_is_slug_roundtrip():
    assert is_slug("already-a-slug")
    assert not is_slug("Not A Slug")
