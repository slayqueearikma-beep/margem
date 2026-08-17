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

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) => _loadStatus());
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

  @override
  Widget build(BuildContext context) {
    final locale = ref.watch(localeProvider);
    final copy = LegalAcceptanceCopy.forLanguageCode(locale.languageCode);

    return PopScope(
      canPop: false,
      child: Scaffold(
        body: MargemBackground(
          child: SafeArea(
            child: Center(
              child: SingleChildScrollView(
                padding: const EdgeInsets.all(AppSpacing.screenHorizontal),
                child: ConstrainedBox(
                  constraints: const BoxConstraints(maxWidth: 520),
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
                        mainAxisSize: MainAxisSize.min,
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

    if (copy.acceptanceLanguageCode == 'fr') {
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
    }

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
