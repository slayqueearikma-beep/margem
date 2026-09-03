/// English, French, and Arabic UI copy for the mandatory legal acceptance popup.
/// Legal document HTML is always French — see [LegalConfig.authoritativeLanguageCode].
class LegalAcceptanceCopy {
  const LegalAcceptanceCopy({
    required this.title,
    required this.description,
    required this.legalContentNotice,
    required this.checkboxLabel,
    required this.acceptButton,
    required this.termsLabel,
    required this.privacyLabel,
    required this.errorTitle,
    required this.retry,
    required this.acceptanceLanguageCode,
  });

  final String title;
  final String description;
  /// Shown when UI locale differs from the French legal text.
  final String legalContentNotice;
  final String checkboxLabel;
  final String acceptButton;
  final String termsLabel;
  final String privacyLabel;
  final String errorTitle;
  final String retry;
  final String acceptanceLanguageCode;

  factory LegalAcceptanceCopy.forLanguageCode(String languageCode) {
    switch (languageCode) {
      case 'fr':
        return const LegalAcceptanceCopy(
          title: 'Avant de continuer',
          description:
              'En continuant, vous reconnaissez avoir lu et accepté nos Conditions d’utilisation et notre Politique de confidentialité.',
          legalContentNotice: '',
          checkboxLabel:
              'J’ai lu et j’accepte les Conditions d’utilisation et la Politique de confidentialité.',
          acceptButton: 'J’accepte',
          termsLabel: 'Conditions d’utilisation',
          privacyLabel: 'Politique de confidentialité',
          errorTitle: 'Impossible d’enregistrer votre acceptation',
          retry: 'Réessayer',
          acceptanceLanguageCode: 'fr',
        );
      case 'ar':
        return const LegalAcceptanceCopy(
          title: 'قبل المتابعة',
          description:
              'للمتابعة، يجب قراءة الوثائق القانونية أدناه والموافقة عليها.',
          legalContentNotice:
              'الوثائق القانونية المعروضة باللغة الفرنسية وهي النسخة المعتمدة والملزمة.',
          checkboxLabel: 'قرأت وأوافق على شروط الاستخدام وسياسة الخصوصية.',
          acceptButton: 'أوافق',
          termsLabel: 'شروط الاستخدام',
          privacyLabel: 'سياسة الخصوصية',
          errorTitle: 'تعذر حفظ موافقتك',
          retry: 'إعادة المحاولة',
          acceptanceLanguageCode: 'fr',
        );
      default:
        return const LegalAcceptanceCopy(
          title: 'Before you continue',
          description:
              'To continue, read the legal documents below and accept them.',
          legalContentNotice:
              'Legal documents are shown in French — the authoritative binding versions.',
          checkboxLabel:
              'I have read and agree to the Terms of Service and Privacy Policy.',
          acceptButton: 'I Accept',
          termsLabel: 'Terms of Service',
          privacyLabel: 'Privacy Policy',
          errorTitle: 'Could not save your acceptance',
          retry: 'Retry',
          acceptanceLanguageCode: 'fr',
        );
    }
  }
}
