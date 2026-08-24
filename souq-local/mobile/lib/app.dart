import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import 'core/config/app_config.dart';
import 'core/models/models.dart';
import 'core/navigation/app_back_handler.dart';
import 'core/navigation/auth_route_guard.dart';
import 'core/services/app_storage.dart';
import 'core/services/auth_service.dart';
import 'core/services/legal_acceptance_service.dart';
import 'core/services/locale_provider.dart';
import 'core/services/theme_mode_provider.dart';
import 'core/theme/app_theme.dart';
import 'features/auth/forgot_password_screen.dart';
import 'features/auth/login_screen.dart';
import 'features/auth/verify_email_screen.dart';
import 'features/buyer/buyer_home_screen.dart';
import 'features/map/map_screen.dart';
import 'features/messages/messages_inbox_screen.dart';
import 'features/marketplace/marketplace_detail_screen.dart';
import 'features/marketplace_community/marketplace_community_channel_screen.dart';
import 'features/marketplace_community/marketplace_community_hub_screen.dart';
import 'features/onboarding/account_type_onboarding_screen.dart';
import 'features/onboarding/become_seller_screen.dart';
import 'features/onboarding/buyer_registration_screen.dart';
import 'features/onboarding/onboarding_welcome_screen.dart';
import 'features/onboarding/seller_registration_screen.dart';
import 'features/premium/premium_screen.dart';
import 'features/search/search_screen.dart';
import 'features/seller/product_detail_screen.dart';
import 'features/seller/seller_catalog_screen.dart';
import 'features/seller/seller_add_service_wizard.dart';
import 'features/seller/seller_add_video_screen.dart';
import 'features/seller/seller_video_record_screen.dart';
import 'features/seller/seller_boost_screen.dart';
import 'features/seller/seller_dashboard_screen.dart';
import 'features/seller/seller_detail_screen.dart';
import 'features/seller/seller_products_screen.dart';
import 'features/seller/seller_services_screen.dart';
import 'features/seller/seller_profile_screen.dart';
import 'features/seller/seller_reviews_screen.dart';
import 'features/seller/seller_settings_screen.dart';
import 'features/wishlist/wishlist_screen.dart';
import 'features/settings/language_selection_screen.dart';
import 'features/settings/billing_settings_screen.dart';
import 'features/legal/legal_acceptance_screen.dart';
import 'features/legal/account_settings_screen.dart';
import 'features/legal/legal_document_screen.dart';
import 'features/legal/privacy_legal_hub_screen.dart';
import 'features/legal/privacy_settings_screen.dart';
import 'features/legal/your_data_screen.dart';
import 'features/splash/splash_screen.dart';
import 'l10n/app_localizations.dart';

/// Notifies [GoRouter] when auth/session state changes so redirects re-run.
class _RouterRefreshListenable extends ChangeNotifier {
  _RouterRefreshListenable(Ref ref) {
    ref.listen(userSessionProvider, (_, __) => notifyListeners());
    ref.listen(authSessionProvider, (_, __) => notifyListeners());
    ref.listen(legalAcceptanceStatusProvider, (_, __) => notifyListeners());
  }
}

