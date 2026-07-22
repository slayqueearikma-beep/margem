"""Azure Blob helpers for presigned uploads."""

from __future__ import annotations

import logging
from typing import Any

logger = logging.getLogger("margem.storage")


def extract_azure_account_key(credential: Any) -> str:
    """Return the account key from BlobServiceClient.credential across SDK versions.

    azure-storage-blob 12.x uses AzureNamedKeyCredential (``.named_key.key``),
    while older docs/examples use ``.account_key``. Using the wrong attribute
    raises AttributeError and surfaces as a generic "Storage service unavailable".
    """
    if credential is None:
        raise ValueError("Storage credential is missing")

    key = getattr(credential, "account_key", None)
    if isinstance(key, str) and key:
        return key

    named = getattr(credential, "named_key", None)
    if named is not None:
        named_key = getattr(named, "key", None)
        if isinstance(named_key, str) and named_key:
            return named_key

    direct = getattr(credential, "key", None)
    if isinstance(direct, str) and direct:
        return direct

    raise ValueError("Unable to read Azure storage account key from credential")


async def ensure_blob_container(container_client: Any) -> None:
    """Create the media container if it does not already exist."""
    try:
        await container_client.create_container()
        logger.info("created_blob_container name=%s", getattr(container_client, "container_name", "?"))
    except Exception as exc:  # noqa: BLE001 — Azure raises typed errors; treat exists as success
        message = str(exc).lower()
        # ContainerAlreadyExists / ResourceExistsError
        if "containeralreadyexists" in message or "already exists" in message or "409" in message:
            return
        # Some clients expose status_code
        status = getattr(exc, "status_code", None) or getattr(getattr(exc, "response", None), "status_code", None)
        if status == 409:
            return
        raise
