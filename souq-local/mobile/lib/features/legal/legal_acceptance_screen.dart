import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../core/models/legal_acceptance_models.dart';
import '../../core/navigation/post_auth_navigation.dart';
import '../../core/services/api_service.dart';
import '../../core/services/app_storage.dart';
import '../../core/services/legal_acceptance_service.dart';
import '../../core/services/locale_provider.dart';
import '../../core/theme/app_spacing.dart';
import '../../core/theme/theme_context.dart';
import '../../core/widgets/app_brand_logo.dart';
import '../../core/widgets/app_buttons.dart';
import '../../core/widgets/error_dialog.dart';
import '../../core/widgets/margem_background.dart';
import 'legal_acceptance_l10n.dart';
import 'legal_document_content.dart';
import 'legal_document_widgets.dart';

class LegalAcceptanceScreen extends ConsumerStatefulWidget {
  const LegalAcceptanceScreen({super.key});

  @override
  ConsumerState<LegalAcceptanceScreen> createState() =>
      _LegalAcceptanceScreenState();
}

class _LegalAcceptanceScreenState extends ConsumerState<LegalAcceptanceScreen> {
  bool _checked = false;
  bool _submitting = false;
  LegalAcceptanceStatus? _status;
  Future<List<LegalDocumentContent>>? _documentsFuture;
  String? _loadedLang;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) => _loadStatus());
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    final lang = ref.read(localeProvider).languageCode;
    if (_documentsFuture == null || _loadedLang != lang) {
      _loadedLang = lang;
      _documentsFuture = _loadDocuments(lang);
    }
  }

  Future<List<LegalDocumentContent>> _loadDocuments(String languageCode) async {
    final results = await Future.wait([
      LegalDocumentContent.fetch('terms', languageCode),
      LegalDocumentContent.fetch('privacy', languageCode),
    ]);
    return results;
  }

  Future<void> _loadStatus() async {
    try {
      final status = await refreshLegalAcceptanceStatus(ref);
      if (!mounted) return;
      setState(() => _status = status);
      if (status.complete) {
        final session = ref.read(userSessionProvider);
        final storage = ref.read(appStorageProvider);
        if (session != null && storage != null && !session.isGuest) {
          context.go(storage.homeRouteFor(session));
        }
      }
    } on ApiException catch (error) {
      if (!mounted) return;
      if (error.statusCode == 401 || error.statusCode == 403) {
        context.go('/login');
      }
    }
  }

  Future<void> _accept() async {
    final locale = ref.read(localeProvider);
    final copy = LegalAcceptanceCopy.forLanguageCode(locale.languageCode);
    final status = _status ?? ref.read(legalAcceptanceStatusProvider);
    final pending = status?.pending ??
        const ['terms_of_service', 'privacy_policy'];

    setState(() => _submitting = true);
    try {
      final updated = await ref.read(legalAcceptanceServiceProvider).accept(
            policyIds: pending,
            language: copy.acceptanceLanguageCode,
          );
      ref.read(legalAcceptanceStatusProvider.notifier).state = updated;
      await ref.read(appStorageProvider)?.setLegalAcceptanceComplete(updated.complete);
      if (!mounted) return;

      final session = ref.read(userSessionProvider);
      final storage = ref.read(appStorageProvider);
      if (session == null || storage == null || session.isGuest) {
        context.go('/login');
        return;
      }
      context.go(await resolveAuthenticatedDestination(ref, storage, session));
    } on ApiException catch (error) {
      if (!mounted) return;
      await showAppErrorDialog(
        context,
        title: copy.errorTitle,
        message: error.message,
      );
    } catch (_) {
      if (!mounted) return;
      await showAppErrorDialog(
        context,
        title: copy.errorTitle,
        message: copy.retry,
      );
    } finally {
      if (mounted) setState(() => _submitting = false);
    }
  }

  void _reloadDocuments() {
    final lang = ref.read(localeProvider).languageCode;
    setState(() {
      _loadedLang = lang;
      _documentsFuture = _loadDocuments(lang);
    });
  }

  @override
  Widget build(BuildContext context) {
    final locale = ref.watch(localeProvider);
    final copy = LegalAcceptanceCopy.forLanguageCode(locale.languageCode);
    final maxCardHeight = MediaQuery.sizeOf(context).height - 48;

    return PopScope(
      canPop: false,
      child: Scaffold(
        body: MargemBackground(
          child: SafeArea(
            child: Padding(
              padding: const EdgeInsets.all(AppSpacing.screenHorizontal),
              child: Center(
                child: ConstrainedBox(
                  constraints: BoxConstraints(
                    maxWidth: 520,
                    maxHeight: maxCardHeight,
                  ),
                  child: Material(
                    color: context.colors.surface,
                    elevation: 0,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(24),
                      side: BorderSide(color: context.colors.border),
                    ),
                    child: Padding(
                      padding: const EdgeInsets.all(24),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        children: [
                          Center(
                            child: AppBrandLogo.forContext(
                              AppBrandContext.compactBranding,
                              size: AppBrandSizes.settingsBranding,
                            ),
                          ),
                          const SizedBox(height: AppSpacing.lg),
                          Text(
                            copy.title,
                            textAlign: TextAlign.center,
                            style: Theme.of(context)
                                .textTheme
                                .titleLarge
                                ?.copyWith(
                                  fontWeight: FontWeight.w800,
                                  color: context.colors.textPrimary,
                                ),
                          ),
                          const SizedBox(height: AppSpacing.md),
                          Text(
                            copy.description,
                            textAlign: TextAlign.center,
                            style: TextStyle(
                              color: context.colors.textSecondary,
                              height: 1.45,
                            ),
                          ),
                          const SizedBox(height: AppSpacing.lg),
                          Expanded(
                            child: _LegalDocumentsPanel(
                              future: _documentsFuture,
                              retryLabel: copy.retry,
                              onRetry: _reloadDocuments,
                            ),
                          ),
                          const SizedBox(height: AppSpacing.md),
                          CheckboxListTile(
                            value: _checked,
                            onChanged: _submitting
                                ? null
                                : (value) =>
                                    setState(() => _checked = value ?? false),
                            contentPadding: EdgeInsets.zero,
                            controlAffinity: ListTileControlAffinity.leading,
                            title: _CheckboxRichText(
                              copy: copy,
                              onOpenTerms: () => context.push('/legal/terms'),
                              onOpenPrivacy: () =>
                                  context.push('/legal/privacy'),
                            ),
                          ),
                          const SizedBox(height: AppSpacing.lg),
                          PrimaryButton(
                            label: copy.acceptButton,
                            onPressed:
                                _checked && !_submitting ? _accept : null,
                            isLoading: _submitting,
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _LegalDocumentsPanel extends StatelessWidget {
  const _LegalDocumentsPanel({
    required this.future,
    required this.retryLabel,
    required this.onRetry,
  });

  final Future<List<LegalDocumentContent>>? future;
  final String retryLabel;
  final VoidCallback onRetry;

  @override
  Widget build(BuildContext context) {
    return DecoratedBox(
      decoration: BoxDecoration(
        color: context.colors.surfaceVariant.withValues(alpha: 0.35),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: context.colors.border),
      ),
      child: FutureBuilder<List<LegalDocumentContent>>(
        future: future,
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return Center(
              child: CircularProgressIndicator(color: context.colors.primary),
            );
          }
          if (snapshot.hasError || !snapshot.hasData) {
            return Center(
              child: Padding(
                padding: const EdgeInsets.all(AppSpacing.md),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      retryLabel,
                      textAlign: TextAlign.center,
                      style: TextStyle(color: context.colors.textSecondary),
                    ),
                    const SizedBox(height: AppSpacing.sm),
                    TextButton(onPressed: onRetry, child: Text(retryLabel)),
                  ],
                ),
              ),
            );
          }

          final documents = snapshot.data!;
          return Scrollbar(
            thumbVisibility: true,
            child: SingleChildScrollView(
              padding: const EdgeInsets.all(AppSpacing.md),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  for (var i = 0; i < documents.length; i++) ...[
                    if (i > 0) ...[
                      const SizedBox(height: AppSpacing.lg),
                      Divider(color: context.colors.border),
                      const SizedBox(height: AppSpacing.lg),
                    ],
                    LegalDocumentBody(content: documents[i]),
                  ],
                ],
              ),
            ),
          );
        },
      ),
    );
  }
}

class _CheckboxRichText extends StatelessWidget {
  const _CheckboxRichText({
    required this.copy,
    required this.onOpenTerms,
    required this.onOpenPrivacy,
  });

  final LegalAcceptanceCopy copy;
  final VoidCallback onOpenTerms;
  final VoidCallback onOpenPrivacy;

  @override
  Widget build(BuildContext context) {
    final baseStyle = TextStyle(
      color: context.colors.textPrimary,
      height: 1.4,
    );
    final linkStyle = baseStyle.copyWith(
      color: context.colors.primary,
      fontWeight: FontWeight.w700,
      decoration: TextDecoration.underline,
    );

    switch (copy.acceptanceLanguageCode) {
      case 'fr':
        return RichText(
          text: TextSpan(
            style: baseStyle,
            children: [
              const TextSpan(text: 'J’ai lu et j’accepte les '),
              TextSpan(
                text: copy.termsLabel,
                style: linkStyle,
                recognizer: TapGestureRecognizer()..onTap = onOpenTerms,
              ),
              const TextSpan(text: ' et la '),
              TextSpan(
                text: copy.privacyLabel,
                style: linkStyle,
                recognizer: TapGestureRecognizer()..onTap = onOpenPrivacy,
              ),
              const TextSpan(text: '.'),
            ],
          ),
        );
      case 'ar':
        return RichText(
          text: TextSpan(
            style: baseStyle,
            children: [
              const TextSpan(text: 'قرأت وأوافق على '),
              TextSpan(
                text: copy.termsLabel,
                style: linkStyle,
                recognizer: TapGestureRecognizer()..onTap = onOpenTerms,
              ),
              const TextSpan(text: ' و'),
              TextSpan(
                text: copy.privacyLabel,
                style: linkStyle,
                recognizer: TapGestureRecognizer()..onTap = onOpenPrivacy,
              ),
              const TextSpan(text: '.'),
            ],
          ),
        );
      default:
        return RichText(
          text: TextSpan(
            style: baseStyle,
            children: [
              const TextSpan(text: 'I have read and agree to the '),
              TextSpan(
                text: copy.termsLabel,
                style: linkStyle,
                recognizer: TapGestureRecognizer()..onTap = onOpenTerms,
              ),
              const TextSpan(text: ' and '),
              TextSpan(
                text: copy.privacyLabel,
                style: linkStyle,
                recognizer: TapGestureRecognizer()..onTap = onOpenPrivacy,
              ),
              const TextSpan(text: '.'),
            ],
          ),
        );
    }
  }
}