final routerProvider = Provider<GoRouter>((ref) {
  final refresh = _RouterRefreshListenable(ref);
  final router = GoRouter(
    navigatorKey: rootNavigatorKey,
    refreshListenable: refresh,
    initialLocation: '/splash',
    // Keep the page stack for Android system-back; only splash/auth flows
    // intentionally replace via context.go().
    redirect: (context, state) {
      final container = ProviderScope.containerOf(context);
      final session = container.read(userSessionProvider);
      final path = state.matchedLocation;
      final isAuthProtected = isAuthProtectedLocation(path);
      final isAuthenticated = session != null && !session.isGuest;
      if (isAuthProtected && !isAuthenticated) {
        return '/login';
      }
      final legalStatus = container.read(legalAcceptanceStatusProvider);
      final authUser = container.read(authSessionProvider)?.user;
      final storage = container.read(appStorageProvider);
      final needsLegalAcceptance = isAuthenticated &&
          (legalStatus != null
              ? !legalStatus.complete
              : authUser != null
                  ? !authUser.legalAcceptanceComplete
                  : !(storage?.getLegalAcceptanceComplete() ?? false));
      if (needsLegalAcceptance &&
          isLegalAcceptanceRequiredLocation(path) &&
          path != '/legal/accept') {
        return '/legal/accept';
      }
      if (path == '/legal/accept' &&
          isAuthenticated &&
          !needsLegalAcceptance) {
        final storage = container.read(appStorageProvider);
        if (storage != null) {
          return storage.homeRouteFor(session);
        }
      }
      final isSellerManagement = path == '/seller/dashboard' ||
          path.startsWith('/seller/products') ||
          path.startsWith('/seller/services') ||
          path.startsWith('/seller/analytics') ||
          path.startsWith('/seller/profile') ||
          path.startsWith('/seller/reviews') ||
          path.startsWith('/seller/notifications') ||
          path.startsWith('/seller/settings') ||
          path.startsWith('/seller/boost') ||
          path.startsWith('/seller/messages');
      if (isSellerManagement &&
          isAuthenticated &&
          !session.hasSellerProfile &&
          session.accountType != AccountType.seller) {
        return '/buyer/home';
      }
      return null;
    },
    routes: [
      GoRoute(path: '/splash', builder: (_, __) => const SplashScreen()),
      GoRoute(
        path: '/legal/accept',
        builder: (_, __) => const LegalAcceptanceScreen(),
      ),
      GoRoute(
        path: '/settings/language',
        builder: (_, __) => const LanguageSelectionScreen(fromSettings: true),
      ),
      GoRoute(path: '/settings', builder: (_, __) => const AccountSettingsScreen()),
      GoRoute(
        path: '/settings/privacy-legal',
        builder: (_, __) => const PrivacyLegalHubScreen(),
      ),
      GoRoute(
        path: '/settings/privacy',
        builder: (_, __) => const PrivacySettingsScreen(),
      ),
      GoRoute(
        path: '/settings/your-data',
        builder: (_, __) => const YourDataScreen(),
      ),
      GoRoute(
        path: '/settings/billing',
        builder: (_, __) => const BillingSettingsScreen(),
      ),
      GoRoute(
        path: '/legal/:doc',
        builder: (_, state) => LegalDocumentScreen(
          docSlug: state.pathParameters['doc']!,
        ),
      ),
      GoRoute(
          path: '/onboarding',
          builder: (_, __) => const OnboardingWelcomeScreen()),
      GoRoute(
          path: '/onboarding/account-type',
          builder: (_, __) => const AccountTypeOnboardingScreen()),
      GoRoute(
          path: '/onboarding/buyer-register',
          builder: (_, __) => const BuyerRegistrationScreen()),
      GoRoute(
          path: '/onboarding/seller-register',
          builder: (_, __) => const SellerRegistrationScreen()),
      GoRoute(
          path: '/onboarding/become-seller',
          builder: (_, __) => const BecomeSellerScreen()),
      GoRoute(path: '/login', builder: (_, __) => const LoginScreen()),
      GoRoute(
          path: '/forgot-password',
          builder: (_, __) => const ForgotPasswordScreen()),
      GoRoute(
        path: '/reset-password',
        builder: (_, state) => ForgotPasswordScreen(
          resetMode: true,
          initialToken: state.uri.queryParameters['token'] ?? '',
        ),
      ),
      GoRoute(
        path: '/verify-email',
        builder: (_, state) => VerifyEmailScreen(
          initialToken: state.uri.queryParameters['token'] ?? '',
        ),
      ),
      GoRoute(path: '/buyer/home', builder: (_, __) => const BuyerHomeShell()),
      GoRoute(path: '/search', builder: (_, __) => const SearchScreen()),
      GoRoute(path: '/bundle', redirect: (_, __) => '/buyer/home'),
      GoRoute(
        path: '/marketplace/:slug',
        builder: (_, state) => MarketplaceDetailScreen(
          slug: state.pathParameters['slug']!,
        ),
      ),
      GoRoute(
        path: '/marketplace/:slug/community',
        builder: (_, state) => MarketplaceCommunityHubScreen(
          marketplaceSlug: state.pathParameters['slug']!,
        ),
      ),
      GoRoute(
        path: '/marketplace/:slug/community/channels/:channelId',
        builder: (_, state) {
          final extra = state.extra;
          final map = extra is Map ? extra : const {};
          return MarketplaceCommunityChannelScreen(
            channelId: state.pathParameters['channelId']!,
            marketplaceSlug: state.pathParameters['slug']!,
            channelName: map['channelName'] as String? ?? '',
            defaultPostType: map['defaultPostType'] as String? ?? 'general',
          );
        },
      ),
      GoRoute(path: '/map', builder: (_, __) => const MapScreen()),
      GoRoute(path: '/community/channels/:channelId', redirect: (_, __) => '/buyer/home'),
      GoRoute(path: '/community', redirect: (_, __) => '/buyer/home'),
      GoRoute(path: '/community/:citySlug', redirect: (_, __) => '/buyer/home'),
      GoRoute(path: '/favorites', builder: (_, __) => const FavoritesScreen()),
      GoRoute(
        path: '/premium',
        builder: (_, state) => PremiumScreen(
          checkoutNotice: state.uri.queryParameters['checkout'],
        ),
      ),
      GoRoute(
        path: '/premium/success',
        redirect: (_, __) => '/premium?checkout=success',
      ),
      GoRoute(
        path: '/premium/cancel',
        redirect: (_, __) => '/premium?checkout=cancelled',
      ),
      GoRoute(path: '/profile', builder: (_, __) => const BuyerProfileScreen()),
      GoRoute(
          path: '/messages',
          builder: (_, __) => const Scaffold(body: MessagesInboxScreen())),
      GoRoute(
        path: '/messages/:id',
        builder: (_, state) {
          final extra = state.extra;
          return ConversationThreadScreen(
            conversationId: state.pathParameters['id']!,
            conversation: extra is ConversationModel ? extra : null,
          );
        },
      ),
      GoRoute(
          path: '/seller/dashboard',
          builder: (_, __) => const SellerDashboardScreen()),
      GoRoute(
          path: '/seller/messages',
          builder: (_, __) => const SellerMessagesRedirect()),
      GoRoute(
          path: '/seller/products',
          builder: (_, __) => const SellerProductsRedirect()),
      GoRoute(
          path: '/seller/products/new',
          builder: (_, __) => const SellerProductEditorScreen()),
      GoRoute(
          path: '/seller/products/:productId',
          builder: (_, state) => SellerProductEditorScreen(
              productId: state.pathParameters['productId'])),
      GoRoute(
          path: '/seller/services',
          builder: (_, __) => const SellerServicesRedirect()),
      GoRoute(
          path: '/seller/services/new',
          builder: (_, __) => const SellerAddServiceWizard()),
      GoRoute(
        path: '/seller/services/:serviceId',
        builder: (_, state) => SellerServiceEditorScreen(
            serviceId: state.pathParameters['serviceId']),
      ),
      GoRoute(
        path: '/seller/videos/new',
        builder: (_, __) => const SellerAddVideoScreen(),
      ),
      GoRoute(
        path: '/seller/videos/record',
        builder: (_, __) => const SellerVideoRecordScreen(),
      ),
      GoRoute(
          path: '/seller/analytics',
          redirect: (_, __) => '/seller/dashboard'),
      GoRoute(
          path: '/seller/profile',
          builder: (_, __) => const SellerProfileScreen()),
      GoRoute(
          path: '/seller/reviews',
          builder: (_, __) => const SellerReviewsScreen()),
      GoRoute(
          path: '/seller/notifications',
          builder: (_, __) => const SellerNotificationsScreen()),
      GoRoute(
          path: '/seller/settings',
          builder: (_, __) => const SellerSettingsScreen()),
      GoRoute(
        path: '/seller/boost',
        builder: (_, state) => SellerBoostScreen(
          checkoutNotice: state.uri.queryParameters['checkout'],
        ),
      ),
      GoRoute(
        path: '/seller/:id',
        builder: (_, state) =>
            SellerDetailScreen(sellerId: state.pathParameters['id']!),
        routes: [
          GoRoute(
            path: 'products',
            builder: (_, state) {
              final extra = state.extra;
              return SellerCatalogScreen(
                sellerId: state.pathParameters['id']!,
                initialSeller: extra is SellerModel ? extra : null,
              );
            },
          ),
        ],
      ),
      GoRoute(
        path: '/product/:sellerId/:productId',
        builder: (_, state) => ProductDetailScreen(
          sellerId: state.pathParameters['sellerId']!,
          productId: state.pathParameters['productId']!,
        ),
      ),
    ],
  );
  ref.onDispose(router.dispose);
  return router;
});

