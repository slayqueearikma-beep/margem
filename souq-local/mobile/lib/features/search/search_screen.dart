import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../core/models/models.dart';
import '../../core/services/api_service.dart';
import '../../core/theme/app_theme.dart';
import '../home/home_shell.dart';

class SearchScreen extends ConsumerStatefulWidget {
  const SearchScreen({super.key});

  @override
  ConsumerState<SearchScreen> createState() => _SearchScreenState();
}

class _SearchScreenState extends ConsumerState<SearchScreen> {
  String _query = '';
  String? _category;

  @override
  Widget build(BuildContext context) {
    final city = ref.watch(selectedCityProvider);

    return SafeArea(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: const EdgeInsets.all(20),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('Search', style: Theme.of(context).textTheme.headlineSmall?.copyWith(fontWeight: FontWeight.w700)),
                const SizedBox(height: 16),
                TextField(
                  autofocus: true,
                  decoration: const InputDecoration(
                    hintText: 'Business name or keyword',
                    prefixIcon: Icon(Icons.search),
                  ),
                  onChanged: (value) => setState(() => _query = value),
                ),
              ],
            ),
          ),
          Expanded(
            child: FutureBuilder<List<SellerModel>>(
              future: apiServiceProvider.fetchSellers(city: city, category: _category, query: _query),
              builder: (context, snapshot) {
                if (snapshot.connectionState == ConnectionState.waiting) {
                  return const Center(child: CircularProgressIndicator());
                }
                if (snapshot.hasError) {
                  return Center(child: Text('Error: ${snapshot.error}'));
                }
                final sellers = snapshot.data ?? [];
                if (sellers.isEmpty) {
                  return const Center(child: Text('No businesses found'));
                }
                return ListView.separated(
                  padding: const EdgeInsets.symmetric(horizontal: 20),
                  itemCount: sellers.length,
                  separatorBuilder: (_, __) => const SizedBox(height: 12),
                  itemBuilder: (_, index) {
                    final seller = sellers[index];
                    return ListTile(
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                      tileColor: Theme.of(context).cardTheme.color,
                      leading: CircleAvatar(child: Text(seller.businessName[0])),
                      title: Text(seller.businessName, style: const TextStyle(fontWeight: FontWeight.w600)),
                      subtitle: Text('${seller.averageRating} ★ · ${seller.city}'),
                      trailing: seller.achievementStars > 0
                          ? Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                const Icon(Icons.star, color: AppColors.orange, size: 16),
                                Text('${seller.achievementStars}'),
                              ],
                            )
                          : null,
                      onTap: () => context.push('/seller/${seller.id}'),
                    );
                  },
                );
              },
            ),
          ),
        ],
      ),
    );
  }
}
