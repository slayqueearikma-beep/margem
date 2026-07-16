import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../core/services/app_storage.dart';
import '../../core/theme/app_colors.dart';
import '../../core/theme/app_spacing.dart';
import '../../core/widgets/app_logo_placeholder.dart';
import '../../core/widgets/content_widgets.dart';

class SellerDashboardScreen extends ConsumerWidget {
  const SellerDashboardScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final session = ref.watch(userSessionProvider);
    final businessName = session?.businessName ?? 'Your Business';

    return Scaffold(
      body: SafeArea(
        child: CustomScrollView(
          slivers: [
            SliverToBoxAdapter(
              child: Padding(
                padding: const EdgeInsets.fromLTRB(AppSpacing.screenHorizontal, AppSpacing.md, AppSpacing.screenHorizontal, 0),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        const AppLogoPlaceholder(size: 32),
                        const SizedBox(width: AppSpacing.sm),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text('Seller Dashboard', style: Theme.of(context).textTheme.bodySmall?.copyWith(color: AppColors.textSecondary)),
                              Text(businessName, style: Theme.of(context).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w700)),
                            ],
                          ),
                        ),
                        IconButton(onPressed: () {}, icon: const Icon(Icons.notifications_none_rounded)),
                      ],
                    ),
                    const SizedBox(height: AppSpacing.lg),
                    Container(
                      width: double.infinity,
                      padding: const EdgeInsets.all(AppSpacing.lg),
                      decoration: BoxDecoration(
                        gradient: const LinearGradient(
                          colors: [AppColors.primary, AppColors.primaryLight],
                          begin: Alignment.topLeft,
                          end: Alignment.bottomRight,
                        ),
                        borderRadius: BorderRadius.circular(AppSpacing.cardRadius),
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text('Welcome, ${session?.name.split(' ').first ?? 'Seller'} 👋', style: const TextStyle(color: Colors.white, fontSize: 18, fontWeight: FontWeight.w700)),
                          const SizedBox(height: 4),
                          Text(
                            'Manage your store, products, and customer reviews.',
                            style: TextStyle(color: Colors.white.withValues(alpha: 0.85)),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            ),
            SliverPadding(
              padding: const EdgeInsets.all(AppSpacing.screenHorizontal),
              sliver: SliverGrid(
                gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                  crossAxisCount: 2,
                  crossAxisSpacing: 12,
                  mainAxisSpacing: 12,
                  childAspectRatio: 1.3,
                ),
                delegate: SliverChildListDelegate([
                  const StatCard(label: 'Profile views', value: '1.2k', icon: Icons.visibility_outlined, trend: '+12% this week'),
                  const StatCard(label: 'Products', value: '8', icon: Icons.inventory_2_outlined),
                  const StatCard(label: 'Reviews', value: '47', icon: Icons.star_outline_rounded, trend: '4.8 avg'),
                  const StatCard(label: 'Inquiries', value: '23', icon: Icons.chat_bubble_outline),
                ]),
              ),
            ),
            SliverToBoxAdapter(
              child: Padding(
                padding: const EdgeInsets.fromLTRB(AppSpacing.screenHorizontal, AppSpacing.lg, AppSpacing.screenHorizontal, 0),
                child: Text('Manage', style: Theme.of(context).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w700)),
              ),
            ),
            SliverPadding(
              padding: const EdgeInsets.all(AppSpacing.screenHorizontal),
              sliver: SliverList(
                delegate: SliverChildListDelegate([
                  DashboardMenuTile(
                    title: 'Product management',
                    subtitle: 'Add, edit, or remove products and services',
                    icon: Icons.storefront_outlined,
                    onTap: () {},
                  ),
                  DashboardMenuTile(
                    title: 'Reviews',
                    subtitle: 'View and respond to customer reviews',
                    icon: Icons.rate_review_outlined,
                    badge: '3',
                    onTap: () {},
                  ),
                  DashboardMenuTile(
                    title: 'Profile management',
                    subtitle: 'Update business info, hours, and photos',
                    icon: Icons.business_outlined,
                    onTap: () {},
                  ),
                  const DashboardMenuTile(
                    title: 'Orders',
                    subtitle: 'Track and manage customer orders',
                    icon: Icons.receipt_long_outlined,
                    comingSoon: true,
                  ),
                  const DashboardMenuTile(
                    title: 'Messages',
                    subtitle: 'Chat with buyers directly',
                    icon: Icons.message_outlined,
                    comingSoon: true,
                  ),
                  const SizedBox(height: AppSpacing.lg),
                  OutlinedButton(
                    onPressed: () async {
                      await ref.read(appStorageProvider)?.logout();
                      ref.read(userSessionProvider.notifier).state = null;
                      if (context.mounted) context.go('/login');
                    },
                    child: const Text('Log out'),
                  ),
                  const SizedBox(height: AppSpacing.xxl),
                ]),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
