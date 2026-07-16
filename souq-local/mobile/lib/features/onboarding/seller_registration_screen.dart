import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';
import 'package:image_picker/image_picker.dart';

import '../../core/config/app_config.dart';
import '../../core/services/app_storage.dart';
import '../../core/theme/app_colors.dart';
import '../../core/theme/app_spacing.dart';
import '../../core/widgets/app_buttons.dart';
import '../../core/widgets/form_widgets.dart';
import '../../core/widgets/onboarding_scaffold.dart';

class SellerRegistrationScreen extends ConsumerStatefulWidget {
  const SellerRegistrationScreen({super.key});

  @override
  ConsumerState<SellerRegistrationScreen> createState() => _SellerRegistrationScreenState();
}

class _SellerRegistrationScreenState extends ConsumerState<SellerRegistrationScreen> {
  static const _totalSteps = 5;
  int _step = 1;
  bool _loading = false;

  // Step 1
  final _businessNameController = TextEditingController();
  final _ownerNameController = TextEditingController();
  final _emailController = TextEditingController();
  final _passwordController = TextEditingController();

  // Step 2
  String _category = 'Food';
  String _city = AppConfig.moroccanCities.first;
  final _addressController = TextEditingController();
  final _phoneController = TextEditingController();
  LatLng _location = const LatLng(33.5731, -7.5898);

  // Step 3
  final _descriptionController = TextEditingController();
  XFile? _logoImage;
  XFile? _coverImage;
  final Map<String, bool> _openDays = {
    'Mon': true,
    'Tue': true,
    'Wed': true,
    'Thu': true,
    'Fri': true,
    'Sat': true,
    'Sun': false,
  };
  TimeOfDay _openTime = const TimeOfDay(hour: 9, minute: 0);
  TimeOfDay _closeTime = const TimeOfDay(hour: 21, minute: 0);

  // Step 4
  final List<_ProductDraft> _products = [_ProductDraft()];

  static const _categories = [
    'Food',
    'Clothing',
    'Electronics',
    'Beauty',
    'Services',
    'Home & Garden',
    'Health',
    'Sports',
  ];

  @override
  void dispose() {
    _businessNameController.dispose();
    _ownerNameController.dispose();
    _emailController.dispose();
    _passwordController.dispose();
    _addressController.dispose();
    _phoneController.dispose();
    _descriptionController.dispose();
    for (final p in _products) {
      p.dispose();
    }
    super.dispose();
  }

  Future<void> _pickImage(void Function(XFile) setter) async {
    final image = await ImagePicker().pickImage(source: ImageSource.gallery, maxWidth: 1200);
    if (image != null) setState(() => setter(image));
  }

  bool _validateStep() {
    switch (_step) {
      case 1:
        return _businessNameController.text.trim().isNotEmpty &&
            _ownerNameController.text.trim().isNotEmpty &&
            _emailController.text.trim().isNotEmpty &&
            _passwordController.text.length >= 6;
      case 2:
        return _addressController.text.trim().isNotEmpty && _phoneController.text.trim().isNotEmpty;
      case 3:
        return _descriptionController.text.trim().isNotEmpty;
      case 4:
        return _products.any((p) => p.nameController.text.trim().isNotEmpty);
      default:
        return true;
    }
  }

