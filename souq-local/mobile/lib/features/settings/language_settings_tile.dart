import 'package:flutter/material.dart';
import '../../core/theme/theme_context.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../core/utils/directional_ui.dart';
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

    return ListTile(
      leading: Icon(Icons.language_rounded, color: context.colors.primary),
      title: Text(l10n.language),
      subtitle: Text(_languageLabel(l10n, code)),
      trailing: Icon(DirectionalUi.forwardChevron(context)),
      onTap: () => context.push('/settings/language'),
    );
  }
}
