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

enum _ResetPasswordState { ready, loading, success, invalidToken }

class ResetPasswordScreen extends StatefulWidget {
  const ResetPasswordScreen({super.key, this.initialToken = ''});

  final String initialToken;

  @override
  State<ResetPasswordScreen> createState() => _ResetPasswordScreenState();
}

class _ResetPasswordScreenState extends State<ResetPasswordScreen> {
  final _passwordController = TextEditingController();
  final _confirmPasswordController = TextEditingController();
  bool _obscurePassword = true;
  bool _obscureConfirm = true;
  _ResetPasswordState _state = _ResetPasswordState.ready;

  @override
  void initState() {
    super.initState();
    if (widget.initialToken.trim().isEmpty) {
      _state = _ResetPasswordState.invalidToken;
    }
  }

  @override
  void dispose() {
    _passwordController.dispose();
    _confirmPasswordController.dispose();
    super.dispose();
  }

  String _resetErrorMessage(ApiException error, AppStrings l10n) {
    if (error.statusCode == 400) {
      return l10n.resetTokenInvalidOrExpired;
    }
    if (error.statusCode == 429) {
      return l10n.tooManyRequests;
    }
    final message = error.message.trim();
    if (message.isNotEmpty) return message;
    return l10n.somethingWentWrong;
  }

  Future<void> _confirmReset() async {
    final l10n = context.l10n;
    final token = widget.initialToken.trim();
    if (token.isEmpty) {
      setState(() => _state = _ResetPasswordState.invalidToken);
      return;
    }

    final password = _passwordController.text;
    final confirm = _confirmPasswordController.text;
    if (!FormValidators.isValidPassword(password)) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(l10n.resetPasswordValidation)),
      );
      return;
    }
    if (password != confirm) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(l10n.passwordsDoNotMatch)),
      );
      return;
    }

    setState(() => _state = _ResetPasswordState.loading);
    try {
      await apiServiceProvider.confirmPasswordReset(
        token: token,
        newPassword: password,
      );
      if (mounted) setState(() => _state = _ResetPasswordState.success);
    } on ApiException catch (error) {
      if (!mounted) return;
      if (error.statusCode == 400) {
        setState(() => _state = _ResetPasswordState.invalidToken);
        return;
      }
      await showAppErrorDialog(
        context,
        title: l10n.somethingWentWrong,
        message: _resetErrorMessage(error, l10n),
      );
      setState(() => _state = _ResetPasswordState.ready);
    } catch (_) {
      if (!mounted) return;
      await showAppErrorDialog(
        context,
        title: l10n.somethingWentWrong,
        message: l10n.serverUnreachable,
      );
      setState(() => _state = _ResetPasswordState.ready);
    }
  }

  InputDecoration _fieldDecoration({
    required String label,
    required IconData icon,
    Widget? suffix,
    String? helperText,
  }) {
    return InputDecoration(
      labelText: label,
      helperText: helperText,
      prefixIcon: Icon(icon),
      suffixIcon: suffix,
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
    final loading = _state == _ResetPasswordState.loading;

    return BuyerScreenScaffold(
      appBar: BuyerAppBar(title: l10n.resetPassword),
      body: SafeArea(
        child: ListView(
          padding: const EdgeInsets.all(AppSpacing.screenHorizontal),
          children: [
            AppBrandHeader(
              tier: AppLogoTier.header,
              includeTopSpacing: true,
              subtitle: l10n.resetPasswordSubtitle,
            ),
            const SizedBox(height: AppSpacing.xl),
            if (_state == _ResetPasswordState.success)
              _StatusCard(
                icon: Icons.check_circle_outline,
                message: l10n.passwordResetComplete,
                actionLabel: l10n.backToLogin,
                onAction: () => context.go('/login'),
              )
            else if (_state == _ResetPasswordState.invalidToken)
              _StatusCard(
                icon: Icons.link_off_outlined,
                message: l10n.resetTokenInvalidOrExpired,
                actionLabel: l10n.forgotPassword,
                onAction: () => context.go('/forgot-password'),
                secondaryActionLabel: l10n.backToLogin,
                onSecondaryAction: () => context.go('/login'),
              )
            else ...[
              TextField(
                controller: _passwordController,
                obscureText: _obscurePassword,
                textInputAction: TextInputAction.next,
                autofillHints: const [AutofillHints.newPassword],
                decoration: _fieldDecoration(
                  label: l10n.newPassword,
                  icon: Icons.lock_outline,
                  helperText: l10n.passwordHint,
                  suffix: IconButton(
                    icon: Icon(
                      _obscurePassword
                          ? Icons.visibility_outlined
                          : Icons.visibility_off_outlined,
                    ),
                    onPressed: () =>
                        setState(() => _obscurePassword = !_obscurePassword),
                  ),
                ),
              ),
              const SizedBox(height: AppSpacing.md),
              TextField(
                controller: _confirmPasswordController,
                obscureText: _obscureConfirm,
                textInputAction: TextInputAction.done,
                autofillHints: const [AutofillHints.newPassword],
                onSubmitted: (_) => _confirmReset(),
                decoration: _fieldDecoration(
                  label: l10n.confirmPassword,
                  icon: Icons.lock_outline,
                  suffix: IconButton(
                    icon: Icon(
                      _obscureConfirm
                          ? Icons.visibility_outlined
                          : Icons.visibility_off_outlined,
                    ),
                    onPressed: () =>
                        setState(() => _obscureConfirm = !_obscureConfirm),
                  ),
                ),
              ),
              const SizedBox(height: AppSpacing.lg),
              PrimaryButton(
                label: l10n.resetPassword,
                onPressed: _confirmReset,
                isLoading: loading,
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

class _StatusCard extends StatelessWidget {
  const _StatusCard({
    required this.icon,
    required this.message,
    required this.actionLabel,
    required this.onAction,
    this.secondaryActionLabel,
    this.onSecondaryAction,
  });

  final IconData icon;
  final String message;
  final String actionLabel;
  final VoidCallback onAction;
  final String? secondaryActionLabel;
  final VoidCallback? onSecondaryAction;

  @override
  Widget build(BuildContext context) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(AppSpacing.lg),
        child: Column(
          children: [
            Icon(icon, size: 40),
            const SizedBox(height: AppSpacing.sm),
            Text(message, textAlign: TextAlign.center),
            const SizedBox(height: AppSpacing.md),
            PrimaryButton(label: actionLabel, onPressed: onAction),
            if (secondaryActionLabel != null && onSecondaryAction != null) ...[
              const SizedBox(height: AppSpacing.sm),
              TextButton(
                onPressed: onSecondaryAction,
                child: Text(secondaryActionLabel!),
              ),
            ],
          ],
        ),
      ),
    );
  }
}
