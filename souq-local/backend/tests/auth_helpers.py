"""Shared helpers for auth tests (signup OTP + register)."""

from httpx import AsyncClient


async def register_test_user(
    client: AsyncClient,
    *,
    email: str,
    password: str = "SecurePass1",
    account_type: str = "buyer",
    display_name: str = "Test User",
    phone: str = "+212600000000",
    channel: str = "email",
) -> dict:
    sent = await client.post(
        "/auth/signup/otp/send",
        json={"email": email, "phone": phone, "channel": channel},
    )
    assert sent.status_code == 200, sent.text
    code = sent.json().get("dev_code")
    assert code, "dev_code missing from signup OTP response in test environment"

    verified = await client.post(
        "/auth/signup/otp/verify",
        json={"email": email, "code": code, "channel": channel},
    )
    assert verified.status_code == 200, verified.text
    proof = verified.json()["signup_proof"]

    register = await client.post(
        "/auth/register",
        json={
            "email": email,
            "password": password,
            "account_type": account_type,
            "display_name": display_name,
            "signup_proof": proof,
        },
    )
    assert register.status_code == 201, register.text
    return register.json()
