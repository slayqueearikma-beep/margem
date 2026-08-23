import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../core/models/purchase_models.dart';
import '../../core/services/api_service.dart';
import '../../core/theme/app_spacing.dart';
import '../../core/widgets/async_error_view.dart';

final myPurchasesProvider = FutureProvider.autoDispose<List<PurchaseOrderModel>>((ref) {
  return apiServiceProvider.fetchMyPurchases();
});

class MyPurchasesScreen extends ConsumerWidget {
  const MyPurchasesScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final ordersAsync = ref.watch(myPurchasesProvider);
    return Scaffold(
      appBar: AppBar(title: const Text('My purchases')),
      body: ordersAsync.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (error, _) => AsyncErrorView.fromError(
          error,
          onRetry: () => ref.invalidate(myPurchasesProvider),
        ),
        data: (orders) {
          if (orders.isEmpty) {
            return const Center(child: Text('No purchases yet'));
          }
          return ListView.separated(
            padding: const EdgeInsets.all(AppSpacing.screenHorizontal),
            itemCount: orders.length,
            separatorBuilder: (_, __) => const SizedBox(height: AppSpacing.sm),
            itemBuilder: (context, index) {
              final order = orders[index];
              return Card(
                child: ListTile(
                  title: Text(order.productName),
                  subtitle: Text(
                    '${order.orderNumber}\n${order.orderStatus} • ${order.totalMad.toStringAsFixed(2)} MAD',
                  ),
                  isThreeLine: true,
                  trailing: const Icon(Icons.chevron_right_rounded),
                  onTap: () => context.push('/purchases/${order.id}'),
                ),
              );
            },
          );
        },
      ),
    );
  }
}

class PurchaseReceiptScreen extends ConsumerStatefulWidget {
  const PurchaseReceiptScreen({super.key, required this.orderId});

  final String orderId;

  @override
  ConsumerState<PurchaseReceiptScreen> createState() => _PurchaseReceiptScreenState();
}

class _PurchaseReceiptScreenState extends ConsumerState<PurchaseReceiptScreen> {
  late Future<PurchaseReceiptModel> _future;

  @override
  void initState() {
    super.initState();
    _future = apiServiceProvider.fetchPurchaseReceipt(widget.orderId);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Receipt')),
      body: FutureBuilder<PurchaseReceiptModel>(
        future: _future,
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          }
          if (snapshot.hasError || !snapshot.hasData) {
            return AsyncErrorView.fromError(
              snapshot.error ?? Exception('Receipt unavailable'),
              onRetry: () => setState(() {
                _future = apiServiceProvider.fetchPurchaseReceipt(widget.orderId);
              }),
            );
          }
          final receipt = snapshot.data!;
          return ListView(
            padding: const EdgeInsets.all(AppSpacing.screenHorizontal),
            children: [
              SelectableText(
                receipt.receiptText,
                style: const TextStyle(fontFamily: 'monospace', height: 1.4),
              ),
              const SizedBox(height: AppSpacing.lg),
              FilledButton.icon(
                onPressed: () async {
                  await Clipboard.setData(ClipboardData(text: receipt.receiptText));
                  if (context.mounted) {
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(content: Text('Receipt copied')),
                    );
                  }
                },
                icon: const Icon(Icons.copy_rounded),
                label: const Text('Copy receipt'),
              ),
            ],
          );
        },
      ),
    );
  }
}
