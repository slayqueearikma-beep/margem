import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../core/theme/app_colors.dart';
import '../../core/theme/app_spacing.dart';
import '../../core/widgets/async_error_view.dart';
import '../../l10n/app_localizations.dart';
import 'seller_account_provider.dart';
import 'seller_widgets.dart';

enum _BookingFilter { upcoming, completed, cancelled }

class SellerBookingsTab extends ConsumerStatefulWidget {
  const SellerBookingsTab({super.key});

  @override
  ConsumerState<SellerBookingsTab> createState() => _SellerBookingsTabState();
}

class _SellerBookingsTabState extends ConsumerState<SellerBookingsTab> {
  _BookingFilter _filter = _BookingFilter.upcoming;

  @override
  Widget build(BuildContext context) {
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
        const completedCount = 0;
        const cancelledCount = 0;

        return Column(
          children: [
            Padding(
              padding: const EdgeInsets.all(AppSpacing.screenHorizontal),
              child: SegmentedButton<_BookingFilter>(
                showSelectedIcon: false,
                style: SegmentedButton.styleFrom(
                  visualDensity: VisualDensity.compact,
                  tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                  textStyle: const TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                segments: [
                  ButtonSegment(
                    value: _BookingFilter.upcoming,
                    label: FittedBox(
                      fit: BoxFit.scaleDown,
                      child: Text(l10n.bookingsUpcoming(inquiryCount)),
                    ),
                  ),
                  ButtonSegment(
                    value: _BookingFilter.completed,
                    label: FittedBox(
                      fit: BoxFit.scaleDown,
                      child: Text(l10n.bookingsCompleted(completedCount)),
                    ),
                  ),
                  ButtonSegment(
                    value: _BookingFilter.cancelled,
                    label: FittedBox(
                      fit: BoxFit.scaleDown,
                      child: Text(l10n.bookingsCancelled(cancelledCount)),
                    ),
                  ),
                ],
                selected: {_filter},
                onSelectionChanged: (value) =>
                    setState(() => _filter = value.first),
              ),
            ),
            Expanded(
              child: _filter == _BookingFilter.upcoming && inquiryCount > 0
                  ? ListView(
                      padding: const EdgeInsets.all(
                        AppSpacing.screenHorizontal,
                      ),
                      children: [
                        Text(
                          l10n.today,
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
                                  AppColors.primary.withValues(alpha: 0.12),
                              child: const Icon(
                                Icons.chat_bubble_outline,
                                color: AppColors.primary,
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
                    )
                  : Center(
                      child: Padding(
                        padding: const EdgeInsets.all(32),
                        child: Column(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Icon(
                              Icons.event_busy_outlined,
                              size: 48,
                              color: Theme.of(context)
                                  .colorScheme
                                  .onSurfaceVariant,
                            ),
                            const SizedBox(height: 12),
                            Text(
                              _filter == _BookingFilter.upcoming
                                  ? l10n.noBookingsYet
                                  : l10n.noBookingsInCategory,
                              textAlign: TextAlign.center,
                            ),
                            const SizedBox(height: 16),
                            FilledButton(
                              onPressed: () => context.push('/seller/messages'),
                              child: Text(l10n.viewMessages),
                            ),
                          ],
                        ),
                      ),
                    ),
            ),
          ],
        );
      },
    );
  }
}
