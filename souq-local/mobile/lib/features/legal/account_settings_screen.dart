import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:geolocator/geolocator.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../core/services/app_storage.dart';
import '../../core/services/theme_mode_provider.dart';
import '../../core/theme/app_spacing.dart';
import '../../core/widgets/buyer_ui_components.dart';
import '../../l10n/app_localizations.dart';
import 'legal_config.dart';
import '../settings/language_settings_tile.dart';

class AccountSettingsScreen extends ConsumerWidget {
  const AccountSettingsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = context.l10n;
    final session = ref.watch(userSessionProvider);
    final isGuest = session == null || session.isGuest;

    return BuyerScreenScaffold(
      appBar: BuyerAppBar(title: l10n.settingsTitle),
      body: ListView(
        padding: const EdgeInsets.all(AppSpacing.screenHorizontal),
        children: [
          _SettingsSection(
            title: l10n.accountSectionTitle,
            children: [
              if (!isGuest)
                BuyerMenuTile(
                  icon: Icons.person_outline,
                  title: l10n.navProfile,
                  subtitle: session.name,
                  onTap: () => context.push('/profile'),
                ),
              if (!isGuest)
                BuyerMenuTile(
                  icon: Icons.mark_email_unread_outlined,
                  title: l10n.verifyEmailTitle,
                  onTap: () => context.push('/verify-email'),
                ),
              if (!isGuest)
                BuyerMenuTile(
                  icon: Icons.lock_outline_rounded,
                  title: l10n.changePassword,
                  onTap: () => context.push('/profile'),
                ),
            ],
          ),
          _SettingsSection(
            title: l10n.notificationsSectionTitle,
            children: [
              BuyerMenuTile(
                icon: Icons.notifications_outlined,
                title: l10n.notificationsSectionTitle,
                subtitle: l10n.notificationsSectionSubtitle,
                onTap: () => Geolocator.openAppSettings(),
              ),
            ],
          ),
          _SettingsSection(
            title: l10n.language,
            children: const [LanguageSettingsTile()],
          ),
          _SettingsSection(
            title: l10n.privacyAndSecurityTitle,
            children: [
              BuyerMenuTile(
                icon: Icons.shield_outlined,
                title: l10n.privacySettings,
                onTap: () => context.push('/settings/privacy'),
              ),
              BuyerMenuTile(
                icon: Icons.folder_shared_outlined,
                title: l10n.yourData,
                onTap: () => context.push('/settings/your-data'),
              ),
              if (!isGuest)
                BuyerMenuTile(
                  icon: Icons.dark_mode_outlined,
                  title: l10n.darkMode,
                  trailing: Switch(
                    value: Theme.of(context).brightness == Brightness.dark,
                    onChanged: (_) {
                      ref.read(themeModeProvider.notifier).toggleLightDark();
                    },
                  ),
                ),
            ],
          ),
          _SettingsSection(
            title: l10n.helpAndSupportTitle,
            children: [
              BuyerMenuTile(
                icon: Icons.support_agent_outlined,
                title: l10n.contactSupport,
                onTap: () => launchUrl(
                  LegalConfig.supportMailto(),
                  mode: LaunchMode.externalApplication,
                ),
              ),
            ],
          ),
          _SettingsSection(
            title: l10n.privacyAndLegal,
            children: [
              BuyerMenuTile(
                icon: Icons.policy_outlined,
                title: l10n.privacyAndLegal,
                subtitle: l10n.privacyLegalHubSubtitle,
                onTap: () => context.push('/settings/privacy-legal'),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _SettingsSection extends StatelessWidget {
  const _SettingsSection({required this.title, required this.children});

  final String title;
  final List<Widget> children;

  @override
  Widget build(BuildContext context) {
    if (children.isEmpty) return const SizedBox.shrink();
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.only(
            top: AppSpacing.md,
            bottom: AppSpacing.sm,
          ),
          child: Text(
            title,
            style: Theme.of(context).textTheme.titleMedium?.copyWith(
                  fontWeight: FontWeight.w700,
                ),
          ),
        ),
        ...children.map(
          (child) => Padding(
            padding: const EdgeInsets.only(bottom: AppSpacing.sm),
            child: child,
          ),
        ),
        const SizedBox(height: AppSpacing.sm),
      ],
    );
  }
}
