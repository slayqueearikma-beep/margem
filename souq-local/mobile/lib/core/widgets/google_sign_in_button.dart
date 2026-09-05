import 'package:flutter/material.dart';

import '../../l10n/app_localizations.dart';
import '../theme/app_spacing.dart';
import '../theme/theme_context.dart';

/// Google-branded sign-in button consistent with Dribex auth screens.
class GoogleSignInButton extends StatelessWidget {
  const GoogleSignInButton({
    super.key,
    required this.onPressed,
    this.isLoading = false,
  });

  final VoidCallback? onPressed;
  final bool isLoading;

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final enabled = onPressed != null && !isLoading;

    return SizedBox(
      width: double.infinity,
      height: 48,
      child: OutlinedButton(
        onPressed: enabled ? onPressed : null,
        style: OutlinedButton.styleFrom(
          backgroundColor: Colors.white,
          foregroundColor: const Color(0xFF1F1F1F),
          disabledForegroundColor: context.colors.textSecondary,
          side: BorderSide(color: context.colors.border, width: 1.2),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(14),
          ),
          textStyle: const TextStyle(
            fontWeight: FontWeight.w600,
            fontSize: 15,
          ),
        ),
        child: isLoading
            ? SizedBox(
                width: 20,
                height: 20,
                child: CircularProgressIndicator(
                  strokeWidth: 2,
                  color: context.colors.primary,
                ),
              )
            : Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  const Icon(
                    Icons.g_mobiledata_rounded,
                    size: 28,
                    color: Color(0xFF4285F4),
                  ),
                  const SizedBox(width: AppSpacing.sm),
                  Text(l10n.continueWithGoogle),
                ],
              ),
      ),
    );
  }
}

class AuthDivider extends StatelessWidget {
  const AuthDivider({super.key});

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: AppSpacing.md),
      child: Row(
        children: [
          Expanded(child: Divider(color: context.colors.border)),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: AppSpacing.sm),
            child: Text(
              l10n.authDividerOr,
              style: TextStyle(color: context.colors.textSecondary),
            ),
          ),
          Expanded(child: Divider(color: context.colors.border)),
        ],
      ),
    );
  }
}
