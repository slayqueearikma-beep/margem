/// English and French copy for the mandatory legal acceptance popup.
///
/// Arabic is intentionally excluded — when the app locale is Arabic, English
/// copy is shown instead.
class LegalAcceptanceCopy {
  const LegalAcceptanceCopy({
    required this.title,
    required this.description,
    required this.checkboxLabel,
    required this.acceptButton,
    required this.termsLabel,
    required this.privacyLabel,
    required this.errorTitle,
    required this.retry,
  });

  final String title;
  final String description;
  final String checkboxLabel;
  final String acceptButton;
  final String termsLabel;
  final String privacyLabel;
  final String errorTitle;
  final String retry;

  factory LegalAcceptanceCopy.forLanguageCode(String languageCode) {
    if (languageCode == 'fr') {
      return const LegalAcceptanceCopy(
        title: 'Avant de continuer',
        description:
            'En continuant, vous reconnaissez avoir lu et accepté nos Conditions d’utilisation et notre Politique de confidentialité.',
        checkboxLabel:
            'J’ai lu et j’accepte les Conditions d’utilisation et la Politique de confidentialité.',
        acceptButton: 'J’accepte',
        termsLabel: 'Conditions d’utilisation',
        privacyLabel: 'Politique de confidentialité',
        errorTitle: 'Impossible d’enregistrer votre acceptation',
        retry: 'Réessayer',
      );
    }
    return const LegalAcceptanceCopy(
      title: 'Before you continue',
      description:
          'By continuing, you acknowledge that you have read and agree to our Terms of Service and Privacy Policy.',
      checkboxLabel:
          'I have read and agree to the Terms of Service and Privacy Policy.',
      acceptButton: 'I Accept',
      termsLabel: 'Terms of Service',
      privacyLabel: 'Privacy Policy',
      errorTitle: 'Could not save your acceptance',
      retry: 'Retry',
    );
  }

  /// Popup supports only English and French. Arabic locale uses English.
  String get acceptanceLanguageCode =>
      title == 'Avant de continuer' ? 'fr' : 'en';
}
