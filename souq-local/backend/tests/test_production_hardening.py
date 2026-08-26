"""Production settings and auth hardening tests."""

import pytest
from pydantic import ValidationError

from app.config import Settings

from tests.settings_helpers import _PROD_NAPS

_PROD_ADMIN_IP = ["10.0.0.0/8"]


_PROD_AZURE = {
    "storage_provider": "azure",
    "azure_storage_connection_string": (
        "DefaultEndpointsProtocol=https;AccountName=x;AccountKey=y;EndpointSuffix=core.windows.net"
    ),
}
_PROD_MINIO = {
    "storage_provider": "selfhosted",
    "minio_endpoint": "http://minio:9000",
    "minio_access_key": "minio-access-key",
    "minio_secret_key": "minio-secret-key",
}


def test_production_rejects_default_jwt_secret():
    with pytest.raises(ValidationError, match="JWT_SECRET_KEY"):
        Settings(
            _env_file=None,
            app_env="production",
            debug=False,
            auth_dev_bypass=False,
            jwt_secret_key="change-this-secret-in-production-use-key-vault",
            cors_origins=["https://margem.ma"],
            allowed_hosts=["api.margem.ma"],
            smtp_host="smtp.example.com",
            public_app_url="https://margem.ma",
            public_api_url="https://api.margem.ma",
            admin_ip_allowlist=_PROD_ADMIN_IP,
            **_PROD_AZURE,
            **_PROD_NAPS,
        )


def test_production_rejects_debug_true():
    with pytest.raises(ValidationError, match="DEBUG"):
        Settings(
            _env_file=None,
            app_env="production",
            debug=True,
            auth_dev_bypass=False,
            jwt_secret_key="a-real-production-secret-key-32chars-min",
            cors_origins=["https://margem.ma"],
            allowed_hosts=["api.margem.ma"],
            smtp_host="smtp.example.com",
            public_app_url="https://margem.ma",
            public_api_url="https://api.margem.ma",
            admin_ip_allowlist=_PROD_ADMIN_IP,
            **_PROD_AZURE,
            **_PROD_NAPS,
        )


def test_production_accepts_rotated_secret():
    settings = Settings(
        _env_file=None,
        app_env="production",
        debug=False,
        auth_dev_bypass=False,
        jwt_secret_key="a-real-production-secret-key-32chars-min",
        upload_token_secret="a-separate-production-upload-secret-32chars",
        mfa_encryption_key="a-separate-production-mfa-encryption-key32",
        cors_origins=["https://margem.ma"],
        allowed_hosts=["api.margem.ma"],
        smtp_host="smtp.example.com",
        public_app_url="https://margem.ma",
        public_api_url="https://api.margem.ma",
        admin_ip_allowlist=_PROD_ADMIN_IP,
        **_PROD_AZURE,
        **_PROD_NAPS,
    )
    assert settings.app_env == "production"


def test_production_rejects_placeholder_secrets():
    with pytest.raises(ValidationError, match="JWT_SECRET_KEY"):
        Settings(
            _env_file=None,
            app_env="production",
            debug=False,
            auth_dev_bypass=False,
            jwt_secret_key="CHANGE_ME_MIN_32_CHAR_JWT_SECRET_KEY_32CHARS",
            upload_token_secret="a-separate-production-upload-secret-32chars",
            mfa_encryption_key="a-separate-production-mfa-encryption-key32",
            cors_origins=["https://margem.ma"],
            allowed_hosts=["api.margem.ma"],
            smtp_host="smtp.example.com",
            public_app_url="https://margem.ma",
            public_api_url="https://api.margem.ma",
            admin_ip_allowlist=_PROD_ADMIN_IP,
            **_PROD_AZURE,
            **_PROD_NAPS,
        )


def test_production_rejects_missing_admin_ip_allowlist():
    with pytest.raises(ValidationError, match="ADMIN_IP_ALLOWLIST"):
        Settings(
            _env_file=None,
            app_env="production",
            debug=False,
            auth_dev_bypass=False,
            jwt_secret_key="a-real-production-secret-key-32chars-min",
            upload_token_secret="a-separate-production-upload-secret-32chars",
            mfa_encryption_key="a-separate-production-mfa-encryption-key32",
            cors_origins=["https://margem.ma"],
            allowed_hosts=["api.margem.ma"],
            smtp_host="smtp.example.com",
            public_app_url="https://margem.ma",
            public_api_url="https://api.margem.ma",
            admin_ip_allowlist=[],
            **_PROD_AZURE,
            **_PROD_NAPS,
        )


