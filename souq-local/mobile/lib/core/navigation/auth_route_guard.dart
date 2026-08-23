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

/// Routes reachable before mandatory legal policy acceptance.
bool isLegalAcceptanceExemptLocation(String path) {
  if (path == '/legal/accept') return true;
  if (path.startsWith('/legal/')) return true;
  if (path.startsWith('/settings/privacy-legal')) return true;
  if (path == '/splash' ||
      path == '/login' ||
      path.startsWith('/onboarding') ||
      path == '/verify-email' ||
      path == '/forgot-password') {
    return true;
  }
  return false;
}

/// Main application routes that require current legal policy acceptance.
bool isLegalAcceptanceRequiredLocation(String path) {
  if (isLegalAcceptanceExemptLocation(path)) return false;
  if (path == '/buyer/home' ||
      path.startsWith('/seller/') ||
      path == '/profile' ||
      path == '/favorites' ||
      path == '/search' ||
      path == '/map' ||
      path == '/bundle' ||
      path == '/community' ||
      path == '/premium' ||
      path.startsWith('/messages') ||
      path.startsWith('/marketplace/') ||
      path.startsWith('/settings')) {
    return true;
  }
  return false;
}
