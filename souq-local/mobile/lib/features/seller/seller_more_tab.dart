import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../core/services/app_storage.dart';
import '../../core/services/auth_service.dart';
import '../../core/theme/app_spacing.dart';
import '../../core/theme/theme_context.dart';
import '../../core/widgets/content_widgets.dart';
import '../../l10n/app_localizations.dart';
import '../settings/language_settings_tile.dart';
import 'seller_account_provider.dart';

class SellerMoreTab extends ConsumerWidget {
  const SellerMoreTab({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = context.l10n;
    final session = ref.watch(userSessionProvider);
    final isGuest = session == null || session.isGuest;
    final account = ref.watch(sellerAccountProvider).valueOrNull;

    return ListView(
      padding: const EdgeInsets.fromLTRB(
        AppSpacing.screenHorizontal,
        8,
        AppSpacing.screenHorizontal,
        100,
      ),
      children: [
        Text(
          l10n.previewStorefront,
          style: Theme.of(context).textTheme.titleSmall?.copyWith(
                fontWeight: FontWeight.w700,
              ),
        ),
        const SizedBox(height: AppSpacing.sm),
        DashboardMenuTile(
          title: l10n.previewStorefront,
          subtitle: l10n.previewStorefrontSub,
          icon: Icons.visibility_outlined,
          onTap: () {
            final id = account?.profile.id;
            if (id != null) context.push('/seller/$id');
          },
        ),
        const SizedBox(height: AppSpacing.lg),
        Text(
          l10n.settingsTitle,
          style: Theme.of(context).textTheme.titleSmall?.copyWith(
                fontWeight: FontWeight.w700,
              ),
        ),
        const SizedBox(height: AppSpacing.sm),
        DashboardMenuTile(
          title: l10n.accountSecurity,
          subtitle: l10n.accountSecuritySub,
          icon: Icons.security_outlined,
          onTap: () => context.push('/seller/settings'),
        ),
        const LanguageSettingsTile(),
        const SizedBox(height: AppSpacing.lg),
        OutlinedButton(
          onPressed: () async {
            await switchToBuyerMode(ref);
            if (context.mounted) context.go('/buyer/home');
          },
          child: Text(l10n.switchToBuyerMode),
        ),
        if (!isGuest) ...[
          const SizedBox(height: 8),
          OutlinedButton(
            onPressed: () async {
              final prefs = await ref.read(sharedPreferencesProvider.future);
              await ref.read(authServiceProvider).logout(prefs);
              await ref.read(appStorageProvider)?.logout();
              ref.invalidate(sellerAccountProvider);
              ref.read(userSessionProvider.notifier).state = null;
              ref.read(authSessionProvider.notifier).state = null;
              if (context.mounted) context.go('/login');
            },
            style: OutlinedButton.styleFrom(
              foregroundColor: context.colors.error,
              side: BorderSide(color: context.colors.error),
            ),
            child: Text(l10n.logOut),
          ),
        ],
      ],
    );
  }
}
