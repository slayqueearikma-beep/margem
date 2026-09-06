# Dribex Profile Photograph — Security & Law 09-08 Lawyer Review Report

**Date:** 2026-08-18  
**Application:** Dribex marketplace (Morocco)  
**Scope:** Profile photographs and image-upload pipeline (buyer profile photos, seller logos/covers used as avatars)  
**Status:** Technical controls implemented; **legal compliance NOT certified**  
**Prepared by:** Engineering audit (not legal counsel)

---

## Executive Summary

Dribex **does not perform biometric processing** (no facial recognition, embeddings, liveness, or biometric authentication). Before this audit:

- **Buyer profile photos did not exist** in the backend (registration UI collected a photo locally but never uploaded it).
- **Seller logos/covers** functioned as marketplace avatars via a generic presign→PUT upload pipeline.
- **Object-storage blobs were not deleted** on account deletion.
- **Azure/MinIO uploads lacked mandatory server-side byte validation** unless clients called `/uploads/validate`.
- **No EXIF stripping or Pillow-based decode validation** occurred on the server.

This audit verified Moroccan legal claims individually, hardened the upload pipeline, added buyer `profile_photo_url` with lifecycle tracking, and documented remaining legal/infrastructure uncertainties.

---

## 1. Legal Claims Verification Matrix (Section 28)

| Claim | Official source | Article / procedure | Verified? | Correct interpretation | Applies to Dribex? | Technical consequence |
|-------|-----------------|---------------------|-----------|------------------------|--------------------|-----------------------|
| **A.** Ordinary profile photo = personal data, not biometric | Loi 09-08 Art. 1 §1 (image data); Art. 1 §3 (sensitive categories) | Art. 1 | **Yes** | Photographs are personal data; **biometric/sensitive** only when used for **biometric identification** (Art. 1 §3). Dribex does not perform biometric ID. | **Yes** | Classify as ordinary personal data; do not treat as Art. 1 §3 sensitive data |
| **B.** Public display requires explicit informed consent | Loi 09-08 Art. 4, 5, 9, 10 | Art. 4–5 | **Partial / counsel** | Consent is default rule but **Art. 4(b) contract** and **Art. 4(e) legitimate interest** may apply to core profile display within the marketplace service. Separate consent likely for **unrelated** uses. | **Partial** | Do not auto-add checkbox without counsel; disclose purpose at collection; separate marketing consent already unbundled |
| **C.** Processing requires Déclaration Normale F211 | CNDP cndp.ma/formalites; Loi 09-08 Art. 12–14 | Art. 12–14 | **Partial** | Automated processing of personal data generally requires **CNDP declaration** (F211/F214). Not profile-photo-specific alone — part of platform processing inventory. | **Yes (platform-level)** | Register in processing registry; **counsel/CNDP filing pending** — not assumed hard blocker here |
| **D.** Profile photos do not trigger prior authorization | Loi 09-08 Art. 12; Art. 1 §3 | Art. 12, 1 §3 | **Yes (ordinary photos)** | **Authorization (F112)** applies to **sensitive** categories (Art. 1 §3), not ordinary photographs without biometric processing. | **Yes** | No F112 for ordinary profile photos |
| **E.** Foreign CDN/cloud = international transfer | Loi 09-08 Art. 43–44 | Art. 43–44 | **Yes in principle** | Transfer outside Morocco requires adequacy/analysis; **not automatically illegal**. | **If infra outside MA** | Map provider regions; counsel for Art. 43–44 |
| **F.** Transfer must be declared through F118 | CNDP procedures | — | **NOT VERIFIED** | **F118 was NOT verified** as current universal transfer form on cndp.ma (see Law 09-08 report). Use current CNDP transfer formalities — **LAWYER VERIFICATION REQUIRED**. | **If transfer occurs** | Do not cite F118 without counsel confirmation |
| **G.** Fixed 30-day deletion legally required | Loi 09-08 Art. 8 | Art. 8 | **No** | Erasure without undue delay (**10 days** for Art. 7–9 requests); **no statutory 30-day profile-photo rule**. | **No** | Use documented lifecycle, not invented 30-day rule |
| **H.** Must be permanently deleted from all DBs and backups | Loi 09-08 Art. 8 | Art. 8 | **Partial / incorrect as absolute** | Erasure obligation exists but **retention exceptions** and **backup technical limits** apply. Cannot claim instant backup purge unless architecture supports it. | **Yes** | Active objects deleted; DB refs cleared; backups follow documented retention |
| **I.** Advertising use requires separate opt-in | Loi 09-08 Art. 4, 9, 10 | Art. 4, 10 | **Partial / counsel** | Marketing/reuse for prospection generally requires **consent** (Art. 4, 10). Not verified that **every** profile display requires separate consent. **No advertising reuse found in codebase.** | **If reused for ads** | Technically separate purposes in registry; marketing consent already separate |

---

## 2. Claim-by-Claim Detail (Section 2 format)

### Claim A — Ordinary photo vs biometric

