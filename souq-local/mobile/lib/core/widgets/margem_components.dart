import 'package:flutter/material.dart';

import '../theme/app_colors.dart';
import '../theme/app_shadows.dart';
import '../theme/app_spacing.dart';

/// Pill-shaped search bar matching the MarGem reference.
class MarGemSearchBar extends StatelessWidget {
  const MarGemSearchBar({
    super.key,
    required this.hint,
    this.onTap,
    this.onChanged,
    this.controller,
    this.focusNode,
    this.autofocus = false,
    this.trailing,
    this.readOnly = false,
  });

  final String hint;
  final VoidCallback? onTap;
  final ValueChanged<String>? onChanged;
  final TextEditingController? controller;
  final FocusNode? focusNode;
  final bool autofocus;
  final Widget? trailing;
  final bool readOnly;

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    if (onTap != null && controller == null) {
      return Material(
        color: isDark ? AppColors.darkCard : AppColors.surfaceMuted,
        borderRadius: BorderRadius.circular(AppSpacing.inputRadius),
        elevation: 0,
        shadowColor: Colors.transparent,
        child: InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(AppSpacing.inputRadius),
          child: Container(
            height: AppSpacing.searchBarHeight,
            padding: const EdgeInsets.symmetric(horizontal: 16),
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(AppSpacing.inputRadius),
              boxShadow: AppShadows.searchBar(isDark: isDark),
            ),
            child: Row(
              children: [
                Icon(
                  Icons.search_rounded,
                  color: AppColors.textTertiary,
                  size: 22,
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: Text(
                    hint,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                      color: AppColors.textTertiary,
                      fontSize: 14,
                    ),
                  ),
                ),
                if (trailing != null) trailing!,
              ],
            ),
          ),
        ),
      );
    }

    return TextField(
      controller: controller,
      focusNode: focusNode,
      autofocus: autofocus,
      readOnly: readOnly,
      onChanged: onChanged,
      onTap: onTap,
      style: const TextStyle(fontSize: 14),
      decoration: InputDecoration(
        hintText: hint,
        prefixIcon: const Icon(Icons.search_rounded, size: 22),
        suffixIcon: trailing,
        filled: true,
        fillColor: isDark ? AppColors.darkCard : AppColors.surfaceMuted,
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(AppSpacing.inputRadius),
          borderSide: BorderSide.none,
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(AppSpacing.inputRadius),
          borderSide: BorderSide.none,
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(AppSpacing.inputRadius),
          borderSide: const BorderSide(color: AppColors.primary, width: 1.5),
        ),
        contentPadding: const EdgeInsets.symmetric(vertical: 12),
      ),
    );
  }
}

/// Underline-style tab selector (Products / Sellers).
class MarGemUnderlineTabs extends StatelessWidget {
  const MarGemUnderlineTabs({
    super.key,
    required this.tabs,
    required this.selectedIndex,
    required this.onSelected,
  });

  final List<String> tabs;
  final int selectedIndex;
  final ValueChanged<int> onSelected;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: List.generate(tabs.length, (index) {
        final selected = index == selectedIndex;
        return Expanded(
          child: GestureDetector(
            onTap: () => onSelected(index),
            behavior: HitTestBehavior.opaque,
            child: Column(
              children: [
                Text(
                  tabs[index],
                  style: TextStyle(
                    fontSize: 14,
                    fontWeight: selected ? FontWeight.w700 : FontWeight.w500,
                    color: selected
                        ? AppColors.primary
                        : AppColors.textTertiary,
                  ),
                ),
                const SizedBox(height: 10),
                AnimatedContainer(
                  duration: const Duration(milliseconds: 200),
                  height: 2.5,
                  decoration: BoxDecoration(
                    color: selected ? AppColors.primary : Colors.transparent,
                    borderRadius: BorderRadius.circular(2),
                  ),
                ),
              ],
            ),
          ),
        );
      }),
    );
  }
}

/// Pill chip for recent/popular searches and filters.
class MarGemFilterChip extends StatelessWidget {
  const MarGemFilterChip({
    super.key,
    required this.label,
    required this.selected,
    required this.onTap,
    this.icon,
  });

