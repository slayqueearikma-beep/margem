import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:souq_local/core/theme/app_theme.dart';
import 'package:souq_local/core/widgets/async_error_view.dart';
import 'package:souq_local/core/services/api_service.dart';
import 'package:souq_local/l10n/app_localizations.dart';

void main() {
  testWidgets('AsyncErrorView text is readable in dark mode', (tester) async {
    await tester.pumpWidget(
      MaterialApp(
        theme: AppTheme.light(),
        darkTheme: AppTheme.dark(),
        themeMode: ThemeMode.dark,
        locale: const Locale('en'),
        localizationsDelegates: const [AppLocalizations.delegate],
        supportedLocales: AppLocalizations.supportedLocales,
        home: Scaffold(
          body: AsyncErrorView.fromError(
            ApiException('Request failed (400)', statusCode: 400),
            onRetry: () {},
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();

    final texts = tester.widgetList<Text>(find.byType(Text)).toList();
    expect(texts.length, greaterThanOrEqualTo(2));
    for (final text in texts) {
      expect(text.style?.color, isNot(equals(Colors.white)));
    }
  });

  testWidgets('SnackBar uses contrasting colors in dark mode', (tester) async {
    await tester.pumpWidget(
      MaterialApp(
        theme: AppTheme.light(),
        darkTheme: AppTheme.dark(),
        themeMode: ThemeMode.dark,
        home: Builder(
          builder: (context) {
            return Scaffold(
              body: Center(
                child: ElevatedButton(
                  onPressed: () {
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(content: Text('Network error')),
                    );
                  },
                  child: const Text('show'),
                ),
              ),
            );
          },
        ),
      ),
    );

    await tester.tap(find.text('show'));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 300));

    final snackBarText = tester.widget<Text>(find.text('Network error'));
    final snackBarTheme = tester
        .widget<MaterialApp>(find.byType(MaterialApp))
        .darkTheme!
        .snackBarTheme;

    expect(snackBarTheme.backgroundColor, isNot(equals(Colors.white)));
    expect(snackBarText.style?.color, isNot(equals(snackBarTheme.backgroundColor)));
  });
}
