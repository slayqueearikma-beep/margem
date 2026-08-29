"""Storage provider abstraction — self-hosted MinIO (default) or Azure Blob (optional)."""

from __future__ import annotations

import logging
from abc import ABC, abstractmethod
from dataclasses import dataclass
from enum import Enum
from typing import TYPE_CHECKING
from uuid import UUID, uuid4

if TYPE_CHECKING:
    from app.models import User

logger = logging.getLogger("margem.storage")


class StoragePurpose(str, Enum):
    PROFILE = "profile"
    PRODUCT = "product"
    LISTING = "listing"
    PRIVATE = "private"
    GENERAL = "general"


@dataclass(frozen=True)
class PresignResult:
    upload_url: str
    public_url: str
    bucket: str
    object_key: str
    storage_provider: str


@dataclass(frozen=True)
class StoredObjectRef:
    bucket: str
    object_key: str
    public_url: str
    storage_provider: str


class StorageProvider(ABC):
    name: str

    @abstractmethod
    def bucket_for(self, purpose: StoragePurpose) -> str: ...

    @abstractmethod
    def build_object_key(self, *, user_id: UUID, purpose: StoragePurpose, filename: str) -> str: ...

    @abstractmethod
    async def presign_upload(
        self,
        *,
        user: User,
        filename: str,
        content_type: str,
        purpose: StoragePurpose = StoragePurpose.GENERAL,
    ) -> PresignResult: ...

    @abstractmethod
    def validate_owner_url(self, url: str, *, owner_user_id: UUID) -> str: ...

    @abstractmethod
    async def delete_object(self, *, bucket: str, object_key: str) -> bool: ...

    @abstractmethod
    async def delete_prefix(self, *, bucket: str, prefix: str) -> int: ...

    @abstractmethod
    def parse_object_ref(self, url: str) -> tuple[str, str] | None:
        """Return (bucket, object_key) if URL belongs to this provider."""

    def log_event(self, event: str, **fields: object) -> None:
        logger.info(
            "storage_event event=%s provider=%s %s",
            event,
            self.name,
            " ".join(f"{k}={v}" for k, v in fields.items()),
        )


def purpose_prefix(purpose: StoragePurpose) -> str:
    return {
        StoragePurpose.PROFILE: "profiles",
        StoragePurpose.PRODUCT: "products",
        StoragePurpose.LISTING: "listings",
        StoragePurpose.PRIVATE: "private",
        StoragePurpose.GENERAL: "uploads",
    }[purpose]


def build_object_key(*, user_id: UUID, purpose: StoragePurpose, filename: str) -> str:
    safe = filename.rsplit(".", 1)[0][:40] if filename else "file"
    return f"{purpose_prefix(purpose)}/{user_id}/{uuid4()}-{safe}"


def purpose_from_string(value: str | None) -> StoragePurpose:
    raw = (value or "general").strip().lower()
    try:
        return StoragePurpose(raw)
    except ValueError:
        return StoragePurpose.GENERAL


_provider_cache: StorageProvider | None = None


def get_storage_provider() -> StorageProvider:
    global _provider_cache
    if _provider_cache is not None:
        return _provider_cache
    from app.config import settings

    effective = settings.effective_storage_provider
    if effective == "azure":
        _provider_cache = AzureBlobStorageProvider()
    elif effective == "local":
        _provider_cache = LocalStorageProvider()
    else:
        _provider_cache = MinioStorageProvider()
    return _provider_cache


def reset_storage_provider_cache() -> None:
    global _provider_cache
    _provider_cache = None


class MinioStorageProvider(StorageProvider):
    name = "selfhosted"

    def bucket_for(self, purpose: StoragePurpose) -> str:
        from app.config import settings

        mapping = {
            StoragePurpose.PROFILE: settings.minio_bucket_profiles,
            StoragePurpose.PRODUCT: settings.minio_bucket_products,
            StoragePurpose.LISTING: settings.minio_bucket_listings,
            StoragePurpose.PRIVATE: settings.minio_bucket_private,
            StoragePurpose.GENERAL: settings.minio_bucket_private,
        }
        return mapping[purpose]

    def build_object_key(self, *, user_id: UUID, purpose: StoragePurpose, filename: str) -> str:
        return build_object_key(user_id=user_id, purpose=purpose, filename=filename)

    async def presign_upload(
        self,
        *,
        user: User,
        filename: str,
        content_type: str,
        purpose: StoragePurpose = StoragePurpose.GENERAL,
    ) -> PresignResult:
        from app.services.minio_storage import presign_put_for_bucket

        bucket = self.bucket_for(purpose)
        object_key = self.build_object_key(user_id=user.id, purpose=purpose, filename=filename)
        upload_url, access_url = presign_put_for_bucket(
            bucket=bucket,
            object_key=object_key,
            content_type=content_type,
            user_id=str(user.id),
        )
        self.log_event("storage_upload_presigned", user_id=user.id, bucket=bucket, key=object_key)
        return PresignResult(
            upload_url=upload_url,
            public_url=access_url,
            bucket=bucket,
            object_key=object_key,
            storage_provider=self.name,
        )

    def validate_owner_url(self, url: str, *, owner_user_id: UUID) -> str:
        from app.services.upload_security import validate_media_url

        return validate_media_url(url, owner_user_id=owner_user_id)

    async def delete_object(self, *, bucket: str, object_key: str) -> bool:
        from app.services.minio_storage import delete_object_in_bucket

        ok = delete_object_in_bucket(bucket, object_key)
        self.log_event(
            "storage_delete_success" if ok else "storage_delete_failure",
            bucket=bucket,
            key=object_key,
        )
        return ok

    async def delete_prefix(self, *, bucket: str, prefix: str) -> int:
        from app.services.minio_storage import delete_prefix_in_bucket

        return delete_prefix_in_bucket(bucket, prefix)

    def parse_object_ref(self, url: str) -> tuple[str, str] | None:
        from app.services.media_urls import parse_media_url

        parsed = parse_media_url(url)
        if parsed is None:
            return None
        bucket, key = parsed
        from app.services.minio_storage import all_buckets

        if bucket in all_buckets():
            return bucket, key
        return None


