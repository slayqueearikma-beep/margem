import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../services/api_service.dart';
import '../theme/app_colors.dart';
import '../theme/app_spacing.dart';
import '../utils/directional_ui.dart';
import '../../l10n/app_localizations.dart';

enum SignupVerificationChannel { email, phone }

/// Shows channel picker then 6-digit code entry before account creation.
Future<String?> showSignupVerificationFlow({
  required BuildContext context,
  required String email,
  required String phone,
}) async {
  while (context.mounted) {
    if (!context.mounted) return null;
    final channel = await showDialog<SignupVerificationChannel>(
      context: context,
      barrierDismissible: false,
      builder: (_) => _ChannelPickerDialog(email: email, phone: phone),
    );
    if (channel == null) return null;
    if (!context.mounted) return null;

    final proof = await showDialog<String>(
      context: context,
      barrierDismissible: false,
      builder: (_) => _CodeEntryDialog(
        email: email,
        phone: phone,
        channel: channel,
      ),
    );
    if (proof == '__change__') continue;
    return proof;
  }
  return null;
}

String maskEmail(String email) {
  final parts = email.split('@');
  if (parts.length != 2) return email;
  final local = parts[0];
  if (local.isEmpty) return email;
  if (local.length <= 2) return '${local[0]}***@${parts[1]}';
  return '${local[0]}***${local[local.length - 1]}@${parts[1]}';
}

String maskPhone(String phone) {
  final digits = phone.replaceAll(RegExp(r'\D'), '');
  if (digits.length < 4) return phone;
  if (digits.startsWith('212') && digits.length >= 12) {
    return '+212 ${digits[3]}** *** **${digits.substring(digits.length - 2)}';
  }
  if (digits.length >= 10) {
    return '+${digits.substring(0, digits.length - 9)} ${digits[digits.length - 9]}** *** **${digits.substring(digits.length - 2)}';
  }
  return '*** **${digits.substring(digits.length - 2)}';
}

class _ChannelPickerDialog extends StatelessWidget {
  const _ChannelPickerDialog({required this.email, required this.phone});

  final String email;
  final String phone;

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    return Dialog(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
      child: Padding(
        padding: const EdgeInsets.fromLTRB(20, 16, 20, 20),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Row(
              children: [
                const Spacer(),
                IconButton(
                  onPressed: () => Navigator.of(context).pop(),
                  icon: const Icon(Icons.close_rounded),
                ),
              ],
            ),
            const Icon(Icons.verified_user_outlined,
                size: 40, color: AppColors.primary),
            const SizedBox(height: AppSpacing.md),
            Text(
              l10n.signupOtpChannelTitle,
              textAlign: TextAlign.center,
              style: Theme.of(context)
                  .textTheme
                  .titleMedium
                  ?.copyWith(fontWeight: FontWeight.w700),
            ),
            const SizedBox(height: AppSpacing.sm),
            Text(
              l10n.signupOtpChannelSubtitle,
              textAlign: TextAlign.center,
              style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                    color: AppColors.textSecondary,
                    height: 1.4,
                  ),
            ),
            const SizedBox(height: AppSpacing.lg),
            if (phone.trim().isNotEmpty) ...[
              _ChannelTile(
                icon: Icons.phone_iphone_rounded,
                title: l10n.signupOtpSendPhone,
                subtitle: maskPhone(phone),
                onTap: () =>
                    Navigator.of(context).pop(SignupVerificationChannel.phone),
              ),
              const SizedBox(height: AppSpacing.sm),
            ],
            _ChannelTile(
              icon: Icons.mail_outline_rounded,
              title: l10n.signupOtpSendEmail,
              subtitle: maskEmail(email),
              onTap: () =>
                  Navigator.of(context).pop(SignupVerificationChannel.email),
            ),
            const SizedBox(height: AppSpacing.lg),
            Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                const Icon(Icons.lock_outline,
                    size: 14, color: AppColors.textSecondary),
                const SizedBox(width: 6),
                Text(
                  l10n.signupOtpPrivacyNote,
                  style: Theme.of(context).textTheme.bodySmall?.copyWith(
                        color: AppColors.textSecondary,
                      ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

class _ChannelTile extends StatelessWidget {
  const _ChannelTile({
    required this.icon,
    required this.title,
    required this.subtitle,
    required this.onTap,
  });

  final IconData icon;
  final String title;
  final String subtitle;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: AppColors.surfaceMuted,
      borderRadius: BorderRadius.circular(14),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(14),
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
          child: Row(
            children: [
              Icon(icon, color: AppColors.primary),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(title,
                        style: const TextStyle(fontWeight: FontWeight.w700)),
                    Text(subtitle,
                        style: const TextStyle(
                          color: AppColors.textSecondary,
                          fontSize: 13,
                        )),
                  ],
                ),
              ),
              Icon(DirectionalUi.forwardChevron(context),
                  color: AppColors.textSecondary),
            ],
          ),
        ),
      ),
    );
  }
}

