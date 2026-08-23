# Self-Hosted Object Storage Migration

This document describes Dribex's transition from Azure Blob Storage to self-hosted
MinIO (S3-compatible) object storage on Moroccan infrastructure, while preserving
the Azure integration for optional re-enablement.

## Current architecture (default)

```
Client → HTTPS → Dribex API → MinIO (internal) → Unix server disk (/srv/dribex/storage)
```

- `STORAGE_PROVIDER=selfhosted` (default)
- Public media URLs are served via the API (`/media/{bucket}/{object_key}`), not direct MinIO access
- Uploads use presigned PUT URLs to MinIO on the internal Docker network

## Buckets

| Bucket | Purpose |
|--------|---------|
| `dribex-profiles` | Profile photographs |
| `dribex-products` | Product images |
| `dribex-listings` | Listing media |
| `dribex-private` | General/private uploads |
| `margem-media` | Legacy single-bucket objects (migration) |

Object keys use opaque UUIDs: `profiles/{user_id}/{uuid}-{sanitized-name}`

## Re-enable Azure (future)

Set `STORAGE_PROVIDER=azure` and provide `AZURE_STORAGE_CONNECTION_STRING`.
The application fails clearly if Azure credentials are missing when Azure is selected.
There is **no silent fallback** between providers.

## Existing Azure objects — migration strategy

**Do not silently delete Azure blobs.**

1. **Classify** objects in `user_media_objects` and URL fields (`profile_photo_url`, seller images, etc.)
2. **Required objects**: copy Azure → MinIO using a one-off migration job (not automated in this PR)
3. **During migration**: `validate_media_url` accepts both Azure HTTPS URLs and new API proxy URLs
4. **After migration**: update database URLs to API proxy form; verify; then decommission Azure reads
5. **Obsolete/orphaned**: mark in registry; delete only after legal retention review

## Backups

- **Primary**: MinIO data volume on the Unix server (`/srv/dribex/storage` or Docker volume)
- **Backup**: separate job copying MinIO data to a Moroccan backup destination
- Do not treat backup storage as primary; do not enable foreign-cloud backup by default without transfer assessment

## Configuration

See `backend/.env.example` and `infra/onprem/docker-compose.prod.yml`.

## Profile background images

No user profile **background/banner** feature exists in Dribex. Seller `cover_image_url` is storefront
cover art and is intentionally retained.