  final String label;
  final bool selected;
  final VoidCallback onTap;
  final IconData? icon;

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return Material(
      color: selected
          ? AppColors.primary
          : (isDark ? AppColors.darkCard : AppColors.surfaceMuted),
      borderRadius: BorderRadius.circular(AppSpacing.chipRadius),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(AppSpacing.chipRadius),
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              if (icon != null) ...[
                Icon(
                  icon,
                  size: 16,
                  color: selected ? Colors.white : AppColors.textSecondary,
                ),
                const SizedBox(width: 6),
              ],
              Text(
                label,
                style: TextStyle(
                  fontSize: 13,
                  fontWeight: FontWeight.w500,
                  color: selected ? Colors.white : AppColors.textSecondary,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// Circular category icon for horizontal scroll lists.
class MarGemCategoryIcon extends StatelessWidget {
  const MarGemCategoryIcon({
    super.key,
    required this.label,
    required this.icon,
    required this.selected,
    required this.onTap,
  });

  final String label;
  final IconData icon;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return GestureDetector(
      onTap: onTap,
      child: SizedBox(
        width: 72,
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            AnimatedContainer(
              duration: const Duration(milliseconds: 200),
              width: AppSpacing.categoryIconSize,
              height: AppSpacing.categoryIconSize,
              decoration: BoxDecoration(
                color: selected
                    ? AppColors.primary
                    : (isDark ? AppColors.darkCard : AppColors.surfaceMuted),
                shape: BoxShape.circle,
                boxShadow: selected ? AppShadows.card() : null,
              ),
              alignment: Alignment.center,
              child: Icon(
                icon,
                size: 24,
                color: selected ? Colors.white : AppColors.primary,
              ),
            ),
            const SizedBox(height: 6),
            Text(
              label,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              textAlign: TextAlign.center,
              style: TextStyle(
                fontSize: 11,
                fontWeight: selected ? FontWeight.w600 : FontWeight.w500,
                color: selected ? AppColors.primary : AppColors.textSecondary,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// Promotional hero banner card — illustration + optional CTA only.
class MarGemHeroBanner extends StatelessWidget {
  const MarGemHeroBanner({
    super.key,
    this.title,
    this.actionLabel,
    this.onAction,
    this.backgroundColor,
    this.icon = Icons.chair_outlined,
  });

  final String? title;
  final String? actionLabel;
  final VoidCallback? onAction;
  final Color? backgroundColor;
  final IconData icon;

  @override
  Widget build(BuildContext context) {
    final bg = backgroundColor ?? AppColors.heroBackground;
    return Container(
      height: 112,
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(AppSpacing.cardRadius),
        gradient: LinearGradient(
          begin: Alignment.centerLeft,
          end: Alignment.centerRight,
          colors: [
            bg,
            AppColors.primary.withValues(alpha: 0.08),
          ],
        ),
        boxShadow: AppShadows.card(),
      ),
      clipBehavior: Clip.antiAlias,
      child: Stack(
        children: [
          Positioned(
            right: -6,
            top: -6,
            bottom: -6,
            child: Opacity(
              opacity: 0.22,
              child: Icon(icon, size: 110, color: AppColors.primary),
            ),
          ),
          Padding(
            padding: const EdgeInsets.all(16),
            child: Row(
              children: [
                if (title != null && title!.isNotEmpty) ...[
                  Expanded(
                    child: Text(
                      title!,
                      style: const TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.w700,
                        height: 1.25,
                      ),
                    ),
                  ),
                ] else
                  const Spacer(),
                if (actionLabel != null && onAction != null)
                  Material(
                    color: AppColors.primary,
                    borderRadius:
                        BorderRadius.circular(AppSpacing.buttonRadius),
                    child: InkWell(
                      onTap: onAction,
                      borderRadius:
                          BorderRadius.circular(AppSpacing.buttonRadius),
                      child: Padding(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 16,
                          vertical: 8,
                        ),
                        child: Text(
                          actionLabel!,
                          style: const TextStyle(
                            color: Colors.white,
                            fontSize: 12,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ),
                    ),
                  ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

/// Verified seller badge.
class MarGemVerifiedBadge extends StatelessWidget {
  const MarGemVerifiedBadge({super.key, this.compact = false});

  final bool compact;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: EdgeInsets.symmetric(
        horizontal: compact ? 6 : 8,
        vertical: compact ? 2 : 4,
      ),
      decoration: BoxDecoration(
        color: AppColors.success.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(AppSpacing.chipRadius),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(
            Icons.verified_rounded,
            size: compact ? 12 : 14,
            color: AppColors.success,
          ),
          if (!compact) ...[
            const SizedBox(width: 4),
            Text(
              'Verified Seller',
              style: TextStyle(
                fontSize: 11,
                fontWeight: FontWeight.w600,
                color: AppColors.success,
              ),
            ),
          ],
        ],
      ),
    );
  }
}

/// Online status indicator dot.
class MarGemOnlineDot extends StatelessWidget {
  const MarGemOnlineDot({super.key, this.size = 10});

  final double size;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: size,
      height: size,
      decoration: BoxDecoration(
        color: AppColors.success,
        shape: BoxShape.circle,
        border: Border.all(color: Colors.white, width: 2),
      ),
    );
  }
}

/// Profile stat column (Products, Followers, etc.).
class MarGemStatColumn extends StatelessWidget {
  const MarGemStatColumn({
    super.key,
    required this.value,
    required this.label,
  });

  final String value;
  final String label;

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        Text(
          value,
          style: const TextStyle(
            fontSize: 18,
            fontWeight: FontWeight.w700,
          ),
        ),
        const SizedBox(height: 2),
        Text(
          label,
          style: const TextStyle(
            fontSize: 12,
            color: AppColors.textTertiary,
            fontWeight: FontWeight.w500,
          ),
        ),
      ],
    );
  }
}

/// Settings/profile menu row with icon and chevron.
class MarGemMenuTile extends StatelessWidget {
  const MarGemMenuTile({
    super.key,
    required this.title,
    required this.icon,
    this.subtitle,
    this.onTap,
    this.trailing,
    this.titleColor,
  });

  final String title;
  final IconData icon;
  final String? subtitle;
  final VoidCallback? onTap;
  final Widget? trailing;
  final Color? titleColor;

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(AppSpacing.cardRadius),
        child: Padding(
          padding: const EdgeInsets.symmetric(vertical: 14),
          child: Row(
            children: [
              Container(
                width: 40,
                height: 40,
                decoration: BoxDecoration(
                  color: isDark
                      ? AppColors.primary.withValues(alpha: 0.15)
                      : AppColors.surfaceMuted,
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Icon(icon, size: 20, color: AppColors.primary),
              ),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      title,
                      style: TextStyle(
                        fontSize: 15,
                        fontWeight: FontWeight.w600,
                        color: titleColor,
                      ),
                    ),
                    if (subtitle != null) ...[
                      const SizedBox(height: 2),
                      Text(
                        subtitle!,
                        style: const TextStyle(
                          fontSize: 12,
                          color: AppColors.textTertiary,
                        ),
                      ),
                    ],
                  ],
                ),
              ),
              trailing ??
                  Icon(
                    Icons.chevron_right_rounded,
                    color: AppColors.textTertiary,
                    size: 22,
                  ),
            ],
          ),
        ),
      ),
    );
  }
}

/// Floating bottom action bar for product detail.
class MarGemBottomActionBar extends StatelessWidget {
  const MarGemBottomActionBar({
    super.key,
    required this.children,
  });

  final List<Widget> children;

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return Container(
      padding: const EdgeInsets.fromLTRB(
        AppSpacing.screenHorizontal,
        12,
        AppSpacing.screenHorizontal,
        12,
      ),
      decoration: BoxDecoration(
        color: isDark ? AppColors.darkSurface : Colors.white,
        boxShadow: AppShadows.bottomBar(isDark: isDark),
      ),
      child: SafeArea(
        top: false,
        child: Row(children: children),
      ),
    );
  }
}

/// Chat message bubble matching reference design.
class MarGemChatBubble extends StatelessWidget {
  const MarGemChatBubble({
    super.key,
    required this.message,
    required this.isMine,
    this.showReadReceipt = false,
  });

  final String message;
  final bool isMine;
  final bool showReadReceipt;

  @override
  Widget build(BuildContext context) {
    return Align(
      alignment: isMine ? Alignment.centerRight : Alignment.centerLeft,
      child: Container(
        margin: const EdgeInsets.only(bottom: 8),
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
        constraints: BoxConstraints(
          maxWidth: MediaQuery.sizeOf(context).width * 0.75,
        ),
        decoration: BoxDecoration(
          color: isMine ? AppColors.chatOutgoing : AppColors.chatIncoming,
          borderRadius: BorderRadius.only(
            topLeft: const Radius.circular(16),
            topRight: const Radius.circular(16),
            bottomLeft: Radius.circular(isMine ? 16 : 4),
            bottomRight: Radius.circular(isMine ? 4 : 16),
          ),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.end,
          children: [
            Flexible(
              child: Text(
                message,
                style: TextStyle(
                  fontSize: 14,
                  height: 1.4,
                  color: isMine ? Colors.white : AppColors.textPrimary,
                ),
              ),
            ),
            if (isMine && showReadReceipt) ...[
              const SizedBox(width: 4),
              const Icon(
                Icons.done_all_rounded,
                size: 14,
                color: Colors.white70,
              ),
            ],
          ],
        ),
      ),
    );
  }
}

/// Floating circular icon button over image galleries.
class MarGemOverlayIconButton extends StatelessWidget {
  const MarGemOverlayIconButton({
    super.key,
    required this.icon,
    required this.onPressed,
  });

  final IconData icon;
  final VoidCallback onPressed;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.white.withValues(alpha: 0.92),
      shape: const CircleBorder(),
      elevation: 2,
      shadowColor: Colors.black26,
      child: InkWell(
        customBorder: const CircleBorder(),
        onTap: onPressed,
        child: SizedBox(
          width: 40,
          height: 40,
          child: Icon(icon, size: 20, color: AppColors.textPrimary),
        ),
      ),
    );
  }
}