class _CodeEntryDialog extends StatefulWidget {
  const _CodeEntryDialog({
    required this.email,
    required this.phone,
    required this.channel,
  });

  final String email;
  final String phone;
  final SignupVerificationChannel channel;

  @override
  State<_CodeEntryDialog> createState() => _CodeEntryDialogState();
}

class _CodeEntryDialogState extends State<_CodeEntryDialog> {
  final _controllers = List.generate(6, (_) => TextEditingController());
  final _focusNodes = List.generate(6, (_) => FocusNode());
  bool _loading = false;
  bool _resending = false;
  String? _error;
  int _resendSeconds = 45;
  Timer? _timer;
  late String _destinationMasked;

  @override
  void initState() {
    super.initState();
    _destinationMasked = widget.channel == SignupVerificationChannel.email
        ? maskEmail(widget.email)
        : maskPhone(widget.phone);
    _startResendTimer();
    WidgetsBinding.instance.addPostFrameCallback((_) => _sendCode());
  }

  @override
  void dispose() {
    _timer?.cancel();
    for (final c in _controllers) {
      c.dispose();
    }
    for (final f in _focusNodes) {
      f.dispose();
    }
    super.dispose();
  }

  void _startResendTimer() {
    _timer?.cancel();
    setState(() => _resendSeconds = 45);
    _timer = Timer.periodic(const Duration(seconds: 1), (timer) {
      if (!mounted) return;
      if (_resendSeconds <= 1) {
        timer.cancel();
        setState(() => _resendSeconds = 0);
      } else {
        setState(() => _resendSeconds -= 1);
      }
    });
  }

  String get _channel =>
      widget.channel == SignupVerificationChannel.email ? 'email' : 'phone';

  Future<void> _sendCode() async {
    setState(() {
      _resending = true;
      _error = null;
    });
    try {
      final result = await apiServiceProvider.sendSignupOtp(
        email: widget.email,
        phone: widget.phone,
        channel: _channel,
      );
      if (!mounted) return;
      setState(() => _destinationMasked = result.destinationMasked);
    } on ApiException catch (e) {
      if (!mounted) return;
      setState(() => _error = e.message);
    } finally {
      if (mounted) setState(() => _resending = false);
    }
  }

