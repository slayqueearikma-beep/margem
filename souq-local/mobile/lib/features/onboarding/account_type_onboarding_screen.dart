import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../core/config/app_config.dart';
import '../../core/services/app_storage.dart';
import '../../core/theme/app_colors.dart';
import '../../core/theme/app_spacing.dart';
import '../../core/widgets/app_buttons.dart';
import '../../core/widgets/design_system_components.dart';
import '../../core/widgets/onboarding_scaffold.dart';
import '../../l10n/app_localizations.dart';

class AccountTypeOnboardingScreen extends ConsumerStatefulWidget {
  const AccountTypeOnboardingScreen({super.key});

  @override
  ConsumerState<AccountTypeOnboardingScreen> createState() =>
      _AccountTypeOnboardingScreenState();
}

class _AccountTypeOnboardingScreenState
    extends ConsumerState<AccountTypeOnboardingScreen> {
  AccountType? _selected;

  void _handleBack() {
    if (context.canPop()) {
      context.pop();
      return;
    }
    final storage = ref.read(appStorageProvider);
    if (storage?.isOnboardingComplete == true) {
      context.go('/login');
    } else {
      context.go('/onboarding');
    }
  }

  void _continue() {
    if (_selected == AccountType.buyer) {
      context.push('/onboarding/buyer-register');
    } else if (_selected == AccountType.seller) {
      context.push('/onboarding/seller-register');
    }
  }

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;

    return OnboardingScaffold(
      showBack: true,
      onBack: _handleBack,
      bottom: Column(
        children: [
          if (_selected != null) ...[
            PrimaryButton(
              label: l10n.continueLabel,
              onPressed: _continue,
              accentColor: _selected == AccountType.seller
                  ? AppColors.peach
                  : AppColors.lavender,
            ),
            const SizedBox(height: AppSpacing.sm),
          ],
          AppSecondaryActionRow(
            label: l10n.decideLater,
            onTap: _continueAsGuest,
          ),
          const SizedBox(height: AppSpacing.lg),
          AppSecurityFooter(
            line1: l10n.secureSignupLine1,
            line2: l10n.secureSignupLine2,
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          AppScreenHeader(
            title: l10n.chooseAccountType,
            subtitle: l10n.chooseAccountTypeSubtitle,
            showLogo: true,
            centered: true,
          ),
          const SizedBox(height: AppSpacing.xl),
          AppSectionLabel(label: l10n.accountTypeSectionLabel),
          const SizedBox(height: AppSpacing.md),
          AccountTypeCard(
            title: l10n.buyer,
            subtitle: l10n.buyerSubtitle,
            icon: Icons.shopping_bag_outlined,
            accentColor: AppColors.lavender,
            ctaLabel: l10n.continueAsBuyer,
            selected: _selected == AccountType.buyer,
            onTap: () => setState(() => _selected = AccountType.buyer),
          ),
          const SizedBox(height: AppSpacing.md),
          AccountTypeCard(
            title: l10n.seller,
            subtitle: l10n.sellerSubtitle,
            icon: Icons.storefront_outlined,
            accentColor: AppColors.peach,
            ctaLabel: l10n.continueAsSeller,
            selected: _selected == AccountType.seller,
            onTap: () => setState(() => _selected = AccountType.seller),
          ),
        ],
      ),
    );
  }

  Future<void> _continueAsGuest() async {
    final storage = ref.read(appStorageProvider);
    if (storage == null) return;
    await storage.completeOnboarding();
    await storage.saveGuestSession(city: AppConfig.launchCity);
    ref.read(userSessionProvider.notifier).state = storage.getSession();
    if (mounted) context.go('/buyer/home');
  }
}