```
CLAIM: Ordinary profile photograph is standard personal data, not biometric data.
OFFICIAL SOURCE: Loi 09-08 (CNDP PDF), Art. 1 §1 and §3
ARTICLE: Art. 1
CURRENT INTERPRETATION: Image of identifiable person = personal data; sensitive/biometric only for Art. 1 §3 categories used for biometric identification.
APPLIES TO DRIBEX?: Yes — no FR/embeddings/liveness in code.
TECHNICAL CONSEQUENCE: No biometric vault; no F112 for photos alone.
```

### Claim B — Public display consent

```
CLAIM: Public profile-photo display requires explicit informed consent.
OFFICIAL SOURCE: Loi 09-08 Art. 4, 5
ARTICLE: Art. 4–5
CURRENT INTERPRETATION: NOT automatically true for core marketplace profile display (contract/legitimate interest candidates). Separate consent more likely for unrelated/publicity uses.
APPLIES TO DRIBEX?: Seller logos are public storefront branding; buyer photos optional.
TECHNICAL CONSEQUENCE: Purpose disclosure in privacy policy; no bundled marketing checkbox added without counsel.
VERDICT: LAWYER VERIFICATION REQUIRED for public buyer photo scope.
```

### Claim F — F118

```
CLAIM: Foreign hosting must be declared through F118.
VERDICT: LAWYER VERIFICATION REQUIRED — form not verified on current CNDP site.
```

---

## 3. Current Architecture (Section 29)

### 3.1 What exists in Dribex

| Asset | Storage | Display |
|-------|---------|---------|
| **Buyer profile photo** | `users.profile_photo_url` + blob `{user_id}/{uuid}-file` | Returned on `GET /auth/me` (authenticated) |
| **Seller logo/cover** | `seller_profiles.logo_image_url`, `cover_image_url` | Public discovery, community avatars |
| **Community avatar** | Derived from seller logo at runtime | Public in channel UI |

**No CDN** in repository. Images served via public blob URLs (Azure anonymous read, local `/media`, or MinIO public URL).

### 3.2 Data flow (Section 5)

```text
User device (ImagePicker, maxWidth downscale)
    ↓
POST /uploads/presign (auth, content-type allowlist, sanitized filename)
    ↓
PUT presigned URL (local: /uploads/local/{token}; Azure/MinIO: direct)
    ↓
Server validation (local PUT: magic bytes + Pillow sanitize + EXIF strip)
    ↓
POST /uploads/validate (Azure/MinIO — mobile now calls after PUT)
    ↓
Object storage: {user_id}/{uuid}-{filename}
    ↓
user_media_objects registry + profile/seller URL reference in PostgreSQL
    ↓
Public URL fetch (unauthenticated read on current backends)
    ↓
Other users / app UI (CachedNetworkImage)
```

**Also touches:** backups (infra-dependent), logs (`margem.storage` events, no image bytes), admin (marketplace admin upload UI), **no** analytics SDK on images.

### 3.3 International transfer map (Section 17)

| Provider | Country | Data | CNDP requirement | Status |
|----------|---------|------|------------------|--------|
| PostgreSQL | Deployment-dependent | URL refs | F211 platform filing | Counsel |
| Azure Blob | Region-dependent | Image bytes | Art. 43–44 if outside MA | Counsel |
| MinIO on-prem | Morocco (if local) | Image bytes | Lower transfer risk | Preferred for MA-only |
| Local `./data/media` | Host-dependent | Image bytes | Same as deployment | Dev/home |

---

## 4. Profile Photo Threat Model (Section 29)

