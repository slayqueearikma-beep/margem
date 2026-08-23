import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/models/purchase_models.dart';
import '../../core/services/api_service.dart';
import '../../core/theme/app_spacing.dart';
import '../../core/widgets/async_error_view.dart';
import '../../l10n/app_localizations.dart';

final sellerPurchaseOrdersProvider =
    FutureProvider.autoDispose<List<PurchaseOrderModel>>((ref) {
  return apiServiceProvider.fetchSellerPurchaseOrders();
});

class SellerOrdersScreen extends ConsumerWidget {
  const SellerOrdersScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = context.l10n;
    final ordersAsync = ref.watch(sellerPurchaseOrdersProvider);

    return Scaffold(
      appBar: AppBar(title: const Text('Orders')),
      body: ordersAsync.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (error, _) => AsyncErrorView.fromError(
          error,
          onRetry: () => ref.invalidate(sellerPurchaseOrdersProvider),
        ),
        data: (orders) {
          if (orders.isEmpty) {
            return Center(
              child: Padding(
                padding: const EdgeInsets.all(AppSpacing.screenHorizontal),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(l10n.noSellerOrders, textAlign: TextAlign.center),
                    const SizedBox(height: 8),
                    Text(
                      l10n.noSellerOrdersSubtitle,
                      textAlign: TextAlign.center,
                      style: Theme.of(context).textTheme.bodySmall,
                    ),
                  ],
                ),
              ),
            );
          }
          return ListView.separated(
            padding: const EdgeInsets.all(AppSpacing.screenHorizontal),
            itemCount: orders.length,
            separatorBuilder: (_, __) => const SizedBox(height: AppSpacing.sm),
            itemBuilder: (context, index) {
              final order = orders[index];
              return Card(
                child: Padding(
                  padding: const EdgeInsets.all(AppSpacing.md),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(order.productName, style: const TextStyle(fontWeight: FontWeight.w700)),
                      const SizedBox(height: 4),
                      Text('${order.orderNumber} • ${order.isPickup ? 'Pickup' : 'Delivery'}'),
                      Text('Buyer: ${order.buyerName.isNotEmpty ? order.buyerName : order.buyerEmail ?? '—'}'),
                      Text('Phone: ${order.buyerPhone.isNotEmpty ? order.buyerPhone : '—'}'),
                      Text('Payment: ${order.paymentStatus} • ${order.totalMad.toStringAsFixed(2)} MAD'),
                      const SizedBox(height: AppSpacing.sm),
                      Wrap(
                        spacing: 8,
                        children: [
                          for (final status in const [
                            'preparing',
                            'ready',
                            'delivered',
                            'completed',
                            'cancelled',
                          ])
                            ActionChip(
                              label: Text(status),
                              backgroundColor: order.orderStatus == status
                                  ? Theme.of(context).colorScheme.primaryContainer
                                  : null,
                              onPressed: () async {
                                try {
                                  await apiServiceProvider.updateSellerOrderStatus(
                                    order.id,
                                    status,
                                  );
                                  ref.invalidate(sellerPurchaseOrdersProvider);
                                } catch (_) {}
                              },
                            ),
                        ],
                      ),
                    ],
                  ),
                ),
              );
            },
          );
        },
      ),
    );
  }
}
