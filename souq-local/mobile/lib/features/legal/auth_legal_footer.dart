import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../../core/theme/app_spacing.dart';
import '../../core/theme/theme_context.dart';
import '../../l10n/app_localizations.dart';

/// Subtle legal footer for authentication screens.
class AuthLegalFooter extends StatelessWidget {
  const AuthLegalFooter({super.key});

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final style = Theme.of(context).textTheme.bodySmall?.copyWith(
          color: context.colors.textTertiary,
          fontSize: 12,
          height: 1.4,
        );
    final linkStyle = style.copyWith(
      color: context.colors.primary,
      decoration: TextDecoration.underline,
    );

    return Padding(
      padding: const EdgeInsets.only(
        top: AppSpacing.lg,
        bottom: AppSpacing.md,
      ),
      child: RichText(
        textAlign: TextAlign.center,
        text: TextSpan(
          style: style,
          children: [
            TextSpan(
              text: l10n.privacyPolicy,
              style: linkStyle,
              recognizer: TapGestureRecognizer()
                ..onTap = () => context.push('/legal/privacy'),
            ),
            TextSpan(text: ' · '),
            TextSpan(
              text: l10n.termsOfService,
              style: linkStyle,
              recognizer: TapGestureRecognizer()
                ..onTap = () => context.push('/legal/terms'),
            ),
            TextSpan(text: ' · '),
            TextSpan(
              text: l10n.privacyAndLegal,
              style: linkStyle,
              recognizer: TapGestureRecognizer()
                ..onTap = () => context.push('/settings/privacy-legal'),
            ),
          ],
        ),
      ),
    );
  }
}
