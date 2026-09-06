import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../navigation/margem_navigation_leading.dart';
import '../theme/app_shadows.dart';
import '../theme/app_spacing.dart';
import '../theme/theme_context.dart';
import '../utils/directional_ui.dart';
import 'app_brand_logo.dart';
import 'margem_app_bar.dart';

/// Customer-facing UI components matching the Home Screen mockup.
class BuyerShellHeader extends StatelessWidget {
  const BuyerShellHeader({
    super.key,
    required this.onMenu,
    required this.onNotifications,
    required this.onProfile,
  });

  final VoidCallback onMenu;
  final VoidCallback onNotifications;
  final VoidCallback onProfile;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: EdgeInsets.symmetric(horizontal: AppSpacing.screenHorizontal),
      child: SizedBox(
        height: AppLogoLayout.toolbarHeight,
        child: Stack(
          alignment: Alignment.center,
          children: [
            Align(
              alignment: AlignmentDirectional.centerStart,
              child: _HeaderIconButton(
                icon: Icons.menu_rounded,
                onTap: onMenu,
              ),
            ),
            const MarGemAppBarLogo(),
            Align(
              alignment: AlignmentDirectional.centerEnd,
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  _HeaderIconButton(
                    icon: Icons.notifications_none_rounded,
                    onTap: onNotifications,
                  ),
                  SizedBox(width: AppSpacing.xs),
                  Stack(
                    clipBehavior: Clip.none,
                    children: [
                      GestureDetector(
                        onTap: onProfile,
                        child: Container(
                          width: 40,
                          height: 40,
                          decoration: BoxDecoration(
                            shape: BoxShape.circle,
                            border: Border.all(
                                color: context.colors.divider, width: 2),
                            boxShadow: AppShadows.soft(context, blur: 12, y: 2),
                          ),
                          child: CircleAvatar(
                            backgroundColor: context.colors.surfaceVariant,
                            child: Icon(
                              Icons.person_rounded,
                              color: context.colors.primary,
                              size: 22,
                            ),
                          ),
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _HeaderIconButton extends StatelessWidget {
  const _HeaderIconButton({required this.icon, required this.onTap});

  final IconData icon;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(12),
        child: SizedBox(
          width: 40,
          height: 40,
          child: Icon(icon, size: 24, color: context.colors.textPrimary),
        ),
      ),
    );
  }
}

class BuyerLocationRow extends StatelessWidget {
  const BuyerLocationRow({
    super.key,
    required this.city,
    this.onTap,
  });

  final String city;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final child = Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(Icons.location_on_rounded, size: 18, color: context.colors.primary),
        SizedBox(width: 4),
        Text(
          city,
          style: Theme.of(context).textTheme.titleSmall?.copyWith(
                fontWeight: FontWeight.w600,
                color: context.colors.primary,
              ),
        ),
        if (onTap != null)
          Icon(Icons.keyboard_arrow_down_rounded,
              size: 20, color: context.colors.primary),
      ],
    );

    if (onTap == null) return child;
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(8),
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 4),
        child: child,
      ),
    );
  }
}

class BuyerGreetingBlock extends StatelessWidget {
  const BuyerGreetingBlock({
    super.key,
    required this.greeting,
    required this.subtitle,
  });

  final String greeting;
  final String subtitle;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          greeting,
          style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                fontWeight: FontWeight.w800,
                letterSpacing: -0.4,
                height: 1.15,
              ),
        ),
        SizedBox(height: AppSpacing.xs),
        Text(
          subtitle,
          style: Theme.of(context).textTheme.bodyLarge?.copyWith(
                color: context.colors.textSecondary,
                height: 1.35,
              ),
        ),
      ],
    );
  }
}

class BuyerSearchBar extends StatelessWidget {
  const BuyerSearchBar({
    super.key,
    required this.hint,
    this.onTap,
    this.onFilter,
    this.controller,
    this.onChanged,
    this.autofocus = false,
    this.focusNode,
  });

  final String hint;
  final VoidCallback? onTap;
  final VoidCallback? onFilter;
  final TextEditingController? controller;
  final ValueChanged<String>? onChanged;
  final bool autofocus;
  final FocusNode? focusNode;

