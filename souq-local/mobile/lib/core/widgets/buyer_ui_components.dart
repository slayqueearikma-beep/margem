import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../theme/app_colors.dart';
import '../theme/app_shadows.dart';
import '../theme/app_spacing.dart';
import 'margem_m_logo.dart';

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

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: AppSpacing.screenHorizontal),
      child: Row(
        children: [
          _HeaderIconButton(
            icon: Icons.menu_rounded,
            onTap: onMenu,
          ),
          const Spacer(),
          const MargemMLogo(size: 32),
          const Spacer(),
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
                    border: Border.all(color: AppColors.borderLight, width: 2),
                    boxShadow: AppShadows.soft(blur: 12, y: 2),
                  ),
                  child: const CircleAvatar(
                    backgroundColor: AppColors.lavenderMuted,
                    child: Icon(
                      Icons.person_rounded,
                      color: AppColors.lavender,
                      size: 22,
                    ),
                  ),
                ),
              ),
              if (showPremiumBadge)
                Positioned(
                  right: -2,
                  bottom: -2,
                  child: Container(
                    padding: const EdgeInsets.all(3),
                    decoration: const BoxDecoration(
                      color: Colors.white,
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
          child: Icon(icon, size: 24, color: AppColors.navy),
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
                color: AppColors.textSecondary,
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
        color: Colors.white,
        borderRadius: BorderRadius.circular(28),
        boxShadow: AppShadows.soft(blur: 20, y: 4),
      ),
      padding: const EdgeInsets.symmetric(horizontal: 6),
      child: Row(
        children: [
          const SizedBox(width: 8),
          const Icon(Icons.search_rounded, color: AppColors.textTertiary, size: 22),
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
                      hintStyle: const TextStyle(
                        color: AppColors.textTertiary,
                        fontSize: 15,
                      ),
                    ),
                  )
                : Text(
                    hint,
                    style: const TextStyle(
                      color: AppColors.textTertiary,
                      fontSize: 15,
                    ),
                  ),
          ),
          if (onFilter != null)
            Material(
              color: AppColors.lavenderMuted,
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
    this.tint = AppColors.lavenderMuted,
  });

  final String label;
  final IconData icon;
  final VoidCallback onTap;
  final Color tint;

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
                  color: tint,
                  borderRadius: BorderRadius.circular(20),
                  boxShadow: AppShadows.soft(blur: 12, y: 3),
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
    this.gradientColors = const [Color(0xFFE8DEFF), Color(0xFFF3EEFF)],
  });

  final String title;
  final String subtitle;
  final String ctaLabel;
  final VoidCallback onTap;
  final List<Color> gradientColors;

  @override
  Widget build(BuildContext context) {
    return Container(
      height: 148,
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.centerLeft,
          end: Alignment.centerRight,
          colors: gradientColors,
        ),
        borderRadius: BorderRadius.circular(AppSpacing.cardRadiusLg),
        boxShadow: AppShadows.soft(color: AppColors.lavender, blur: 24, y: 6),
      ),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(AppSpacing.cardRadiusLg),
          child: Padding(
            padding: const EdgeInsets.all(AppSpacing.lg),
            child: Row(
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    mainAxisAlignment: MainAxisAlignment.center,
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
                        style: Theme.of(context).textTheme.bodySmall?.copyWith(
                              color: AppColors.textSecondary,
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
                          style: const TextStyle(
                            color: Colors.white,
                            fontWeight: FontWeight.w700,
                            fontSize: 13,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(width: 8),
                Icon(
                  Icons.chair_outlined,
                  size: 56,
                  color: AppColors.lavender.withValues(alpha: 0.35),
                ),
                Icon(
                  Icons.shopping_bag_outlined,
                  size: 40,
                  color: AppColors.peach.withValues(alpha: 0.6),
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
          height: 148,
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
                color: active ? AppColors.lavender : AppColors.border,
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
                  const Icon(Icons.chevron_right_rounded, size: 18),
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
    return SizedBox(
      width: 200,
      child: Material(
        color: Colors.white,
        elevation: 0,
        shadowColor: Colors.transparent,
        borderRadius: BorderRadius.circular(AppSpacing.cardRadiusLg),
        clipBehavior: Clip.antiAlias,
        child: InkWell(
          onTap: onTap,
          child: DecoratedBox(
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(AppSpacing.cardRadiusLg),
              boxShadow: AppShadows.card(),
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
                              errorBuilder: (_, __, ___) => _imagePlaceholder())
                          : _imagePlaceholder(),
                      Positioned(
                        left: 8,
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
                      Positioned(
                        top: 8,
                        right: 8,
                        child: Material(
                          color: Colors.white,
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
                        style: const TextStyle(
                          fontWeight: FontWeight.w800,
                          fontSize: 15,
                        ),
                      ),
                      if (subtitle.isNotEmpty) ...[
                        const SizedBox(height: 2),
                        Text(
                          subtitle,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: const TextStyle(
                            color: AppColors.textSecondary,
                            fontSize: 12,
                          ),
                        ),
                      ],
                      if (priceLabel.isNotEmpty) ...[
                        const SizedBox(height: 4),
                        Text(
                          priceLabel,
                          style: const TextStyle(
                            fontWeight: FontWeight.w800,
                            fontSize: 14,
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
                            backgroundColor: AppColors.lavenderMuted,
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

  Widget _imagePlaceholder() {
    return Container(
      color: AppColors.lavenderMuted,
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
    this.tint = AppColors.lavenderMuted,
  });

  final String label;
  final IconData icon;
  final VoidCallback onTap;
  final Color tint;

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
            color: tint,
            borderRadius: BorderRadius.circular(AppSpacing.cardRadius),
            boxShadow: AppShadows.soft(blur: 14, y: 3),
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
                style: const TextStyle(
                  fontWeight: FontWeight.w700,
                  fontSize: 13,
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
                          color: AppColors.textSecondary,
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
      backgroundColor: Colors.white,
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
          color: AppColors.borderLight,
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
      color: Colors.white,
      borderRadius: BorderRadius.circular(AppSpacing.cardRadius),
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(AppSpacing.cardRadius),
        child: DecoratedBox(
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(AppSpacing.cardRadius),
            boxShadow: AppShadows.soft(blur: 16, y: 4),
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
    final color = destructive ? AppColors.danger : AppColors.navy;
    return Material(
      color: Colors.white,
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
            boxShadow: AppShadows.soft(blur: 12, y: 2),
          ),
          child: Row(
            children: [
              Container(
                width: 40,
                height: 40,
                decoration: BoxDecoration(
                  color: destructive
                      ? AppColors.dangerMuted
                      : AppColors.lavenderMuted,
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
                        style: const TextStyle(
                          color: AppColors.textSecondary,
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
                const Icon(
                  Icons.chevron_right_rounded,
                  color: AppColors.textTertiary,
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
                color: AppColors.lavenderMuted,
                shape: BoxShape.circle,
                boxShadow: AppShadows.soft(color: AppColors.lavender, blur: 20),
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
                style: const TextStyle(
                  color: AppColors.textSecondary,
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
        color: AppColors.lavenderMuted,
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
                color: active ? Colors.white : Colors.transparent,
                borderRadius: BorderRadius.circular(999),
                boxShadow: active ? AppShadows.soft(blur: 8, y: 2) : null,
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
                              : AppColors.textTertiary,
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
                                  : AppColors.textTertiary,
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
        color: Colors.white,
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
                                ? AppColors.lavender
                                : AppColors.textTertiary,
                            size: 24,
                          ),
                          if ((badges[i] ?? 0) > 0)
                            Positioned(
                              right: -10,
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
                              : AppColors.textTertiary,
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

/// White scaffold background for all customer screens.
class BuyerScreenScaffold extends StatelessWidget {
  const BuyerScreenScaffold({
    super.key,
    required this.body,
    this.bottomNavigationBar,
    this.appBar,
  });

  final Widget body;
  final Widget? bottomNavigationBar;
  final PreferredSizeWidget? appBar;

  @override
  Widget build(BuildContext context) {
    return AnnotatedRegion<SystemUiOverlayStyle>(
      value: SystemUiOverlayStyle.dark,
      child: Scaffold(
        backgroundColor: Colors.white,
        appBar: appBar,
        body: body,
        bottomNavigationBar: bottomNavigationBar,
      ),
    );
  }
}
