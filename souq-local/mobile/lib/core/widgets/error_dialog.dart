import 'package:flutter/material.dart';

import '../../l10n/app_localizations.dart';

Future<void> showAppErrorDialog(
  BuildContext context, {
  required String title,
  required String message,
}) {
  return showDialog<void>(
    context: context,
    builder: (ctx) => AlertDialog(
      title: Text(title),
      content: SingleChildScrollView(child: Text(message)),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(ctx),
          child: Text(AppLocalizations.get(ctx).strings.ok),
        ),
      ],
    ),
  );
}