  @override
  Widget build(BuildContext context) {
    final isInteractive = controller != null || onChanged != null;

    final field = Container(
      height: 52,
      decoration: BoxDecoration(
        color: context.colors.surface,
        borderRadius: BorderRadius.circular(28),
        border: Border.all(color: context.colors.divider),
      ),
      padding: const EdgeInsets.symmetric(horizontal: 6),
      child: Row(
        children: [
          SizedBox(width: 8),
          Icon(Icons.search_rounded, color: context.colors.textTertiary, size: 22),
          SizedBox(width: 8),
          Expanded(
            child: isInteractive
                ? TextField(
                    controller: controller,
                    focusNode: focusNode,
                    autofocus: autofocus,
                    onChanged: onChanged,
                    decoration: InputDecoration(
                      hintText: hint,
                      border: InputBorder.none,
                      enabledBorder: InputBorder.none,
                      focusedBorder: InputBorder.none,
                      contentPadding: EdgeInsets.zero,
                      hintStyle: TextStyle(
                        color: context.colors.textTertiary,
                        fontSize: 15,
                      ),
                    ),
                  )
                : Text(
                    hint,
                    style: TextStyle(
                      color: context.colors.textTertiary,
                      fontSize: 15,
                    ),
                  ),
          ),
          if (onFilter != null)
            Material(
              color: context.colors.surfaceVariant,
              borderRadius: BorderRadius.circular(20),
              child: InkWell(
                onTap: onFilter,
                borderRadius: BorderRadius.circular(20),
                child: SizedBox(
                  width: 40,
                  height: 40,
                  child: Icon(Icons.tune_rounded, color: context.colors.primary, size: 20),
                ),
              ),
            ),
          const SizedBox(width: 4),
        ],
      ),
    );

    if (!isInteractive && onTap != null) {
      return Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(28),
          child: field,
        ),
      );
    }
    return field;
  }
}

class BuyerQuickCategoryTile extends StatelessWidget {
  BuyerQuickCategoryTile({
    super.key,
    required this.label,
    required this.icon,
    required this.onTap,
    this.tint,
  });

  final String label;
  final IconData icon;
  final VoidCallback onTap;
  final Color? tint;

