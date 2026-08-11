import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../theme/app_colors.dart';
import '../theme/app_shadows.dart';
import '../theme/app_spacing.dart';
import '../utils/directional_ui.dart';
import 'app_brand_logo.dart';

/// Customer-facing UI components matching the Home Screen mockup.
class BuyerShellHeader extends StatelessWidget {
  const BuyerShellHeader({
    super.key,
    required this.onMenu,
    required this.onNotifications,
    required this.onProfile,
    this.showPremiumBadge = false,
  });

  final VoidCallback onMenu;
  final VoidCallback onNotifications;
  final VoidCallback onProfile;
  final bool showPremiumBadge;

  static const double _sideSlotWidth = 88;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: AppSpacing.screenHorizontal),
      child: SizedBox(
        height: 40,
        child: Stack(
          alignment: Alignment.center,
          children: [
            Align(
              alignment: AlignmentDirectional.centerStart,
              child: SizedBox(
                width: _sideSlotWidth,
                child: _HeaderIconButton(
                  icon: Icons.menu_rounded,
                  onTap: onMenu,
                ),
              ),
            ),
            Center(
              child: AppBrandLogo.forContext(
                AppBrandContext.compactBranding,
                includeClearSpace: false,
              ),
            ),
            Align(
              alignment: AlignmentDirectional.centerEnd,
              child: SizedBox(
                width: _sideSlotWidth,
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.end,
                  children: [
                    _HeaderIconButton(
                      icon: Icons.notifications_none_rounded,
                      onTap: onNotifications,
                    ),
                    const SizedBox(width: AppSpacing.xs),
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
                                color: AppColors.outlineSubtle(context),
                                width: 2,
                              ),
                              boxShadow: AppShadows.softFor(context, blur: 12, y: 2),
                            ),
                            child: CircleAvatar(
                              backgroundColor: AppColors.iconCircle(context),
                              child: const Icon(
                                Icons.person_rounded,
                                color: AppColors.lavender,
                                size: 22,
                              ),
                            ),
                          ),
                        ),
                        if (showPremiumBadge)
                          PositionedDirectional(
                            end: -2,
                            bottom: -2,
                            child: Container(
                              padding: const EdgeInsets.all(3),
                              decoration: BoxDecoration(
                                color: AppColors.badgeBorder(context),
                                shape: BoxShape.circle,
                              ),
                              child: const Icon(
                                Icons.workspace_premium_rounded,
                                size: 14,
                                color: AppColors.goldenCrown,
                              ),
                            ),
                          ),
                      ],
                    ),
                  ],
                ),
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
          child: Icon(icon, size: 24, color: AppColors.onSurface(context)),
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
        const Icon(Icons.location_on_rounded, size: 18, color: AppColors.lavender),
        const SizedBox(width: 4),
        Text(
          city,
          style: Theme.of(context).textTheme.titleSmall?.copyWith(
                fontWeight: FontWeight.w600,
                color: AppColors.lavender,
              ),
        ),
        if (onTap != null)
          const Icon(Icons.keyboard_arrow_down_rounded,
              size: 20, color: AppColors.lavender),
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
        const SizedBox(height: AppSpacing.xs),
        Text(
          subtitle,
          style: Theme.of(context).textTheme.bodyLarge?.copyWith(
                color: AppColors.onSurfaceVariant(context),
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
    final hintColor = AppColors.onSurfaceVariant(context);

    final field = Container(
      height: 52,
      decoration: BoxDecoration(
        color: AppColors.searchBar(context),
        borderRadius: BorderRadius.circular(28),
        border: Border.all(color: AppColors.outlineSubtle(context)),
        boxShadow: AppShadows.softFor(context, blur: 16, y: 3),
      ),
      padding: const EdgeInsets.symmetric(horizontal: 6),
      child: Row(
        children: [
          const SizedBox(width: 8),
          Icon(Icons.search_rounded, color: hintColor, size: 22),
          const SizedBox(width: 8),
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
                        color: hintColor,
                        fontSize: 15,
                      ),
                    ),
                  )
                : Text(
                    hint,
                    style: TextStyle(
                      color: hintColor,
                      fontSize: 15,
                    ),
                  ),
          ),
          if (onFilter != null)
            Material(
              color: AppColors.filterChip(context),
              borderRadius: BorderRadius.circular(20),
              child: InkWell(
                onTap: onFilter,
                borderRadius: BorderRadius.circular(20),
                child: const SizedBox(
                  width: 40,
                  height: 40,
                  child: Icon(Icons.tune_rounded, color: AppColors.lavender, size: 20),
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
  const BuyerQuickCategoryTile({
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
                  color: tint ?? AppColors.mutedSurface(context),
                  borderRadius: BorderRadius.circular(20),
                  boxShadow: AppShadows.softFor(context, blur: 12, y: 3),
                ),
                child: Icon(icon, color: AppColors.lavender, size: 28),
              ),
              const SizedBox(height: AppSpacing.xs),
              Text(
                label,
                maxLines: 2,
                textAlign: TextAlign.center,
                overflow: TextOverflow.ellipsis,
                style: Theme.of(context).textTheme.bodySmall?.copyWith(
                      fontWeight: FontWeight.w600,
                      fontSize: 11,
                      height: 1.2,
                    ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class BuyerPromoBanner extends StatelessWidget {
  const BuyerPromoBanner({
    super.key,
    required this.title,
    required this.subtitle,
    required this.ctaLabel,
    required this.onTap,
    this.gradientColors,
  });

  final String title;
  final String subtitle;
  final String ctaLabel;
  final VoidCallback onTap;
  final List<Color>? gradientColors;

  @override
  Widget build(BuildContext context) {
    return Container(
      constraints: const BoxConstraints(minHeight: 152),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: AlignmentDirectional.centerStart,
          end: AlignmentDirectional.centerEnd,
          colors: gradientColors ?? AppColors.promoBannerGradient(context),
        ),
        borderRadius: BorderRadius.circular(AppSpacing.cardRadiusLg),
        boxShadow: AppShadows.softFor(context, blur: 20, y: 4),
      ),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(AppSpacing.cardRadiusLg),
          child: Padding(
            padding: const EdgeInsets.all(AppSpacing.lg),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.center,
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(
                        title,
                        style: Theme.of(context).textTheme.titleLarge?.copyWith(
                              fontWeight: FontWeight.w800,
                              height: 1.2,
                            ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        subtitle,
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                        style: Theme.of(context).textTheme.bodySmall?.copyWith(
                              color: AppColors.onSurfaceVariant(context),
                            ),
                      ),
                      const SizedBox(height: AppSpacing.sm),
                      Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 16,
                          vertical: 8,
                        ),
                        decoration: BoxDecoration(
                          color: AppColors.lavender,
                          borderRadius: BorderRadius.circular(999),
                        ),
                        child: Text(
                          ctaLabel,
                          style: TextStyle(
                            color: Theme.of(context).colorScheme.onPrimary,
                            fontWeight: FontWeight.w700,
                            fontSize: 13,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(width: 4),
                Icon(
                  Icons.chair_outlined,
                  size: 48,
                  color: AppColors.lavender.withValues(alpha: 0.25),
                ),
                Icon(
                  Icons.shopping_bag_outlined,
                  size: 36,
                  color: AppColors.beige.withValues(alpha: 0.9),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class BuyerPromoCarousel extends StatefulWidget {
  const BuyerPromoCarousel({super.key, required this.slides});

  final List<Widget> slides;

  @override
  State<BuyerPromoCarousel> createState() => _BuyerPromoCarouselState();
}

class _BuyerPromoCarouselState extends State<BuyerPromoCarousel> {
  final _controller = PageController();
  int _index = 0;

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    if (widget.slides.isEmpty) return const SizedBox.shrink();
    return Column(
      children: [
        SizedBox(
          height: 160,
          child: PageView.builder(
            controller: _controller,
            itemCount: widget.slides.length,
            onPageChanged: (i) => setState(() => _index = i),
            itemBuilder: (_, i) => Padding(
              padding: const EdgeInsets.symmetric(horizontal: 2),
              child: widget.slides[i],
            ),
          ),
        ),
        const SizedBox(height: AppSpacing.sm),
        Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: List.generate(widget.slides.length, (i) {
            final active = i == _index;
            return AnimatedContainer(
              duration: const Duration(milliseconds: 220),
              margin: const EdgeInsets.symmetric(horizontal: 3),
              width: active ? 20 : 6,
              height: 6,
              decoration: BoxDecoration(
                color: active
                    ? AppColors.lavender
                    : AppColors.outline(context),
                borderRadius: BorderRadius.circular(3),
              ),
            );
          }),
        ),
      ],
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
      padding: const EdgeInsets.symmetric(horizontal: AppSpacing.screenHorizontal),
      child: Row(
        children: [
          Text(
            title,
            style: Theme.of(context).textTheme.titleMedium?.copyWith(
                  fontWeight: FontWeight.w800,
                ),
          ),
          const Spacer(),
          if (actionLabel != null && onAction != null)
            TextButton(
              onPressed: onAction,
              style: TextButton.styleFrom(
                foregroundColor: AppColors.lavender,
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

  @override
  Widget build(BuildContext context) {
    final isDark = AppColors.isDark(context);
    return SizedBox(
      width: 200,
      child: Material(
        color: AppColors.cardSurface(context),
        elevation: 0,
        shadowColor: Colors.transparent,
        borderRadius: BorderRadius.circular(AppSpacing.cardRadiusLg),
        clipBehavior: Clip.antiAlias,
        child: InkWell(
          onTap: onTap,
          child: DecoratedBox(
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(AppSpacing.cardRadiusLg),
              boxShadow: AppShadows.card(isDark: isDark),
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
                              errorBuilder: (_, __, ___) =>
                                  _imagePlaceholder(context))
                          : _imagePlaceholder(context),
                      PositionedDirectional(
                        start: 8,
                        bottom: 8,
                        child: Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 8,
                            vertical: 4,
                          ),
                          decoration: BoxDecoration(
                            color: AppColors.lavender,
                            borderRadius: BorderRadius.circular(999),
                          ),
                          child: Text(
                            distanceLabel,
                            style: const TextStyle(
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
                          color: AppColors.favoriteButton(context),
                          shape: const CircleBorder(),
                          elevation: 1,
                          child: InkWell(
                            customBorder: const CircleBorder(),
                            onTap: onFavorite,
                            child: Padding(
                              padding: const EdgeInsets.all(6),
                              child: Icon(
                                isFavorite
                                    ? Icons.favorite_rounded
                                    : Icons.favorite_border_rounded,
                                size: 18,
                                color: AppColors.lavender,
                              ),
                            ),
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
                Padding(
                  padding: const EdgeInsets.fromLTRB(12, 10, 12, 12),
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
                          color: AppColors.onSurface(context),
                        ),
                      ),
                      if (subtitle.isNotEmpty) ...[
                        const SizedBox(height: 2),
                        Text(
                          subtitle,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: TextStyle(
                            color: AppColors.onSurfaceVariant(context),
                            fontSize: 12,
                          ),
                        ),
                      ],
                      if (priceLabel.isNotEmpty) ...[
                        const SizedBox(height: 4),
                        Text(
                          priceLabel,
                          style: TextStyle(
                            fontWeight: FontWeight.w800,
                            fontSize: 14,
                            color: AppColors.onSurface(context),
                          ),
                        ),
                      ],
                      const SizedBox(height: 6),
                      Row(
                        children: [
                          const Icon(Icons.location_on_outlined,
                              size: 12, color: AppColors.lavender),
                          const SizedBox(width: 2),
                          Expanded(
                            child: Text(
                              locationLabel,
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: const TextStyle(
                                color: AppColors.lavender,
                                fontSize: 11,
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 6),
                      Row(
                        children: [
                          CircleAvatar(
                            radius: 10,
                            backgroundColor: AppColors.iconCircle(context),
                            backgroundImage: sellerAvatarUrl.isNotEmpty
                                ? NetworkImage(sellerAvatarUrl)
                                : null,
                            child: sellerAvatarUrl.isEmpty
                                ? const Icon(Icons.store, size: 10)
                                : null,
                          ),
                          const SizedBox(width: 6),
                          const Icon(Icons.star_rounded,
                              size: 14, color: AppColors.star),
                          const SizedBox(width: 2),
                          Text(
                            rating.toStringAsFixed(1),
                            style: TextStyle(
                              fontSize: 12,
                              fontWeight: FontWeight.w700,
                              color: AppColors.onSurface(context),
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
      color: AppColors.imagePlaceholder(context),
      child: const Center(
        child: Icon(Icons.storefront_rounded, color: AppColors.lavender, size: 40),
      ),
    );
  }
}

class BuyerPopularCategoryCard extends StatelessWidget {
  const BuyerPopularCategoryCard({
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
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(AppSpacing.cardRadius),
        child: Container(
          padding: const EdgeInsets.symmetric(vertical: AppSpacing.md),
          decoration: BoxDecoration(
            color: tint ?? AppColors.mutedSurface(context),
            borderRadius: BorderRadius.circular(AppSpacing.cardRadius),
            boxShadow: AppShadows.softFor(context, blur: 14, y: 3),
          ),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(icon, size: 32, color: AppColors.lavender),
              const SizedBox(height: AppSpacing.sm),
              Text(
                label,
                textAlign: TextAlign.center,
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(
                  fontWeight: FontWeight.w700,
                  fontSize: 13,
                  color: AppColors.onSurface(context),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// Large screen title used at the top of tab screens.
class BuyerScreenTitle extends StatelessWidget {
  const BuyerScreenTitle({
    super.key,
    required this.title,
    this.subtitle,
    this.trailing,
  });

  final String title;
  final String? subtitle;
  final Widget? trailing;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(
        AppSpacing.screenHorizontal,
        AppSpacing.md,
        AppSpacing.screenHorizontal,
        AppSpacing.sm,
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                        fontWeight: FontWeight.w800,
                        letterSpacing: -0.4,
                      ),
                ),
                if (subtitle != null) ...[
                  const SizedBox(height: 4),
                  Text(
                    subtitle!,
                    style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                          color: AppColors.onSurfaceVariant(context),
                        ),
                  ),
                ],
              ],
            ),
          ),
          if (trailing != null) trailing!,
        ],
      ),
    );
  }
}

/// White elevated app bar for pushed customer routes.
class BuyerAppBar extends StatelessWidget implements PreferredSizeWidget {
  const BuyerAppBar({
    super.key,
    required this.title,
    this.actions,
    this.leading,
  });

  final String title;
  final List<Widget>? actions;
  final Widget? leading;

  @override
  Size get preferredSize => const Size.fromHeight(kToolbarHeight);

  @override
  Widget build(BuildContext context) {
    return AppBar(
      backgroundColor: AppColors.scaffold(context),
      surfaceTintColor: Colors.transparent,
      elevation: 0,
      scrolledUnderElevation: 0,
      leading: leading,
      title: Text(
        title,
        style: Theme.of(context).textTheme.titleLarge?.copyWith(
              fontWeight: FontWeight.w700,
            ),
      ),
      actions: actions,
      bottom: PreferredSize(
        preferredSize: const Size.fromHeight(1),
        child: Container(
          height: 1,
          color: AppColors.outlineSubtle(context),
        ),
      ),
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
      color: AppColors.cardSurface(context),
      borderRadius: BorderRadius.circular(AppSpacing.cardRadius),
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(AppSpacing.cardRadius),
        child: DecoratedBox(
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(AppSpacing.cardRadius),
            boxShadow: AppShadows.softFor(context, blur: 16, y: 4),
          ),
          child: content,
        ),
      ),
    );
  }
}

/// Settings / profile menu row matching the mockup rhythm.
class BuyerMenuTile extends StatelessWidget {
  const BuyerMenuTile({
    super.key,
    required this.icon,
    required this.title,
    this.subtitle,
    this.trailing,
    this.onTap,
    this.iconColor = AppColors.lavender,
    this.destructive = false,
  });

  final IconData icon;
  final String title;
  final String? subtitle;
  final Widget? trailing;
  final VoidCallback? onTap;
  final Color iconColor;
  final bool destructive;

  @override
  Widget build(BuildContext context) {
    final color =
        destructive ? AppColors.danger : AppColors.onSurface(context);
    return Material(
      color: AppColors.cardSurface(context),
      borderRadius: BorderRadius.circular(AppSpacing.cardRadius),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(AppSpacing.cardRadius),
        child: Container(
          padding: const EdgeInsets.symmetric(
            horizontal: AppSpacing.md,
            vertical: AppSpacing.md,
          ),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(AppSpacing.cardRadius),
            boxShadow: AppShadows.softFor(context, blur: 12, y: 2),
          ),
          child: Row(
            children: [
              Container(
                width: 40,
                height: 40,
                decoration: BoxDecoration(
                  color: destructive
                      ? AppColors.destructiveIconBg(context)
                      : AppColors.iconCircle(context),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Icon(
                  icon,
                  color: destructive ? AppColors.danger : iconColor,
                  size: 20,
                ),
              ),
              const SizedBox(width: AppSpacing.md),
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
                      const SizedBox(height: 2),
                      Text(
                        subtitle!,
                        style: TextStyle(
                          color: AppColors.onSurfaceVariant(context),
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
                  color: AppColors.onSurfaceVariant(context),
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
        padding: const EdgeInsets.all(AppSpacing.xl),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 72,
              height: 72,
              decoration: BoxDecoration(
                color: AppColors.emptyStateCircle(context),
                shape: BoxShape.circle,
                boxShadow: AppShadows.softFor(context, blur: 20),
              ),
              child: Icon(icon, size: 32, color: AppColors.lavender),
            ),
            const SizedBox(height: AppSpacing.lg),
            Text(
              title,
              textAlign: TextAlign.center,
              style: Theme.of(context).textTheme.titleMedium?.copyWith(
                    fontWeight: FontWeight.w800,
                  ),
            ),
            if (subtitle != null) ...[
              const SizedBox(height: AppSpacing.sm),
              Text(
                subtitle!,
                textAlign: TextAlign.center,
                style: TextStyle(
                  color: AppColors.onSurfaceVariant(context),
                  height: 1.4,
                ),
              ),
            ],
            if (actionLabel != null && onAction != null) ...[
              const SizedBox(height: AppSpacing.lg),
              FilledButton(
                onPressed: onAction,
                style: FilledButton.styleFrom(
                  backgroundColor: AppColors.lavender,
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
      padding: const EdgeInsets.all(4),
      decoration: BoxDecoration(
        color: AppColors.segmentedTrack(context),
        borderRadius: BorderRadius.circular(999),
      ),
      child: Row(
        children: segments.map((segment) {
          final active = segment.value == selected;
          return Expanded(
            child: AnimatedContainer(
              duration: const Duration(milliseconds: 200),
              curve: Curves.easeOutCubic,
              decoration: BoxDecoration(
                color: active
                    ? AppColors.segmentedThumb(context)
                    : Colors.transparent,
                borderRadius: BorderRadius.circular(999),
                boxShadow: active
                    ? AppShadows.softFor(context, blur: 8, y: 2)
                    : null,
              ),
              child: Material(
                color: Colors.transparent,
                child: InkWell(
                  onTap: () => onChanged(segment.value),
                  borderRadius: BorderRadius.circular(999),
                  child: Padding(
                    padding: const EdgeInsets.symmetric(vertical: 10),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(
                          segment.icon,
                          size: 16,
                          color: active
                              ? AppColors.lavender
                              : AppColors.onSurfaceVariant(context),
                        ),
                        const SizedBox(width: 6),
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
                                  ? AppColors.lavender
                                  : AppColors.onSurfaceVariant(context),
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
    final isDark = AppColors.isDark(context);
    return Container(
      decoration: BoxDecoration(
        color: AppColors.navBar(context),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: isDark ? 0.35 : 0.05),
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
                                ? AppColors.lavender
                                : AppColors.onSurfaceVariant(context),
                            size: 24,
                          ),
                          if ((badges[i] ?? 0) > 0)
                            PositionedDirectional(
                              end: -10,
                              top: -4,
                              child: Container(
                                padding: const EdgeInsets.symmetric(
                                  horizontal: 5,
                                  vertical: 2,
                                ),
                                decoration: BoxDecoration(
                                  color: AppColors.danger,
                                  borderRadius: BorderRadius.circular(10),
                                  border: Border.all(
                                    color: Colors.white,
                                    width: 1.5,
                                  ),
                                ),
                                constraints: const BoxConstraints(
                                  minWidth: 16,
                                  minHeight: 16,
                                ),
                                child: Text(
                                  (badges[i]! > 99) ? '99+' : '${badges[i]}',
                                  style: const TextStyle(
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
                      const SizedBox(height: 4),
                      Text(
                        item.label,
                        style: TextStyle(
                          fontSize: 11,
                          fontWeight:
                              selected ? FontWeight.w700 : FontWeight.w500,
                          color: selected
                              ? AppColors.lavender
                              : AppColors.onSurfaceVariant(context),
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

/// Customer shell scaffold — follows [MaterialApp] theme (light and dark).
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
    final isDark = AppColors.isDark(context);
    return AnnotatedRegion<SystemUiOverlayStyle>(
      value: isDark ? SystemUiOverlayStyle.light : SystemUiOverlayStyle.dark,
      child: Scaffold(
        backgroundColor: Theme.of(context).scaffoldBackgroundColor,
        appBar: appBar,
        drawer: drawer,
        body: body,
        bottomNavigationBar: bottomNavigationBar,
      ),
    );
  }
}