/// Gallery page indicator pill (e.g. "1/6").
class MarGemGalleryIndicator extends StatelessWidget {
  const MarGemGalleryIndicator({
    super.key,
    required this.current,
    required this.total,
  });

  final int current;
  final int total;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
      decoration: BoxDecoration(
        color: Colors.black.withValues(alpha: 0.55),
        borderRadius: BorderRadius.circular(AppSpacing.chipRadius),
      ),
      child: Text(
        '$current/$total',
        style: const TextStyle(
          color: Colors.white,
          fontSize: 12,
          fontWeight: FontWeight.w600,
        ),
      ),
    );
  }
}

/// Embedded seller card on product detail screen.
class MarGemSellerPreviewCard extends StatelessWidget {
  const MarGemSellerPreviewCard({
    super.key,
    required this.name,
    required this.imageUrl,
    required this.verified,
    required this.onTap,
    this.reviewLabel,
    this.viewProfileLabel = 'View profile',
  });

  final String name;
  final String imageUrl;
  final bool verified;
  final VoidCallback onTap;
  final String? reviewLabel;
  final String viewProfileLabel;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: AppColors.surfaceMuted,
        borderRadius: BorderRadius.circular(AppSpacing.cardRadius),
      ),
      child: Row(
        children: [
          CircleAvatar(
            radius: 24,
            backgroundColor: AppColors.primary.withValues(alpha: 0.1),
            child: ClipOval(
              child: SizedBox(
                width: 48,
                height: 48,
                child: imageUrl.isEmpty
                    ? const Icon(Icons.storefront_rounded,
                        color: AppColors.primary)
                    : Image.network(
                        imageUrl,
                        fit: BoxFit.cover,
                        errorBuilder: (_, __, ___) => const Icon(
                          Icons.storefront_rounded,
                          color: AppColors.primary,
                        ),
                      ),
              ),
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Flexible(
                      child: Text(
                        name,
                        style: const TextStyle(
                          fontWeight: FontWeight.w700,
                          fontSize: 15,
                        ),
                      ),
                    ),
                    if (verified) ...[
                      const SizedBox(width: 4),
                      const MarGemVerifiedBadge(compact: true),
                    ],
                  ],
                ),
                if (reviewLabel != null) ...[
                  const SizedBox(height: 2),
                  Text(
                    reviewLabel!,
                    style: const TextStyle(
                      fontSize: 12,
                      color: AppColors.textTertiary,
                    ),
                  ),
                ],
              ],
            ),
          ),
          OutlinedButton(
            onPressed: onTap,
            style: OutlinedButton.styleFrom(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
              minimumSize: Size.zero,
              tapTargetSize: MaterialTapTargetSize.shrinkWrap,
            ),
            child: Text(viewProfileLabel, style: const TextStyle(fontSize: 12)),
          ),
        ],
      ),
    );
  }
}