  @override
  Widget build(BuildContext context) {
    final tileTint = tint ?? context.colors.surfaceVariant;
    return SizedBox(
      width: 72,
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(20),
          child: Column(
            children: [
              Container(
                width: 64,
                height: 64,
                decoration: BoxDecoration(
                  color: tileTint,
                  borderRadius: BorderRadius.circular(20),
                  border: Border.all(color: context.colors.border),
                ),
                child: Icon(icon, color: context.colors.primary, size: 28),
              ),
              const SizedBox(height: 6),
              Text(
                label,
                maxLines: 2,
                textAlign: TextAlign.center,
                overflow: TextOverflow.ellipsis,
                style: Theme.of(context).textTheme.bodySmall?.copyWith(
                      fontWeight: FontWeight.w600,
                      fontSize: 11,
                      height: 1.1,
                    ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class BuyerSectionHeader extends StatelessWidget {
  const BuyerSectionHeader({
    super.key,
    required this.title,
    this.actionLabel,
    this.onAction,
  });

  final String title;
  final String? actionLabel;
  final VoidCallback? onAction;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: EdgeInsets.symmetric(horizontal: AppSpacing.screenHorizontal),
      child: Row(
        children: [
          Text(
            title,
            style: Theme.of(context).textTheme.titleMedium?.copyWith(
                  fontWeight: FontWeight.w800,
                ),
          ),
          Spacer(),
          if (actionLabel != null && onAction != null)
            TextButton(
              onPressed: onAction,
              style: TextButton.styleFrom(
                foregroundColor: context.colors.primary,
                padding: const EdgeInsets.symmetric(horizontal: 8),
                minimumSize: const Size(44, 36),
                tapTargetSize: MaterialTapTargetSize.shrinkWrap,
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    actionLabel!,
                    style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 14),
                  ),
                  Icon(DirectionalUi.forwardChevron(context), size: 18),
                ],
              ),
            ),
        ],
      ),
    );
  }
}

class BuyerNearYouCard extends StatelessWidget {
  const BuyerNearYouCard({
    super.key,
    required this.title,
    required this.subtitle,
    required this.priceLabel,
    required this.distanceLabel,
    required this.locationLabel,
    required this.rating,
    required this.imageUrl,
    required this.isFavorite,
    required this.onTap,
    required this.onFavorite,
    this.sellerAvatarUrl = '',
    this.favoriteLoading = false,
  });

  final String title;
  final String subtitle;
  final String priceLabel;
  final String distanceLabel;
  final String locationLabel;
  final double rating;
  final String imageUrl;
  final bool isFavorite;
  final VoidCallback onTap;
  final VoidCallback onFavorite;
  final String sellerAvatarUrl;
  final bool favoriteLoading;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: 200,
      child: Material(
        color: context.colors.surface,
        elevation: 0,
        shadowColor: Colors.transparent,
        borderRadius: BorderRadius.circular(AppSpacing.cardRadiusLg),
        clipBehavior: Clip.antiAlias,
        child: InkWell(
          onTap: onTap,
          child: DecoratedBox(
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(AppSpacing.cardRadiusLg),
              boxShadow: AppShadows.card(context),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                SizedBox(
                  height: 130,
                  child: Stack(
                    fit: StackFit.expand,
                    children: [
                      imageUrl.isNotEmpty
                          ? Image.network(imageUrl, fit: BoxFit.cover,
                              errorBuilder: (_, __, ___) => _imagePlaceholder(context))
                          : _imagePlaceholder(context),
                      PositionedDirectional(
                        start: 8,
                        bottom: 8,
                        child: Container(
                          padding: EdgeInsets.symmetric(
                            horizontal: 8,
                            vertical: 4,
                          ),
                          decoration: BoxDecoration(
                            color: context.colors.primary,
                            borderRadius: BorderRadius.circular(999),
                          ),
                          child: Text(
                            distanceLabel,
                            style: TextStyle(
                              color: Colors.white,
                              fontSize: 11,
                              fontWeight: FontWeight.w700,
                            ),
                          ),
                        ),
                      ),
                      PositionedDirectional(
                        top: 8,
                        end: 8,
                        child: Material(
                          color: Colors.white,
                          shape: CircleBorder(),
                          elevation: 1,
                          child: InkWell(
                            customBorder: CircleBorder(),
                            onTap: favoriteLoading ? null : onFavorite,
                            child: Padding(
                              padding: EdgeInsets.all(6),
                              child: favoriteLoading
                                  ? SizedBox(
                                      width: 18,
                                      height: 18,
                                      child: CircularProgressIndicator(
                                        strokeWidth: 2,
                                        color: context.colors.primary,
                                      ),
                                    )
                                  : Icon(
                                      isFavorite
                                          ? Icons.favorite_rounded
                                          : Icons.favorite_border_rounded,
                                      size: 18,
                                      color: context.colors.primary,
                                    ),
                            ),
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
                Padding(
                  padding: EdgeInsets.fromLTRB(12, 10, 12, 12),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        title,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(
                          fontWeight: FontWeight.w800,
                          fontSize: 15,
                        ),
                      ),
                      if (subtitle.isNotEmpty) ...[
                        SizedBox(height: 2),
                        Text(
                          subtitle,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: TextStyle(
                            color: context.colors.textSecondary,
                            fontSize: 12,
                          ),
                        ),
                      ],
                      if (priceLabel.isNotEmpty) ...[
                        SizedBox(height: 4),
                        Text(
                          priceLabel,
                          style: TextStyle(
                            fontWeight: FontWeight.w800,
                            fontSize: 14,
                          ),
                        ),
                      ],
                      SizedBox(height: 6),
                      Row(
                        children: [
                          Icon(Icons.location_on_outlined,
                              size: 12, color: context.colors.primary),
                          SizedBox(width: 2),
                          Expanded(
                            child: Text(
                              locationLabel,
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: TextStyle(
                                color: context.colors.primary,
                                fontSize: 11,
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                          ),
                        ],
                      ),
                      SizedBox(height: 6),
                      Row(
                        children: [
                          CircleAvatar(
                            radius: 10,
                            backgroundColor: context.colors.surfaceVariant,
                            backgroundImage: sellerAvatarUrl.isNotEmpty
                                ? NetworkImage(sellerAvatarUrl)
                                : null,
                            child: sellerAvatarUrl.isEmpty
                                ? Icon(Icons.store, size: 10)
                                : null,
                          ),
                          SizedBox(width: 6),
                          Icon(Icons.star_rounded,
                              size: 14, color: context.colors.star),
                          const SizedBox(width: 2),
                          Text(
                            rating.toStringAsFixed(1),
                            style: const TextStyle(
                              fontSize: 12,
                              fontWeight: FontWeight.w700,
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _imagePlaceholder(BuildContext context) {
    return Container(
      color: context.colors.surfaceVariant,
      child: Center(
        child: Icon(
          Icons.storefront_rounded,
          color: context.colors.textSecondary,
          size: 40,
        ),
      ),
    );
  }
}

class BuyerPopularCategoryCard extends StatelessWidget {
  BuyerPopularCategoryCard({
    super.key,
    required this.label,
    required this.icon,
    required this.onTap,
    this.tint,
  });

  final String label;
  final IconData icon;
  final VoidCallback onTap;
  final Color? tint;

  @override
  Widget build(BuildContext context) {
    final tileTint = tint ?? context.colors.surfaceVariant;
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(AppSpacing.cardRadius),
        child: Container(
          padding: const EdgeInsets.symmetric(vertical: AppSpacing.sm),
          decoration: BoxDecoration(
            color: tileTint,
            borderRadius: BorderRadius.circular(AppSpacing.cardRadius),
            border: Border.all(color: context.colors.border),
          ),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(icon, size: 32, color: context.colors.primary),
              const SizedBox(height: AppSpacing.sm),
              Text(
                label,
                textAlign: TextAlign.center,
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
                style: const TextStyle(
                  fontWeight: FontWeight.w700,
                  fontSize: 13,
                  height: 1.15,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// Centered logo row for buyer tab content. Shows a back control when this
/// widget is used on a pushed route (e.g. `/search`, `/messages`) but not
/// when embedded in [BuyerHomeShell] tabs.
class BuyerAdaptiveHeader extends StatelessWidget {
  const BuyerAdaptiveHeader({
    super.key,
    this.trailing,
    this.showBack = false,
    this.onBack,
  });

  final Widget? trailing;
  final bool showBack;
  final VoidCallback? onBack;

  @override
  Widget build(BuildContext context) {
    final showBackButton = showBack || shouldShowMargemBackButton(context);

    return Padding(
      padding: EdgeInsets.fromLTRB(
        AppSpacing.screenHorizontal,
        AppSpacing.md,
        AppSpacing.screenHorizontal,
        AppSpacing.sm,
      ),
      child: SizedBox(
        height: AppLogoLayout.toolbarHeight,
        child: Stack(
          alignment: Alignment.center,
          children: [
            const Center(child: MarGemAppBarLogo()),
            if (showBackButton)
              Align(
                alignment: AlignmentDirectional.centerStart,
                child: MargemBackLeading(
                  forceShow: showBack,
                  onPressed: onBack,
                ),
              ),
            if (trailing != null)
              Align(
                alignment: AlignmentDirectional.centerEnd,
                child: trailing!,
              ),
          ],
        ),
      ),
    );
  }
}

/// Large screen title used at the top of tab screens.
class BuyerScreenTitle extends StatelessWidget {
  const BuyerScreenTitle({
    super.key,
    this.title,
    this.subtitle,
    this.trailing,
  });

  final String? title;
  final String? subtitle;
  final Widget? trailing;

  @override
  Widget build(BuildContext context) {
    return BuyerAdaptiveHeader(trailing: trailing);
  }
}

/// White elevated app bar for pushed customer routes.
class BuyerAppBar extends StatelessWidget implements PreferredSizeWidget {
  const BuyerAppBar({
    super.key,
    this.title,
    this.actions,
    this.leading,
  });

  final String? title;
  final List<Widget>? actions;
  final Widget? leading;

  @override
  Size get preferredSize => const MarGemAppBar().preferredSize;

  @override
  Widget build(BuildContext context) {
    return MarGemAppBar(
      leading: leading,
      actions: actions,
      semanticLabel: title,
    );
  }
}

/// Rounded surface card with soft shadow — default container for lists.
class BuyerSurfaceCard extends StatelessWidget {
  const BuyerSurfaceCard({
    super.key,
    required this.child,
    this.onTap,
    this.padding,
  });

  final Widget child;
  final VoidCallback? onTap;
  final EdgeInsetsGeometry? padding;

  @override
  Widget build(BuildContext context) {
    final content = Padding(
      padding: padding ?? EdgeInsets.zero,
      child: child,
    );

    return Material(
      color: context.colors.surface,
      borderRadius: BorderRadius.circular(AppSpacing.cardRadius),
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(AppSpacing.cardRadius),
        child: DecoratedBox(
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(AppSpacing.cardRadius),
            border: Border.all(color: context.colors.border),
          ),
          child: content,
        ),
      ),
    );
  }
}

/// Settings / profile menu row matching the mockup rhythm.
class BuyerMenuTile extends StatelessWidget {
  BuyerMenuTile({
    super.key,
    required this.icon,
    required this.title,
    this.subtitle,
    this.trailing,
    this.onTap,
    this.iconColor,
    this.destructive = false,
  });

  final IconData icon;
  final String title;
  final String? subtitle;
  final Widget? trailing;
  final VoidCallback? onTap;
  final Color? iconColor;
  final bool destructive;

  @override
  Widget build(BuildContext context) {
    final color = destructive ? context.colors.error : context.colors.textPrimary;
    final leadingColor = iconColor ?? context.colors.textSecondary;
    return Material(
      color: context.colors.surface,
      borderRadius: BorderRadius.circular(AppSpacing.cardRadius),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(AppSpacing.cardRadius),
        child: Container(
          padding: EdgeInsets.symmetric(
            horizontal: AppSpacing.md,
            vertical: AppSpacing.md,
          ),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(AppSpacing.cardRadius),
            border: Border.all(color: context.colors.border),
          ),
          child: Row(
            children: [
              Container(
                width: 40,
                height: 40,
                decoration: BoxDecoration(
                  color: destructive
                      ? context.colors.errorMuted
                      : context.colors.surfaceVariant,
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Icon(
                  icon,
                  color: destructive ? context.colors.error : leadingColor,
                  size: 20,
                ),
              ),
              SizedBox(width: AppSpacing.md),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      title,
                      style: TextStyle(
                        fontWeight: FontWeight.w700,
                        fontSize: 15,
                        color: color,
                      ),
                    ),
                    if (subtitle != null) ...[
                      SizedBox(height: 2),
                      Text(
                        subtitle!,
                        style: TextStyle(
                          color: context.colors.textSecondary,
                          fontSize: 12,
                        ),
                      ),
                    ],
                  ],
                ),
              ),
              if (trailing != null)
                trailing!
              else if (onTap != null)
                Icon(
                  DirectionalUi.forwardChevron(context),
                  color: context.colors.textTertiary,
                  size: 20,
                ),
            ],
          ),
        ),
      ),
    );
  }
}

/// Centered empty state with lavender accent.
class BuyerEmptyState extends StatelessWidget {
  const BuyerEmptyState({
    super.key,
    required this.icon,
    required this.title,
    this.subtitle,
    this.actionLabel,
    this.onAction,
  });

  final IconData icon;
  final String title;
  final String? subtitle;
  final String? actionLabel;
  final VoidCallback? onAction;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: EdgeInsets.all(AppSpacing.xl),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 72,
              height: 72,
              decoration: BoxDecoration(
                color: context.colors.surfaceVariant,
                shape: BoxShape.circle,
                boxShadow: AppShadows.soft(context, blur: 20),
              ),
              child: Icon(icon, size: 32, color: context.colors.primary),
            ),
            SizedBox(height: AppSpacing.lg),
            Text(
              title,
              textAlign: TextAlign.center,
              style: Theme.of(context).textTheme.titleMedium?.copyWith(
                    fontWeight: FontWeight.w800,
                  ),
            ),
            if (subtitle != null) ...[
              SizedBox(height: AppSpacing.sm),
              Text(
                subtitle!,
                textAlign: TextAlign.center,
                style: TextStyle(
                  color: context.colors.textSecondary,
                  height: 1.4,
                ),
              ),
            ],
            if (actionLabel != null && onAction != null) ...[
              SizedBox(height: AppSpacing.lg),
              FilledButton(
                onPressed: onAction,
                style: FilledButton.styleFrom(
                  backgroundColor: context.colors.primary,
                  foregroundColor: Colors.white,
                  minimumSize: const Size(160, 48),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(999),
                  ),
                ),
                child: Text(actionLabel!),
              ),
            ],
          ],
        ),
      ),
    );
  }
}

/// Lavender / peach segmented toggle for search modes etc.
class BuyerSegmentedToggle<T> extends StatelessWidget {
  const BuyerSegmentedToggle({
    super.key,
    required this.segments,
    required this.selected,
    required this.onChanged,
  });

  final List<BuyerSegment<T>> segments;
  final T selected;
  final ValueChanged<T> onChanged;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: EdgeInsets.all(4),
      decoration: BoxDecoration(
        color: context.colors.surfaceVariant,
        borderRadius: BorderRadius.circular(999),
      ),
      child: Row(
        children: segments.map((segment) {
          final active = segment.value == selected;
          return Expanded(
            child: AnimatedContainer(
              duration: Duration(milliseconds: 200),
              curve: Curves.easeOutCubic,
              decoration: BoxDecoration(
                color: active ? context.colors.surface : Colors.transparent,
                borderRadius: BorderRadius.circular(999),
                boxShadow: active ? AppShadows.soft(context, blur: 8, y: 2) : null,
              ),
              child: Material(
                color: Colors.transparent,
                child: InkWell(
                  onTap: () => onChanged(segment.value),
                  borderRadius: BorderRadius.circular(999),
                  child: Padding(
                    padding: EdgeInsets.symmetric(vertical: 10),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(
                          segment.icon,
                          size: 16,
                          color: active
                              ? context.colors.primary
                              : context.colors.textTertiary,
                        ),
                        SizedBox(width: 6),
                        Flexible(
                          child: Text(
                            segment.label,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: TextStyle(
                              fontWeight:
                                  active ? FontWeight.w700 : FontWeight.w500,
                              fontSize: 13,
                              color: active
                                  ? context.colors.primary
                                  : context.colors.textTertiary,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ),
          );
        }).toList(),
      ),
    );
  }
}

class BuyerSegment<T> {
  const BuyerSegment({
    required this.value,
    required this.label,
    required this.icon,
  });

  final T value;
  final String label;
  final IconData icon;
}

class BuyerBottomNavBar extends StatelessWidget {
  const BuyerBottomNavBar({
    super.key,
    required this.selectedIndex,
    required this.onSelected,
    required this.items,
    this.badges = const {},
  });

  final int selectedIndex;
  final ValueChanged<int> onSelected;
  final List<BuyerNavItem> items;
  final Map<int, int> badges;

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: context.colors.surface,
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.05),
            blurRadius: 20,
            offset: const Offset(0, -4),
          ),
        ],
      ),
      child: SafeArea(
        top: false,
        child: SizedBox(
          height: 64,
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceAround,
            children: List.generate(items.length, (i) {
              final item = items[i];
              final selected = i == selectedIndex;
              return Expanded(
                child: InkWell(
                  onTap: () => onSelected(i),
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Stack(
                        clipBehavior: Clip.none,
                        children: [
                          Icon(
                            selected ? item.selectedIcon : item.icon,
                            color: selected
                                ? context.colors.primary
                                : context.colors.textTertiary,
                            size: 24,
                          ),
                          if ((badges[i] ?? 0) > 0)
                            PositionedDirectional(
                              end: -10,
                              top: -4,
                              child: Container(
                                padding: EdgeInsets.symmetric(
                                  horizontal: 5,
                                  vertical: 2,
                                ),
                                decoration: BoxDecoration(
                                  color: context.colors.error,
                                  borderRadius: BorderRadius.circular(10),
                                  border: Border.all(
                                    color: Colors.white,
                                    width: 1.5,
                                  ),
                                ),
                                constraints: BoxConstraints(
                                  minWidth: 16,
                                  minHeight: 16,
                                ),
                                child: Text(
                                  (badges[i]! > 99) ? '99+' : '${badges[i]}',
                                  style: TextStyle(
                                    color: Colors.white,
                                    fontSize: 9,
                                    fontWeight: FontWeight.w700,
                                    height: 1,
                                  ),
                                  textAlign: TextAlign.center,
                                ),
                              ),
                            ),
                        ],
                      ),
                      SizedBox(height: 4),
                      Text(
                        item.label,
                        style: TextStyle(
                          fontSize: 11,
                          fontWeight:
                              selected ? FontWeight.w700 : FontWeight.w500,
                          color: selected
                              ? context.colors.primary
                              : context.colors.textTertiary,
                        ),
                      ),
                    ],
                  ),
                ),
              );
            }),
          ),
        ),
      ),
    );
  }
}

class BuyerNavItem {
  const BuyerNavItem({
    required this.icon,
    required this.selectedIcon,
    required this.label,
  });

  final IconData icon;
  final IconData selectedIcon;
  final String label;
}

/// Customer scaffold background — follows light/dark semantic surface tokens.
class BuyerScreenScaffold extends StatelessWidget {
  const BuyerScreenScaffold({
    super.key,
    required this.body,
    this.bottomNavigationBar,
    this.appBar,
    this.drawer,
  });

  final Widget body;
  final Widget? bottomNavigationBar;
  final PreferredSizeWidget? appBar;
  final Widget? drawer;

  @override
  Widget build(BuildContext context) {
    final isDark = context.isDark;
    return AnnotatedRegion<SystemUiOverlayStyle>(
      value: isDark ? SystemUiOverlayStyle.light : SystemUiOverlayStyle.dark,
      child: Scaffold(
        backgroundColor: context.colors.surface,
        appBar: appBar,
        drawer: drawer,
        body: body,
        bottomNavigationBar: bottomNavigationBar,
      ),
    );
  }
}
