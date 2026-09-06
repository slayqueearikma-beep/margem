import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../core/widgets/buyer_ui_components.dart';
import '../../l10n/app_localizations.dart';

class LanguageSettingsTile extends ConsumerWidget {
  const LanguageSettingsTile({super.key});

  String _languageLabel(AppStrings l10n, String code) {
    switch (code) {
      case 'fr':
        return '🇫🇷 ${l10n.french}';
      case 'ar':
        return '🇲🇦 ${l10n.arabic}';
      default:
        return '🇬🇧 ${l10n.english}';
    }
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = context.l10n;
    final code = Localizations.localeOf(context).languageCode;

    return BuyerMenuTile(
      icon: Icons.language_rounded,
      title: l10n.language,
      subtitle: _languageLabel(l10n, code),
      onTap: () => context.push('/settings/language'),
    );
  }
}
