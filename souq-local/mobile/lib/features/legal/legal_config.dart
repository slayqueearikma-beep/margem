/// Centralized legal contact and entity configuration for the mobile app.
///
/// Keep in sync with [legal/config/entity.yaml] in the repository root.
/// Regenerate hosted HTML after changing entity or contact details.
class LegalConfig {
  LegalConfig._();

  static const platformName = 'Dribex';

  static const supportEmail = 'support@dribex.ma';
  static const privacyEmail = 'privacy@dribex.app';
  static const legalEmail = 'legal@dribex.ma';
  static const dpoEmail = 'dpo@dribex.app';
  static const sellersEmail = 'sellers@dribex.ma';
  static const billingEmail = 'billing@dribex.ma';

  static Uri privacyMailto({String? subject}) => Uri(
        scheme: 'mailto',
        path: privacyEmail,
        queryParameters: subject == null ? null : {'subject': subject},
      );

  static Uri supportMailto({String? subject}) => Uri(
        scheme: 'mailto',
        path: supportEmail,
        queryParameters: subject == null ? null : {'subject': subject},
      );
}