| Threat | Likelihood | Impact | Mitigation |
|--------|------------|--------|------------|
| Malicious file upload (polyglot, decompression bomb) | Medium | High | Pillow decode, pixel cap, 8MB limit, format allowlist |
| MIME/extension spoofing | Medium | High | Magic bytes + decode; don't trust client Content-Type alone |
| IDOR (set another user's blob URL) | Medium | High | `validate_media_url` owner prefix on profile update |
| Predictable paths / enumeration | Low | Medium | UUID blob names under `{user_id}/` |
| Orphan blobs after delete | High (was present) | Medium | Account deletion prefix purge; supersede on replace |
| EXIF GPS leak | Medium | Medium | Pillow re-encode strips metadata |
| Public blob URL sharing | Medium | Medium | **Remaining:** URLs are world-readable on current backends |
| Admin browsing all photos | Low | Medium | No bulk admin gallery; least privilege RBAC |
| Advertising reuse | None found | — | No code path uses profile photos in ads |

---

## 5. Vulnerabilities Found & Fixes (Section 29)

| ID | Vulnerability | Fix | File | Test |
|----|---------------|-----|------|------|
| V1 | Buyer photo UI never uploaded | Wire upload + `PUT /auth/me/profile-photo` | `buyer_registration_screen.dart`, `auth.py` | `test_profile_photo_update_and_delete` |
| V2 | No buyer profile field | Migration 029 `profile_photo_url` | `029_profile_photo_security.py` | Same |
| V3 | Blobs orphaned on delete | `delete_all_user_media()` on account delete | `auth.py`, `media_lifecycle.py` | `test_account_deletion_purges_local_media` |
| V4 | No server sanitize/EXIF strip | `sanitize_image_bytes()` on local PUT | `image_processing.py`, `uploads.py` | `test_sanitize_strips_exif` |
| V5 | Azure/MinIO skip validation | Mobile calls `/uploads/validate`; extended for MinIO/local | `upload_service.dart`, `uploads.py` | Manual |
| V6 | MinIO URLs rejected on seller save | Pass `minio_public_url` to `validate_media_url` | `sellers.py` | Existing seller tests |
| V7 | Old logo not deleted on replace | `supersede_media_url()` | `sellers.py`, `media_registry.py` | — |
| V8 | No media audit trail | `user_media_objects` + structured logs | Migration 029, `media_registry.py` | Deletion test |

---

## 6. Fixes Implemented — Traceability

| Requirement | Source | Change | Component | Test | Status |
|-------------|--------|--------|-----------|------|--------|
| Server-side image validation | Art. 23 / security | Pillow sanitize | `image_processing.py` | `test_profile_photo_security.py` | Done |
| EXIF/metadata strip | Privacy best practice | Re-encode output | `image_processing.py` | EXIF test | Done |
| Owner-only media URLs | IDOR prevention | `validate_media_url` | `upload_security.py`, `auth.py` | IDOR test | Done |
| Deletion lifecycle | Art. 8 (partial) | Prefix purge + registry | `media_lifecycle.py` | Account delete test | Done |
| Purpose registry | Art. 3, 5 | `buyer_profile_photo` activity | `processing_registry.yaml` | — | Done |
| Buyer photo persistence | Product gap | `profile_photo_url` API | `auth.py`, mobile | Integration | Done |

---

## 7. Retention Lifecycle (Section 26)

| Stage | Action | Legal basis | Technical state |
|-------|--------|-------------|-----------------|
| Active account | Photo retained while user keeps it | Contract/service | Blob + DB URL |
| Replace | Old blob superseded + deleted | Business/security | `supersede_media_url` |
| Profile delete | URL cleared, blob deleted | Art. 8 erasure (counsel) | `DELETE /auth/me/profile-photo` |
| Account delete | Prefix purge all `{user_id}/` objects | Art. 8 + exceptions | `delete_all_user_media` |
| Backups | Retained per infra policy | Legal/security exception | **Not instant purge** — document in privacy policy |
| CDN cache | N/A (no CDN) | — | — |

**No invented 30-day statutory period.**

---

## 8. Remaining Risks & Legal Uncertainties

### Remaining technical risks

1. **Public read URLs** — Azure/local/MinIO blobs are fetchable by anyone with the URL (obscurity via UUID). Private profile visibility would require signed URLs or authenticated image proxy (not implemented).
2. **Azure upload bytes** — Client must call `/uploads/validate`; malicious client could skip (blob would exist but not be linkable to profile without owner validation).
3. **Backup purge** — Cannot guarantee immediate erasure from DR copies.
4. **No CDN purge** — Not applicable today; document if CDN added later.

### Legal uncertainties (counsel/CNDP)

1. Is separate **consent** required for **buyer profile photo display** to other authenticated users?
2. Which **CNDP form** applies to **international transfers** (F118 not verified)?
3. Is buyer profile photo a **separate F211** treatment or part of core account F211?
4. Retention period for **security logs** referencing upload events.

---

## 9. Production Blockers (Section 29)

| Blocker | Legally supported? | Status |
|---------|-------------------|--------|
| No way to store/delete buyer profile photo | Art. 8 operational erasure (counsel) | **Mitigated** |
| Misleading registration UI (photo never saved) | Art. 5 transparency | **Fixed** |
| Account deletion leaves orphan identity images | Art. 8 | **Mitigated** (active storage) |
| Biometric processing without authorization | Art. 1 §3 / F112 | **N/A** — not performed |
| Formal Law 09-08 compliance certificate | — | **Not claimed** |

---

## 10. Lawyer Review Checklist

- [ ] Confirm Art. 1 classification for buyer profile photos and seller logos
- [ ] Confirm legal basis for profile display (Art. 4(b) vs consent)
- [ ] Confirm CNDP filing scope (F211) including image storage subprocessors
- [ ] Confirm transfer formalities for actual cloud regions (reject F118 unless verified)
- [ ] Confirm erasure/back-up retention wording in privacy policy
- [ ] Confirm whether public blob URLs are acceptable for buyer profile photos
- [ ] Sign off before marketing use of any user photograph

---

## 11. Advertising Audit (Section 19)

**Search result:** No codebase usage of `profile_photo`, user images in marketing emails, banners, or recommendation training. Seller terms mention platform display of seller content — **counsel** should distinguish **storefront operation** from **advertising**.

---

**Disclaimer:** This report documents technical hardening aligned with verified statutory text where possible. It is **not** legal advice or CNDP approval.
