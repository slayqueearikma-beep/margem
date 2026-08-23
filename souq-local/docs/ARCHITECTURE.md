# MarGem Architecture

## Overview

MarGem is a **local discovery and connection marketplace** for Morocco. Users discover businesses, products, and services; transactions occur **off-platform** between buyers and sellers.

```
┌─────────────┐     HTTPS/JWT      ┌──────────────┐     asyncpg    ┌────────────┐
│ Flutter App │ ◄────────────────► │  FastAPI API │ ◄────────────► │ PostgreSQL │
│ Android/Web │                    │  (Uvicorn)   │                │            │
└─────────────┘                    └──────┬───────┘                └────────────┘
                                          │
                    ┌─────────────────────┼─────────────────────┐
                    ▼                     ▼                     ▼
              Azure Blob            Redis (opt)           SMTP Email
              (media)               (rate limits)
```

## Backend (`souq-local/backend`)

| Layer | Responsibility |
|-------|----------------|
| `routers/` | HTTP endpoints — auth, sellers, discovery, search, admin, uploads |
| `services/` | Business logic — security, premium, admin audit, email, uploads |
| `models/` | SQLAlchemy ORM entities |
| `schemas/` | Pydantic request/response models |
| `middleware/` | Security headers, request limits, logging context |
| `auth.py` | JWT validation, RBAC guards (`require_staff`, `require_admin`, etc.) |

### Key flows
- **Auth:** Register → email verify → JWT access + refresh rotation with reuse detection
- **Discovery:** Favorites, follows, saved searches, contact events, reports
- **Seller:** Storefront CRUD, products/services, verification request
- **Admin:** RBAC matrix, audit logging, moderation, premium grants

## Mobile (`souq-local/mobile`)

| Layer | Responsibility |
|-------|----------------|
| `features/` | Feature-first screens (buyer, seller, admin, auth, onboarding) |
| `core/services/` | API client, auth, storage, upload, location |
| `core/models/` | Domain models and payloads |
| `core/navigation/` | GoRouter, back handler, refresh notifier |
| `core/widgets/` | Shared UI components |

**State management:** Riverpod (`Provider`, `StateProvider`, `FutureProvider`)

## Infrastructure (`souq-local/infra`)

- **Azure Container Apps** + PostgreSQL Flexible Server + Key Vault (production)
- **Docker Compose** for local dev and home-server deployments
- **Terraform** modules for Azure resources

## Security boundaries

- Client validates input for UX; **server is authoritative**
- Staff admin routes require `isStaff` role + permission matrix
- Upload URLs validated against owner prefix + magic bytes
- Production config rejects default secrets, wildcard CORS/hosts, debug mode

## Data stores

| Store | Data |
|-------|------|
| PostgreSQL | Users, sellers, listings, messages, reviews, subscriptions, audit logs |
| Azure Blob / local disk | Product images, logos, covers |
| Secure storage (mobile) | JWT tokens |
| SharedPreferences | Language, theme, guest favorites, onboarding state |