  void _next() {
    if (!_validateStep()) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please complete all required fields before continuing.')),
      );
      return;
    }
    if (_step < _totalSteps) {
      setState(() => _step++);
    } else {
      _submit();
    }
  }

  void _back() {
    if (_step > 1) {
      setState(() => _step--);
    } else {
      context.pop();
    }
  }

  Future<void> _submit() async {
    setState(() => _loading = true);
    final storage = ref.read(appStorageProvider);
    if (storage == null) return;

    final session = UserSession(
      name: _ownerNameController.text.trim(),
      email: _emailController.text.trim(),
      accountType: AccountType.seller,
      city: _city,
      businessName: _businessNameController.text.trim(),
    );

    await storage.completeOnboarding();
    await storage.saveSession(session);
    ref.read(userSessionProvider.notifier).state = session;

    if (!mounted) return;
    context.go('/seller/dashboard');
  }

  @override
  Widget build(BuildContext context) {
    return OnboardingScaffold(
      showBack: true,
      onBack: _back,
      progressStep: _step,
      progressTotal: _totalSteps,
      child: AnimatedSwitcher(
        duration: const Duration(milliseconds: 300),
        child: _buildStep(),
      ),
      bottom: Column(
        children: [
          PrimaryButton(
            label: _step == _totalSteps ? 'Submit & create account' : 'Next',
            onPressed: _next,
            isLoading: _loading,
          ),
          if (_step < _totalSteps) SecondaryTextButton(label: 'Back', onPressed: _back),
        ],
      ),
    );
  }

  Widget _buildStep() {
    return switch (_step) {
      1 => _buildStep1(),
      2 => _buildStep2(),
      3 => _buildStep3(),
      4 => _buildStep4(),
      _ => _buildStep5(),
    };
  }

  Widget _buildStep1() {
    return Column(
      key: const ValueKey(1),
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const AppScreenHeader(
          title: 'Business account',
          subtitle: 'Step 1 of 5 — Tell us about you and your business.',
        ),
        const SizedBox(height: AppSpacing.xl),
        AppTextField(label: 'Business name', controller: _businessNameController, hint: 'e.g. Hana Chicken'),
        const SizedBox(height: AppSpacing.md),
        AppTextField(label: 'Owner name', controller: _ownerNameController, hint: 'Your full name'),
        const SizedBox(height: AppSpacing.md),
        AppTextField(label: 'Email', controller: _emailController, hint: 'business@example.com', keyboardType: TextInputType.emailAddress),
        const SizedBox(height: AppSpacing.md),
        AppTextField(label: 'Password', controller: _passwordController, hint: 'Minimum 6 characters', obscureText: true),
      ],
    );
  }

  Widget _buildStep2() {
    return Column(
      key: const ValueKey(2),
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const AppScreenHeader(
          title: 'Location & contact',
          subtitle: 'Step 2 of 5 — Help buyers find your physical store.',
        ),
        const SizedBox(height: AppSpacing.xl),
        AppTextField(
          label: 'Business category',
          hint: _category,
          readOnly: true,
          prefixIcon: Icons.category_outlined,
          onTap: () async {
            final selected = await showModalBottomSheet<String>(
              context: context,
              builder: (ctx) => ListView(
                children: _categories.map((c) => ListTile(title: Text(c), onTap: () => Navigator.pop(ctx, c))).toList(),
              ),
            );
            if (selected != null) setState(() => _category = selected);
          },
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
                children: AppConfig.moroccanCities.map((c) => ListTile(title: Text(c), onTap: () => Navigator.pop(ctx, c))).toList(),
              ),
            );
            if (selected != null) setState(() => _city = selected);
          },
        ),
        const SizedBox(height: AppSpacing.md),
        AppTextField(label: 'Full address', controller: _addressController, hint: 'Street, neighborhood'),
        const SizedBox(height: AppSpacing.md),
        AppTextField(label: 'Phone number', controller: _phoneController, hint: '+212 6XX XXX XXX', keyboardType: TextInputType.phone),
        const SizedBox(height: AppSpacing.md),
        Text('Store location', style: Theme.of(context).textTheme.bodyMedium?.copyWith(color: AppColors.textSecondary)),
        const SizedBox(height: AppSpacing.sm),
        ClipRRect(
          borderRadius: BorderRadius.circular(AppSpacing.inputRadius),
          child: SizedBox(
            height: 180,
            child: GoogleMap(
              initialCameraPosition: CameraPosition(target: _location, zoom: 14),
              markers: {Marker(markerId: const MarkerId('store'), position: _location)},
              onTap: (pos) => setState(() => _location = pos),
              myLocationButtonEnabled: false,
              zoomControlsEnabled: false,
            ),
          ),
        ),
        const SizedBox(height: AppSpacing.sm),
        Text(
          'Tap the map to set your store pin.',
          style: Theme.of(context).textTheme.bodySmall?.copyWith(color: AppColors.textSecondary),
        ),
      ],
    );
  }

  Widget _buildStep3() {
    return Column(
      key: const ValueKey(3),
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const AppScreenHeader(
          title: 'Business profile',
          subtitle: 'Step 3 of 5 — Make your store stand out.',
        ),
        const SizedBox(height: AppSpacing.xl),
        AppTextField(label: 'Business description', controller: _descriptionController, hint: 'Tell buyers what makes your business special…', maxLines: 4),
        const SizedBox(height: AppSpacing.md),
        Row(
          children: [
            Expanded(
              child: _ImagePickerBox(
                label: 'Business logo',
                file: _logoImage,
                onTap: () => _pickImage((f) => _logoImage = f),
                height: 100,
              ),
            ),
            const SizedBox(width: AppSpacing.md),
            Expanded(
              child: _ImagePickerBox(
                label: 'Cover photo',
                file: _coverImage,
                onTap: () => _pickImage((f) => _coverImage = f),
                height: 100,
              ),
            ),
          ],
        ),
        const SizedBox(height: AppSpacing.lg),
        Text('Opening hours', style: Theme.of(context).textTheme.titleSmall?.copyWith(fontWeight: FontWeight.w600)),
        const SizedBox(height: AppSpacing.sm),
        Wrap(
          spacing: 8,
          runSpacing: 8,
          children: _openDays.entries.map((entry) {
            return FilterChip(
              label: Text(entry.key),
              selected: entry.value,
              onSelected: (v) => setState(() => _openDays[entry.key] = v),
            );
          }).toList(),
        ),
        const SizedBox(height: AppSpacing.md),
        Row(
          children: [
            Expanded(child: _TimePickerTile(label: 'Opens', time: _openTime, onPick: (t) => setState(() => _openTime = t))),
            const SizedBox(width: AppSpacing.md),
            Expanded(child: _TimePickerTile(label: 'Closes', time: _closeTime, onPick: (t) => setState(() => _closeTime = t))),
          ],
        ),
      ],
    );
  }

  Widget _buildStep4() {
    return Column(
      key: const ValueKey(4),
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const AppScreenHeader(
          title: 'First products & services',
          subtitle: 'Step 4 of 5 — Add at least one item to your catalog.',
        ),
        const SizedBox(height: AppSpacing.xl),
        ..._products.asMap().entries.map((entry) {
          final index = entry.key;
          final product = entry.value;
          return Card(
            margin: const EdgeInsets.only(bottom: AppSpacing.md),
            child: Padding(
              padding: const EdgeInsets.all(AppSpacing.md),
              child: Column(
                children: [
                  _ImagePickerBox(
                    label: 'Product image',
                    file: product.image,
                    onTap: () => _pickImage((f) => setState(() => product.image = f)),
                    height: 120,
                  ),
                  const SizedBox(height: AppSpacing.md),
                  AppTextField(label: 'Name', controller: product.nameController, hint: 'Product or service name'),
                  const SizedBox(height: AppSpacing.sm),
                  AppTextField(label: 'Description', controller: product.descriptionController, hint: 'Short description', maxLines: 2),
                  const SizedBox(height: AppSpacing.sm),
                  AppTextField(
                    label: 'Price (MAD, optional)',
                    controller: product.priceController,
                    hint: 'e.g. 49.99',
                    keyboardType: const TextInputType.numberWithOptions(decimal: true),
                  ),
                  if (_products.length > 1)
                    Align(
                      alignment: Alignment.centerRight,
                      child: TextButton(
                        onPressed: () => setState(() {
                          product.dispose();
                          _products.removeAt(index);
                        }),
                        child: const Text('Remove', style: TextStyle(color: AppColors.danger)),
                      ),
                    ),
                ],
              ),
            ),
          );
        }),
        OutlinedButton.icon(
          onPressed: () => setState(() => _products.add(_ProductDraft())),
          icon: const Icon(Icons.add),
          label: const Text('Add another item'),
        ),
      ],
    );
  }

  Widget _buildStep5() {
    return Column(
      key: const ValueKey(5),
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const AppScreenHeader(
          title: 'Review & submit',
          subtitle: 'Step 5 of 5 — Confirm your information before creating your account.',
        ),
        const SizedBox(height: AppSpacing.xl),
        _ReviewRow('Business', _businessNameController.text),
        _ReviewRow('Owner', _ownerNameController.text),
        _ReviewRow('Email', _emailController.text),
        _ReviewRow('Category', _category),
        _ReviewRow('City', _city),
        _ReviewRow('Address', _addressController.text),
        _ReviewRow('Phone', _phoneController.text),
        _ReviewRow('Products', '${_products.where((p) => p.nameController.text.isNotEmpty).length} item(s)'),
        const SizedBox(height: AppSpacing.lg),
        Container(
          padding: const EdgeInsets.all(AppSpacing.md),
          decoration: BoxDecoration(
            color: AppColors.primary.withValues(alpha: 0.08),
            borderRadius: BorderRadius.circular(AppSpacing.inputRadius),
          ),
          child: Row(
            children: [
              const Icon(Icons.info_outline, color: AppColors.primary),
              const SizedBox(width: AppSpacing.sm),
              Expanded(
                child: Text(
                  'Your business profile will be visible to buyers in $_city once your account is created.',
                  style: Theme.of(context).textTheme.bodySmall,
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }
}

class _ReviewRow extends StatelessWidget {
  const _ReviewRow(this.label, this.value);

  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: AppSpacing.sm),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(width: 100, child: Text(label, style: const TextStyle(color: AppColors.textSecondary))),
          Expanded(child: Text(value.isEmpty ? '—' : value, style: const TextStyle(fontWeight: FontWeight.w500))),
        ],
      ),
    );
  }
}

