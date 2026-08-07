import 'package:flutter/material.dart';

import '../../core/theme/app_colors.dart';
import '../../core/theme/app_spacing.dart';
import 'partnership_models.dart';

class PartnershipBadge extends StatelessWidget {
  const PartnershipBadge({
    super.key,
    required this.partnership,
    this.compact = false,
  });

  final PublicPartnershipModel partnership;
  final bool compact;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: EdgeInsets.symmetric(
        horizontal: compact ? AppSpacing.sm : AppSpacing.md,
        vertical: compact ? AppSpacing.xs : AppSpacing.sm,
      ),
      decoration: BoxDecoration(
        color: AppColors.cardSelected,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: AppColors.primary.withValues(alpha: 0.2)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(
                Icons.handshake_outlined,
                size: compact ? 16 : 20,
                color: AppColors.primary,
              ),
              const SizedBox(width: AppSpacing.xs),
              Expanded(
                child: Text(
                  partnership.name,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: Theme.of(context).textTheme.titleSmall?.copyWith(
                        color: AppColors.primary,
                        fontWeight: FontWeight.w700,
                      ),
                ),
              ),
              if (partnership.isVerified)
                const Icon(Icons.verified, size: 16, color: AppColors.primary),
            ],
          ),
          if (!compact) ...[
            const SizedBox(height: AppSpacing.xs),
            Text(
              '${partnership.members.length} participating businesses · '
              '${partnership.combinedRating.toStringAsFixed(1)}★',
              style: Theme.of(context).textTheme.bodySmall?.copyWith(
                    color: Theme.of(context).colorScheme.onSurfaceVariant,
                  ),
            ),
            const SizedBox(height: AppSpacing.sm),
            Wrap(
              spacing: AppSpacing.xs,
              runSpacing: AppSpacing.xs,
              children: partnership.members
                  .map(
                    (m) => Chip(
                      avatar: m.logoImageUrl.isNotEmpty
                          ? CircleAvatar(
                              backgroundImage: NetworkImage(m.logoImageUrl),
                            )
                          : const CircleAvatar(
                              child: Icon(Icons.store, size: 14),
                            ),
                      label: Text(m.businessName, style: const TextStyle(fontSize: 12)),
                      visualDensity: VisualDensity.compact,
                    ),
                  )
                  .toList(),
            ),
          ],
        ],
      ),
    );
  }
}

class PartnershipStatusChip extends StatelessWidget {
  const PartnershipStatusChip({super.key, required this.status});

  final String status;

  @override
  Widget build(BuildContext context) {
    Color color;
    switch (status) {
      case 'active':
        color = AppColors.success;
      case 'pending':
        color = AppColors.warning;
      case 'suspended':
        color = AppColors.danger;
      default:
        color = AppColors.textSecondary;
    }
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(20),
      ),
      child: Text(
        status.replaceAll('_', ' ').toUpperCase(),
        style: TextStyle(
          color: color,
          fontSize: 11,
          fontWeight: FontWeight.w700,
          letterSpacing: 0.4,
        ),
      ),
    );
  }
}
