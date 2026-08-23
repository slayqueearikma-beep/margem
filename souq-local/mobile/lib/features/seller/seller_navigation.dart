import 'package:flutter_riverpod/flutter_riverpod.dart';

/// Bottom navigation tab index for [SellerShell].
final sellerTabIndexProvider = StateProvider<int>((ref) => 0);

/// Catalog tab filter: services vs products.
enum SellerCatalogKind { services, products }

final sellerCatalogKindProvider =
    StateProvider<SellerCatalogKind>((ref) => SellerCatalogKind.services);

/// Availability filter for catalog lists.
enum SellerCatalogAvailability { all, active, inactive }

final sellerCatalogAvailabilityProvider =
    StateProvider<SellerCatalogAvailability>(
        (ref) => SellerCatalogAvailability.all);
