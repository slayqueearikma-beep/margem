import 'package:flutter_test/flutter_test.dart';
import 'package:souq_local/core/theme/app_colors.dart';

void main() {
  test('dark and light secondary text tokens differ', () {
    expect(AppColors.darkTextSecondary, isNot(equals(AppColors.textSecondary)));
  });

  test('selected card surface tokens differ between light and dark', () {
    expect(
      AppColors.cardSelected,
      isNot(equals(AppColors.lavender.withValues(alpha: 0.15))),
    );
  });

  test('dark scaffold background differs from light cream', () {
    expect(AppColors.darkBackground, isNot(equals(AppColors.cream)));
  });
}
