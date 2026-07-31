# MarGem Administration System

Private administration interface for platform operators. Completely isolated from the customer marketplace UI and APIs used by buyers/sellers.

## Architecture

```
souq-local/backend/
├── app/routers/admin.py          # /admin/* REST API
├── app/services/
│   ├── admin_permissions.py      # RBAC matrix
│   ├── admin_audit.py            # Immutable audit trail writes
│   ├── admin_login.py            # Staff login audit
│   └── admin_premium.py          # Premium grant logic
└── alembic/versions/014_admin_system.py

souq-local/mobile/lib/features/admin/
├── admin_shell.dart              # Sidebar layout + route guard helpers
├── admin_api_service.dart        # HTTP client
├── admin_models.dart             # DTOs
├── admin_providers.dart          # Riverpod providers
├── admin_theme.dart              # Enterprise console theme
└── screens/                      # Dashboard + management UIs
```

Customer routes (`/buyer/*`, `/seller/*`) are unchanged. Admin routes live under `/admin/*` and are not linked from buyer navigation.

## Roles

| Role | Label | Access |
|------|-------|--------|
| `super_admin` | Super Admin | Full access; only role that can assign staff roles |
| `admin` | Admin | User management, premium, categories, announcements |
| `moderator` | Moderator | Reports, listings, business verification |
| `support` | Support | Read-only across staff console (legacy) |

Normal users (`buyer`, `seller`) cannot access `/admin/*`.

## Permissions

| Permission | Roles |
|------------|-------|
| `dashboard.view` | All staff |
| `users.view` | All staff |
| `users.write` | super_admin, admin |
| `users.role` | super_admin only |
| `businesses.view` | All staff |
| `businesses.moderate` | super_admin, admin, moderator |
| `listings.view` | All staff |
| `listings.moderate` | super_admin, admin, moderator |
| `reports.view` | All staff |
| `reports.moderate` | super_admin, admin, moderator |
| `categories.view` | All staff |
| `categories.write` | super_admin, admin |
| `premium.view` | All staff |
| `premium.write` | super_admin, admin |
| `analytics.view` | All staff |
| `notifications.send` | super_admin, admin |
| `audit.view` | All staff |

## Security

- **Authentication:** Same JWT/session as marketplace; staff role checked on every `/admin/*` request via `require_staff`, `require_admin`, `require_moderator`, or `require_super_admin`.
- **Route protection (mobile):** `GoRouter` redirect blocks non-staff from `/admin/*`; staff logins route to `/admin/dashboard`.
- **Session expiry:** Existing token refresh failure clears session and redirects to login.
- **Password hashing:** bcrypt via existing `security` module.
- **Admin login audit:** Every staff login (success/failure) recorded in `admin_login_logs`.
- **Immutable audit:** `admin_audit_logs` rows are append-only; includes IP, user-agent, previous/new values.
- **Rate limiting:** Write endpoints limited (10–60/minute per route).
- **MFA (architecture):** `users.mfa_enabled` field reserved; enforcement hooks can be added without schema changes.

## Admin Workflow

1. Super admin promotes a user: `PATCH /admin/users/{id}/role` with `{ "role": "admin" }`.
2. Staff signs in via normal login; mobile app detects `role` and opens admin console.
3. Moderators review pending businesses and open reports.
4. Admins manage users, categories, premium grants, and announcements.
5. All actions are recorded in audit logs (`GET /admin/audit-logs`).

## API Endpoints

| Method | Path | Description |
|--------|------|-------------|
| GET | `/admin/me` | Staff identity + permissions |
| GET | `/admin/dashboard` | Platform overview, charts, system status |
| GET | `/admin/users` | Search/filter users (paginated) |
| GET | `/admin/users/{id}` | User detail |
| PATCH | `/admin/users/{id}/status` | Suspend/reactivate/delete |
| PATCH | `/admin/users/{id}/role` | Assign role (super_admin only) |
| POST | `/admin/users/{id}/reset-password` | Trigger password reset email |
| GET | `/admin/users/{id}/sessions` | Login history / devices |
| GET | `/admin/sellers` | List businesses |
| GET | `/admin/sellers/pending` | Pending verifications |
| POST | `/admin/sellers/{id}/verify` | Approve/reject verification |
| PATCH | `/admin/sellers/{id}/active` | Suspend/activate business |
| GET | `/admin/products` | List listings |
| PATCH | `/admin/products/{id}` | Hide/feature/pause/archive |
| GET | `/admin/reports` | Moderation queue |
| PATCH | `/admin/reports/{id}` | Resolve/dismiss |
| GET | `/admin/categories` | List categories |
| POST | `/admin/categories` | Create category |
| PATCH | `/admin/categories/{id}` | Update category |
| POST | `/admin/categories/reorder` | Reorder categories |
| POST | `/admin/users/{id}/premium` | Grant subscription |
| DELETE | `/admin/users/{id}/premium` | Revoke premium |
| GET | `/admin/analytics` | Growth, DAU/MAU, geography |
| POST | `/admin/announcements` | Queue broadcast (async delivery) |
| GET | `/admin/audit-logs` | Immutable action history |

## Mobile Entry

- Staff users are routed to `/admin/dashboard` after login or cold start.
- No admin navigation appears in buyer or seller shells.
- Admin UI uses a separate dark sidebar theme (`AdminTheme`).

## Database Migration

Run `alembic upgrade head` to apply `014_admin_system`:

- Adds `moderator`, `super_admin` to `userrole` enum
- Extends `admin_audit_logs` with IP, user-agent, success, previous/new JSON
- Creates `admin_login_logs`
- Adds `categories.sort_order`

## Promoting the First Super Admin

```sql
UPDATE users SET role = 'super_admin' WHERE email = 'you@example.com';
```

Or via API after an existing super_admin exists.
