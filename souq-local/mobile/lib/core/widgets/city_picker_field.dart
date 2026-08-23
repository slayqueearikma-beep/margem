import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../l10n/app_localizations.dart';
import '../models/city_model.dart';
import '../providers/city_providers.dart';
import '../theme/app_colors.dart';
import '../theme/app_spacing.dart';
import 'form_widgets.dart';

/// Autocomplete city selector backed by the geography API.
class CityPickerField extends ConsumerWidget {
  const CityPickerField({
    super.key,
    required this.selected,
    required this.onSelected,
    this.label,
    this.readOnly = false,
  });

  final CityModel? selected;
  final ValueChanged<CityModel> onSelected;
  final String? label;
  final bool readOnly;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = context.l10n;
    final locale = Localizations.localeOf(context).languageCode;
    final citiesAsync = ref.watch(citiesProvider);

    return citiesAsync.when(
      loading: () => AppTextField(
        label: label ?? l10n.city,
        hint: selected?.localizedName(locale) ?? '…',
        readOnly: true,
        prefixIcon: Icons.location_city_outlined,
      ),
      error: (_, __) => AppTextField(
        label: label ?? l10n.city,
        hint: selected?.localizedName(locale) ?? l10n.city,
        readOnly: true,
        prefixIcon: Icons.location_city_outlined,
      ),
      data: (cities) {
        if (readOnly && selected != null) {
          return AppTextField(
            label: label ?? l10n.city,
            hint: selected!.localizedName(locale),
            readOnly: true,
            prefixIcon: Icons.location_city_outlined,
          );
        }
        return _CityAutocompleteField(
          label: label ?? l10n.city,
          cities: cities,
          selected: selected,
          locale: locale,
          onSelected: onSelected,
        );
      },
    );
  }
}

class _CityAutocompleteField extends StatelessWidget {
  const _CityAutocompleteField({
    required this.label,
    required this.cities,
    required this.selected,
    required this.locale,
    required this.onSelected,
  });

  final String label;
  final List<CityModel> cities;
  final CityModel? selected;
  final String locale;
  final ValueChanged<CityModel> onSelected;

  @override
  Widget build(BuildContext context) {
    return Autocomplete<CityModel>(
      initialValue: selected == null
          ? null
          : TextEditingValue(text: selected!.localizedName(locale)),
      displayStringForOption: (city) => city.localizedName(locale),
      optionsBuilder: (textEditingValue) {
        final query = textEditingValue.text;
        final filtered = cities.where((city) => city.matchesQuery(query)).toList();
        filtered.sort(
          (a, b) => a.localizedName(locale).compareTo(b.localizedName(locale)),
        );
        return filtered;
      },
      onSelected: onSelected,
      fieldViewBuilder: (context, controller, focusNode, onFieldSubmitted) {
        if (selected != null && controller.text.isEmpty) {
          controller.text = selected!.localizedName(locale);
        }
        return TextField(
          controller: controller,
          focusNode: focusNode,
          decoration: InputDecoration(
            labelText: label,
            prefixIcon: const Icon(Icons.location_city_outlined),
            filled: true,
            fillColor: AppColors.surfaceMuted,
            border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(16),
              borderSide: const BorderSide(color: AppColors.border),
            ),
            enabledBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(16),
              borderSide: const BorderSide(color: AppColors.border),
            ),
            focusedBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(16),
              borderSide: const BorderSide(color: AppColors.primary, width: 1.4),
            ),
          ),
        );
      },
      optionsViewBuilder: (context, onSelected, options) {
        return Align(
          alignment: Alignment.topLeft,
          child: Material(
            elevation: 4,
            borderRadius: BorderRadius.circular(AppSpacing.cardRadius),
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxHeight: 240, minWidth: 280),
              child: ListView.builder(
                padding: EdgeInsets.zero,
                shrinkWrap: true,
                itemCount: options.length,
                itemBuilder: (context, index) {
                  final city = options.elementAt(index);
                  return ListTile(
                    title: Text(city.localizedName(locale)),
                    subtitle: city.region.isEmpty
                        ? null
                        : Text(
                            city.region,
                            style: const TextStyle(fontSize: 12),
                          ),
                    onTap: () => onSelected(city),
                  );
                },
              ),
            ),
          ),
        );
      },
    );
  }
}

Future<CityModel?> showCityPickerSheet(
  BuildContext context,
  WidgetRef ref, {
  CityModel? selected,
}) async {
  final locale = Localizations.localeOf(context).languageCode;
  final cities = await ref.read(citiesProvider.future);
  if (!context.mounted) return null;
  final sorted = [...cities]
    ..sort((a, b) => a.localizedName(locale).compareTo(b.localizedName(locale)));

  return showModalBottomSheet<CityModel>(
    context: context,
    isScrollControlled: true,
    builder: (ctx) {
      var filtered = sorted;
      return StatefulBuilder(
        builder: (context, setState) {
          return Padding(
            padding: EdgeInsets.only(
              bottom: MediaQuery.paddingOf(context).bottom,
            ),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                const SizedBox(height: 12),
                Padding(
                  padding: const EdgeInsets.symmetric(
                    horizontal: AppSpacing.screenHorizontal,
                  ),
                  child: TextField(
                    autofocus: true,
                    decoration: InputDecoration(
                      hintText: context.l10n.city,
                      prefixIcon: const Icon(Icons.search),
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(16),
                      ),
                    ),
                    onChanged: (value) {
                      setState(() {
                        filtered = sorted
                            .where((city) => city.matchesQuery(value))
                            .toList();
                      });
                    },
                  ),
                ),
                const SizedBox(height: 8),
                Flexible(
                  child: ListView.builder(
                    shrinkWrap: true,
                    itemCount: filtered.length,
                    itemBuilder: (_, index) {
                      final city = filtered[index];
                      final isSelected = selected?.id == city.id;
                      return ListTile(
                        title: Text(city.localizedName(locale)),
                        subtitle: city.region.isEmpty
                            ? null
                            : Text(city.region),
                        trailing: isSelected
                            ? const Icon(Icons.check, color: AppColors.primary)
                            : null,
                        onTap: () => Navigator.pop(context, city),
                      );
                    },
                  ),
                ),
              ],
            ),
          );
        },
      );
    },
  );
}
