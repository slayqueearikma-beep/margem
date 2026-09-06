"""Helpers for legal acceptance in tests."""

from httpx import AsyncClient


async def accept_required_policies(
    client: AsyncClient,
    headers: dict[str, str],
    *,
    language: str = "en",
) -> None:
    response = await client.post(
        "/legal/accept",
        headers=headers,
        json={
            "policies": [
                {"policy_id": "terms_of_service"},
                {"policy_id": "privacy_policy"},
            ],
            "language": language,
            "acknowledged": True,
        },
    )
    assert response.status_code == 200, response.text
