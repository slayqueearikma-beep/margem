/// Routes that require a signed-in (non-guest) session.
bool isAuthProtectedLocation(String path) {
  final isSellerManagement = path == '/seller/dashboard' ||
      path.startsWith('/seller/products') ||
      path.startsWith('/seller/services') ||
      path.startsWith('/seller/analytics') ||
      path.startsWith('/seller/profile') ||
      path.startsWith('/seller/reviews') ||
      path.startsWith('/seller/notifications') ||
      path.startsWith('/seller/settings') ||
      path.startsWith('/seller/messages');
  final isMarketplaceCommunity =
      RegExp(r'^/marketplace/[^/]+/community').hasMatch(path);
  return isSellerManagement ||
      path == '/premium' ||
      path.startsWith('/messages') ||
      path.startsWith('/community/channels') ||
      isMarketplaceCommunity;
}
