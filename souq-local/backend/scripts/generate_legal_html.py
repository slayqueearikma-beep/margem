#!/usr/bin/env python3
"""Generate localized legal HTML pages under backend/static/legal/."""

from __future__ import annotations

from pathlib import Path

ROOT = Path(__file__).resolve().parents[1] / "static" / "legal"
VERSION = "1.1.0"
EFFECTIVE = "August 1, 2026"
UPDATED = "August 10, 2026"

CSS = """
:root { --text:#1a1a2e; --muted:#5c5c7a; --border:#e8e8f0; --accent:#6b5ce7; --bg:#faf9f7; }
* { box-sizing: border-box; }
body { font-family: system-ui, -apple-system, "Segoe UI", Roboto, "Noto Sans Arabic", sans-serif;
  line-height: 1.65; color: var(--text); background: var(--bg); margin: 0; padding: 0; }
.wrap { max-width: 760px; margin: 0 auto; padding: 2rem 1.25rem 4rem; }
header { border-bottom: 1px solid var(--border); margin-bottom: 2rem; padding-bottom: 1rem; }
h1 { font-size: 1.75rem; margin: 0 0 .5rem; letter-spacing: -0.02em; }
.meta { color: var(--muted); font-size: .9rem; }
h2 { font-size: 1.15rem; margin: 2rem 0 .75rem; color: var(--text); }
p, li { font-size: .98rem; }
ul { padding-inline-start: 1.25rem; }
table { width: 100%; border-collapse: collapse; font-size: .92rem; margin: 1rem 0; }
th, td { border: 1px solid var(--border); padding: .55rem .65rem; text-align: start; vertical-align: top; }
th { background: #f3f2ff; }
.note { background: #fff8e6; border: 1px solid #f0d78c; border-radius: 8px; padding: .85rem 1rem; font-size: .92rem; }
footer { margin-top: 3rem; padding-top: 1rem; border-top: 1px solid var(--border); color: var(--muted); font-size: .85rem; }
.lang-nav { margin-top: .75rem; font-size: .88rem; }
.lang-nav a { color: var(--accent); margin-inline-end: .75rem; }
[dir="rtl"] body { text-align: right; }
"""

