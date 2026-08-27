import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../../core/theme/app_spacing.dart';
import '../../core/theme/theme_context.dart';
import '../../core/widgets/buyer_ui_components.dart';
import '../../l10n/app_localizations.dart';
import 'legal_document_screen.dart';
import 'legal_documents.dart';

class PrivacyLegalHubScreen extends StatelessWidget {
  const PrivacyLegalHubScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;

    return BuyerScreenScaffold(
      appBar: BuyerAppBar(title: l10n.privacyAndLegal),
      body: ListView(
        padding: const EdgeInsets.all(AppSpacing.screenHorizontal),
        children: [
          Text(
            l10n.privacyLegalHubIntro,
            style: TextStyle(
              color: context.colors.textSecondary,
              height: 1.45,
            ),
          ),
          const SizedBox(height: AppSpacing.lg),
          _SectionTitle(title: l10n.privacySectionTitle),
          _HubTile(
            icon: Icons.privacy_tip_outlined,
            label: l10n.privacyPolicy,
            onTap: () => openLegalDocument(context, LegalDocumentId.privacy),
          ),
          _HubTile(
            icon: Icons.tune_rounded,
            label: l10n.privacySettings,
            onTap: () => context.push('/settings/privacy'),
          ),
          _HubTile(
            icon: Icons.folder_shared_outlined,
            label: l10n.yourData,
            onTap: () => context.push('/settings/your-data'),
          ),
          _HubTile(
            icon: Icons.download_outlined,
            label: l10n.dataExport,
            onTap: () => context.push('/settings/your-data'),
          ),
          _HubTile(
            icon: Icons.delete_forever_outlined,
            label: l10n.deleteAccount,
            destructive: true,
            onTap: () => context.push('/settings/your-data'),
          ),
          _HubTile(
            icon: Icons.phonelink_setup_outlined,
            label: l10n.managePermissions,
            onTap: () => context.push('/settings/privacy'),
          ),
          const SizedBox(height: AppSpacing.xl),
          _SectionTitle(title: l10n.legalSubsectionTitle),
          _HubTile(
            icon: Icons.description_outlined,
            label: l10n.termsOfService,
            onTap: () => openLegalDocument(context, LegalDocumentId.terms),
          ),
          _HubTile(
            icon: Icons.storefront_outlined,
            label: l10n.sellerTerms,
            onTap: () => openLegalDocument(context, LegalDocumentId.sellerTerms),
          ),
          _HubTile(
            icon: Icons.groups_outlined,
            label: l10n.communityGuidelines,
            onTap: () =>
                openLegalDocument(context, LegalDocumentId.communityGuidelines),
          ),
          _HubTile(
            icon: Icons.cookie_outlined,
            label: l10n.cookiePolicy,
            onTap: () => openLegalDocument(context, LegalDocumentId.cookies),
          ),
          _HubTile(
            icon: Icons.receipt_long_outlined,
            label: l10n.subscriptionTerms,
            onTap: () =>
                openLegalDocument(context, LegalDocumentId.subscriptionTerms),
          ),
          _HubTile(
            icon: Icons.policy_outlined,
            label: l10n.accountDeletionPolicy,
            onTap: () =>
                openLegalDocument(context, LegalDocumentId.accountDeletion),
          ),
          _HubTile(
            icon: Icons.gavel_outlined,
            label: l10n.legalNotice,
            onTap: () => openLegalDocument(context, LegalDocumentId.legalNotice),
          ),
          _HubTile(
            icon: Icons.code_outlined,
            label: l10n.openSourceLicenses,
            onTap: () =>
                openLegalDocument(context, LegalDocumentId.openSourceLicenses),
          ),
        ],
      ),
    );
  }
}

class _SectionTitle extends StatelessWidget {
  const _SectionTitle({required this.title});

  final String title;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: AppSpacing.sm),
      child: Text(
        title,
        style: Theme.of(context).textTheme.titleMedium?.copyWith(
              fontWeight: FontWeight.w700,
            ),
      ),
    );
  }
}

class _HubTile extends StatelessWidget {
  const _HubTile({
    required this.icon,
    required this.label,
    required this.onTap,
    this.destructive = false,
  });

  final IconData icon;
  final String label;
  final VoidCallback onTap;
  final bool destructive;

  @override
  Widget build(BuildContext context) {
    final color = destructive ? context.colors.error : null;
    return BuyerMenuTile(
      icon: icon,
      title: label,
      destructive: destructive,
      onTap: onTap,
    );
  }
}
