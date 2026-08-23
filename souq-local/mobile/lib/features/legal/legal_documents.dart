import '../../l10n/app_localizations.dart';

/// Hosted legal document slugs served by `GET /legal/{lang}/{doc}`.
class LegalDocumentId {
  const LegalDocumentId(this.slug, this.titleBuilder);

  final String slug;
  final String Function(AppStrings l10n) titleBuilder;

  static const privacy = LegalDocumentId('privacy', _privacy);
  static const terms = LegalDocumentId('terms', _terms);
  static const sellerTerms = LegalDocumentId('seller-terms', _sellerTerms);
  static const communityGuidelines =
      LegalDocumentId('community-guidelines', _communityGuidelines);
  static const cookies = LegalDocumentId('cookies', _cookies);
  static const legalNotice = LegalDocumentId('legal-notice', _legalNotice);
  static const openSourceLicenses =
      LegalDocumentId('open-source-licenses', _openSourceLicenses);
  static const accountDeletion =
      LegalDocumentId('account-deletion', _accountDeletion);

  static String _privacy(AppStrings l10n) => l10n.privacyPolicy;
  static String _terms(AppStrings l10n) => l10n.termsOfService;
  static String _sellerTerms(AppStrings l10n) => l10n.sellerTerms;
  static String _communityGuidelines(AppStrings l10n) =>
      l10n.communityGuidelines;
  static String _cookies(AppStrings l10n) => l10n.cookiePolicy;
  static String _legalNotice(AppStrings l10n) => l10n.legalNotice;
  static String _openSourceLicenses(AppStrings l10n) => l10n.openSourceLicenses;
  static String _accountDeletion(AppStrings l10n) => l10n.accountDeletionPolicy;

  static LegalDocumentId? fromSlug(String slug) {
    for (final doc in values) {
      if (doc.slug == slug) return doc;
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
  ];
}