def test_production_rejects_shared_mfa_key():
    with pytest.raises(ValidationError, match="MFA_ENCRYPTION_KEY"):
        Settings(
            _env_file=None,
            app_env="production",
            debug=False,
            auth_dev_bypass=False,
            jwt_secret_key="a-real-production-secret-key-32chars-min",
            upload_token_secret="a-separate-production-upload-secret-32chars",
            mfa_encryption_key="a-real-production-secret-key-32chars-min",
            cors_origins=["https://margem.ma"],
            allowed_hosts=["api.margem.ma"],
            smtp_host="smtp.example.com",
            public_app_url="https://margem.ma",
            public_api_url="https://api.margem.ma",
            admin_ip_allowlist=_PROD_ADMIN_IP,
            **_PROD_AZURE,
            **_PROD_NAPS,
        )


_NAPS_SAFETY_MESSAGE = (
    "Refusing to start: non-production APP_ENV with NAPS_ENVIRONMENT=production"
)


def test_naps_production_environment_rejected_for_staging_app_env():
    with pytest.raises(ValidationError, match=_NAPS_SAFETY_MESSAGE):
        Settings(
            _env_file=None,
            app_env="staging",
            naps_environment="production",
        )


def test_naps_production_environment_rejected_for_development_app_env():
    with pytest.raises(ValidationError, match=_NAPS_SAFETY_MESSAGE):
        Settings(
            _env_file=None,
            app_env="development",
            naps_environment="production",
        )


def test_naps_sandbox_allowed_for_staging_app_env():
    settings = Settings(
        _env_file=None,
        app_env="staging",
        debug=False,
        auth_dev_bypass=False,
        jwt_secret_key="a-real-production-secret-key-32chars-min",
        upload_token_secret="a-separate-production-upload-secret-32chars",
        mfa_encryption_key="a-separate-production-mfa-encryption-key32",
        cors_origins=["https://margem.ma"],
        allowed_hosts=["api.margem.ma"],
        smtp_host="smtp.example.com",
        public_app_url="https://margem.ma",
        public_api_url="https://api.margem.ma",
        admin_ip_allowlist=_PROD_ADMIN_IP,
        naps_environment="sandbox",
        **_PROD_MINIO,
    )
    assert settings.naps_environment == "sandbox"


def test_naps_sandbox_allowed_for_development_app_env():
    settings = Settings(
        _env_file=None,
        app_env="development",
        naps_environment="sandbox",
    )
    assert settings.naps_environment == "sandbox"


def test_naps_production_allowed_for_production_app_env():
    settings = Settings(
        _env_file=None,
        app_env="production",
        debug=False,
        auth_dev_bypass=False,
        jwt_secret_key="a-real-production-secret-key-32chars-min",
        upload_token_secret="a-separate-production-upload-secret-32chars",
        mfa_encryption_key="a-separate-production-mfa-encryption-key32",
        cors_origins=["https://margem.ma"],
        allowed_hosts=["api.margem.ma"],
        smtp_host="smtp.example.com",
        public_app_url="https://margem.ma",
        public_api_url="https://api.margem.ma",
        admin_ip_allowlist=_PROD_ADMIN_IP,
        naps_environment="production",
        naps_api_key="test-production-naps-api-key-32chars-min",
        **_PROD_AZURE,
        **_PROD_NAPS,
    )
    assert settings.naps_environment == "production"


def test_host_lists_accept_comma_delimited_docker_environment_values():
    settings = Settings(
        _env_file=None,
        cors_origins="https://margem.ma,https://admin.margem.ma",
        allowed_hosts="api.margem.ma,admin-api.margem.ma",
    )
    assert settings.cors_origins == ["https://margem.ma", "https://admin.margem.ma"]
    assert settings.allowed_hosts == [
        "api.margem.ma",
        "admin-api.margem.ma",
        "localhost",
        "127.0.0.1",
    ]


def test_cors_origins_from_env_accepts_comma_separated_and_malformed_json(monkeypatch):
    monkeypatch.setenv(
        "CORS_ORIGINS",
        "http://192.168.11.101:8000,http://192.168.11.101:8080",
    )
    settings = Settings(_env_file=None)
    assert settings.cors_origins == [
        "http://192.168.11.101:8000",
        "http://192.168.11.101:8080",
    ]

    monkeypatch.setenv(
        "CORS_ORIGINS",
        '["http://192.168.11.101:8000","http://192.168.11.101:8080',
    )
    settings = Settings(_env_file=None)
    assert settings.cors_origins == [
        "http://192.168.11.101:8000",
        "http://192.168.11.101:8080",
    ]


@pytest.mark.asyncio
async def test_invalid_token_returns_401_without_firebase(prepare_database):
    from httpx import ASGITransport, AsyncClient

    from app.main import app

    transport = ASGITransport(app=app)
    async with AsyncClient(transport=transport, base_url="http://test") as client:
        res = await client.get("/auth/me", headers={"Authorization": "Bearer not-a-valid-jwt"})
        assert res.status_code == 401
        assert res.json()["detail"] == "Invalid token"