class AzureBlobStorageProvider(StorageProvider):
    name = "azure"

    def bucket_for(self, purpose: StoragePurpose) -> str:
        from app.config import settings

        return settings.azure_storage_container

    def build_object_key(self, *, user_id: UUID, purpose: StoragePurpose, filename: str) -> str:
        return build_object_key(user_id=user_id, purpose=purpose, filename=filename)

    async def presign_upload(
        self,
        *,
        user: User,
        filename: str,
        content_type: str,
        purpose: StoragePurpose = StoragePurpose.GENERAL,
    ) -> PresignResult:
        from app.services.azure_storage import presign_upload

        object_key = self.build_object_key(user_id=user.id, purpose=purpose, filename=filename)
        upload_url, public_url = await presign_upload(
            user_id=user.id,
            object_key=object_key,
            content_type=content_type,
        )
        return PresignResult(
            upload_url=upload_url,
            public_url=public_url,
            bucket=self.bucket_for(purpose),
            object_key=object_key,
            storage_provider=self.name,
        )

    def validate_owner_url(self, url: str, *, owner_user_id: UUID) -> str:
        from app.services.upload_security import validate_media_url

        return validate_media_url(url, owner_user_id=owner_user_id)

    async def delete_object(self, *, bucket: str, object_key: str) -> bool:
        from app.services.azure_storage import delete_blob

        return await delete_blob(object_key)

    async def delete_prefix(self, *, bucket: str, prefix: str) -> int:
        from app.services.azure_storage import delete_prefix

        return await delete_prefix(prefix)

    def parse_object_ref(self, url: str) -> tuple[str, str] | None:
        from app.services.media_urls import parse_media_url

        return parse_media_url(url)


class LocalStorageProvider(StorageProvider):
    name = "local"

    def bucket_for(self, purpose: StoragePurpose) -> str:
        return purpose.value

    def build_object_key(self, *, user_id: UUID, purpose: StoragePurpose, filename: str) -> str:
        return build_object_key(user_id=user_id, purpose=purpose, filename=filename)

    async def presign_upload(
        self,
        *,
        user: User,
        filename: str,
        content_type: str,
        purpose: StoragePurpose = StoragePurpose.GENERAL,
    ) -> PresignResult:
        from app.services.local_storage import public_media_url, sign_upload_token

        object_key = self.build_object_key(user_id=user.id, purpose=purpose, filename=filename)
        token = sign_upload_token(
            blob_name=object_key,
            content_type=content_type,
            user_id=str(user.id),
        )
        from app.config import settings

        base = settings.public_api_url.rstrip("/")
        return PresignResult(
            upload_url=f"{base}/uploads/local/{token}",
            public_url=public_media_url(object_key),
            bucket="local",
            object_key=object_key,
            storage_provider=self.name,
        )

    def validate_owner_url(self, url: str, *, owner_user_id: UUID) -> str:
        from app.services.upload_security import validate_media_url

        return validate_media_url(url, owner_user_id=owner_user_id)

    async def delete_object(self, *, bucket: str, object_key: str) -> bool:
        from app.services.local_storage import delete_local_blob

        return delete_local_blob(object_key)

    async def delete_prefix(self, *, bucket: str, prefix: str) -> int:
        from app.services.local_storage import delete_user_prefix

        return delete_user_prefix(prefix)

    def parse_object_ref(self, url: str) -> tuple[str, str] | None:
        from app.services.media_urls import parse_media_url

        parsed = parse_media_url(url)
        if parsed and parsed[0] == "local":
            return parsed
        return None
