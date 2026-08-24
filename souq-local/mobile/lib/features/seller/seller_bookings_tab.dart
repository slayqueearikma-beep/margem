import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../core/theme/app_spacing.dart';
import '../../core/theme/theme_context.dart';
import '../../core/widgets/async_error_view.dart';
import '../../l10n/app_localizations.dart';
import 'seller_account_provider.dart';
import 'seller_widgets.dart';

class SellerBookingsTab extends ConsumerWidget {
  const SellerBookingsTab({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = context.l10n;
    final accountAsync = ref.watch(sellerAccountProvider);

    return accountAsync.when(
      loading: () => const Center(child: CircularProgressIndicator()),
      error: (error, _) => AsyncErrorView.fromError(
        error,
        onRetry: () => ref.invalidate(sellerAccountProvider),
      ),
      data: (account) {
        final inquiryCount = account.stats.inquiryCount;

        if (inquiryCount == 0) {
          return Center(
            child: Padding(
              padding: const EdgeInsets.all(32),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(
                    Icons.chat_bubble_outline,
                    size: 48,
                    color: Theme.of(context).colorScheme.onSurfaceVariant,
                  ),
                  const SizedBox(height: 12),
                  Text(
                    l10n.noInquiriesYet,
                    textAlign: TextAlign.center,
                    style: Theme.of(context).textTheme.titleMedium,
                  ),
                  const SizedBox(height: 8),
                  Text(
                    l10n.bookingsInquiryHint,
                    textAlign: TextAlign.center,
                    style: TextStyle(color: context.colors.textSecondary),
                  ),
                  const SizedBox(height: 16),
                  FilledButton(
                    onPressed: () => context.push('/seller/messages'),
                    child: Text(l10n.viewMessages),
                  ),
                ],
              ),
            ),
          );
        }

        return ListView(
          padding: EdgeInsets.all(AppSpacing.screenHorizontal),
          children: [
            Text(
              l10n.inquiries,
              style: Theme.of(context)
                  .textTheme
                  .titleSmall
                  ?.copyWith(fontWeight: FontWeight.w700),
            ),
            const SizedBox(height: 8),
            Card(
              child: ListTile(
                leading: CircleAvatar(
                  backgroundColor:
                      context.colors.primary.withValues(alpha: 0.12),
                  child: Icon(
                    Icons.chat_bubble_outline,
                    color: context.colors.primary,
                  ),
                ),
                title: Text(l10n.inquiries),
                subtitle: Text(l10n.bookingsInquiryHint),
                trailing: SellerStatusBadge(
                  label: l10n.upcoming,
                  active: true,
                ),
                onTap: () => context.push('/seller/messages'),
              ),
            ),
          ],
        );
      },
    );
  }
}