/// Horizontal step progress for sell wizard.
class MarGemStepProgress extends StatelessWidget {
  const MarGemStepProgress({
    super.key,
    required this.currentStep,
    required this.totalSteps,
  });

  final int currentStep;
  final int totalSteps;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: List.generate(totalSteps, (index) {
        final step = index + 1;
        final active = step <= currentStep;
        return Expanded(
          child: Row(
            children: [
              Container(
                width: 28,
                height: 28,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: active ? AppColors.primary : AppColors.surfaceMuted,
                  border: Border.all(
                    color: active ? AppColors.primary : AppColors.border,
                  ),
                ),
                alignment: Alignment.center,
                child: Text(
                  '$step',
                  style: TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.w700,
                    color: active ? Colors.white : AppColors.textTertiary,
                  ),
                ),
              ),
              if (index < totalSteps - 1)
                Expanded(
                  child: Container(
                    height: 2,
                    color: step < currentStep
                        ? AppColors.primary
                        : AppColors.divider,
                  ),
                ),
            ],
          ),
        );
      }),
    );
  }
}

/// Notification list section header.
class MarGemSectionLabel extends StatelessWidget {
  const MarGemSectionLabel({super.key, required this.label});

  final String label;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(0, 16, 0, 8),
      child: Text(
        label,
        style: const TextStyle(
          fontSize: 13,
          fontWeight: FontWeight.w700,
          color: AppColors.textSecondary,
        ),
      ),
    );
  }
}

