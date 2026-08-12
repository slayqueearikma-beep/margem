import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../core/config/app_config.dart';
import '../../core/theme/app_spacing.dart';
import '../../l10n/app_localizations.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

/// Links to hosted legal documents (localized) and support contacts.
class LegalLinksSection extends ConsumerWidget {
  const LegalLinksSection({super.key, this.compact = false});

  final bool compact;

  Future<void> _open(BuildContext context, String doc) async {
    final lang = Localizations.localeOf(context).languageCode;
    final uri = Uri.parse(AppConfig.legalDocumentUrl(doc, lang));
    if (!await launchUrl(uri, mode: LaunchMode.externalApplication)) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(context.l10n.somethingWentWrong)),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = context.l10n;
    final style = Theme.of(context).textTheme.bodySmall?.copyWith(
          color: Theme.of(context).colorScheme.onSurfaceVariant,
          height: 1.45,
        );

    if (compact) {
      return Text(
        l10n.signupTermsAcknowledgment,
        textAlign: TextAlign.center,
        style: style,
      );
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Text(
          l10n.legalSectionTitle,
          style: Theme.of(context).textTheme.titleMedium?.copyWith(
                fontWeight: FontWeight.w700,
              ),
        ),
        const SizedBox(height: AppSpacing.sm),
        _LegalTile(
          icon: Icons.privacy_tip_outlined,
          label: l10n.privacyPolicy,
          onTap: () => _open(context, 'privacy'),
        ),
        _LegalTile(
          icon: Icons.description_outlined,
          label: l10n.termsOfService,
          onTap: () => _open(context, 'terms'),
        ),
        _LegalTile(
          icon: Icons.cookie_outlined,
          label: l10n.cookiePolicy,
          onTap: () => _open(context, 'cookies'),
        ),
        _LegalTile(
          icon: Icons.delete_forever_outlined,
          label: l10n.accountDeletionPolicy,
          onTap: () => _open(context, 'account-deletion'),
        ),
        _LegalTile(
          icon: Icons.support_agent_outlined,
          label: l10n.contactSupport,
          onTap: () => launchUrl(
            Uri.parse('mailto:support@dribex.ma'),
            mode: LaunchMode.externalApplication,
          ),
        ),
      ],
    );
  }
}

class _LegalTile extends StatelessWidget {
  const _LegalTile({
    required this.icon,
    required this.label,
    required this.onTap,
  });

  final IconData icon;
  final String label;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return ListTile(
      contentPadding: EdgeInsets.zero,
      leading: Icon(icon, size: 22),
      title: Text(label),
      trailing: const Icon(Icons.open_in_new, size: 18),
      onTap: onTap,
    );
  }
}