DOCS: dict[str, dict[str, dict[str, str]]] = {
    "privacy": {
        "en": {
            "title": "Privacy Policy",
            "body": """
<p>MarGem ("we", "us") operates a local discovery and marketplace platform for Morocco (Android, iOS, and Web). This Privacy Policy explains how we collect, use, retain, and protect personal information.</p>
<div class="note"><strong>Legal notice:</strong> MarGem is subject to Morocco's Law 09-08 on the protection of individuals with regard to the processing of personal data. We have <strong>not</strong> confirmed CNDP registration or authorization in this repository — counsel must verify before publication.</div>
<h2>1. Data we collect</h2>
<ul>
<li><strong>Account:</strong> email, display name, password (stored as a bcrypt hash), account type, optional phone, email verification status</li>
<li><strong>Seller profile:</strong> business name, description, address, city, coordinates, contact links, images, listings, hours, payment/delivery options (display only)</li>
<li><strong>User content:</strong> reviews, buyer–seller messages, city community messages, reports, favorites, follows, saved searches</li>
<li><strong>Automatic:</strong> device/OS, app version, language, IP address, request IDs, refresh-token metadata (device name, IP, user agent, last seen)</li>
<li><strong>Location:</strong> only with your permission, to show nearby businesses on the map</li>
<li><strong>Guests:</strong> favorites and preferences stored locally on the device until you sign in</li>
</ul>
<h2>2. Why we process data</h2>
<p>We use data to provide accounts, listings, messaging, community channels, verification, notifications, discovery, security, fraud prevention, analytics, legal compliance, and premium features. We do <strong>not</strong> sell personal information or run third-party ad networks.</p>
<h2>3. Third-party services (actual)</h2>
<table>
<tr><th>Service</th><th>Purpose</th></tr>
<tr><td>PostgreSQL</td><td>Primary database</td></tr>
<tr><td>Azure Blob Storage or local media storage</td><td>Uploaded images/media</td></tr>
<tr><td>SMTP (optional)</td><td>Verification, password reset, service email</td></tr>
<tr><td>Firebase Admin (optional)</td><td>Identity token verification only if enabled</td></tr>
<tr><td>Google Maps (optional, ENABLE_MAPS)</td><td>Map display when configured</td></tr>
<tr><td>Sentry (optional)</td><td>Crash/error reporting when SENTRY_DSN is set</td></tr>
<tr><td>Azure Application Insights (optional)</td><td>Performance telemetry when configured</td></tr>
<tr><td>Redis (optional)</td><td>Rate limiting / caching</td></tr>
</table>
<p>Payments for subscriptions are <strong>not</strong> processed in-app today; billing is manual/admin-assisted. Off-platform payments between buyers and sellers are arranged directly between users.</p>
<h2>4. International transfers</h2>
<p>MarGem is based in Morocco. Data may be processed in Morocco and in countries where our infrastructure providers operate (for example Microsoft Azure regions). Transfers outside Morocco or the EEA use appropriate safeguards where required by law.</p>
<h2>5. Retention & deletion</h2>
<p>We keep data only as long as needed for the purposes above. When you delete your account, we anonymize your profile (email becomes <code>deleted+{uuid}@invalid.local</code>), remove storefronts, listings, messages, favorites, and tokens, and anonymize community messages. Limited records (billing, security logs, backups up to 90 days, legal holds) may be retained as described in our Account Deletion Policy.</p>
<h2>6. Your rights (Morocco Law 09-08)</h2>
<p>You may request access, rectification, opposition, and deletion. Contact <a href="mailto:privacy@margem.app">privacy@margem.app</a> or use in-app deletion. Data export is available via <code>GET /auth/me/export</code> when signed in.</p>
<h2>7. Security</h2>
<p>We use TLS in transit, bcrypt password hashing, encrypted token storage on mobile, access controls, audit logging, and rate limiting. No system is completely secure.</p>
<h2>8. Children</h2>
<p>MarGem is not directed to children under 16. We do not knowingly collect children's data.</p>
<h2>9. Contact</h2>
<p>Privacy: <a href="mailto:privacy@margem.app">privacy@margem.app</a> · DPO: <a href="mailto:dpo@margem.app">dpo@margem.app</a></p>
""",
        },
        "fr": {
            "title": "Politique de confidentialité",
            "body": """
<p>MarGem (« nous ») exploite une plateforme locale de découverte et de marketplace au Maroc (Android, iOS et Web). Cette politique explique comment nous collectons, utilisons, conservons et protégeons les données personnelles.</p>
<div class="note"><strong>Avis juridique :</strong> MarGem est soumis à la loi marocaine 09-08. Nous n'avons <strong>pas</strong> confirmé l'enregistrement ou l'autorisation CNDP dans ce dépôt — un avocat doit vérifier avant publication.</div>
<h2>1. Données collectées</h2>
<ul>
<li><strong>Compte :</strong> e-mail, nom affiché, mot de passe (haché bcrypt), type de compte, téléphone optionnel</li>
<li><strong>Vendeur :</strong> entreprise, description, adresse, ville, coordonnées, contacts, images, annonces</li>
<li><strong>Contenu :</strong> avis, messages, messages communautaires, signalements, favoris, recherches enregistrées</li>
<li><strong>Automatique :</strong> appareil, version, langue, adresse IP, métadonnées de session</li>
<li><strong>Localisation :</strong> uniquement avec votre autorisation pour la carte</li>
</ul>
<h2>2. Finalités</h2>
<p>Fourniture du service, messagerie, communauté, sécurité, analyses, conformité légale et fonctionnalités premium. Nous ne vendons pas vos données.</p>
<h2>3. Services tiers</h2>
<p>PostgreSQL, stockage média (Azure ou local), SMTP optionnel, Firebase optionnel, Google Maps optionnel, Sentry optionnel, Application Insights optionnel, Redis optionnel. Les paiements d'abonnement ne sont pas encore traités dans l'application.</p>
<h2>4. Transferts internationaux</h2>
<p>Données traitées au Maroc et chez nos hébergeurs (ex. Azure). Garanties appropriées lorsque la loi l'exige.</p>
<h2>5. Conservation et suppression</h2>
<p>Suppression de compte via l'application ou <code>DELETE /auth/me</code>. E-mail anonymisé en <code>deleted+{uuid}@invalid.local</code>. Export via <code>GET /auth/me/export</code>.</p>
<h2>6. Vos droits (loi 09-08)</h2>
<p>Accès, rectification, opposition, suppression : <a href="mailto:privacy@margem.app">privacy@margem.app</a></p>
<h2>7. Contact</h2>
<p><a href="mailto:privacy@margem.app">privacy@margem.app</a> · <a href="mailto:dpo@margem.app">dpo@margem.app</a></p>
""",
        },
        "ar": {
            "title": "سياسة الخصوصية",
            "body": """
<p>تدير MarGem («نحن») منصة اكتشاف وسوق محلية في المغرب (أندرويد وiOS والويب). توضح هذه السياسة كيفية جمع بياناتك الشخصية واستخدامها وحمايتها.</p>
<div class="note"><strong>تنبيه قانوني:</strong> تخضع MarGem للقانون المغربي 09-08. <strong>لم</strong> يتم تأكيد التصريح أو الترخيص لدى اللجنة الوطنية (CNDP) في هذا المستودع — يجب على المستشار القانوني التحقق قبل النشر.</div>
<h2>1. البيانات التي نجمعها</h2>
<ul>
<li><strong>الحساب:</strong> البريد الإلكتروني، الاسم المعروض، كلمة المرور (مشفّرة bcrypt)، نوع الحساب، رقم الهاتف اختياري</li>
<li><strong>البائع:</strong> اسم النشاط، الوصف، العنوان، المدينة، الإحداثيات، وسائل التواصل، الصور، القوائم</li>
<li><strong>المحتوى:</strong> التقييمات، الرسائل، رسائل المجتمع، البلاغات، المفضلة، عمليات البحث المحفوظة</li>
<li><strong>تلقائياً:</strong> الجهاز، إصدار التطبيق، اللغة، عنوان IP، بيانات الجلسة</li>
<li><strong>الموقع:</strong> فقط بإذنك لعرض المحلات القريبة على الخريطة</li>
</ul>
<h2>2. أغراض المعالجة</h2>
<p>تقديم الخدمة، المراسلة، المجتمعات، الأمان، التحليلات، الامتثال القانوني، والميزات المميزة. لا نبيع بياناتك الشخصية.</p>
<h2>3. خدمات الطرف الثالث</h2>
<p>PostgreSQL، تخزين الوسائط (Azure أو محلي)، SMTP اختياري، Firebase اختياري، خرائط Google اختياري، Sentry اختياري، Application Insights اختياري، Redis اختياري. مدفوعات الاشتراك غير مفعّلة داخل التطبيق حالياً.</p>
<h2>4. النقل الدولي</h2>
<p>قد تُعالج البيانات في المغرب ودى مزودي البنية التحتية (مثل Azure) مع الضمانات المناسبة عند الاقتضاء.</p>
<h2>5. الاحتفاظ والحذف</h2>
<p>حذف الحساب من الإعدادات أو عبر <code>DELETE /auth/me</code>. يُستبدل البريد بـ <code>deleted+{uuid}@invalid.local</code>. التصدير عبر <code>GET /auth/me/export</code>.</p>
<h2>6. حقوقك (القانون 09-08)</h2>
<p>الوصول، التصحيح، الاعتراض، الحذف: <a href="mailto:privacy@margem.app">privacy@margem.app</a></p>
<h2>7. التواصل</h2>
<p><a href="mailto:privacy@margem.app">privacy@margem.app</a> · <a href="mailto:dpo@margem.app">dpo@margem.app</a></p>
""",
        },
    },
    "terms": {
        "en": {
            "title": "Terms of Service",
            "body": """
<p>These Terms govern your use of MarGem. By creating an account or using the Platform, you agree to these Terms and our Privacy Policy.</p>
<h2>1. The Platform</h2>
<p>MarGem helps users discover local businesses, products, and services in Morocco. MarGem is an intermediary — we do not own inventory, employ sellers, or guarantee off-platform transactions.</p>
<h2>2. Accounts</h2>
<p>You must provide accurate information, keep credentials secure, and be at least 16 years old. You are responsible for activity under your account.</p>
<h2>3. Sellers</h2>
<p>Sellers must provide truthful listings, comply with Moroccan law, handle customer communications responsibly, and not list prohibited content. Verification badges indicate review status, not a guarantee of quality or legality.</p>
<h2>4. Payments</h2>
<p>Buyer–seller payments are arranged directly between users (cash, transfer, etc.) unless we later enable in-app billing. Premium subscriptions are administered manually today and are blocked for self-service checkout in production.</p>
<h2>5. User content</h2>
<p>You retain ownership of content you post but grant MarGem a license to host, display, and moderate it on the Platform. Do not post illegal, fraudulent, hateful, or infringing content.</p>
<h2>6. Prohibited conduct</h2>
<p>No spam, scraping, impersonation, harassment, malware, or attempts to bypass security or rate limits.</p>
<h2>7. Limitation of liability</h2>
<p>MarGem is provided "as is" to the maximum extent permitted by law. We are not liable for off-platform dealings, seller conduct, or indirect damages.</p>
<h2>8. Governing law</h2>
<p>These Terms are governed by the laws of the Kingdom of Morocco, subject to mandatory consumer protections. Disputes may be brought before competent Moroccan courts unless counsel approves alternative dispute resolution.</p>
<h2>9. Contact</h2>
<p><a href="mailto:legal@margem.ma">legal@margem.ma</a> · <a href="mailto:support@margem.ma">support@margem.ma</a></p>
""",
        },
        "fr": {
            "title": "Conditions d'utilisation",
            "body": """
<p>Ces conditions régissent votre utilisation de MarGem. En créant un compte, vous acceptez ces conditions et notre politique de confidentialité.</p>
<h2>1. La plateforme</h2>
<p>MarGem met en relation acheteurs et vendeurs locaux au Maroc. Nous ne sommes pas partie aux transactions hors plateforme.</p>
<h2>2. Comptes</h2>
<p>Informations exactes, sécurité des identifiants, âge minimum 16 ans.</p>
<h2>3. Vendeurs</h2>
<p>Annonces véridiques, respect de la loi marocaine, contenu interdit interdit. Le badge de vérification n'est pas une garantie.</p>
<h2>4. Paiements</h2>
<p>Paiements directs entre utilisateurs. Abonnements premium gérés manuellement aujourd'hui.</p>
<h2>5. Responsabilité</h2>
<p>Service fourni « en l'état » dans les limites légales. Loi marocaine applicable.</p>
<h2>6. Contact</h2>
<p><a href="mailto:legal@margem.ma">legal@margem.ma</a></p>
""",
        },
        "ar": {
            "title": "شروط الاستخدام",
            "body": """
<p>تحكم هذه الشروط استخدامك لـ MarGem. بإنشاء حساب، فإنك توافق على هذه الشروط وسياسة الخصوصية.</p>
<h2>1. المنصة</h2>
<p>تساعد MarGem على اكتشاف المحلات والمنتجات والخدمات المحلية في المغرب. نحن وسيط — لا نملك مخزون البائعين ولا نضمن المعاملات خارج المنصة.</p>
<h2>2. الحسابات</h2>
<p>معلومات دقيقة، حماية بيانات الدخول، الحد الأدنى للعمر 16 سنة.</p>
<h2>3. البائعون</h2>
<p>قوائم صحيحة، الامتثال للقانون المغربي، محتوى محظور ممنوع. شارة التوثيق ليست ضماناً للجودة.</p>
<h2>4. المدفوعات</h2>
<p>الدفع مباشرة بين المستخدمين. الاشتراكات المميزة تُدار يدوياً حالياً.</p>
<h2>5. المسؤولية</h2>
<p>الخدمة «كما هي» ضمن حدود القانون. يخضع النزاع للقانون المغربي.</p>
<h2>6. التواصل</h2>
<p><a href="mailto:legal@margem.ma">legal@margem.ma</a></p>
""",
        },
    },
    "cookies": {
        "en": {
            "title": "Cookie Policy",
            "body": """
<p>This policy covers the MarGem <strong>website</strong>. Mobile apps use secure storage and preferences instead of browser cookies.</p>
<h2>Web cookies</h2>
<table>
<tr><th>Cookie</th><th>Purpose</th><th>Duration</th></tr>
<tr><td>Session / auth</td><td>Keep you signed in on Web</td><td>Session</td></tr>
<tr><td>Language</td><td>Remember language choice</td><td>1 year</td></tr>
<tr><td>Cookie consent</td><td>Store consent choice (when banner is shown)</td><td>1 year</td></tr>
</table>
<p>Analytics cookies are used only if enabled and, where required, with consent. Google Maps may set cookies when maps are enabled.</p>
<h2>Mobile storage</h2>
<ul>
<li>Encrypted tokens (secure storage)</li>
<li>Language, onboarding, guest favorites (preferences)</li>
<li>Cache for performance</li>
</ul>
<p>Clear app data or delete your account to remove local storage.</p>
""",
        },
        "fr": {
            "title": "Politique des cookies",
            "body": """
<p>Cette politique concerne le <strong>site Web</strong> MarGem. Les applications mobiles utilisent le stockage sécurisé.</p>
<h2>Cookies Web</h2>
<p>Session, langue, consentement aux cookies. Analytics uniquement si activé et avec consentement si requis.</p>
<h2>Stockage mobile</h2>
<p>Jetons chiffrés, préférences, cache. Effacez les données de l'application pour supprimer le stockage local.</p>
""",
        },
        "ar": {
            "title": "سياسة ملفات تعريف الارتباط",
            "body": """
<p>تنطبق هذه السياسة على <strong>موقع</strong> MarGem. تستخدم التطبيقات تخزيناً آمناً بدلاً من ملفات تعريف الارتباط.</p>
<h2>ملفات الويب</h2>
<p>الجلسة، اللغة، الموافقة على ملفات التعريف. التحليلات فقط عند التفعيل وبالموافقة عند الاقتضاء.</p>
<h2>تخزين التطبيق</h2>
<p>رموز مشفّرة، تفضيلات، ذاكرة تخزين مؤقت. امسح بيانات التطبيق أو احذف حسابك لإزالة التخزين المحلي.</p>
""",
        },
    },
    "account-deletion": {
        "en": {
            "title": "Account Deletion",
            "body": """
<p>You may delete your MarGem account at any time. Deletion is permanent.</p>
<h2>How to delete</h2>
<ol>
<li>In the app: Settings → Delete account → enter password → confirm</li>
<li>API: <code>DELETE /auth/me</code> with password and confirmation <code>"DELETE"</code></li>
<li>Email: <a href="mailto:privacy@margem.app">privacy@margem.app</a> from your registered address</li>
</ol>
<h2>What we remove</h2>
<ul>
<li>Storefront, products, services, seller categories</li>
<li>Buyer–seller messages and conversations</li>
<li>Reviews you wrote; reviews on your business (if seller)</li>
<li>Favorites, follows, saved searches, notifications, subscriptions, refresh tokens</li>
<li>Community memberships; your community messages are anonymized</li>
<li>MFA factors and recovery codes</li>
</ul>
<h2>What we keep</h2>
<ul>
<li>Anonymized account row (<code>deleted+{uuid}@invalid.local</code>, display name "Deleted user")</li>
<li>Billing/tax records where legally required (up to 7 years)</li>
<li>Security and admin audit logs</li>
<li>Backup copies up to 90 days</li>
<li>Data under legal hold</li>
</ul>
<h2>Before you delete</h2>
<p>Export your data via <code>GET /auth/me/export</code> or email privacy@margem.app. Guest favorites remain on your device until you clear app data.</p>
""",
        },
        "fr": {
            "title": "Suppression de compte",
            "body": """
<p>Vous pouvez supprimer votre compte à tout moment. Action irréversible.</p>
<h2>Comment supprimer</h2>
<p>Application → Paramètres → Supprimer le compte, ou <code>DELETE /auth/me</code>, ou e-mail à privacy@margem.app.</p>
<h2>Données supprimées</h2>
<p>Boutique, annonces, messages, avis, favoris, abonnements, jetons, adhésions communautaires (messages anonymisés).</p>
<h2>Données conservées</h2>
<p>Compte anonymisé, obligations légales, sauvegardes (90 jours), conservation judiciaire.</p>
""",
        },
        "ar": {
            "title": "حذف الحساب",
            "body": """
<p>يمكنك حذف حساب MarGem في أي وقت. الحذف نهائي.</p>
<h2>كيفية الحذف</h2>
<p>الإعدادات → حذف الحساب، أو <code>DELETE /auth/me</code>، أو privacy@margem.app.</p>
<h2>ما نحذفه</h2>
<p>المتجر، القوائم، الرسائل، التقييمات، المفضلة، الاشتراكات، عضويات المجتمع (رسائلك تُجهّل).</p>
<h2>ما نحتفظ به</h2>
<p>سجل حساب مجهّل، سجلات قانونية/ضريبية، نسخ احتياطية (90 يوماً)، حجز قانوني.</p>
""",
        },
    },
}


