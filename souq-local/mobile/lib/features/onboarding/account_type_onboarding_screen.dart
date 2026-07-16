import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../../core/services/app_storage.dart';
import '../../core/theme/app_spacing.dart';
import '../../core/widgets/app_buttons.dart';
import '../../core/widgets/form_widgets.dart';
import '../../core/widgets/onboarding_scaffold.dart';

class AccountTypeOnboardingScreen extends StatefulWidget {
  const AccountTypeOnboardingScreen({super.key});

  @override
  State<AccountTypeOnboardingScreen> createState() => _AccountTypeOnboardingScreenState();
}

class _AccountTypeOnboardingScreenState extends State<AccountTypeOnboardingScreen> {
  AccountType? _selected;

  @override
  Widget build(BuildContext context) {
    return OnboardingScaffold(
      showBack: true,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const AppScreenHeader(
            title: 'Choose your account type',
            subtitle: 'Select how you want to use Souq Local. You can always update your profile later.',
            showLogo: true,
          ),
          const SizedBox(height: AppSpacing.xl),
          SelectionCard(
            title: 'Buyer',
            subtitle: 'Discover and support local businesses in your city.',
            icon: Icons.shopping_bag_outlined,
            selected: _selected == AccountType.buyer,
            accentColor: const Color(0xFF4D96FF),
            bulletPoints: const [
              'Discover nearby stores',
              'Browse products',
              'Read reviews',
              'Find businesses on the map',
            ],
            onTap: () => setState(() => _selected = AccountType.buyer),
          ),
          const SizedBox(height: AppSpacing.md),
          SelectionCard(
            title: 'Seller',
            subtitle: 'Create your online presence and reach more customers.',
            icon: Icons.store_mall_directory_outlined,
            selected: _selected == AccountType.seller,
            accentColor: const Color(0xFF6236FF),
            bulletPoints: const [
              'Create your business profile',
              'Upload products and services',
              'Manage customers',
              'Grow your visibility',
            ],
            onTap: () => setState(() => _selected = AccountType.seller),
          ),
        ],
      ),
      bottom: Column(
        children: [
          PrimaryButton(
            label: 'Continue',
            onPressed: _selected == null
                ? null
                : () {
                    if (_selected == AccountType.buyer) {
                      context.push('/onboarding/buyer-register');
                    } else {
                      context.push('/onboarding/seller-register');
                    }
                  },
          ),
          SecondaryTextButton(label: 'Back', onPressed: () => context.pop()),
        ],
      ),
    );
  }
}
