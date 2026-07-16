import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:image_picker/image_picker.dart';

import '../../core/config/app_config.dart';
import '../../core/services/app_storage.dart';
import '../../core/theme/app_spacing.dart';
import '../../core/widgets/app_buttons.dart';
import '../../core/widgets/form_widgets.dart';
import '../../core/widgets/onboarding_scaffold.dart';

class BuyerRegistrationScreen extends ConsumerStatefulWidget {
  const BuyerRegistrationScreen({super.key});

  @override
  ConsumerState<BuyerRegistrationScreen> createState() => _BuyerRegistrationScreenState();
}

class _BuyerRegistrationScreenState extends ConsumerState<BuyerRegistrationScreen> {
  final _nameController = TextEditingController();
  final _emailController = TextEditingController();
  final _passwordController = TextEditingController();
  String _city = AppConfig.moroccanCities.first;
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
    final picker = ImagePicker();
    final image = await picker.pickImage(source: ImageSource.gallery, maxWidth: 800);
    if (image != null) setState(() => _profileImage = image);
  }

  Future<void> _submit() async {
    if (_nameController.text.trim().isEmpty ||
        _emailController.text.trim().isEmpty ||
        _passwordController.text.length < 6) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please fill all required fields (password min 6 characters).')),
      );
      return;
    }

    setState(() => _loading = true);
    final storage = ref.read(appStorageProvider);
    if (storage == null) return;

    final session = UserSession(
      name: _nameController.text.trim(),
      email: _emailController.text.trim(),
      accountType: AccountType.buyer,
      city: _city,
    );

    await storage.completeOnboarding();
    await storage.saveSession(session);
    ref.read(userSessionProvider.notifier).state = session;

    if (!mounted) return;
    context.go('/buyer/home');
  }

  @override
  Widget build(BuildContext context) {
    return OnboardingScaffold(
      showBack: true,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const AppScreenHeader(
            title: 'Create your buyer account',
            subtitle: 'Start discovering trusted local businesses in minutes.',
          ),
          const SizedBox(height: AppSpacing.xl),
          Center(
            child: GestureDetector(
              onTap: _pickImage,
              child: CircleAvatar(
                radius: 48,
                backgroundColor: Theme.of(context).inputDecorationTheme.fillColor,
                backgroundImage: _profileImage != null ? FileImage(File(_profileImage!.path)) : null,
                child: _profileImage == null
                    ? const Icon(Icons.add_a_photo_outlined, size: 28, color: Colors.grey)
                    : null,
              ),
            ),
          ),
          const SizedBox(height: 8),
          const Center(
            child: Text('Profile picture (optional)', style: TextStyle(color: Colors.grey, fontSize: 13)),
          ),
          const SizedBox(height: AppSpacing.lg),
          AppTextField(label: 'Full name', controller: _nameController, hint: 'Your name'),
          const SizedBox(height: AppSpacing.md),
          AppTextField(
            label: 'Email',
            controller: _emailController,
            hint: 'you@example.com',
            keyboardType: TextInputType.emailAddress,
            prefixIcon: Icons.email_outlined,
          ),
          const SizedBox(height: AppSpacing.md),
          AppTextField(
            label: 'Password',
            controller: _passwordController,
            hint: 'Minimum 6 characters',
            obscureText: true,
            prefixIcon: Icons.lock_outline,
          ),
          const SizedBox(height: AppSpacing.md),
          AppTextField(
            label: 'City',
            hint: _city,
            readOnly: true,
            prefixIcon: Icons.location_city_outlined,
            onTap: () async {
              final selected = await showModalBottomSheet<String>(
                context: context,
                builder: (ctx) => ListView(
                  children: AppConfig.moroccanCities
                      .map(
                        (city) => ListTile(
                          title: Text(city),
                          onTap: () => Navigator.pop(ctx, city),
                        ),
                      )
                      .toList(),
                ),
              );
              if (selected != null) setState(() => _city = selected);
            },
          ),
        ],
      ),
      bottom: PrimaryButton(label: 'Create account', onPressed: _submit, isLoading: _loading),
    );
  }
}
