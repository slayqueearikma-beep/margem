import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import 'app_brand_logo.dart';
import '../services/api_service.dart';
import '../theme/app_spacing.dart';
import '../theme/theme_context.dart';
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
        padding: EdgeInsets.fromLTRB(20, 16, 20, 20),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Row(
              children: [
                Spacer(),
                IconButton(
                  onPressed: () => Navigator.of(context).pop(),
                  icon: Icon(Icons.close_rounded),
                ),
              ],
            ),
            AppBrandLogo(
              tier: AppLogoTier.header,
              includeClearSpace: false,
            ),
            SizedBox(height: AppSpacing.md),
            Text(
              l10n.signupOtpChannelTitle,
              textAlign: TextAlign.center,
              style: Theme.of(context)
                  .textTheme
                  .titleMedium
                  ?.copyWith(fontWeight: FontWeight.w700),
            ),
            SizedBox(height: AppSpacing.sm),
            Text(
              l10n.signupOtpChannelSubtitle,
              textAlign: TextAlign.center,
              style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                    color: context.colors.textSecondary,
                    height: 1.4,
                  ),
            ),
            SizedBox(height: AppSpacing.lg),
            if (phone.trim().isNotEmpty) ...[
              _ChannelTile(
                icon: Icons.phone_iphone_rounded,
                title: l10n.signupOtpSendPhone,
                subtitle: maskPhone(phone),
                onTap: () =>
                    Navigator.of(context).pop(SignupVerificationChannel.phone),
              ),
              SizedBox(height: AppSpacing.sm),
            ],
            _ChannelTile(
              icon: Icons.mail_outline_rounded,
              title: l10n.signupOtpSendEmail,
              subtitle: maskEmail(email),
              onTap: () =>
                  Navigator.of(context).pop(SignupVerificationChannel.email),
            ),
            SizedBox(height: AppSpacing.lg),
            Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(Icons.lock_outline,
                    size: 14, color: context.colors.textSecondary),
                SizedBox(width: 6),
                Text(
                  l10n.signupOtpPrivacyNote,
                  style: Theme.of(context).textTheme.bodySmall?.copyWith(
                        color: context.colors.textSecondary,
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
      color: context.colors.surfaceVariant,
      borderRadius: BorderRadius.circular(14),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(14),
        child: Padding(
          padding: EdgeInsets.symmetric(horizontal: 14, vertical: 12),
          child: Row(
            children: [
              Icon(icon, color: context.colors.primary),
              SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(title,
                        style: TextStyle(fontWeight: FontWeight.w700)),
                    Text(subtitle,
                        style: TextStyle(
                          color: context.colors.textSecondary,
                          fontSize: 13,
                        )),
                  ],
                ),
              ),
              Icon(DirectionalUi.forwardChevron(context),
                  color: context.colors.textSecondary),
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
        padding: EdgeInsets.fromLTRB(20, 12, 20, 20),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Row(
              children: [
                IconButton(
                  onPressed: () => Navigator.of(context).pop(),
                  icon: Icon(DirectionalUi.backArrow(context), size: 18),
                ),
                Spacer(),
                IconButton(
                  onPressed: () => Navigator.of(context).pop(),
                  icon: Icon(Icons.close_rounded),
                ),
              ],
            ),
            AppBrandLogo(
              tier: AppLogoTier.header,
              includeClearSpace: false,
            ),
            SizedBox(height: AppSpacing.md),
            Text(
              l10n.signupOtpCodeTitle,
              textAlign: TextAlign.center,
              style: Theme.of(context)
                  .textTheme
                  .titleMedium
                  ?.copyWith(fontWeight: FontWeight.w700),
            ),
            SizedBox(height: AppSpacing.sm),
            Text(
              l10n.signupOtpCodeSentTo(_destinationMasked),
              textAlign: TextAlign.center,
              style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                    color: context.colors.textSecondary,
                    height: 1.4,
                  ),
            ),
            TextButton(
              onPressed:
                  _loading ? null : () => Navigator.of(context).pop('__change__'),
              child: Text(l10n.signupOtpChange),
            ),
            const SizedBox(height: AppSpacing.lg),
            LayoutBuilder(
              builder: (context, constraints) {
                const digitCount = 6;
                const gap = 6.0;
                final totalGap = gap * (digitCount - 1);
                final boxWidth =
                    ((constraints.maxWidth - totalGap) / digitCount).clamp(32.0, 44.0);
                return Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: List.generate(digitCount, (index) {
                    return Padding(
                      padding: EdgeInsetsDirectional.only(
                        end: index == digitCount - 1 ? 0 : gap,
                      ),
                      child: SizedBox(
                        width: boxWidth,
                        child: TextField(
                          controller: _controllers[index],
                          focusNode: _focusNodes[index],
                          textAlign: TextAlign.center,
                          keyboardType: TextInputType.number,
                          maxLength: 6,
                          enabled: !_loading,
                          style: Theme.of(context).textTheme.titleMedium,
                          inputFormatters: [
                            FilteringTextInputFormatter.digitsOnly,
                          ],
                          decoration: InputDecoration(
                            counterText: '',
                            contentPadding:
                                const EdgeInsets.symmetric(vertical: 12),
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
                );
              },
            ),
            if (_error != null) ...[
              SizedBox(height: AppSpacing.sm),
              Text(
                _error!,
                textAlign: TextAlign.center,
                style: TextStyle(color: context.colors.error, fontSize: 13),
              ),
            ],
            SizedBox(height: AppSpacing.md),
            Text(
              l10n.signupOtpDidntReceive,
              style: Theme.of(context).textTheme.bodySmall?.copyWith(
                    color: context.colors.textSecondary,
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
