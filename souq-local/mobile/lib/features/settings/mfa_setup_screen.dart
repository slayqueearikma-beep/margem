import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:qr_flutter/qr_flutter.dart';

import '../../core/services/api_service.dart';
import '../../core/services/mfa_service.dart';
import '../../core/theme/app_colors.dart';
import '../../core/theme/app_spacing.dart';
import '../../core/utils/mfa_utils.dart';
import '../../core/widgets/app_buttons.dart';
import '../../core/widgets/error_dialog.dart';
import '../../l10n/app_localizations.dart';

class MfaSetupScreen extends ConsumerStatefulWidget {
  const MfaSetupScreen({super.key});

  @override
  ConsumerState<MfaSetupScreen> createState() => _MfaSetupScreenState();
}

class _MfaSetupScreenState extends ConsumerState<MfaSetupScreen> {
  final _codeController = TextEditingController();
  String? _otpauthUri;
  String? _secret;
  String? _loadError;
  bool _loadingEnrollment = true;
  bool _confirming = false;
  String? _codeError;

  @override
  void initState() {
    super.initState();
    _startEnrollment();
  }

  @override
  void dispose() {
    _codeController.dispose();
    super.dispose();
  }

  Future<void> _startEnrollment() async {
    setState(() {
      _loadingEnrollment = true;
      _loadError = null;
      _otpauthUri = null;
      _secret = null;
      _codeError = null;
    });
    try {
      final result = await ref.read(mfaServiceProvider).startEnrollment();
      if (!mounted) return;
      final secret = MfaUtils.secretFromOtpAuthUri(result.otpauthUri);
      if (secret == null || result.otpauthUri.isEmpty) {
        setState(() {
          _loadError = context.l10n.mfaSetupInvalidResponse;
          _loadingEnrollment = false;
        });
        return;
      }
      setState(() {
        _otpauthUri = result.otpauthUri;
        _secret = secret;
        _loadingEnrollment = false;
      });
    } on ApiException catch (error) {
      if (!mounted) return;
      setState(() {
        _loadError = error.message;
        _loadingEnrollment = false;
      });
    } catch (_) {
      if (!mounted) return;
      setState(() {
        _loadError = context.l10n.serverUnreachable;
        _loadingEnrollment = false;
      });
    }
  }

  Future<void> _confirmEnrollment() async {
    final l10n = context.l10n;
    final code = _codeController.text.trim();
    if (code.length != 6 || !RegExp(r'^\d{6}$').hasMatch(code)) {
      setState(() => _codeError = l10n.mfaInvalidCode);
      return;
    }

    setState(() {
      _confirming = true;
      _codeError = null;
    });
    try {
      final recoveryCodes =
          await ref.read(mfaServiceProvider).confirmEnrollment(code);
      final user = await refreshAuthSessionUser(ref);
      if (!mounted) return;
      if (!user.mfaEnabled) {
        await showAppErrorDialog(
          context,
          title: l10n.somethingWentWrong,
          message: l10n.mfaEnableFailed,
        );
        return;
      }
      await _showRecoveryCodesDialog(recoveryCodes);
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(l10n.mfaEnableSuccess)),
      );
      context.pop(true);
    } on ApiException catch (error) {
      if (!mounted) return;
      setState(() => _codeError = error.message);
    } catch (_) {
      if (!mounted) return;
      setState(() => _codeError = l10n.serverUnreachable);
    } finally {
      if (mounted) setState(() => _confirming = false);
    }
  }

  Future<void> _showRecoveryCodesDialog(List<String> recoveryCodes) {
    final l10n = context.l10n;
    return showDialog<void>(
      context: context,
      barrierDismissible: false,
      builder: (context) => AlertDialog(
        title: Text(l10n.mfaRecoveryCodesTitle),
        content: SingleChildScrollView(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(l10n.mfaRecoveryCodesBody),
              const SizedBox(height: AppSpacing.md),
              SelectableText(
                recoveryCodes.join('\n'),
                style: const TextStyle(
                  fontFamily: 'monospace',
                  fontWeight: FontWeight.w600,
                ),
              ),
            ],
          ),
        ),
        actions: [
          FilledButton(
            onPressed: () => Navigator.of(context).pop(),
            child: Text(l10n.mfaRecoveryCodesSave),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;

    return Scaffold(
      appBar: AppBar(title: Text(l10n.mfaSetupTitle)),
      body: _loadingEnrollment
          ? const Center(child: CircularProgressIndicator())
          : _loadError != null
              ? _ErrorBody(
                  message: _loadError!,
                  onRetry: _startEnrollment,
                )
              : ListView(
                  padding: const EdgeInsets.all(AppSpacing.screenHorizontal),
                  children: [
                    Text(
                      l10n.mfaSetupInstructions,
                      style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                            color: AppColors.textSecondary,
                            height: 1.45,
                          ),
                    ),
                    const SizedBox(height: AppSpacing.lg),
                    Center(
                      child: Container(
                        padding: const EdgeInsets.all(AppSpacing.md),
                        decoration: BoxDecoration(
                          color: Colors.white,
                          borderRadius: BorderRadius.circular(16),
                          border: Border.all(color: AppColors.border),
                        ),
                        child: QrImageView(
                          data: _otpauthUri!,
                          size: 220,
                          backgroundColor: Colors.white,
                        ),
                      ),
                    ),
                    const SizedBox(height: AppSpacing.lg),
                    Text(
                      l10n.mfaManualSecret,
                      style: Theme.of(context).textTheme.titleSmall?.copyWith(
                            fontWeight: FontWeight.w700,
                          ),
                    ),
                    const SizedBox(height: AppSpacing.sm),
                    Container(
                      width: double.infinity,
                      padding: const EdgeInsets.all(AppSpacing.md),
                      decoration: BoxDecoration(
                        color: AppColors.surfaceMuted.withValues(alpha: 0.5),
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(color: AppColors.border),
                      ),
                      child: SelectableText(
                        _secret!,
                        style: const TextStyle(
                          fontFamily: 'monospace',
                          fontWeight: FontWeight.w700,
                          letterSpacing: 1.2,
                        ),
                      ),
                    ),
                    const SizedBox(height: AppSpacing.xl),
                    TextField(
                      controller: _codeController,
                      keyboardType: TextInputType.number,
                      maxLength: 6,
                      inputFormatters: [FilteringTextInputFormatter.digitsOnly],
                      decoration: InputDecoration(
                        labelText: l10n.mfaEnterCode,
                        counterText: '',
                        errorText: _codeError,
                      ),
                      onSubmitted: (_) => _confirmEnrollment(),
                    ),
                    const SizedBox(height: AppSpacing.lg),
                    PrimaryButton(
                      label: l10n.mfaConfirmEnable,
                      onPressed: _confirmEnrollment,
                      isLoading: _confirming,
                    ),
                  ],
                ),
    );
  }
}

class _ErrorBody extends StatelessWidget {
  const _ErrorBody({required this.message, required this.onRetry});

  final String message;
  final VoidCallback onRetry;

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    return Padding(
      padding: const EdgeInsets.all(AppSpacing.screenHorizontal),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Text(message, textAlign: TextAlign.center),
          const SizedBox(height: AppSpacing.lg),
          PrimaryButton(label: l10n.tryAgain, onPressed: onRetry),
        ],
      ),
    );
  }
}
