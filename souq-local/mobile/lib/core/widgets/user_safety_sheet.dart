import 'package:flutter/material.dart';

import '../services/api_service.dart';
import '../../l10n/app_localizations.dart';

/// Report reasons accepted by the marketplace reports API.
const marketplaceReportReasons = <String>[
  'wrong_location',
  'closed_business',
  'wrong_phone',
  'wrong_category',
  'duplicate_business',
  'incorrect_product',
  'scam',
  'spam',
  'harassment',
  'inappropriate',
  'other',
];

String reportReasonLabel(AppStrings l10n, String reason) {
  return switch (reason) {
    'wrong_location' => l10n.reportReasonWrongLocation,
    'closed_business' => l10n.reportReasonClosedBusiness,
    'wrong_phone' => l10n.reportReasonWrongPhone,
    'wrong_category' => l10n.reportReasonWrongCategory,
    'duplicate_business' => l10n.reportReasonDuplicateBusiness,
    'incorrect_product' => l10n.reportReasonIncorrectProduct,
    'spam' => l10n.reportReasonSpam,
    'harassment' => l10n.reportReasonHarassment,
    'scam' => l10n.reportReasonScam,
    'inappropriate' => l10n.reportReasonInappropriate,
    _ => l10n.reportReasonOther,
  };
}

/// Bottom sheet with report and block actions for a marketplace user.
Future<void> showUserSafetySheet(
  BuildContext context, {
  required String userId,
  required String displayName,
  String? sellerId,
  String? productId,
  VoidCallback? onBlocked,
}) async {
  final l10n = context.l10n;
  await showModalBottomSheet<void>(
    context: context,
    showDragHandle: true,
    builder: (ctx) => SafeArea(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 0, 16, 8),
            child: Text(
              displayName,
              style: Theme.of(ctx).textTheme.titleMedium,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
          ),
          ListTile(
            leading: const Icon(Icons.flag_outlined),
            title: Text(l10n.reportUser),
            onTap: () async {
              Navigator.pop(ctx);
              await _reportUser(
                context,
                userId: userId,
                displayName: displayName,
                sellerId: sellerId,
                productId: productId,
              );
            },
          ),
          ListTile(
            leading: const Icon(Icons.block_outlined),
            title: Text(l10n.blockUser),
            onTap: () async {
              Navigator.pop(ctx);
              await _blockUser(
                context,
                userId: userId,
                displayName: displayName,
                onBlocked: onBlocked,
              );
            },
          ),
        ],
      ),
    ),
  );
}

Future<void> _reportUser(
  BuildContext context, {
  required String userId,
  required String displayName,
  String? sellerId,
  String? productId,
}) async {
  final l10n = context.l10n;
  final detailsController = TextEditingController();
  var selectedReason = marketplaceReportReasons.first;

  final submitted = await showDialog<bool>(
    context: context,
    builder: (ctx) => StatefulBuilder(
      builder: (ctx, setState) => AlertDialog(
        title: Text(l10n.reportUser),
        content: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Text(
                l10n.reportUserSubtitle(displayName),
                style: Theme.of(ctx).textTheme.bodyMedium,
              ),
              const SizedBox(height: 16),
              DropdownButtonFormField<String>(
                value: selectedReason,
                decoration: InputDecoration(labelText: l10n.reportReasonLabel),
                items: [
                  for (final reason in marketplaceReportReasons)
                    DropdownMenuItem(
                      value: reason,
                      child: Text(reportReasonLabel(l10n, reason)),
                    ),
                ],
                onChanged: (value) {
                  if (value != null) setState(() => selectedReason = value);
                },
              ),
              const SizedBox(height: 12),
              TextField(
                controller: detailsController,
                maxLines: 3,
                decoration: InputDecoration(
                  labelText: l10n.reportDetailsOptional,
                ),
              ),
            ],
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: Text(l10n.cancel),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(ctx, true),
            child: Text(l10n.submitReport),
          ),
        ],
      ),
    ),
  );

  if (submitted != true || !context.mounted) {
    detailsController.dispose();
    return;
  }

  try {
    await apiServiceProvider.createReport(
      sellerId: sellerId,
      productId: productId,
      reportedUserId: userId,
      reason: selectedReason,
      details: detailsController.text.trim(),
    );
    if (context.mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(l10n.userReported)),
      );
    }
  } on ApiException catch (error) {
    if (context.mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(error.message)),
      );
    }
  } catch (_) {
    if (context.mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(l10n.somethingWentWrong)),
      );
    }
  } finally {
    detailsController.dispose();
  }
}

Future<void> _blockUser(
  BuildContext context, {
  required String userId,
  required String displayName,
  VoidCallback? onBlocked,
}) async {
  final l10n = context.l10n;
  final confirmed = await showDialog<bool>(
    context: context,
    builder: (ctx) => AlertDialog(
      title: Text(l10n.blockUser),
      content: Text(l10n.blockUserConfirm(displayName)),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(ctx, false),
          child: Text(l10n.cancel),
        ),
        FilledButton(
          onPressed: () => Navigator.pop(ctx, true),
          child: Text(l10n.blockUser),
        ),
      ],
    ),
  );

  if (confirmed != true || !context.mounted) return;

  try {
    await apiServiceProvider.blockUser(userId);
    if (!context.mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(l10n.userBlocked)),
    );
    onBlocked?.call();
  } on ApiException catch (error) {
    if (context.mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(error.message)),
      );
    }
  } catch (_) {
    if (context.mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(l10n.somethingWentWrong)),
      );
    }
  }
}

/// Overflow menu button for report/block on profile and chat screens.
class UserSafetyMenuButton extends StatelessWidget {
  const UserSafetyMenuButton({
    super.key,
    required this.userId,
    required this.displayName,
    this.sellerId,
    this.productId,
    this.onBlocked,
  });

  final String userId;
  final String displayName;
  final String? sellerId;
  final String? productId;
  final VoidCallback? onBlocked;

  @override
  Widget build(BuildContext context) {
    return IconButton(
      icon: const Icon(Icons.more_vert_rounded),
      onPressed: () => showUserSafetySheet(
        context,
        userId: userId,
        displayName: displayName,
        sellerId: sellerId,
        productId: productId,
        onBlocked: onBlocked,
      ),
    );
  }
}
