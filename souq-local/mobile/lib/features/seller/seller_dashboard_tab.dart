import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../core/services/api_service.dart';
import '../../core/services/app_storage.dart';
import '../../core/services/auth_service.dart';
import '../../core/theme/app_spacing.dart';
import '../../core/theme/theme_context.dart';
import '../../core/widgets/async_error_view.dart';
import '../../l10n/app_localizations.dart';
import '../messages/messages_inbox_screen.dart';
import 'seller_account_provider.dart';
import 'seller_navigation.dart';
import 'seller_widgets.dart';

class SellerDashboardTab extends ConsumerWidget {
  const SellerDashboardTab({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = context.l10n;
    final session = ref.watch(userSessionProvider);
    final accountAsync = ref.watch(sellerAccountProvider);
    final unreadAsync = ref.watch(conversationsUnreadCountProvider);
    final unreadCount = unreadAsync.valueOrNull ?? 0;

    return accountAsync.when(
      loading: () => const Center(child: CircularProgressIndicator()),
      error: (error, _) => AsyncErrorView(
        message:
            error is ApiException ? error.message : l10n.somethingWentWrong,
        onRetry: () => ref.invalidate(sellerAccountProvider),
      ),
      data: (account) {
        final stats = account.stats;
        final profileViews = stats.profileViewCount;
        final reviewCount = stats.reviewCount;

        return RefreshIndicator(
          onRefresh: () async {
            ref.invalidate(sellerAccountProvider);
            ref.invalidate(conversationsProvider);
            await ref.read(sellerAccountProvider.future);
          },
          child: ListView(
            padding: EdgeInsets.fromLTRB(
              AppSpacing.screenHorizontal,
              AppSpacing.md,
              AppSpacing.screenHorizontal,
              100,
            ),
            children: [
              Text(
                _greeting(
                  l10n,
                  businessName: account.profile.businessName,
                  sessionName: session?.name,
                  authName: ref.watch(authSessionProvider)?.user.displayName,
                ),
                style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                      fontWeight: FontWeight.w800,
                    ),
              ),
              SizedBox(height: 4),
              Text(
                l10n.manageStoreSubtitle,
                style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                      color: Theme.of(context).colorScheme.onSurfaceVariant,
                    ),
              ),
              SizedBox(height: AppSpacing.md),
              GridView.count(
                crossAxisCount: 2,
                shrinkWrap: true,
                physics: NeverScrollableScrollPhysics(),
                mainAxisSpacing: 12,
                crossAxisSpacing: 12,
                childAspectRatio: 1.35,
                children: [
                  SellerMetricTile(
                    label: l10n.profileViews,
                    value: '$profileViews',
                    icon: Icons.visibility_outlined,
                  ),
                  SellerMetricTile(
                    label: l10n.navMessages,
                    value: unreadCount > 0 ? '$unreadCount' : '0',
                    icon: Icons.chat_bubble_outline,
                    subtitle: unreadCount > 0 ? l10n.messagesSub : null,
                    onTap: () =>
                        ref.read(sellerTabIndexProvider.notifier).state = 2,
                  ),
                  SellerMetricTile(
                    label: l10n.reviews,
                    value: '$reviewCount',
                    icon: Icons.star_outline_rounded,
                    subtitle: stats.averageRating > 0
                        ? stats.averageRating.toStringAsFixed(1)
                        : null,
                    onTap: () => context.push('/seller/reviews'),
                  ),
                ],
              ),
              const SizedBox(height: AppSpacing.lg),
              SellerSectionHeader(
                title: l10n.highlightServices,
                actionLabel: l10n.manage,
                onAction: () =>
                    ref.read(sellerTabIndexProvider.notifier).state = 1,
              ),
              const SizedBox(height: AppSpacing.sm),
              if (account.profile.services.isEmpty)
                _EmptyHintCard(message: l10n.noServicesYet)
              else
                SizedBox(
                  height: 132,
                  child: ListView.separated(
                    scrollDirection: Axis.horizontal,
                    itemCount: account.profile.services.take(6).length,
                    separatorBuilder: (_, __) => const SizedBox(width: 12),
                    itemBuilder: (context, index) {
                      final service = account.profile.services[index];
                      return SizedBox(
                        width: 220,
                        child: Card(
                          child: Padding(
                            padding: EdgeInsets.all(12),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  service.name,
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                  style: TextStyle(
                                    fontWeight: FontWeight.w700,
                                  ),
                                ),
                                Spacer(),
                                Text(
                                  service.displayPrice(l10n),
                                  style: TextStyle(
                                    color: context.colors.primary,
                                    fontWeight: FontWeight.w800,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ),
                      );
                    },
                  ),
                ),
            ],
          ),
        );
      },
    );
  }
}

String _greeting(
  AppStrings l10n, {
  required String businessName,
  String? sessionName,
  String? authName,
}) {
  for (final candidate in [businessName, authName ?? '', sessionName ?? '']) {
    final cleaned = candidate.trim();
    if (cleaned.length >= 2) {
      return l10n.welcomeSeller(cleaned.split(RegExp(r'\s+')).first);
    }
  }
  return l10n.welcomeExclamation;
}

class _EmptyHintCard extends StatelessWidget {
  const _EmptyHintCard({required this.message});

  final String message;

  @override
  Widget build(BuildContext context) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Text(
          message,
          style: TextStyle(
            color: Theme.of(context).colorScheme.onSurfaceVariant,
          ),
        ),
      ),
    );
  }
}
