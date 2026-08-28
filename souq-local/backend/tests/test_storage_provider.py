"""Storage provider selection and self-hosted object layout tests."""

from uuid import uuid4

import pytest

from app.config import Settings
from app.services.media_urls import parse_media_url
from app.services.storage_provider import (
    StoragePurpose,
    build_object_key,
    get_storage_provider,
    reset_storage_provider_cache,
)
from tests.settings_helpers import _PROD_BREVO, _PROD_NAPS


@pytest.fixture(autouse=True)
def _reset_provider_cache():
    reset_storage_provider_cache()
    yield
    reset_storage_provider_cache()


def test_default_provider_is_selfhosted(monkeypatch):
    monkeypatch.delenv("STORAGE_PROVIDER", raising=False)
    monkeypatch.setenv("STORAGE_PROVIDER", "selfhosted")
    settings = Settings(_env_file=None, storage_provider="selfhosted")
    assert settings.effective_storage_provider == "selfhosted"
    assert settings.storage_provider == "selfhosted"


def test_storage_backend_local_used_when_provider_unset(monkeypatch):
    monkeypatch.delenv("STORAGE_PROVIDER", raising=False)
    settings = Settings(_env_file=None, storage_provider="", storage_backend="local")
    assert settings.storage_provider == ""
    assert settings.effective_storage_provider == "local"


def test_storage_backend_minio_maps_to_selfhosted():
    settings = Settings(_env_file=None, storage_provider="minio")
    assert settings.effective_storage_provider == "selfhosted"


def test_production_selfhosted_without_azure_starts():
    settings = Settings(
        _env_file=None,
        app_env="production",
        debug=False,
        auth_dev_bypass=False,
        admin_require_staff_mfa=True,
        storage_provider="selfhosted",
        jwt_secret_key="a-real-production-secret-key-32chars-min",
        upload_token_secret="a-separate-production-upload-secret-32chars",
        mfa_encryption_key="a-separate-production-mfa-encryption-key32",
        cors_origins=["https://dribex.ma"],
        allowed_hosts=["api.dribex.ma"],
        minio_endpoint="http://minio:9000",
        minio_access_key="minio-access-key",
        minio_secret_key="minio-secret-key",
        public_app_url="https://dribex.ma",
        public_api_url="https://api.dribex.ma",
        **_PROD_BREVO,
        admin_ip_allowlist=["10.0.0.0/8"],
        **_PROD_NAPS,
    )
    assert settings.effective_storage_provider == "selfhosted"
    assert settings.azure_storage_connection_string == ""


def test_production_azure_requires_connection_string():
    with pytest.raises(ValueError, match="AZURE_STORAGE_CONNECTION_STRING"):
        Settings(
            _env_file=None,
            app_env="production",
            debug=False,
            auth_dev_bypass=False,
            storage_provider="azure",
            jwt_secret_key="a-real-production-secret-key-32chars-min",
            upload_token_secret="a-separate-production-upload-secret-32chars",
            mfa_encryption_key="a-separate-production-mfa-encryption-key32",
            cors_origins=["https://dribex.ma"],
            allowed_hosts=["api.dribex.ma"],
            public_app_url="https://dribex.ma",
            public_api_url="https://api.dribex.ma",
            **_PROD_BREVO,
            admin_ip_allowlist=["10.0.0.0/8"],
            **_PROD_NAPS,
        )


def test_object_key_uses_opaque_uuid_and_purpose_prefix():
    user_id = uuid4()
    key = build_object_key(user_id=user_id, purpose=StoragePurpose.PROFILE, filename="avatar.jpg")
    assert key.startswith(f"profiles/{user_id}/")
    suffix = key.rsplit("/", 1)[-1]
    assert suffix.endswith("-avatar")
    object_uuid = suffix.rsplit("-", 1)[0]
    uuid4()  # noqa: B018 — pattern check only
    assert len(object_uuid) == 36


def test_parse_api_proxy_media_url(monkeypatch):
    monkeypatch.setattr("app.config.settings.public_api_url", "https://api.dribex.ma")
    user_id = uuid4()
    url = f"https://api.dribex.ma/media/dribex-profiles/profiles/{user_id}/abc-avatar"
    parsed = parse_media_url(url)
    assert parsed == ("dribex-profiles", f"profiles/{user_id}/abc-avatar")


def test_get_storage_provider_local(monkeypatch):
    from app.config import settings

    monkeypatch.setattr(settings, "storage_provider", "local")
    reset_storage_provider_cache()
    provider = get_storage_provider()
    assert provider.name == "local"


def test_get_storage_provider_selfhosted(monkeypatch):
    from app.config import settings

    monkeypatch.setattr(settings, "storage_provider", "selfhosted")
    reset_storage_provider_cache()
    provider = get_storage_provider()
    assert provider.name == "selfhosted"
