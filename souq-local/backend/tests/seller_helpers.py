"""Shared seller creation payloads for tests (Law 53-05 seller terms acceptance)."""

SELLER_TERMS_FIELDS = {
    "seller_terms_acknowledged": True,
    "acceptance_language": "en",
}


def with_seller_terms(payload: dict) -> dict:
    return {**payload, **SELLER_TERMS_FIELDS}
