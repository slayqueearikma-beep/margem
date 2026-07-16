import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

enum AccountType { buyer, seller }

class AccountTypeScreen extends StatefulWidget {
  const AccountTypeScreen({super.key});

  @override
  State<AccountTypeScreen> createState() => _AccountTypeScreenState();
}

class _AccountTypeScreenState extends State<AccountTypeScreen> {
  AccountType _selected = AccountType.buyer;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Choose account type')),
      body: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'How will you use Souq Local?',
              style: Theme.of(context).textTheme.titleLarge?.copyWith(fontWeight: FontWeight.w700),
            ),
            const SizedBox(height: 24),
            _TypeCard(
              title: 'Buyer',
              subtitle: 'Discover shops, products, and services in your city.',
              icon: Icons.search_rounded,
              selected: _selected == AccountType.buyer,
              onTap: () => setState(() => _selected = AccountType.buyer),
            ),
            const SizedBox(height: 16),
            _TypeCard(
              title: 'Seller',
              subtitle: 'Showcase your store, products, and location to nearby buyers.',
              icon: Icons.store_rounded,
              selected: _selected == AccountType.seller,
              onTap: () => setState(() => _selected = AccountType.seller),
            ),
            const Spacer(),
            SizedBox(
              width: double.infinity,
              child: FilledButton(
                onPressed: () => context.go('/home'),
                child: Text(_selected == AccountType.buyer ? 'Start exploring' : 'Set up my store'),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _TypeCard extends StatelessWidget {
  const _TypeCard({
    required this.title,
    required this.subtitle,
    required this.icon,
    required this.selected,
    required this.onTap,
  });

  final String title;
  final String subtitle;
  final IconData icon;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(20),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        padding: const EdgeInsets.all(20),
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(20),
          border: Border.all(
            color: selected ? Theme.of(context).colorScheme.primary : Colors.transparent,
            width: 2,
          ),
        ),
        child: Row(
          children: [
            Icon(icon, size: 32),
            const SizedBox(width: 16),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(title, style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 18)),
                  const SizedBox(height: 4),
                  Text(subtitle),
                ],
              ),
            ),
            if (selected) const Icon(Icons.check_circle_rounded),
          ],
        ),
      ),
    );
  }
}
