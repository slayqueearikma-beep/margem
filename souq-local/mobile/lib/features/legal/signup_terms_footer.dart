import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../../core/theme/app_spacing.dart';
import '../../core/theme/theme_context.dart';
import '../../l10n/app_localizations.dart';

/// Contextual signup consent with tappable Terms and Privacy links.
class SignupTermsFooter extends StatelessWidget {
  const SignupTermsFooter({super.key});

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final style = (Theme.of(context).textTheme.bodySmall ?? const TextStyle())
        .copyWith(
          color: context.colors.textSecondary,
          height: 1.45,
        );
    final linkStyle = style.copyWith(
      color: context.colors.primary,
      fontWeight: FontWeight.w600,
      decoration: TextDecoration.underline,
    );

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: AppSpacing.sm),
      child: RichText(
        textAlign: TextAlign.center,
        text: TextSpan(
          style: style,
          children: [
            TextSpan(text: l10n.signupTermsPrefix),
            TextSpan(
              text: l10n.termsOfService,
              style: linkStyle,
              recognizer: TapGestureRecognizer()
                ..onTap = () => context.push('/legal/terms'),
            ),
            TextSpan(text: l10n.signupTermsMiddle),
            TextSpan(
              text: l10n.privacyPolicy,
              style: linkStyle,
              recognizer: TapGestureRecognizer()
                ..onTap = () => context.push('/legal/privacy'),
            ),
            TextSpan(text: l10n.signupTermsSuffix),
          ],
        ),
      ),
    );
  }
}