def page(lang: str, doc: str, content: dict[str, str]) -> str:
    rtl = ' dir="rtl"' if lang == "ar" else ""
    lang_attr = lang
    links = []
    for code, label in [("en", "English"), ("fr", "Français"), ("ar", "العربية")]:
        if code != lang:
            links.append(f'<a href="/legal/{code}/{doc}">{label}</a>')
    nav = " · ".join(links)
    other_docs = {
        "privacy": [("terms", "Terms"), ("cookies", "Cookies"), ("account-deletion", "Account deletion")],
        "terms": [("privacy", "Privacy"), ("cookies", "Cookies")],
        "cookies": [("privacy", "Privacy")],
        "account-deletion": [("privacy", "Privacy")],
    }
    doc_links = []
    for slug, label in other_docs.get(doc, []):
        doc_links.append(f'<a href="/legal/{lang}/{slug}">{label}</a>')
    doc_nav = " · ".join(doc_links)

    return f"""<!DOCTYPE html>
<html lang="{lang_attr}"{rtl}>
<head>
<meta charset="utf-8"/>
<meta name="viewport" content="width=device-width, initial-scale=1"/>
<title>{content["title"]} — MarGem</title>
<style>{CSS}</style>
</head>
<body>
<div class="wrap">
<header>
<h1>{content["title"]}</h1>
<p class="meta">MarGem · Version {VERSION} · Effective {EFFECTIVE} · Last updated {UPDATED}</p>
<p class="lang-nav">{nav}</p>
</header>
<main>
{content["body"]}
</main>
<footer>
<p>{doc_nav}</p>
<p>© MarGem · <a href="mailto:privacy@margem.app">privacy@margem.app</a></p>
</footer>
</div>
</body>
</html>
"""


def main() -> None:
    for doc, langs in DOCS.items():
        for lang, content in langs.items():
            out = ROOT / lang / f"{doc}.html"
            out.parent.mkdir(parents=True, exist_ok=True)
            out.write_text(page(lang, doc, content), encoding="utf-8")
            print(f"wrote {out}")


if __name__ == "__main__":
    main()
