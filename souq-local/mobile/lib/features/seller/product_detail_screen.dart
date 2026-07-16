import 'package:flutter/material.dart';
import 'package:flutter_rating_bar/flutter_rating_bar.dart';

import '../../core/models/models.dart';
import '../../core/services/api_service.dart';
import '../../core/theme/app_theme.dart';

class ProductDetailScreen extends StatelessWidget {
  const ProductDetailScreen({
    super.key,
    required this.sellerId,
    required this.productId,
  });

  final String sellerId;
  final String productId;

  @override
  Widget build(BuildContext context) {
    return FutureBuilder<SellerModel>(
      future: apiServiceProvider.fetchSeller(sellerId),
      builder: (context, snapshot) {
        if (!snapshot.hasData) {
          return const Scaffold(body: Center(child: CircularProgressIndicator()));
        }

        final seller = snapshot.data!;
        final product = seller.products.firstWhere(
          (p) => p.id == productId,
          orElse: () => seller.products.isNotEmpty ? seller.products.first : const ProductModel(id: '', name: 'Product', description: ''),
        );

        return Scaffold(
          appBar: AppBar(title: Text(product.name)),
          body: ListView(
            padding: const EdgeInsets.all(20),
            children: [
              AspectRatio(
                aspectRatio: 1,
                child: Card(
                  clipBehavior: Clip.antiAlias,
                  child: Container(
                    color: Theme.of(context).colorScheme.primaryContainer.withValues(alpha: 0.35),
                    child: product.imageUrl.isEmpty ? const Icon(Icons.image_outlined, size: 72) : null,
                  ),
                ),
              ),
              const SizedBox(height: 20),
              if (product.priceMad != null)
                Text(
                  '${product.priceMad!.toStringAsFixed(2)} MAD',
                  style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                        color: AppColors.orange,
                        fontWeight: FontWeight.w700,
                      ),
                ),
              const SizedBox(height: 8),
              Row(
                children: [
                  RatingBarIndicator(
                    rating: seller.averageRating,
                    itemBuilder: (_, __) => const Icon(Icons.star, color: AppColors.orange),
                    itemCount: 5,
                    itemSize: 18,
                  ),
                  const SizedBox(width: 8),
                  Text('${seller.averageRating} · ${seller.businessName}'),
                ],
              ),
              const SizedBox(height: 16),
              Text(product.description.isEmpty ? 'No description provided.' : product.description),
            ],
          ),
        );
      },
    );
  }
}
