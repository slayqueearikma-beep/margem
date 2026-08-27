import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../core/services/api_service.dart';
import '../../core/services/auth_service.dart';
import '../../core/services/mfa_service.dart';
import '../../core/theme/app_colors.dart';
import '../../core/theme/app_spacing.dart';
import '../../core/widgets/app_buttons.dart';
import '../../core/widgets/error_dialog.dart';
import '../../l10n/app_localizations.dart';

class MfaSettingsScreen extends ConsumerStatefulWidget {
  const MfaSettingsScreen({super.key});

  @override
  ConsumerState<MfaSettingsScreen> createState() => _MfaSettingsScreenState();
}

class _MfaSettingsScreenState extends ConsumerState<MfaSettingsScreen> {
  bool _refreshing = true;
  bool _mfaEnabled = false;
  String? _loadError;

  @override
  void initState() {
    super.initState();
    _refreshStatus();
  }

  Future<void> _refreshStatus() async {
    setState(() {
      _refreshing = true;
      _loadError = null;
    });
    try {
      final user = await refreshAuthSessionUser(ref);
      if (!mounted) return;
      setState(() {
        _mfaEnabled = user.mfaEnabled;
        _refreshing = false;
      });
    } on ApiException catch (error) {
      if (!mounted) return;
      setState(() {
        _loadError = error.message;
        _mfaEnabled = ref.read(authSessionProvider)?.user.mfaEnabled ?? false;
        _refreshing = false;
      });
    } catch (_) {
      if (!mounted) return;
      setState(() {
        _loadError = context.l10n.serverUnreachable;
        _mfaEnabled = ref.read(authSessionProvider)?.user.mfaEnabled ?? false;
        _refreshing = false;
      });
    }
  }

  Future<void> _openSetup() async {
    final enabled = await context.push<bool>('/settings/mfa/setup');
    if (enabled == true) {
      await _refreshStatus();
    }
  }

  Future<void> _disableMfa() async {
    final l10n = context.l10n;
    final passwordController = TextEditingController();
    final codeController = TextEditingController();
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(l10n.disableMfa),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(l10n.disableMfaConfirm),
            const SizedBox(height: AppSpacing.md),
            TextField(
              controller: passwordController,
              obscureText: true,
              decoration: InputDecoration(labelText: l10n.password),
            ),
            const SizedBox(height: AppSpacing.sm),
            TextField(
              controller: codeController,
              keyboardType: TextInputType.number,
              maxLength: 6,
              inputFormatters: [FilteringTextInputFormatter.digitsOnly],
              decoration: InputDecoration(
                labelText: l10n.twoFactorAuthCodeLabel,
                counterText: '',
              ),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: Text(l10n.cancel),
          ),
          FilledButton(
            onPressed: () => Navigator.of(context).pop(true),
            child: Text(l10n.disableMfa),
          ),
        ],
      ),
    );

    if (confirmed != true) {
      passwordController.dispose();
      codeController.dispose();
      return;
    }

    try {
      await ref.read(mfaServiceProvider).disable(
            password: passwordController.text,
            code: codeController.text.trim(),
          );
      passwordController.dispose();
      codeController.dispose();
      final user = await refreshAuthSessionUser(ref);
      if (!mounted) return;
      if (user.mfaEnabled) {
        await showAppErrorDialog(
          context,
          title: l10n.somethingWentWrong,
          message: l10n.mfaDisableFailed,
        );
        return;
      }
      setState(() => _mfaEnabled = false);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(l10n.mfaDisableSuccess)),
      );
    } on ApiException catch (error) {
      passwordController.dispose();
      codeController.dispose();
      if (!mounted) return;
      await showAppErrorDialog(
        context,
        title: l10n.somethingWentWrong,
        message: error.message,
      );
    } catch (_) {
      passwordController.dispose();
      codeController.dispose();
      if (!mounted) return;
      await showAppErrorDialog(
        context,
        title: l10n.somethingWentWrong,
        message: l10n.serverUnreachable,
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;

    return Scaffold(
      appBar: AppBar(title: Text(l10n.mfaSettingsTitle)),
      body: _refreshing
          ? const Center(child: CircularProgressIndicator())
          : ListView(
              padding: const EdgeInsets.all(AppSpacing.screenHorizontal),
              children: [
                if (_loadError != null) ...[
                  Text(
                    _loadError!,
                    style: const TextStyle(color: AppColors.danger),
                  ),
                  const SizedBox(height: AppSpacing.sm),
                ],
                Container(
                  width: double.infinity,
                  padding: const EdgeInsets.all(AppSpacing.lg),
                  decoration: BoxDecoration(
                    color: _mfaEnabled
                        ? AppColors.primary.withValues(alpha: 0.08)
                        : AppColors.surfaceMuted.withValues(alpha: 0.5),
                    borderRadius: BorderRadius.circular(16),
                    border: Border.all(
                      color: _mfaEnabled
                          ? AppColors.primary.withValues(alpha: 0.35)
                          : AppColors.border,
                    ),
                  ),
                  child: Row(
                    children: [
                      Icon(
                        _mfaEnabled
                            ? Icons.verified_user_outlined
                            : Icons.shield_outlined,
                        color: _mfaEnabled
                            ? AppColors.primary
                            : AppColors.textSecondary,
                      ),
                      const SizedBox(width: AppSpacing.md),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              _mfaEnabled ? l10n.mfaEnabled : l10n.mfaDisabled,
                              style: Theme.of(context)
                                  .textTheme
                                  .titleMedium
                                  ?.copyWith(fontWeight: FontWeight.w700),
                            ),
                            const SizedBox(height: 4),
                            Text(
                              _mfaEnabled
                                  ? l10n.mfaEnabledDescription
                                  : l10n.mfaDisabledDescription,
                              style: Theme.of(context)
                                  .textTheme
                                  .bodySmall
                                  ?.copyWith(color: AppColors.textSecondary),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: AppSpacing.xl),
                if (_mfaEnabled)
                  OutlinedButton(
                    style: OutlinedButton.styleFrom(
                      foregroundColor: AppColors.danger,
                      side: const BorderSide(color: AppColors.danger),
                    ),
                    onPressed: _disableMfa,
                    child: Text(l10n.disableMfa),
                  )
                else
                  PrimaryButton(
                    label: l10n.enableMfa,
                    onPressed: _openSetup,
                  ),
              ],
            ),
    );
  }
}
