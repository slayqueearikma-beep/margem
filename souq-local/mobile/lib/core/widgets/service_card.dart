import 'package:flutter/material.dart';

import '../../l10n/app_localizations.dart';
import '../models/models.dart';
import '../theme/app_spacing.dart';
import '../theme/theme_context.dart';
import '../utils/directional_ui.dart';
import 'network_image_view.dart';

class ServiceCard extends StatelessWidget {
  const ServiceCard({
    super.key,
    required this.service,
    this.onTap,
    this.showAvailability = false,
  });

  final ServiceModel service;
  final VoidCallback? onTap;
  final bool showAvailability;

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final theme = Theme.of(context);

    return Card(
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: onTap,
        child: Padding(
          padding: EdgeInsets.all(AppSpacing.sm),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              ClipRRect(
                borderRadius: BorderRadius.circular(10),
                child: SizedBox(
                  width: 72,
                  height: 72,
                  child: NetworkImageView(
                    url: service.imageUrl,
                    placeholderIcon: Icons.handyman_outlined,
                  ),
                ),
              ),
              SizedBox(width: AppSpacing.sm),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      service.name,
                      style: theme.textTheme.titleSmall?.copyWith(
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                    if (service.description.isNotEmpty) ...[
                      SizedBox(height: 4),
                      Text(
                        service.description,
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                        style: theme.textTheme.bodySmall?.copyWith(
                          color: theme.colorScheme.onSurfaceVariant,
                        ),
                      ),
                    ],
                    SizedBox(height: 6),
                    Text(
                      service.displayPrice(l10n),
                      style: theme.textTheme.bodyMedium?.copyWith(
                        color: context.colors.primary,
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                    if (showAvailability) ...[
                      SizedBox(height: 4),
                      Text(
                        service.isAvailable ? l10n.available : l10n.unavailable,
                        style: TextStyle(
                          color: service.isAvailable
                              ? context.colors.success
                              : context.colors.warning,
                          fontSize: 12,
                        ),
                      ),
                    ],
                  ],
                ),
              ),
              if (onTap != null)
                Icon(
                  DirectionalUi.forwardChevron(context),
                  color: theme.colorScheme.onSurfaceVariant,
                ),
            ],
          ),
        ),
      ),
    );
  }
}
