import 'package:flutter/material.dart';

import '../theme/app_spacing.dart';
import '../theme/theme_context.dart';
import '../utils/directional_ui.dart';
import 'app_brand_logo.dart';

class PrimaryButton extends StatelessWidget {
  const PrimaryButton({
    super.key,
    required this.label,
    required this.onPressed,
    this.isLoading = false,
    this.icon,
    this.trailingIcon,
    this.accentColor,
  });

  final String label;
  final VoidCallback? onPressed;
  final bool isLoading;
  final IconData? icon;
  final IconData? trailingIcon;
  final Color? accentColor;

  @override
  Widget build(BuildContext context) {
    final accent = accentColor ?? context.colors.primary;

    return SizedBox(
      width: double.infinity,
      child: FilledButton(
        style: FilledButton.styleFrom(
          backgroundColor: accent,
          disabledBackgroundColor: accent.withValues(alpha: 0.35),
        ),
        onPressed: isLoading ? null : onPressed,
        child: isLoading
            ? SizedBox(
                height: 22,
                width: 22,
                child: CircularProgressIndicator(
                  strokeWidth: 2,
                  color: context.colors.onPrimary,
                ),
              )
            : Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  if (icon != null) ...[
                    Icon(icon, size: 20),
                    SizedBox(width: 8),
                  ],
                  Text(label),
                  if (trailingIcon != null) ...[
                    SizedBox(width: 8),
                    Icon(_trailingIcon(context), size: 20),
                  ],
                ],
              ),
      ),
    );
  }

  IconData _trailingIcon(BuildContext context) {
    if (trailingIcon == Icons.arrow_forward_rounded ||
        trailingIcon == Icons.arrow_forward_ios_rounded) {
      return DirectionalUi.forwardArrow(context);
    }
    if (trailingIcon == Icons.chevron_right_rounded ||
        trailingIcon == Icons.chevron_left_rounded) {
      return DirectionalUi.forwardChevron(context);
    }
    return trailingIcon!;
  }
}

class SecondaryTextButton extends StatelessWidget {
  const SecondaryTextButton({
    super.key,
    required this.label,
    required this.onPressed,
  });

  final String label;
  final VoidCallback onPressed;

  @override
  Widget build(BuildContext context) {
    return TextButton(
      onPressed: onPressed,
      child: Text(
        label,
        style: Theme.of(context).textTheme.bodyMedium?.copyWith(
              color: context.colors.textSecondary,
              fontWeight: FontWeight.w500,
            ),
      ),
    );
  }
}

class LinkTextButton extends StatelessWidget {
  const LinkTextButton({
    super.key,
    required this.label,
    required this.onPressed,
  });

  final String label;
  final VoidCallback onPressed;

  @override
  Widget build(BuildContext context) {
    return TextButton(
      onPressed: onPressed,
      child: Text(
        label,
        style: TextStyle(
          color: context.colors.primary,
          fontWeight: FontWeight.w600,
        ),
      ),
    );
  }
}

class AppScreenHeader extends StatelessWidget {
  const AppScreenHeader({
    super.key,
    required this.title,
    this.subtitle,
    this.showLogo = true,
    this.centered = false,
  });

  final String title;
  final String? subtitle;
  final bool showLogo;
  final bool centered;

  @override
  Widget build(BuildContext context) {
    final alignment =
        centered ? CrossAxisAlignment.center : CrossAxisAlignment.start;
    final textAlign = centered ? TextAlign.center : TextAlign.start;

    return Column(
      crossAxisAlignment: alignment,
      children: [
        if (showLogo) ...[
          AppBrandHeader(
            tier: AppLogoTier.header,
            includeTopSpacing: false,
            logoToTitleGap: AppSpacing.logoToTitle,
          ),
        ],
        Text(
          title,
          textAlign: textAlign,
          style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                fontWeight: FontWeight.w700,
                height: 1.2,
              ),
        ),
        if (subtitle != null) ...[
          SizedBox(height: AppSpacing.sm),
          Text(
            subtitle!,
            textAlign: textAlign,
            style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                  color: context.colors.textSecondary,
                  height: 1.45,
                ),
          ),
        ],
      ],
    );
  }
}