  Future<void> _verify() async {
    final code = _controllers.map((c) => c.text).join();
    if (code.length != 6) {
      setState(() => _error = context.l10n.signupOtpCodeInvalid);
      return;
    }
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final proof = await apiServiceProvider.verifySignupOtp(
        email: widget.email,
        code: code,
        channel: _channel,
      );
      if (!mounted) return;
      Navigator.of(context).pop(proof);
    } on ApiException catch (e) {
      if (!mounted) return;
      setState(() => _error = e.message);
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  void _onDigitChanged(int index, String value) {
    if (value.length > 1) {
      final digits = value.replaceAll(RegExp(r'\D'), '');
      for (var i = 0; i < digits.length && index + i < 6; i++) {
        _controllers[index + i].text = digits[i];
      }
      final next = (index + digits.length).clamp(0, 5);
      _focusNodes[next].requestFocus();
      return;
    }
    if (value.isNotEmpty && index < 5) {
      _focusNodes[index + 1].requestFocus();
    }
    if (value.isEmpty && index > 0) {
      _focusNodes[index - 1].requestFocus();
    }
  }

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    return Dialog(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
      child: Padding(
        padding: const EdgeInsets.fromLTRB(20, 12, 20, 20),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Row(
              children: [
                IconButton(
                  onPressed: () => Navigator.of(context).pop(),
                  icon: Icon(DirectionalUi.backArrow(context), size: 18),
                ),
                const Spacer(),
                IconButton(
                  onPressed: () => Navigator.of(context).pop(),
                  icon: const Icon(Icons.close_rounded),
                ),
              ],
            ),
            const Icon(Icons.sms_outlined, size: 40, color: AppColors.primary),
            const SizedBox(height: AppSpacing.md),
            Text(
              l10n.signupOtpCodeTitle,
              textAlign: TextAlign.center,
              style: Theme.of(context)
                  .textTheme
                  .titleMedium
                  ?.copyWith(fontWeight: FontWeight.w700),
            ),
            const SizedBox(height: AppSpacing.sm),
            Text(
              l10n.signupOtpCodeSentTo(_destinationMasked),
              textAlign: TextAlign.center,
              style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                    color: AppColors.textSecondary,
                    height: 1.4,
                  ),
            ),
            TextButton(
              onPressed:
                  _loading ? null : () => Navigator.of(context).pop('__change__'),
              child: Text(l10n.signupOtpChange),
            ),
            const SizedBox(height: AppSpacing.lg),
            Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: List.generate(6, (index) {
                return Padding(
                  padding: EdgeInsets.only(right: index == 5 ? 0 : 8),
                  child: SizedBox(
                    width: 42,
                    child: TextField(
                      controller: _controllers[index],
                      focusNode: _focusNodes[index],
                      textAlign: TextAlign.center,
                      keyboardType: TextInputType.number,
                      maxLength: 6,
                      enabled: !_loading,
                      inputFormatters: [FilteringTextInputFormatter.digitsOnly],
                      decoration: InputDecoration(
                        counterText: '',
                        contentPadding: const EdgeInsets.symmetric(vertical: 12),
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(10),
                        ),
                      ),
                      onChanged: (value) => _onDigitChanged(index, value),
                      onSubmitted: (_) => _verify(),
                    ),
                  ),
                );
              }),
            ),
            if (_error != null) ...[
              const SizedBox(height: AppSpacing.sm),
              Text(
                _error!,
                textAlign: TextAlign.center,
                style: const TextStyle(color: AppColors.danger, fontSize: 13),
              ),
            ],
            const SizedBox(height: AppSpacing.md),
            Text(
              l10n.signupOtpDidntReceive,
              style: Theme.of(context).textTheme.bodySmall?.copyWith(
                    color: AppColors.textSecondary,
                  ),
            ),
            TextButton(
              onPressed: (_resendSeconds > 0 || _resending || _loading)
                  ? null
                  : () async {
                      await _sendCode();
                      _startResendTimer();
                    },
              child: Text(
                _resendSeconds > 0
                    ? l10n.signupOtpResendCountdown(_resendSeconds)
                    : l10n.signupOtpResend,
              ),
            ),
            const SizedBox(height: AppSpacing.sm),
            SizedBox(
              width: double.infinity,
              child: FilledButton(
                onPressed: _loading ? null : _verify,
                child: _loading
                    ? const SizedBox(
                        width: 22,
                        height: 22,
                        child: CircularProgressIndicator(
                          strokeWidth: 2,
                          color: Colors.white,
                        ),
                      )
                    : Text(l10n.signupOtpVerify),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
