import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:geolocator/geolocator.dart';

import '../../core/services/api_service.dart';
import '../../core/services/locale_provider.dart';
import '../../core/services/privacy_preferences.dart';
import '../../core/theme/app_spacing.dart';
import '../../core/theme/theme_context.dart';
import '../../core/widgets/buyer_ui_components.dart';
import '../../l10n/app_localizations.dart';

class PrivacySettingsScreen extends ConsumerWidget {
  const PrivacySettingsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = context.l10n;
    final prefs = ref.watch(privacyPreferencesProvider);

    return BuyerScreenScaffold(
      appBar: BuyerAppBar(title: l10n.privacySettings),
      body: ListView(
        padding: const EdgeInsets.all(AppSpacing.screenHorizontal),
        children: [
          Text(
            l10n.privacySettingsIntro,
            style: TextStyle(
              color: context.colors.textSecondary,
              height: 1.45,
            ),
          ),
          const SizedBox(height: AppSpacing.lg),
          _SectionHeader(title: l10n.requiredDataProcessing),
          _InfoCard(text: l10n.requiredDataProcessingBody),
          const SizedBox(height: AppSpacing.lg),
          _SectionHeader(title: l10n.optionalPreferences),
          _InfoCard(text: l10n.locationAccessDescription),
          const SizedBox(height: AppSpacing.sm),
          OutlinedButton.icon(
            onPressed: () => Geolocator.openAppSettings(),
            icon: const Icon(Icons.location_on_outlined),
            label: Text(l10n.manageLocationPermission),
          ),
          const SizedBox(height: AppSpacing.md),
          _InfoCard(text: l10n.notificationsPermissionDescription),
          const SizedBox(height: AppSpacing.sm),
          OutlinedButton.icon(
            onPressed: () => Geolocator.openAppSettings(),
            icon: const Icon(Icons.notifications_outlined),
            label: Text(l10n.manageNotificationPermission),
          ),
          if (prefs != null) ...[
            const SizedBox(height: AppSpacing.md),
            SwitchListTile(
              contentPadding: EdgeInsets.zero,
              title: Text(l10n.personalizedRecommendations),
              subtitle: Text(
                l10n.personalizedRecommendationsDescription,
                style: TextStyle(color: context.colors.textSecondary),
              ),
              value: prefs.personalizedRecommendations,
              onChanged: (value) async {
                await prefs.setPersonalizedRecommendations(value);
                try {
                  final locale = ref.read(localeProvider).languageCode;
                  await ref.read(apiServiceProvider).updatePrivacyConsent(
                        consentType: 'personalized_recommendations',
                        granted: value,
                        language: locale,
                      );
                } on ApiException {
                  // Local preference retained; server sync retried on next toggle.
                }
                ref.invalidate(privacyPreferencesProvider);
              },
            ),
            SwitchListTile(
              contentPadding: EdgeInsets.zero,
              title: Text(l10n.marketingCommunications),
              subtitle: Text(
                l10n.marketingCommunicationsDescription,
                style: TextStyle(color: context.colors.textSecondary),
              ),
              value: prefs.marketingOptIn,
              onChanged: (value) async {
                await prefs.setMarketingOptIn(value);
                try {
                  final locale = ref.read(localeProvider).languageCode;
                  await ref.read(apiServiceProvider).updatePrivacyConsent(
                        consentType: 'marketing_email',
                        granted: value,
                        language: locale,
                      );
                } on ApiException {
                  // Local preference retained; server sync retried on next toggle.
                }
                ref.invalidate(privacyPreferencesProvider);
              },
            ),
          ],
        ],
      ),
    );
  }
}

class _SectionHeader extends StatelessWidget {
  const _SectionHeader({required this.title});

  final String title;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: AppSpacing.sm),
      child: Text(
        title,
        style: Theme.of(context).textTheme.titleMedium?.copyWith(
              fontWeight: FontWeight.w700,
            ),
      ),
    );
  }
}

class _InfoCard extends StatelessWidget {
  const _InfoCard({required this.text});

  final String text;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(AppSpacing.md),
      decoration: BoxDecoration(
        color: context.colors.surfaceVariant,
        borderRadius: BorderRadius.circular(AppSpacing.cardRadius),
        border: Border.all(color: context.colors.border),
      ),
      child: Text(
        text,
        style: TextStyle(
          color: context.colors.textPrimary,
          height: 1.5,
        ),
      ),
    );
  }
}
