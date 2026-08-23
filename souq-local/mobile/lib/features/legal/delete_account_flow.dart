import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../core/services/app_storage.dart';
import '../../core/services/auth_service.dart';
import '../../core/theme/app_spacing.dart';
import '../../core/widgets/error_dialog.dart';
import '../../l10n/app_localizations.dart';

/// Shared account deletion confirmation flow with password entry.
Future<void> showDeleteAccountFlow(BuildContext context, WidgetRef ref) async {
  final l10n = context.l10n;
  final password = await showDialog<String>(
    context: context,
    builder: (_) => const _DeleteAccountDialog(),
  );
  if (password == null || !context.mounted) return;

  try {
    await ref.read(authServiceProvider).deleteAccount(password: password);
    final prefs = await ref.read(sharedPreferencesProvider.future);
    await ref.read(authServiceProvider).logout(prefs);
    await ref.read(appStorageProvider)?.logout();
    ref.read(userSessionProvider.notifier).state = null;
    ref.read(authSessionProvider.notifier).state = null;
    if (context.mounted) context.go('/login');
  } on Object catch (e) {
    if (context.mounted) {
      await showAppErrorDialog(
        context,
        title: l10n.somethingWentWrong,
        message: e.toString(),
      );
    }
  }
}

class _DeleteAccountDialog extends StatefulWidget {
  const _DeleteAccountDialog();

  @override
  State<_DeleteAccountDialog> createState() => _DeleteAccountDialogState();
}

class _DeleteAccountDialogState extends State<_DeleteAccountDialog> {
  final _password = TextEditingController();

  @override
  void dispose() {
    _password.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    return AlertDialog(
      title: Text(l10n.deleteAccount),
      content: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(l10n.deleteAccountExplainer),
            const SizedBox(height: AppSpacing.md),
            Text(l10n.deleteAccountConfirm),
            const SizedBox(height: 12),
            TextField(
              controller: _password,
              obscureText: true,
              decoration: InputDecoration(labelText: l10n.password),
            ),
          ],
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: Text(l10n.cancel),
        ),
        FilledButton(
          onPressed: () => Navigator.pop(context, _password.text),
          child: Text(l10n.deleteAccount),
        ),
      ],
    );
  }
}
