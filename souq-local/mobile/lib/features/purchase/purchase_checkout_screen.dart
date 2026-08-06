import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../core/models/models.dart';
import '../../core/services/api_service.dart';
import '../../core/services/app_storage.dart';
import '../../core/theme/app_spacing.dart';
import '../../core/widgets/error_dialog.dart';

class PurchaseCheckoutScreen extends ConsumerStatefulWidget {
  const PurchaseCheckoutScreen({
    super.key,
    required this.sellerId,
    required this.product,
  });

  final String sellerId;
  final ProductModel product;

  @override
  ConsumerState<PurchaseCheckoutScreen> createState() => _PurchaseCheckoutScreenState();
}

class _PurchaseCheckoutScreenState extends ConsumerState<PurchaseCheckoutScreen> {
  var _quantity = 1;
  var _deliveryMethod = 'pickup';
  var _loading = false;
  var _previewLoading = true;
  double _subtotal = 0;
  double _deliveryFee = 0;
  double _tax = 0;
  double _total = 0;

  final _nameController = TextEditingController();
  final _phoneController = TextEditingController();
  final _addressController = TextEditingController();

  @override
  void initState() {
    super.initState();
    final session = ref.read(userSessionProvider);
    _nameController.text = session?.name ?? '';
    if (widget.product.isPickupOnly) {
      _deliveryMethod = 'pickup';
    }
    _refreshPreview();
  }

  @override
  void dispose() {
    _nameController.dispose();
    _phoneController.dispose();
    _addressController.dispose();
    super.dispose();
  }

  Future<void> _refreshPreview() async {
    setState(() => _previewLoading = true);
    try {
      final preview = await apiServiceProvider.previewCheckout(
        productId: widget.product.id,
        quantity: _quantity,
        deliveryMethod: _deliveryMethod,
        buyerName: _nameController.text.trim(),
        buyerPhone: _phoneController.text.trim(),
        buyerAddress: _addressController.text.trim(),
      );
      if (!mounted) return;
      setState(() {
        _subtotal = preview.subtotalMad;
        _deliveryFee = preview.deliveryFeeMad;
        _tax = preview.taxMad;
        _total = preview.totalMad;
        _previewLoading = false;
      });
    } on ApiException catch (e) {
      if (!mounted) return;
      setState(() => _previewLoading = false);
      await showAppErrorDialog(context, title: 'Checkout', message: e.message);
    }
  }

  Future<void> _pay() async {
    setState(() => _loading = true);
    try {
      final session = await apiServiceProvider.createCheckoutSession(
        productId: widget.product.id,
        quantity: _quantity,
        deliveryMethod: _deliveryMethod,
        successUrl: 'margem://purchase/success',
        cancelUrl: 'margem://purchase/cancel',
        buyerName: _nameController.text.trim(),
        buyerPhone: _phoneController.text.trim(),
        buyerAddress: _addressController.text.trim(),
      );
      final uri = Uri.parse(session.checkoutUrl);
      if (!await launchUrl(uri, mode: LaunchMode.externalApplication)) {
        throw ApiException('Could not open Stripe checkout');
      }
      if (!mounted) return;
      context.pop();
    } on ApiException catch (e) {
      if (!mounted) return;
      await showAppErrorDialog(context, title: 'Payment', message: e.message);
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final product = widget.product;

    return Scaffold(
      appBar: AppBar(title: const Text('Review order')),
      body: ListView(
        padding: const EdgeInsets.all(AppSpacing.screenHorizontal),
        children: [
          Text(product.name, style: Theme.of(context).textTheme.titleLarge),
          const SizedBox(height: AppSpacing.sm),
          Row(
            children: [
              const Text('Quantity'),
              const Spacer(),
              IconButton(
                onPressed: _quantity > 1
                    ? () {
                        setState(() => _quantity--);
                        _refreshPreview();
                      }
                    : null,
                icon: const Icon(Icons.remove_circle_outline),
              ),
              Text('$_quantity'),
              IconButton(
                onPressed: _quantity < product.stockQuantity
                    ? () {
                        setState(() => _quantity++);
                        _refreshPreview();
                      }
                    : null,
                icon: const Icon(Icons.add_circle_outline),
              ),
            ],
          ),
          if (!product.isPickupOnly) ...[
            const SizedBox(height: AppSpacing.md),
            const Text('Delivery', style: TextStyle(fontWeight: FontWeight.w600)),
            RadioListTile<String>(
              title: const Text('Pickup'),
              value: 'pickup',
              groupValue: _deliveryMethod,
              onChanged: (value) {
                setState(() => _deliveryMethod = value!);
                _refreshPreview();
              },
            ),
            RadioListTile<String>(
              title: const Text('Delivery'),
              subtitle: product.deliveryEta.isNotEmpty ? Text(product.deliveryEta) : null,
              value: 'delivery',
              groupValue: _deliveryMethod,
              onChanged: (value) {
                setState(() => _deliveryMethod = value!);
                _refreshPreview();
              },
            ),
            if (_deliveryMethod == 'delivery') ...[
              TextField(
                controller: _nameController,
                decoration: const InputDecoration(labelText: 'Full name'),
                onChanged: (_) => _refreshPreview(),
              ),
              TextField(
                controller: _phoneController,
                decoration: const InputDecoration(labelText: 'Phone'),
                keyboardType: TextInputType.phone,
                onChanged: (_) => _refreshPreview(),
              ),
              TextField(
                controller: _addressController,
                decoration: const InputDecoration(labelText: 'Delivery address'),
                minLines: 2,
                maxLines: 3,
                onChanged: (_) => _refreshPreview(),
              ),
            ],
          ]           else
            const Chip(label: Text('Pickup only')),
          const SizedBox(height: AppSpacing.lg),
          if (_previewLoading)
            const Center(child: CircularProgressIndicator())
          else ...[
            _line('Subtotal', _subtotal),
            _line('Delivery fee', _deliveryFee),
            if (product.taxEnabled) _line('Tax', _tax),
            const Divider(),
            _line('Total', _total, bold: true),
          ],
          const SizedBox(height: AppSpacing.lg),
          FilledButton(
            onPressed: _loading || _previewLoading ? null : _pay,
            child: _loading
                ? const SizedBox(
                    height: 20,
                    width: 20,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  )
                : const Text('Pay with Stripe'),
          ),
        ],
      ),
    );
  }

  Widget _line(String label, double amount, {bool bold = false}) {
    final style = TextStyle(fontWeight: bold ? FontWeight.w700 : FontWeight.w400);
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        children: [
          Text(label, style: style),
          const Spacer(),
          Text('${amount.toStringAsFixed(2)} MAD', style: style),
        ],
      ),
    );
  }
}
