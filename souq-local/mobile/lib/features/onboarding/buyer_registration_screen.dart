import 'dart:async';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:image_picker/image_picker.dart';

import '../../core/validation/form_validators.dart';
import '../../core/config/app_config.dart';
import '../../core/services/api_service.dart';
import '../../core/services/app_storage.dart';
import '../../core/services/auth_service.dart';
import '../../core/theme/app_spacing.dart';
import '../../core/widgets/app_buttons.dart';
import '../../core/widgets/error_dialog.dart';
import '../../core/widgets/form_widgets.dart';
import '../../core/models/city_model.dart';
import '../../core/providers/city_providers.dart';
import '../../core/widgets/city_picker_field.dart';
import '../../core/widgets/onboarding_scaffold.dart';
import '../../core/widgets/signup_verification_dialogs.dart';
import '../../l10n/app_localizations.dart';

class BuyerRegistrationScreen extends ConsumerStatefulWidget {
  const BuyerRegistrationScreen({super.key});

  @override
  ConsumerState<BuyerRegistrationScreen> createState() =>
      _BuyerRegistrationScreenState();
}

class _BuyerRegistrationScreenState
    extends ConsumerState<BuyerRegistrationScreen> {
  final _nameController = TextEditingController();
  final _emailController = TextEditingController();
  final _passwordController = TextEditingController();
  CityModel? _selectedCity;
  XFile? _profileImage;
  bool _loading = false;

  @override
  void dispose() {
    _nameController.dispose();
    _emailController.dispose();
    _passwordController.dispose();
    super.dispose();
  }

  Future<void> _pickImage() async {
    final image = await ImagePicker()
        .pickImage(source: ImageSource.gallery, maxWidth: 800);
    if (image != null) setState(() => _profileImage = image);
  }

  Future<void> _submit() async {
    final l10n = context.l10n;
    if (_nameController.text.trim().isEmpty ||
        !FormValidators.isValidEmail(_emailController.text.trim()) ||
        !FormValidators.isValidPassword(_passwordController.text)) {
      ScaffoldMessenger.of(context)
          .showSnackBar(SnackBar(content: Text(l10n.fillRequiredFields)));
      return;
    }

    final email = _emailController.text.trim();
    final signupProof = await showSignupVerificationFlow(
      context: context,
      email: email,
      phone: '',
    );
    if (!mounted || signupProof == null) return;

    setState(() => _loading = true);
    try {
      await apiServiceProvider.runSubmit(() async {
        await apiServiceProvider.checkHealth();

        final auth = ref.read(authServiceProvider);
        final session = await auth.register(
          email: email,
          password: _passwordController.text,
          accountType: 'buyer',
          displayName: _nameController.text.trim(),
          signupProof: signupProof,
        );

        final prefs = await ref.read(sharedPreferencesProvider.future);
        await auth.persistToken(prefs);

        final storage = ref.read(appStorageProvider);
        if (storage == null) {
          throw ApiException(
              'App storage is not ready. Please restart the app.');
        }

        final userSession = UserSession(
          name: session.user.displayName,
          email: session.user.email,
          accountType: AccountType.buyer,
          city: _selectedCity?.nameEn ?? AppConfig.launchCity,
        );

        final guestItems = guestFavoritesMigrationPayload(storage);
        if (guestItems.isNotEmpty) {
          await apiServiceProvider.migrateGuestFavorites(guestItems);
          await storage.clearGuestFavorites();
        }

        await storage.completeOnboarding();
        await storage.saveSession(userSession);
        await storage.saveAppMode(AppMode.buyer);
        ref.read(userSessionProvider.notifier).state = userSession;
        ref.read(authSessionProvider.notifier).state = session;

        if (!mounted) return;
        context.go('/buyer/home');
      });
    } on ApiException catch (e) {
      if (!mounted) return;
      await showAppErrorDialog(context,
          title: l10n.somethingWentWrong, message: e.message);
    } on TimeoutException {
      if (!mounted) return;
      await showAppErrorDialog(context,
          title: l10n.somethingWentWrong, message: l10n.serverUnreachable);
    } catch (e) {
      if (!mounted) return;
      await showAppErrorDialog(context,
          title: l10n.somethingWentWrong, message: l10n.serverUnreachable);
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final cities = ref.watch(citiesProvider).valueOrNull;
    if (_selectedCity == null && cities != null && cities.isNotEmpty) {
      _selectedCity =
          findCityByName(cities, AppConfig.launchCity) ?? cities.first;
    }

    return OnboardingScaffold(
      showBack: true,
      bottom: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          PrimaryButton(
              label: l10n.createAccount,
              onPressed: _submit,
              isLoading: _loading),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          AppScreenHeader(
              title: l10n.createBuyerAccount,
              subtitle: l10n.createBuyerSubtitle),
          const SizedBox(height: AppSpacing.xl),
          Center(
            child: GestureDetector(
              onTap: _pickImage,
              child: CircleAvatar(
                radius: 48,
                backgroundColor:
                    Theme.of(context).inputDecorationTheme.fillColor,
                backgroundImage: _profileImage != null
                    ? FileImage(File(_profileImage!.path))
                    : null,
                child: _profileImage == null
                    ? const Icon(Icons.add_a_photo_outlined,
                        size: 28, color: Colors.grey)
                    : null,
              ),
            ),
          ),
          const SizedBox(height: 8),
          Center(
              child: Text(l10n.profilePictureOptional,
                  style: const TextStyle(color: Colors.grey, fontSize: 13))),
          const SizedBox(height: AppSpacing.lg),
          AppTextField(
              label: l10n.fullName,
              controller: _nameController,
              hint: l10n.yourName),
          const SizedBox(height: AppSpacing.md),
          AppTextField(
            label: l10n.email,
            controller: _emailController,
            hint: l10n.emailHint,
            keyboardType: TextInputType.emailAddress,
            prefixIcon: Icons.email_outlined,
          ),
          const SizedBox(height: AppSpacing.md),
          AppTextField(
            label: l10n.password,
            controller: _passwordController,
            hint: l10n.passwordHint,
            obscureText: true,
            prefixIcon: Icons.lock_outline,
          ),
          const SizedBox(height: AppSpacing.md),
          CityPickerField(
            selected: _selectedCity,
            onSelected: (city) => setState(() => _selectedCity = city),
          ),
        ],
      ),
    );
  }
}