/// Notification row matching reference.
class MarGemNotificationTile extends StatelessWidget {
  const MarGemNotificationTile({
    super.key,
    required this.title,
    required this.body,
    required this.timeLabel,
    required this.icon,
    this.isUnread = false,
    this.onTap,
  });

  final String title;
  final String body;
  final String timeLabel;
  final IconData icon;
  final bool isUnread;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 12),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            CircleAvatar(
              radius: 22,
              backgroundColor: AppColors.primary.withValues(alpha: 0.1),
              child: Icon(icon, size: 20, color: AppColors.primary),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    title,
                    style: TextStyle(
                      fontSize: 14,
                      fontWeight:
                          isUnread ? FontWeight.w700 : FontWeight.w500,
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    body,
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(
                      fontSize: 13,
                      color: AppColors.textTertiary,
                      height: 1.3,
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(width: 8),
            Text(
              timeLabel,
              style: TextStyle(
                fontSize: 11,
                color: isUnread ? AppColors.primary : AppColors.textMuted,
                fontWeight: isUnread ? FontWeight.w600 : FontWeight.w400,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// Chat composer bar matching reference.
class MarGemChatInputBar extends StatelessWidget {
  const MarGemChatInputBar({
    super.key,
    required this.controller,
    required this.hint,
    required this.onSend,
    this.sending = false,
    this.onAttach,
  });

  final TextEditingController controller;
  final String hint;
  final VoidCallback onSend;
  final bool sending;
  final VoidCallback? onAttach;

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      top: false,
      child: Padding(
        padding: const EdgeInsets.fromLTRB(12, 8, 12, 12),
        child: Row(
          children: [
            if (onAttach != null)
              IconButton(
                onPressed: onAttach,
                icon: const Icon(Icons.add_circle_outline_rounded,
                    color: AppColors.textTertiary),
              ),
            Expanded(
              child: TextField(
                controller: controller,
                minLines: 1,
                maxLines: 4,
                textInputAction: TextInputAction.send,
                onSubmitted: (_) => onSend(),
                decoration: InputDecoration(
                  hintText: hint,
                  filled: true,
                  fillColor: AppColors.surfaceMuted,
                  contentPadding: const EdgeInsets.symmetric(
                    horizontal: 16,
                    vertical: 10,
                  ),
                  border: OutlineInputBorder(
                    borderRadius:
                        BorderRadius.circular(AppSpacing.inputRadius),
                    borderSide: BorderSide.none,
                  ),
                ),
              ),
            ),
            const SizedBox(width: 4),
            IconButton(
              onPressed: sending ? null : onSend,
              icon: const Icon(Icons.photo_camera_outlined,
                  color: AppColors.primary),
            ),
            IconButton(
              onPressed: sending ? null : onSend,
              icon: sending
                  ? const SizedBox(
                      width: 20,
                      height: 20,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    )
                  : const Icon(Icons.send_rounded, color: AppColors.primary),
            ),
          ],
        ),
      ),
    );
  }
}
