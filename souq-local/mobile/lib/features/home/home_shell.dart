import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../app.dart';
import '../../core/config/app_config.dart';
import '../../core/models/models.dart';
import '../../core/services/api_service.dart';
import '../../core/theme/app_theme.dart';
import '../map/map_screen.dart';
import '../search/search_screen.dart';

final selectedCityProvider = StateProvider<String>((ref) => AppConfig.moroccanCities.first);

final sellersProvider = FutureProvider.autoDispose<List<SellerModel>>((ref) async {
  final city = ref.watch(selectedCityProvider);
  return apiServiceProvider.fetchSellers(city: city);
});

class HomeShell extends StatefulWidget {
  const HomeShell({super.key});

  @override
  State<HomeShell> createState() => _HomeShellState();
}

class _HomeShellState extends State<HomeShell> {
  int _index = 0;

  @override
  Widget build(BuildContext context) {
    final pages = [
      const DiscoverTab(),
      const SearchScreen(),
      const MapScreen(),
      const _ProfileTab(),
    ];

    return Scaffold(
      body: IndexedStack(index: _index, children: pages),
      bottomNavigationBar: NavigationBar(
        selectedIndex: _index,
        onDestinationSelected: (value) => setState(() => _index = value),
        destinations: const [
          NavigationDestination(icon: Icon(Icons.home_outlined), selectedIcon: Icon(Icons.home), label: 'Home'),
          NavigationDestination(icon: Icon(Icons.search), label: 'Search'),
          NavigationDestination(icon: Icon(Icons.map_outlined), selectedIcon: Icon(Icons.map), label: 'Map'),
          NavigationDestination(icon: Icon(Icons.person_outline), selectedIcon: Icon(Icons.person), label: 'Profile'),
        ],
      ),
    );
  }
}

class DiscoverTab extends ConsumerWidget {
  const DiscoverTab({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final city = ref.watch(selectedCityProvider);
    final sellersAsync = ref.watch(sellersProvider);
    final categoriesAsync = ref.watch(categoriesProvider);

    return SafeArea(
      child: CustomScrollView(
        slivers: [
          SliverToBoxAdapter(
            child: Padding(
              padding: const EdgeInsets.fromLTRB(20, 16, 20, 8),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text('Good morning', style: Theme.of(context).textTheme.bodyMedium?.copyWith(color: AppColors.textMuted)),
                          Text('Discover $city', style: Theme.of(context).textTheme.headlineSmall?.copyWith(fontWeight: FontWeight.w700)),
                        ],
                      ),
                      IconButton(onPressed: () {}, icon: const Icon(Icons.notifications_none_rounded)),
                    ],
                  ),
                  const SizedBox(height: 16),
                  TextField(
                    readOnly: true,
                    onTap: () {},
                    decoration: const InputDecoration(
                      hintText: 'Search shops, products, services…',
                      prefixIcon: Icon(Icons.search),
                    ),
                  ),
                  const SizedBox(height: 20),
                  Text('Categories', style: Theme.of(context).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w700)),
                  const SizedBox(height: 12),
                ],
              ),
            ),
          ),
          categoriesAsync.when(
            data: (categories) => SliverToBoxAdapter(
              child: SizedBox(
                height: 44,
                child: ListView.separated(
                  padding: const EdgeInsets.symmetric(horizontal: 20),
                  scrollDirection: Axis.horizontal,
                  itemCount: categories.length,
                  separatorBuilder: (_, __) => const SizedBox(width: 8),
                  itemBuilder: (_, index) {
                    final cat = categories[index];
                    return FilterChip(
                      label: Text(cat.nameEn),
                      onSelected: (_) {},
                    );
                  },
                ),
              ),
            ),
            loading: () => const SliverToBoxAdapter(child: LinearProgressIndicator()),
            error: (_, __) => const SliverToBoxAdapter(child: SizedBox.shrink()),
          ),
          SliverToBoxAdapter(
            child: Padding(
              padding: const EdgeInsets.fromLTRB(20, 24, 20, 12),
              child: Text('Near you', style: Theme.of(context).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w700)),
            ),
          ),
          sellersAsync.when(
            data: (sellers) => SliverPadding(
              padding: const EdgeInsets.symmetric(horizontal: 20),
              sliver: SliverList.separated(
                itemCount: sellers.length,
                separatorBuilder: (_, __) => const SizedBox(height: 12),
                itemBuilder: (_, index) => _SellerCard(seller: sellers[index]),
              ),
            ),
            loading: () => const SliverFillRemaining(child: Center(child: CircularProgressIndicator())),
            error: (e, _) => SliverFillRemaining(
              child: Center(child: Text('Could not load businesses\n$e', textAlign: TextAlign.center)),
            ),
          ),
          const SliverToBoxAdapter(child: SizedBox(height: 24)),
        ],
      ),
    );
  }
}

final categoriesProvider = FutureProvider.autoDispose<List<CategoryModel>>((ref) {
  return apiServiceProvider.fetchCategories();
});

class _SellerCard extends StatelessWidget {
  const _SellerCard({required this.seller});

  final SellerModel seller;

  @override
  Widget build(BuildContext context) {
    return Card(
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: () => context.push('/seller/${seller.id}'),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Container(
              height: 140,
              width: double.infinity,
              color: Theme.of(context).colorScheme.primaryContainer.withValues(alpha: 0.35),
              child: seller.coverImageUrl.isEmpty
                  ? const Icon(Icons.storefront, size: 48)
                  : null,
            ),
            Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Expanded(
                        child: Text(seller.businessName, style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 18)),
                      ),
                      if (seller.achievementStars > 0)
                        Row(
                          children: List.generate(
                            seller.achievementStars.clamp(0, 3),
                            (_) => const Icon(Icons.star, color: AppColors.orange, size: 16),
                          ),
                        ),
                    ],
                  ),
                  const SizedBox(height: 4),
                  Text(
                    seller.description,
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(color: AppColors.textMuted),
                  ),
                  const SizedBox(height: 8),
                  Row(
                    children: [
                      const Icon(Icons.star_rounded, size: 16, color: AppColors.orange),
                      const SizedBox(width: 4),
                      Text('${seller.averageRating} (${seller.reviewCount} reviews)'),
                      const Spacer(),
                      Text(seller.city, style: TextStyle(color: AppColors.textMuted)),
                    ],
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _ProfileTab extends ConsumerWidget {
  const _ProfileTab();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return SafeArea(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          children: [
            const CircleAvatar(radius: 40, child: Icon(Icons.person, size: 40)),
            const SizedBox(height: 12),
            Text('Your profile', style: Theme.of(context).textTheme.titleLarge),
            const SizedBox(height: 24),
            SwitchListTile(
              title: const Text('Dark mode'),
              value: Theme.of(context).brightness == Brightness.dark,
              onChanged: (_) {
                final current = ref.read(themeModeProvider);
                ref.read(themeModeProvider.notifier).state =
                    current == ThemeMode.dark ? ThemeMode.light : ThemeMode.dark;
              },
            ),
          ],
        ),
      ),
    );
  }
}
