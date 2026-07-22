import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:souq_local/core/widgets/content_widgets.dart';

void main() {
  testWidgets('StatCard uses compact icon-to-value spacing', (tester) async {
    await tester.pumpWidget(
      const MaterialApp(
        home: Scaffold(
          body: SizedBox(
            width: 180,
            height: 118,
            child: StatCard(
              label: 'Profile views',
              value: '0',
              icon: Icons.visibility_outlined,
              trend: 'No views yet',
            ),
          ),
        ),
      ),
    );

    final icon = tester.getRect(find.byIcon(Icons.visibility_outlined));
    final value = tester.getRect(find.text('0'));
    final label = tester.getRect(find.text('Profile views'));
    final trend = tester.getRect(find.text('No views yet'));

    // Icon sits directly above value with ~8px gap (allow small layout tolerance).
    expect(value.top - icon.bottom, closeTo(8, 2));
    expect(label.top - value.bottom, closeTo(4, 2));
    expect(trend.top - label.bottom, closeTo(2, 2));
    expect(find.textContaining('API:'), findsNothing);
  });
}
