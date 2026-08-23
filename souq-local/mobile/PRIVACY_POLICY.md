# MarGem Privacy Policy

**Last updated:** August 5, 2026

MarGem ("we", "our", "the app") is a local discovery and marketplace platform that connects buyers with businesses across Morocco.

## Information we collect

- **Account information:** email address, display name, password (stored as a hash), account type (buyer or seller), and optional phone number.
- **Seller information:** business name, description, address, city, phone number, location coordinates, opening hours, and images you upload.
- **Community chat:** city memberships, channel messages, reactions, mentions, and reports when you join a city community.
- **Usage data:** app interactions, device type, language preference, and crash logs (if enabled).
- **Location:** only when you grant permission, to show nearby businesses on the map.

## How we use information

- To create and manage your account.
- To display businesses, products, services, and reviews.
- To operate buyer–seller messaging and city community channels.
- To host images and media you upload.
- To improve app reliability, security, and moderation.

## Data storage

- Account data is stored in our secure PostgreSQL database.
- Images are stored in Azure Blob Storage.
- Authentication tokens are stored locally on your device using encrypted storage.
- Guest favorites may be stored locally on your device until you register.

## Subscriptions

MarGem offers free standard accounts plus optional paid plans:

| Plan | Price | Audience |
|------|-------|----------|
| Standard | Free | All users |
| MarGem Plus | 49 MAD / 30 days | Buyers |
| Seller Pro | 199 MAD / 30 days | Sellers |

See [Subscription Terms](../docs/SUBSCRIPTION_TERMS.md) and the full [Privacy Policy](../../legal/privacy/privacy-policy.md) for details.

## Sharing

We do not sell your personal data. We share data only with service providers required to run the app (e.g. cloud hosting, email delivery, maps, crash reporting).

## Your rights (Morocco Law 09-08 / GDPR where applicable)

- Access, correct, or export your data by contacting **privacy@margem.app**
- Delete your account in **Settings → Delete Account**, via `DELETE /auth/me`, or by emailing **privacy@margem.app**
- Withdraw location or marketing consent in app settings where available

## Children

MarGem is not directed to children under 16. We do not knowingly collect data from children under 16.

## Contact

- **privacy@margem.app**
- **dpo@margem.app** (Data Protection Officer)

Publish this document at your `PRIVACY_POLICY_URL` (default: `https://margem.app/privacy`) before Play Store submission. The complete legal package is in the repository [`legal/`](../../legal/) folder.
