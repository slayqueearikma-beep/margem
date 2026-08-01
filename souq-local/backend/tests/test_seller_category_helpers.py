"""Unit tests for seller category helpers."""

from uuid import uuid4

import pytest

from app.services.seller_categories import (
    MAX_SELLER_CATEGORIES,
    normalize_category_ids,
    validate_category_ids,
)


def test_normalize_category_ids_deduplicates():
    a, b = uuid4(), uuid4()
    assert normalize_category_ids([a, b, a]) == [a, b]


def test_validate_category_ids_requires_at_least_one():
    with pytest.raises(ValueError, match="at least one"):
        validate_category_ids([])


def test_validate_category_ids_limits_to_three():
    ids = [uuid4() for _ in range(MAX_SELLER_CATEGORIES + 1)]
    with pytest.raises(ValueError, match="at most"):
        validate_category_ids(ids)
