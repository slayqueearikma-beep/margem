import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../core/services/api_service.dart';
import '../../core/services/app_storage.dart';
import '../../core/theme/app_spacing.dart';
import '../../core/theme/theme_context.dart';
import '../../core/utils/friendly_errors.dart';
import '../../core/widgets/buyer_ui_components.dart';
import '../../core/widgets/error_dialog.dart';
import '../../l10n/app_localizations.dart';
import 'legal_config.dart';
import 'delete_account_flow.dart';
import 'legal_document_screen.dart';
import 'legal_documents.dart';

class YourDataScreen extends ConsumerStatefulWidget {
  const YourDataScreen({super.key});

  @override
  ConsumerState<YourDataScreen> createState() => _YourDataScreenState();
}

class _YourDataScreenState extends ConsumerState<YourDataScreen> {
  var _exporting = false;

  Future<void> _exportData() async {
    final l10n = context.l10n;
    setState(() => _exporting = true);
    try {
      final payload = await apiServiceProvider.exportMyData();
      final encoded = const JsonEncoder.withIndent('  ').convert(payload);
      await Clipboard.setData(ClipboardData(text: encoded));
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(l10n.dataExportCopied)),
      );
    } on ApiException catch (e) {
      if (!mounted) return;
      await showAppErrorDialog(
        context,
        title: l10n.somethingWentWrong,
        message: friendlyErrorMessage(e, l10n),
      );
    } finally {
      if (mounted) setState(() => _exporting = false);
    }
  }

  Future<void> _requestCorrection() async {
    final uri = LegalConfig.privacyMailto(subject: 'Data correction request');
    if (await canLaunchUrl(uri)) {
      await launchUrl(uri);
    }
  }

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final session = ref.watch(userSessionProvider);
    final isGuest = session == null || session.isGuest;

    if (isGuest) {
      return BuyerScreenScaffold(
        appBar: BuyerAppBar(title: l10n.yourData),
        body: Center(
          child: Padding(
            padding: const EdgeInsets.all(AppSpacing.screenHorizontal),
            child: Text(
              l10n.signInToManageData,
              textAlign: TextAlign.center,
              style: TextStyle(color: context.colors.textSecondary),
            ),
          ),
        ),
      );
    }

    return BuyerScreenScaffold(
      appBar: BuyerAppBar(title: l10n.yourData),
      body: ListView(
        padding: const EdgeInsets.all(AppSpacing.screenHorizontal),
        children: [
          Text(
            l10n.yourDataIntro,
            style: TextStyle(
              color: context.colors.textSecondary,
              height: 1.45,
            ),
          ),
          const SizedBox(height: AppSpacing.lg),
          _DataCard(
            title: l10n.viewAccountInfo,
            children: [
              _InfoRow(label: l10n.fullName, value: session.name),
              _InfoRow(label: l10n.email, value: session.email),
              if (session.city != null)
                _InfoRow(label: l10n.city, value: session.city!),
            ],
          ),
          const SizedBox(height: AppSpacing.md),
          BuyerMenuTile(
            icon: Icons.download_outlined,
            title: l10n.dataExport,
            subtitle: l10n.dataExportDescription,
            onTap: _exporting ? null : _exportData,
          ),
          if (_exporting)
            const Padding(
              padding: EdgeInsets.symmetric(vertical: AppSpacing.sm),
              child: LinearProgressIndicator(),
            ),
          const SizedBox(height: AppSpacing.sm),
          BuyerMenuTile(
            icon: Icons.edit_outlined,
            title: l10n.requestDataCorrection,
            subtitle: l10n.requestDataCorrectionDescription,
            onTap: _requestCorrection,
          ),
          const SizedBox(height: AppSpacing.sm),
          BuyerMenuTile(
            icon: Icons.schedule_outlined,
            title: l10n.dataRetentionInfo,
            onTap: () =>
                openLegalDocument(context, LegalDocumentId.accountDeletion),
          ),
          const SizedBox(height: AppSpacing.lg),
          BuyerMenuTile(
            icon: Icons.delete_forever_outlined,
            title: l10n.deleteAccount,
            subtitle: l10n.deleteAccountExplainer,
            destructive: true,
            onTap: () => showDeleteAccountFlow(context, ref),
          ),
        ],
      ),
    );
  }
}

class _DataCard extends StatelessWidget {
  const _DataCard({required this.title, required this.children});

  final String title;
  final List<Widget> children;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(AppSpacing.md),
      decoration: BoxDecoration(
        color: context.colors.surface,
        borderRadius: BorderRadius.circular(AppSpacing.cardRadius),
        border: Border.all(color: context.colors.border),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            title,
            style: Theme.of(context).textTheme.titleSmall?.copyWith(
                  fontWeight: FontWeight.w700,
                ),
          ),
          const SizedBox(height: AppSpacing.sm),
          ...children,
        ],
      ),
    );
  }
}

class _InfoRow extends StatelessWidget {
  const _InfoRow({required this.label, required this.value});

  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 6),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 88,
            child: Text(
              label,
              style: TextStyle(color: context.colors.textSecondary),
            ),
          ),
          Expanded(
            child: Text(
              value.isEmpty ? '—' : value,
              style: const TextStyle(fontWeight: FontWeight.w600),
            ),
          ),
        ],
      ),
    );
  }
}
