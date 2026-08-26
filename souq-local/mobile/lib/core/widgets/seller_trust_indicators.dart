import 'package:flutter/material.dart';

import '../models/models.dart';
import '../theme/theme_context.dart';
import '../../l10n/app_localizations.dart';

/// Maps backend verification status to buyer-facing trust labels.
class SellerTrustIndicators extends StatelessWidget {
  const SellerTrustIndicators({
    super.key,
    required this.seller,
    this.compact = false,
  });

  final SellerModel seller;
  final bool compact;

  String _verificationLabel(AppStrings l10n) {
    return switch (seller.verificationStatus) {
      'verified' => l10n.verificationBusinessVerified,
      'pending' => l10n.verificationPending,
      'rejected' => l10n.verificationRejected,
      _ => l10n.verificationUnverified,
    };
  }

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final chips = <Widget>[
      _TrustChip(
        label: _verificationLabel(l10n),
        icon: seller.verificationStatus == 'verified'
            ? Icons.verified_outlined
            : Icons.info_outline,
        emphasized: seller.verificationStatus == 'verified',
      ),
      if (seller.phoneVerified)
        _TrustChip(label: l10n.verificationPhoneVerified, icon: Icons.phone_android),
      if (seller.isSellerPro)
        _TrustChip(label: l10n.sellerProBadge, icon: Icons.workspace_premium_outlined),
      if (seller.isBuyerPlus)
        _TrustChip(label: l10n.buyerPlusBadge, icon: Icons.star_outline),
    ];

    if (compact) {
      return Text(
        chips.map((w) => (w as _TrustChip).label).join(' · '),
        style: TextStyle(color: context.colors.textSecondary, fontSize: 12),
        maxLines: 2,
        overflow: TextOverflow.ellipsis,
      );
    }

    return Wrap(
      spacing: 6,
      runSpacing: 6,
      children: chips,
    );
  }
}

class ListingPremiumBadges extends StatelessWidget {
  const ListingPremiumBadges({
    super.key,
    required this.sellerPremium,
    this.sellerBuyerPlus = false,
  });

  final bool sellerPremium;
  final bool sellerBuyerPlus;

  @override
  Widget build(BuildContext context) {
    if (!sellerPremium && !sellerBuyerPlus) return const SizedBox.shrink();
    final l10n = context.l10n;
    return Wrap(
      spacing: 4,
      children: [
        if (sellerPremium)
          _MiniBadge(label: l10n.sellerProBadge, emphasized: true),
        if (sellerBuyerPlus) _MiniBadge(label: l10n.buyerPlusBadge),
      ],
    );
  }
}

class _MiniBadge extends StatelessWidget {
  const _MiniBadge({required this.label, this.emphasized = false});

  final String label;
  final bool emphasized;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
      decoration: BoxDecoration(
        color: emphasized
            ? context.colors.primaryMuted
            : context.colors.surfaceVariant,
        borderRadius: BorderRadius.circular(999),
      ),
      child: Text(
        label,
        style: TextStyle(
          fontSize: 10,
          fontWeight: FontWeight.w700,
          color: emphasized
              ? context.colors.primary
              : context.colors.textSecondary,
        ),
      ),
    );
  }
}

class _TrustChip extends StatelessWidget {
  const _TrustChip({
    required this.label,
    required this.icon,
    this.emphasized = false,
  });

  final String label;
  final IconData icon;
  final bool emphasized;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: emphasized
            ? context.colors.primaryMuted
            : context.colors.surfaceVariant,
        borderRadius: BorderRadius.circular(999),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 14, color: context.colors.primary),
          const SizedBox(width: 4),
          Text(
            label,
            style: TextStyle(
              fontSize: 11,
              fontWeight: FontWeight.w600,
              color: context.colors.textPrimary,
            ),
          ),
        ],
      ),
    );
  }
}
