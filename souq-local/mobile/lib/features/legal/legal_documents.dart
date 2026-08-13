import '../../l10n/app_localizations.dart';

/// Stable identifiers for hosted legal documents (`GET /legal/{lang}/{slug}`).
///
/// Source content lives in repository `legal/content/{slug}/{lang}.md`.
/// Regenerate HTML with `python souq-local/backend/scripts/generate_legal_html.py`.
class LegalDocumentId {
  const LegalDocumentId(this.id, this.slug, this.titleBuilder);

  /// Stable document id from `legal/manifest.yaml` (not the URL slug).
  final String id;
  final String slug;
  final String Function(AppStrings l10n) titleBuilder;

  static const privacy = LegalDocumentId(
    'privacy_policy',
    'privacy',
    _privacy,
  );
  static const terms = LegalDocumentId(
    'terms_of_service',
    'terms',
    _terms,
  );
  static const sellerTerms = LegalDocumentId(
    'seller_terms',
    'seller-terms',
    _sellerTerms,
  );
  static const communityGuidelines = LegalDocumentId(
    'community_guidelines',
    'community-guidelines',
    _communityGuidelines,
  );
  static const cookies = LegalDocumentId(
    'cookie_policy',
    'cookies',
    _cookies,
  );
  static const legalNotice = LegalDocumentId(
    'legal_notice',
    'legal-notice',
    _legalNotice,
  );
  static const openSourceLicenses = LegalDocumentId(
    'open_source_licenses',
    'open-source-licenses',
    _openSourceLicenses,
  );
  static const accountDeletion = LegalDocumentId(
    'account_deletion',
    'account-deletion',
    _accountDeletion,
  );
  static const subscriptionTerms = LegalDocumentId(
    'subscription_terms',
    'subscription-terms',
    _subscriptionTerms,
  );

  static String _privacy(AppStrings l10n) => l10n.privacyPolicy;
  static String _terms(AppStrings l10n) => l10n.termsOfService;
  static String _sellerTerms(AppStrings l10n) => l10n.sellerTerms;
  static String _communityGuidelines(AppStrings l10n) =>
      l10n.communityGuidelines;
  static String _cookies(AppStrings l10n) => l10n.cookiePolicy;
  static String _legalNotice(AppStrings l10n) => l10n.legalNotice;
  static String _openSourceLicenses(AppStrings l10n) => l10n.openSourceLicenses;
  static String _accountDeletion(AppStrings l10n) => l10n.accountDeletionPolicy;
  static String _subscriptionTerms(AppStrings l10n) => l10n.subscriptionTerms;

  static LegalDocumentId? fromSlug(String slug) {
    for (final doc in values) {
      if (doc.slug == slug) return doc;
    }
    return null;
  }

  static LegalDocumentId? fromId(String id) {
    for (final doc in values) {
      if (doc.id == id) return doc;
    }
    return null;
  }

  static const values = [
    privacy,
    terms,
    sellerTerms,
    communityGuidelines,
    cookies,
    legalNotice,
    openSourceLicenses,
    accountDeletion,
    subscriptionTerms,
  ];
}
