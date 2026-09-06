import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../../core/validation/form_validators.dart';
import '../../core/services/api_service.dart';
import '../../core/theme/app_spacing.dart';
import '../../core/theme/theme_context.dart';
import '../../core/widgets/app_brand_logo.dart';
import '../../core/widgets/app_buttons.dart';
import '../../core/widgets/buyer_ui_components.dart';
import '../../core/widgets/error_dialog.dart';
import '../../l10n/app_localizations.dart';

class ForgotPasswordScreen extends StatefulWidget {
  const ForgotPasswordScreen({super.key});

  @override
  State<ForgotPasswordScreen> createState() => _ForgotPasswordScreenState();
}

class _ForgotPasswordScreenState extends State<ForgotPasswordScreen> {
  final _emailController = TextEditingController();
  bool _loading = false;
  bool _requestSent = false;
  String? _successMessage;

  @override
  void dispose() {
    _emailController.dispose();
    super.dispose();
  }

  Future<void> _requestReset() async {
    final l10n = context.l10n;
    final email = _emailController.text.trim();
    if (email.isEmpty || !FormValidators.isValidEmail(email)) {
      ScaffoldMessenger.of(context)
          .showSnackBar(SnackBar(content: Text(l10n.emailRequired)));
      return;
    }
    setState(() {
      _loading = true;
      _requestSent = false;
      _successMessage = null;
    });
    try {
      final message = await apiServiceProvider.requestPasswordReset(email);
      if (mounted) {
        setState(() {
          _requestSent = true;
          _successMessage = message;
        });
      }
    } on ApiException catch (error) {
      if (mounted) {
        await showAppErrorDialog(context,
            title: l10n.somethingWentWrong, message: error.message);
      }
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  InputDecoration _fieldDecoration({
    required String label,
    required IconData icon,
  }) {
    return InputDecoration(
      labelText: label,
      prefixIcon: Icon(icon),
      filled: true,
      fillColor: context.colors.surfaceVariant.withValues(alpha: 0.65),
      border: OutlineInputBorder(
        borderRadius: BorderRadius.circular(16),
        borderSide: BorderSide(color: context.colors.border),
      ),
      enabledBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(16),
        borderSide: BorderSide(color: context.colors.border),
      ),
      focusedBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(16),
        borderSide: BorderSide(color: context.colors.primary, width: 1.4),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;

    return BuyerScreenScaffold(
      appBar: BuyerAppBar(title: l10n.forgotPassword),
      body: SafeArea(
        child: ListView(
          padding: const EdgeInsets.all(AppSpacing.screenHorizontal),
          children: [
            AppBrandHeader(
              tier: AppLogoTier.header,
              includeTopSpacing: true,
              subtitle: l10n.forgotPasswordSubtitle,
            ),
            const SizedBox(height: AppSpacing.xl),
            if (_requestSent)
              _SuccessCard(
                message: _successMessage ?? l10n.resetLinkSent,
                actionLabel: l10n.backToLogin,
                onAction: () => context.go('/login'),
              )
            else ...[
              TextField(
                controller: _emailController,
                keyboardType: TextInputType.emailAddress,
                textInputAction: TextInputAction.done,
                autofillHints: const [AutofillHints.email],
                onSubmitted: (_) => _requestReset(),
                decoration: _fieldDecoration(
                  label: l10n.email,
                  icon: Icons.email_outlined,
                ),
              ),
              const SizedBox(height: AppSpacing.lg),
              PrimaryButton(
                label: l10n.sendResetLink,
                onPressed: _requestReset,
                isLoading: _loading,
              ),
              const SizedBox(height: AppSpacing.sm),
              TextButton(
                onPressed: () => context.go('/login'),
                child: Text(l10n.backToLogin),
              ),
            ],
          ],
        ),
      ),
    );
  }
}

class _SuccessCard extends StatelessWidget {
  const _SuccessCard({
    required this.message,
    required this.actionLabel,
    required this.onAction,
  });

  final String message;
  final String actionLabel;
  final VoidCallback onAction;

  @override
  Widget build(BuildContext context) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(AppSpacing.lg),
        child: Column(
          children: [
            const Icon(Icons.mark_email_read_outlined, size: 40),
            const SizedBox(height: AppSpacing.sm),
            Text(message, textAlign: TextAlign.center),
            const SizedBox(height: AppSpacing.md),
            PrimaryButton(label: actionLabel, onPressed: onAction),
          ],
        ),
      ),
    );
  }
}