class _ImagePickerBox extends StatelessWidget {
  const _ImagePickerBox({required this.label, required this.onTap, this.file, this.height = 120});

  final String label;
  final VoidCallback onTap;
  final XFile? file;
  final double height;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(label, style: Theme.of(context).textTheme.bodySmall?.copyWith(color: AppColors.textSecondary)),
        const SizedBox(height: AppSpacing.sm),
        InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(AppSpacing.inputRadius),
          child: Container(
            height: height,
            width: double.infinity,
            decoration: BoxDecoration(
              border: Border.all(color: AppColors.border),
              borderRadius: BorderRadius.circular(AppSpacing.inputRadius),
              color: Theme.of(context).inputDecorationTheme.fillColor,
            ),
            child: file != null
                ? ClipRRect(
                    borderRadius: BorderRadius.circular(AppSpacing.inputRadius),
                    child: Image.file(File(file!.path), fit: BoxFit.cover),
                  )
                : const Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(Icons.add_photo_alternate_outlined, color: AppColors.textSecondary),
                      SizedBox(height: 4),
                      Text('Upload', style: TextStyle(fontSize: 12, color: AppColors.textSecondary)),
                    ],
                  ),
          ),
        ),
      ],
    );
  }
}

class _TimePickerTile extends StatelessWidget {
  const _TimePickerTile({required this.label, required this.time, required this.onPick});

  final String label;
  final TimeOfDay time;
  final ValueChanged<TimeOfDay> onPick;

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: () async {
        final picked = await showTimePicker(context: context, initialTime: time);
        if (picked != null) onPick(picked);
      },
      borderRadius: BorderRadius.circular(AppSpacing.inputRadius),
      child: InputDecorator(
        decoration: InputDecoration(
          labelText: label,
          suffixIcon: const Icon(Icons.access_time, size: 18),
        ),
        child: Text(time.format(context)),
      ),
    );
  }
}

class _ProductDraft {
  final nameController = TextEditingController();
  final descriptionController = TextEditingController();
  final priceController = TextEditingController();
  XFile? image;

  void dispose() {
    nameController.dispose();
    descriptionController.dispose();
    priceController.dispose();
  }
}
