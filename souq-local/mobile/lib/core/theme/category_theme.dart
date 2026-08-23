import 'package:flutter/material.dart';

import '../theme/app_colors.dart';

/// Dynamic category icons and accent colors from API metadata.
abstract final class CategoryTheme {
  static Color accentColor(String? hex, {String? slug}) {
    if (hex != null && hex.isNotEmpty && hex.startsWith('#') && hex.length == 7) {
      final value = int.tryParse(hex.substring(1), radix: 16);
      if (value != null) return Color(0xFF000000 | value);
    }
    if (slug != null) {
      final hash = slug.codeUnits.fold<int>(0, (a, b) => a + b);
      final hue = (hash * 37) % 360;
      return HSLColor.fromAHSL(1, hue.toDouble(), 0.55, 0.48).toColor();
    }
    return AppColors.primary;
  }

  static IconData iconFor(String iconName) {
    return _icons[iconName] ?? Icons.storefront_outlined;
  }

  static final Map<String, IconData> _icons = {
    'store': Icons.storefront_outlined,
    'medical_services': Icons.medical_services_outlined,
    'medical_information': Icons.medical_information_outlined,
    'local_pharmacy': Icons.local_pharmacy_outlined,
    'pets': Icons.pets_outlined,
    'pet_supplies': Icons.pets_outlined,
    'restaurant': Icons.restaurant_outlined,
    'local_cafe': Icons.local_cafe_outlined,
    'hotel': Icons.hotel_outlined,
    'spa': Icons.spa_outlined,
    'content_cut': Icons.content_cut_outlined,
    'fitness_center': Icons.fitness_center_outlined,
    'car_repair': Icons.car_repair_outlined,
    'directions_car': Icons.directions_car_outlined,
    'two_wheeler': Icons.two_wheeler_outlined,
    'motorcycle': Icons.two_wheeler_outlined,
    'moped': Icons.moped_outlined,
    'car_rental': Icons.car_rental_outlined,
    'tire_repair': Icons.tire_repair_outlined,
    'local_car_wash': Icons.local_car_wash_outlined,
    'build_circle': Icons.build_circle_outlined,
    'real_estate_agent': Icons.real_estate_agent_outlined,
    'flight': Icons.flight_outlined,
    'policy': Icons.policy_outlined,
    'account_balance': Icons.account_balance_outlined,
    'gavel': Icons.gavel_outlined,
    'approval': Icons.verified_outlined,
    'calculate': Icons.calculate_outlined,
    'school': Icons.school_outlined,
    'cleaning_services': Icons.cleaning_services_outlined,
    'local_shipping': Icons.local_shipping_outlined,
    'plumbing': Icons.plumbing_outlined,
    'electrical_services': Icons.electrical_services_outlined,
    'format_paint': Icons.format_paint_outlined,
    'carpenter': Icons.carpenter_outlined,
    'handyman': Icons.handyman_outlined,
    'lock': Icons.lock_outlined,
    'locksmith': Icons.lock_outlined,
    'ac_unit': Icons.ac_unit_outlined,
    'security': Icons.security_outlined,
    'pest_control': Icons.pest_control_outlined,
    'campaign': Icons.campaign_outlined,
    'devices': Icons.devices_outlined,
    'devices_other': Icons.devices_other_outlined,
    'web': Icons.web_outlined,
    'computer': Icons.computer_outlined,
    'architecture': Icons.architecture_outlined,
    'engineering': Icons.engineering_outlined,
    'work': Icons.work_outline_outlined,
    'event': Icons.event_outlined,
    'chair': Icons.chair_outlined,
    'checkroom': Icons.checkroom_outlined,
    'diamond': Icons.diamond_outlined,
    'menu_book': Icons.menu_book_outlined,
    'local_florist': Icons.local_florist_outlined,
    'bakery_dining': Icons.bakery_dining_outlined,
    'shopping_cart': Icons.shopping_cart_outlined,
    'build': Icons.handyman_outlined,
    'home': Icons.home_outlined,
    'local_hospital': Icons.local_hospital_outlined,
    'sports_soccer': Icons.sports_soccer_outlined,
    'fashion': Icons.checkroom_outlined,
    'beauty': Icons.spa_outlined,
    'food': Icons.restaurant_outlined,
    'clothing': Icons.checkroom_outlined,
    'electronics': Icons.devices_outlined,
    'services': Icons.handyman_outlined,
    'health': Icons.local_hospital_outlined,
    'sports': Icons.sports_soccer_outlined,
  };
}