class MarGemApp extends ConsumerStatefulWidget {
  const MarGemApp({super.key});

  @override
  ConsumerState<MarGemApp> createState() => _MarGemAppState();
}

class _MarGemAppState extends ConsumerState<MarGemApp>
    with WidgetsBindingObserver {
  var _sessionBound = false;

  @override
  void initState() {
    super.initState();
    // Intercept Android system back before go_router exits the activity when
    // canPop is false on a root route (and still pop the stack when it can).
    WidgetsBinding.instance.addObserver(this);
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  @override
  Future<bool> didPopRoute() async {
    final navContext = rootNavigatorKey.currentContext;
    if (navContext == null) {
      // No navigator yet (startup) — let the framework decide.
      return false;
    }
    return handleAppBack(context: navContext, ref: ref);
  }

  @override
  Widget build(BuildContext context) {
    final themeMode = ref.watch(themeModeProvider);
    final router = ref.watch(routerProvider);
    final locale = ref.watch(localeProvider);

    ref.listen(appStorageProvider, (previous, next) {
      if (next != null) {
        ref.read(localeProvider.notifier).updateStorage(next);
        ref.read(themeModeProvider.notifier).updateStorage(next);
      }
    });

    // Bind once at the app root so the callback outlives SplashScreen disposal.
    if (!_sessionBound) {
      _sessionBound = true;
      ref.read(authServiceProvider).bindApi(
        onSessionExpired: () async {
          final prefs = await ref.read(sharedPreferencesProvider.future);
          await ref.read(authServiceProvider).logout(prefs);
          await ref.read(appStorageProvider)?.logout();
          ref.read(userSessionProvider.notifier).state = null;
          ref.read(authSessionProvider.notifier).state = null;
          router.go('/login');
        },
      );
    }

    return MaterialApp.router(
      title: AppConfig.appName,
      debugShowCheckedModeBanner: false,
      themeMode: themeMode,
      theme: AppTheme.light(languageCode: locale.languageCode),
      darkTheme: AppTheme.dark(languageCode: locale.languageCode),
      locale: locale,
      supportedLocales: AppLocalizations.supportedLocales,
      localeResolutionCallback: (deviceLocale, supportedLocales) {
        for (final supported in supportedLocales) {
          if (supported.languageCode == locale.languageCode) {
            return supported;
          }
        }
        return const Locale(AppStorage.defaultLanguageCode);
      },
      localizationsDelegates: const [
        AppLocalizations.delegate,
        GlobalMaterialLocalizations.delegate,
        GlobalWidgetsLocalizations.delegate,
        GlobalCupertinoLocalizations.delegate,
      ],
      routerConfig: router,
    );
  }
}
