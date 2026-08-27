import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../core/services/api_service.dart';
import '../../core/services/auth_service.dart';
import '../../core/services/theme_mode_provider.dart';
import '../../core/theme/app_spacing.dart';
import '../../core/theme/theme_context.dart';
import '../../core/widgets/app_buttons.dart';
import '../../core/widgets/buyer_ui_components.dart';
import '../../core/widgets/error_dialog.dart';
import '../../core/widgets/margem_app_bar.dart';
import '../../l10n/app_localizations.dart';

class SellerSettingsScreen extends ConsumerStatefulWidget {
  const SellerSettingsScreen({super.key});

  @override
  ConsumerState<SellerSettingsScreen> createState() => _SellerSettingsScreenState();
}

class _SellerSettingsScreenState extends ConsumerState<SellerSettingsScreen> {
  final _currentPasswordController = TextEditingController();
  final _newPasswordController = TextEditingController();
  bool _loadingPassword = false;
  bool _obscureCurrent = true;
  bool _obscureNew = true;

  @override
  void dispose() {
    _currentPasswordController.dispose();
    _newPasswordController.dispose();
    super.dispose();
  }

  Future<void> _changePassword() async {
    final l10n = context.l10n;
    if (_currentPasswordController.text.isEmpty || _newPasswordController.text.length < 8) {
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(l10n.completeRequiredStep)));
      return;
    }

    setState(() => _loadingPassword = true);
    try {
      await apiServiceProvider.changePassword(
        currentPassword: _currentPasswordController.text,
        newPassword: _newPasswordController.text,
      );
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(l10n.passwordChanged)));
      _currentPasswordController.clear();
      _newPasswordController.clear();
    } on ApiException catch (e) {
      if (!mounted) return;
      await showAppErrorDialog(context, title: l10n.somethingWentWrong, message: e.message);
    } finally {
      if (mounted) setState(() => _loadingPassword = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final themeMode = ref.watch(themeModeProvider);

    return Scaffold(
      appBar: MarGemAppBar(semanticLabel: l10n.accountSecurity),
      body: ListView(
        padding: const EdgeInsets.all(AppSpacing.screenHorizontal),
        children: [
          Text(l10n.appearance, style: Theme.of(context).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w700)),
          const SizedBox(height: AppSpacing.sm),
          SegmentedButton<ThemeMode>(
            segments: [
              ButtonSegment(value: ThemeMode.system, label: Text(l10n.systemTheme), icon: const Icon(Icons.brightness_auto)),
              ButtonSegment(value: ThemeMode.light, label: Text(l10n.lightTheme), icon: const Icon(Icons.light_mode_outlined)),
              ButtonSegment(value: ThemeMode.dark, label: Text(l10n.darkTheme), icon: const Icon(Icons.dark_mode_outlined)),
            ],
            selected: {themeMode},
            onSelectionChanged: (values) {
              ref.read(themeModeProvider.notifier).setThemeMode(values.first);
            },
          ),
          SizedBox(height: AppSpacing.xl),
          Text(l10n.verifyEmailTitle, style: Theme.of(context).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w700)),
          SizedBox(height: AppSpacing.sm),
          ListTile(
            contentPadding: EdgeInsets.zero,
            leading: Icon(Icons.mark_email_unread_outlined),
            title: Text(l10n.resendVerificationEmail),
            onTap: () => context.push('/verify-email'),
          ),
          SizedBox(height: AppSpacing.xl),
          Text(l10n.billingSectionTitle, style: Theme.of(context).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w700)),
          SizedBox(height: AppSpacing.sm),
          ListTile(
            contentPadding: EdgeInsets.zero,
            leading: Icon(Icons.receipt_long_outlined),
            title: Text(l10n.billingSettingsTitle),
            subtitle: Text(l10n.billingSectionSubtitle),
            onTap: () => context.push('/settings/billing'),
          ),
          SizedBox(height: AppSpacing.xl),
          Text(l10n.twoFactorAuthTitle, style: Theme.of(context).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w700)),
          SizedBox(height: AppSpacing.sm),
          ListTile(
            contentPadding: EdgeInsets.zero,
            leading: const Icon(Icons.verified_user_outlined),
            title: Text(l10n.mfaSettingsTitle),
            subtitle: Text(
              ref.watch(authSessionProvider)?.user.mfaEnabled == true
                  ? l10n.mfaEnabled
                  : l10n.enableMfa,
            ),
            onTap: () => context.push('/settings/mfa'),
          ),
          SizedBox(height: AppSpacing.xl),
          Text(l10n.changePassword, style: Theme.of(context).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w700)),
          SizedBox(height: AppSpacing.md),
          TextField(
            controller: _currentPasswordController,
            obscureText: _obscureCurrent,
            decoration: InputDecoration(
              labelText: l10n.currentPassword,
              suffixIcon: IconButton(
                icon: Icon(_obscureCurrent ? Icons.visibility_outlined : Icons.visibility_off_outlined),
                onPressed: () => setState(() => _obscureCurrent = !_obscureCurrent),
              ),
            ),
          ),
          SizedBox(height: AppSpacing.md),
          TextField(
            controller: _newPasswordController,
            obscureText: _obscureNew,
            decoration: InputDecoration(
              labelText: l10n.newPassword,
              suffixIcon: IconButton(
                icon: Icon(_obscureNew ? Icons.visibility_outlined : Icons.visibility_off_outlined),
                onPressed: () => setState(() => _obscureNew = !_obscureNew),
              ),
            ),
          ),
          SizedBox(height: AppSpacing.md),
          PrimaryButton(
            label: l10n.changePassword,
            onPressed: _changePassword,
            isLoading: _loadingPassword,
          ),
          SizedBox(height: AppSpacing.xxl),
          BuyerMenuTile(
            icon: Icons.policy_outlined,
            title: l10n.privacyAndLegal,
            subtitle: l10n.privacyLegalHubSubtitle,
            onTap: () => context.push('/settings/privacy-legal'),
          ),
        ],
      ),
    );
  }
}
