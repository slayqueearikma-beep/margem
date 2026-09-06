import 'package:flutter/material.dart';

import '../../l10n/app_localizations.dart';
import '../theme/theme_context.dart';

Future<void> showAppErrorDialog(
  BuildContext context, {
  required String title,
  required String message,
}) {
  final colors = context.colors;
  return showDialog<void>(
    context: context,
    builder: (ctx) => AlertDialog(
      title: Text(
        title,
        style: TextStyle(color: colors.textPrimary),
      ),
      content: SingleChildScrollView(
        child: Text(
          message,
          style: TextStyle(color: colors.textSecondary, height: 1.4),
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(ctx),
          child: Text(AppLocalizations.get(ctx).strings.ok),
        ),
      ],
    ),
  );
}
