import 'dart:math' as math;
import 'dart:ui';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../admin_models.dart';
import '../admin_theme.dart';

// ── Skeleton shimmer ────────────────────────────────────────────────────────

class AdminShimmer extends StatefulWidget {
  const AdminShimmer({super.key, required this.child});

  final Widget child;

  @override
  State<AdminShimmer> createState() => _AdminShimmerState();
}

class _AdminShimmerState extends State<AdminShimmer>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1400),
    )..repeat();
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: _controller,
      builder: (context, child) {
        return ShaderMask(
          blendMode: BlendMode.srcATop,
          shaderCallback: (bounds) {
            return LinearGradient(
              begin: Alignment(-1 + _controller.value * 2, 0),
              end: Alignment(1 + _controller.value * 2, 0),
              colors: const [
                Color(0xFFE8EAED),
                Color(0xFFF3F4F6),
                Color(0xFFE8EAED),
              ],
            ).createShader(bounds);
          },
          child: child,
        );
      },
      child: widget.child,
    );
  }
}

class AdminSkeletonBox extends StatelessWidget {
  const AdminSkeletonBox({
    super.key,
    required this.width,
    required this.height,
    this.radius = AdminTheme.radiusMd,
  });

  final double width;
  final double height;
  final double radius;

  @override
  Widget build(BuildContext context) {
    return AdminShimmer(
      child: Container(
        width: width,
        height: height,
        decoration: BoxDecoration(
          color: const Color(0xFFE8EAED),
          borderRadius: BorderRadius.circular(radius),
        ),
      ),
    );
  }
}

// ── Glass app bar ───────────────────────────────────────────────────────────

class AdminGlassAppBar extends StatelessWidget implements PreferredSizeWidget {
  const AdminGlassAppBar({
    super.key,
    required this.title,
    this.subtitle,
    required this.displayName,
    required this.onMenu,
    required this.onSearch,
    required this.onNotifications,
    this.notificationCount = 0,
    this.showMenu = true,
  });

  final String title;
  final String? subtitle;
  final String displayName;
  final VoidCallback onMenu;
  final VoidCallback onSearch;
  final VoidCallback onNotifications;
  final int notificationCount;
  final bool showMenu;

  @override
  Size get preferredSize => Size.fromHeight(subtitle != null ? 88 : 72);

  @override
  Widget build(BuildContext context) {
    final top = MediaQuery.paddingOf(context).top;
    return ClipRRect(
      child: BackdropFilter(
        filter: ImageFilter.blur(sigmaX: 18, sigmaY: 18),
        child: Container(
          padding: EdgeInsets.fromLTRB(8, top + 4, 12, 12),
          decoration: BoxDecoration(
            color: Colors.white.withValues(alpha: 0.82),
            border: Border(
              bottom: BorderSide(color: AdminTheme.border.withValues(alpha: 0.5)),
            ),
            boxShadow: AdminTheme.glassShadow,
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  if (showMenu)
                    IconButton(
                      onPressed: onMenu,
                      icon: const Icon(Icons.menu_rounded),
                      tooltip: 'Menu',
                    ),
                  Container(
                    width: 32,
                    height: 32,
                    decoration: BoxDecoration(
                      color: AdminTheme.primary,
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: const Icon(Icons.diamond_rounded, color: Colors.white, size: 18),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'MarGem',
                          style: Theme.of(context).textTheme.labelLarge?.copyWith(
                                color: AdminTheme.primary,
                                fontSize: 12,
                              ),
                        ),
                        Text(
                          title,
                          style: Theme.of(context).textTheme.titleMedium,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ],
                    ),
                  ),
                  IconButton(
                    onPressed: onSearch,
                    icon: const Icon(Icons.search_rounded),
                    tooltip: 'Search',
                  ),
                  Stack(
                    clipBehavior: Clip.none,
                    children: [
                      IconButton(
                        onPressed: onNotifications,
                        icon: const Icon(Icons.notifications_none_rounded),
                        tooltip: 'Notifications',
                      ),
                      if (notificationCount > 0)
                        Positioned(
                          right: 8,
                          top: 8,
                          child: Container(
                            padding: const EdgeInsets.all(4),
                            decoration: const BoxDecoration(
                              color: AdminTheme.danger,
                              shape: BoxShape.circle,
                            ),
                            constraints: const BoxConstraints(minWidth: 18, minHeight: 18),
                            child: Text(
                              notificationCount > 9 ? '9+' : '$notificationCount',
                              textAlign: TextAlign.center,
                              style: const TextStyle(
                                color: Colors.white,
                                fontSize: 10,
                                fontWeight: FontWeight.w700,
                              ),
                            ),
                          ),
                        ),
                    ],
                  ),
                  _AdminAvatar(name: displayName),
                ],
              ),
              if (subtitle != null) ...[
                const SizedBox(height: 4),
                Padding(
                  padding: const EdgeInsets.only(left: 12),
                  child: Text(
                    subtitle!,
                    style: Theme.of(context).textTheme.bodySmall,
                  ),
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }
}

class _AdminAvatar extends StatelessWidget {
  const _AdminAvatar({required this.name});

  final String name;

  @override
  Widget build(BuildContext context) {
    final initial = name.isNotEmpty ? name[0].toUpperCase() : 'A';
    return Stack(
      clipBehavior: Clip.none,
      children: [
        CircleAvatar(
          radius: 18,
          backgroundColor: AdminTheme.primary.withValues(alpha: 0.12),
          child: Text(
            initial,
            style: const TextStyle(
              color: AdminTheme.primary,
              fontWeight: FontWeight.w700,
            ),
          ),
        ),
        Positioned(
          right: 0,
          bottom: 0,
          child: Container(
            width: 10,
            height: 10,
            decoration: BoxDecoration(
              color: AdminTheme.success,
              shape: BoxShape.circle,
              border: Border.all(color: Colors.white, width: 2),
            ),
          ),
        ),
      ],
    );
  }
}

// ── Welcome card ────────────────────────────────────────────────────────────

class AdminWelcomeCard extends StatelessWidget {
  const AdminWelcomeCard({
    super.key,
    required this.greeting,
    required this.name,
    required this.dateLabel,
    required this.syncLabel,
  });

  final String greeting;
  final String name;
  final String dateLabel;
  final String syncLabel;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(22),
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [AdminTheme.primary, Color(0xFF6B1522)],
        ),
        borderRadius: BorderRadius.circular(AdminTheme.radiusXl),
        boxShadow: [
          BoxShadow(
            color: AdminTheme.primary.withValues(alpha: 0.28),
            blurRadius: 24,
            offset: const Offset(0, 12),
          ),
        ],
      ),
      child: Row(
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  '$greeting,',
                  style: const TextStyle(
                    color: Colors.white70,
                    fontSize: 14,
                    fontWeight: FontWeight.w500,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  name,
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 26,
                    fontWeight: FontWeight.w700,
                    letterSpacing: -0.5,
                  ),
                ),
                const SizedBox(height: 8),
                const Text(
                  "Today's overview of your marketplace.",
                  style: TextStyle(color: Colors.white70, fontSize: 13, height: 1.4),
                ),
                const SizedBox(height: 14),
                Row(
                  children: [
                    _WelcomeChip(icon: Icons.calendar_today_rounded, label: dateLabel),
                    const SizedBox(width: 8),
                    _WelcomeChip(icon: Icons.sync_rounded, label: syncLabel),
                  ],
                ),
              ],
            ),
          ),
          const SizedBox(width: 12),
          Container(
            width: 72,
            height: 72,
            decoration: BoxDecoration(
              color: Colors.white.withValues(alpha: 0.15),
              borderRadius: BorderRadius.circular(20),
            ),
            child: const Icon(Icons.insights_rounded, color: Colors.white, size: 36),
          ),
        ],
      ),
    );
  }
}

class _WelcomeChip extends StatelessWidget {
  const _WelcomeChip({required this.icon, required this.label});

  final IconData icon;
  final String label;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.14),
        borderRadius: BorderRadius.circular(20),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 12, color: Colors.white70),
          const SizedBox(width: 4),
          Text(label, style: const TextStyle(color: Colors.white, fontSize: 11)),
        ],
      ),
    );
  }
}

// ── KPI cards ─────────────────────────────────────────────────────────────

class AdminKpiCard extends StatelessWidget {
  const AdminKpiCard({
    super.key,
    required this.label,
    required this.value,
    required this.icon,
    required this.iconColor,
    required this.iconBg,
    this.trendPercent,
    this.sparkline = const [],
    this.onTap,
  });

  final String label;
  final String value;
  final IconData icon;
  final Color iconColor;
  final Color iconBg;
  final double? trendPercent;
  final List<int> sparkline;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final trend = trendPercent;
    final isUp = trend != null && trend >= 0;
    final textScaler = MediaQuery.textScalerOf(context).clamp(maxScaleFactor: 1.1);

    return MediaQuery(
      data: MediaQuery.of(context).copyWith(textScaler: textScaler),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(AdminTheme.radiusXl),
          child: Ink(
            width: 168,
            height: double.infinity,
            padding: const EdgeInsets.all(14),
            decoration: AdminTheme.cardDecoration(),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Container(
                      width: 34,
                      height: 34,
                      decoration: BoxDecoration(
                        color: iconBg,
                        borderRadius: BorderRadius.circular(10),
                      ),
                      child: Icon(icon, color: iconColor, size: 18),
                    ),
                    const Spacer(),
                    if (trend != null)
                      Flexible(
                        child: Container(
                          padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 2),
                          decoration: BoxDecoration(
                            color: (isUp ? AdminTheme.success : AdminTheme.danger)
                                .withValues(alpha: 0.12),
                            borderRadius: BorderRadius.circular(20),
                          ),
                          child: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Icon(
                                isUp ? Icons.arrow_upward_rounded : Icons.arrow_downward_rounded,
                                size: 10,
                                color: isUp ? AdminTheme.success : AdminTheme.danger,
                              ),
                              Flexible(
                                child: Text(
                                  '${trend.abs().toStringAsFixed(1)}%',
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                  style: TextStyle(
                                    fontSize: 10,
                                    fontWeight: FontWeight.w700,
                                    color: isUp ? AdminTheme.success : AdminTheme.danger,
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                  ],
                ),
                const SizedBox(height: 10),
                Text(
                  value,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    fontSize: 22,
                    fontWeight: FontWeight.w800,
                    letterSpacing: -0.5,
                    color: AdminTheme.textPrimary,
                    height: 1.0,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  label,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: Theme.of(context).textTheme.bodySmall?.copyWith(fontSize: 11),
                ),
                if (sparkline.isNotEmpty) ...[
                  const Spacer(),
                  SizedBox(
                    height: 24,
                    width: double.infinity,
                    child: CustomPaint(
                      painter: _SparklinePainter(
                        values: sparkline,
                        color: iconColor.withValues(alpha: 0.8),
                      ),
                    ),
                  ),
                ],
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _SparklinePainter extends CustomPainter {
  _SparklinePainter({required this.values, required this.color});

  final List<int> values;
  final Color color;

  @override
  void paint(Canvas canvas, Size size) {
    if (values.length < 2) return;
    final max = values.reduce(math.max).clamp(1, 999999);
    final paint = Paint()
      ..color = color
      ..strokeWidth = 2
      ..style = PaintingStyle.stroke
      ..strokeCap = StrokeCap.round;

    final path = Path();
    for (var i = 0; i < values.length; i++) {
      final x = i / (values.length - 1) * size.width;
      final y = size.height - (values[i] / max) * size.height;
      if (i == 0) {
        path.moveTo(x, y);
      } else {
        path.lineTo(x, y);
      }
    }
    canvas.drawPath(path, paint);
  }

  @override
  bool shouldRepaint(covariant _SparklinePainter oldDelegate) =>
      oldDelegate.values != values;
}

// ── Line chart ──────────────────────────────────────────────────────────────

class AdminLineChartCard extends StatelessWidget {
  const AdminLineChartCard({
    super.key,
    required this.title,
    required this.subtitle,
    required this.points,
    required this.totalLabel,
    this.trendPercent,
    this.accentColor = AdminTheme.primary,
  });

  final String title;
  final String subtitle;
  final List<GrowthPoint> points;
  final String totalLabel;
  final double? trendPercent;
  final Color accentColor;

  @override
  Widget build(BuildContext context) {
    final values = points.map((p) => p.count).toList();
    final total = values.fold<int>(0, (a, b) => a + b);
    final trend = trendPercent;

    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 2),
      padding: const EdgeInsets.fromLTRB(16, 16, 16, 12),
      decoration: AdminTheme.cardDecoration(),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      title,
                      style: Theme.of(context).textTheme.titleMedium?.copyWith(fontSize: 15),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                    const SizedBox(height: 2),
                    Text(
                      subtitle,
                      style: Theme.of(context).textTheme.bodySmall?.copyWith(fontSize: 11),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 6),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                decoration: BoxDecoration(
                  color: AdminTheme.background,
                  borderRadius: BorderRadius.circular(20),
                  border: Border.all(color: AdminTheme.border),
                ),
                child: const Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text('30d', style: TextStyle(fontSize: 11, fontWeight: FontWeight.w600)),
                    SizedBox(width: 2),
                    Icon(Icons.expand_more_rounded, size: 14),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          Row(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              Expanded(
                child: Text(
                  totalLabel.isNotEmpty ? totalLabel : _formatNumber(total),
                  style: const TextStyle(
                    fontSize: 26,
                    fontWeight: FontWeight.w800,
                    letterSpacing: -0.8,
                    height: 1.0,
                  ),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
              ),
              if (trend != null) ...[
                const SizedBox(width: 6),
                Flexible(
                  child: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 3),
                    decoration: BoxDecoration(
                      color: (trend >= 0 ? AdminTheme.success : AdminTheme.danger)
                          .withValues(alpha: 0.12),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Text(
                      '${trend >= 0 ? '+' : ''}${trend.toStringAsFixed(1)}%',
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                        fontSize: 11,
                        fontWeight: FontWeight.w700,
                        color: trend >= 0 ? AdminTheme.success : AdminTheme.danger,
                      ),
                    ),
                  ),
                ),
              ],
            ],
          ),
          const SizedBox(height: 10),
          Expanded(
            child: CustomPaint(
              painter: _LineChartPainter(values: values, color: accentColor),
            ),
          ),
        ],
      ),
    );
  }

  static String _formatNumber(int n) {
    if (n >= 1000000) return '${(n / 1000000).toStringAsFixed(1)}M';
    if (n >= 1000) return '${(n / 1000).toStringAsFixed(1)}K';
    return '$n';
  }
}

class _LineChartPainter extends CustomPainter {
  _LineChartPainter({required this.values, required this.color});

  final List<int> values;
  final Color color;

  @override
  void paint(Canvas canvas, Size size) {
    if (values.isEmpty) return;
    final max = values.reduce(math.max).clamp(1, 999999).toDouble();
    final linePaint = Paint()
      ..color = color
      ..strokeWidth = 2.5
      ..style = PaintingStyle.stroke
      ..strokeCap = StrokeCap.round;

    final fillPaint = Paint()
      ..shader = LinearGradient(
        begin: Alignment.topCenter,
        end: Alignment.bottomCenter,
        colors: [color.withValues(alpha: 0.25), color.withValues(alpha: 0.02)],
      ).createShader(Rect.fromLTWH(0, 0, size.width, size.height));

    final linePath = Path();
    final fillPath = Path()..moveTo(0, size.height);

    for (var i = 0; i < values.length; i++) {
      final x = values.length == 1 ? size.width / 2 : i / (values.length - 1) * size.width;
      final y = size.height - (values[i] / max) * (size.height - 16);
      if (i == 0) {
        linePath.moveTo(x, y);
        fillPath.lineTo(x, y);
      } else {
        linePath.lineTo(x, y);
        fillPath.lineTo(x, y);
      }
    }
    fillPath.lineTo(size.width, size.height);
    fillPath.close();

    canvas.drawPath(fillPath, fillPaint);
    canvas.drawPath(linePath, linePaint);

    // Dots on last point
    if (values.isNotEmpty) {
      final lastX = size.width;
      final lastY = size.height - (values.last / max) * (size.height - 16);
      canvas.drawCircle(Offset(lastX, lastY), 5, Paint()..color = color);
      canvas.drawCircle(Offset(lastX, lastY), 3, Paint()..color = Colors.white);
    }
  }

  @override
  bool shouldRepaint(covariant _LineChartPainter oldDelegate) =>
      oldDelegate.values != values;
}

// ── Quick actions ───────────────────────────────────────────────────────────

class AdminQuickActionsGrid extends StatelessWidget {
  const AdminQuickActionsGrid({super.key, required this.actions});

  final List<AdminQuickAction> actions;

  @override
  Widget build(BuildContext context) {
    final width = MediaQuery.sizeOf(context).width;
    final columns = width < 400 ? 3 : 4;
    final aspectRatio = width < 400 ? 0.82 : 0.72;

    return GridView.builder(
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
        crossAxisCount: columns,
        mainAxisSpacing: 10,
        crossAxisSpacing: 10,
        childAspectRatio: aspectRatio,
      ),
      itemCount: actions.length,
      itemBuilder: (context, index) {
        final action = actions[index];
        return Material(
          color: Colors.transparent,
          child: InkWell(
            onTap: action.onTap,
            borderRadius: BorderRadius.circular(AdminTheme.radiusLg),
            child: Ink(
              decoration: BoxDecoration(
                color: AdminTheme.card,
                borderRadius: BorderRadius.circular(AdminTheme.radiusLg),
                border: Border.all(color: AdminTheme.border.withValues(alpha: 0.7)),
              ),
              padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 6),
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Container(
                    width: 34,
                    height: 34,
                    decoration: BoxDecoration(
                      color: action.color.withValues(alpha: 0.12),
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: Icon(action.icon, color: action.color, size: 17),
                  ),
                  const SizedBox(height: 5),
                  Expanded(
                    child: Align(
                      alignment: Alignment.topCenter,
                      child: Text(
                        action.label,
                        textAlign: TextAlign.center,
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(
                          fontSize: 10,
                          fontWeight: FontWeight.w600,
                          color: AdminTheme.textPrimary,
                          height: 1.1,
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        );
      },
    );
  }
}

class AdminQuickAction {
  const AdminQuickAction({
    required this.label,
    required this.icon,
    required this.color,
    required this.onTap,
  });

  final String label;
  final IconData icon;
  final Color color;
  final VoidCallback onTap;
}

// ── Activity timeline ───────────────────────────────────────────────────────

class AdminActivityTimeline extends StatelessWidget {
  const AdminActivityTimeline({super.key, required this.items});

  final List<ActivityItem> items;

  @override
  Widget build(BuildContext context) {
    if (items.isEmpty) {
      return const AdminEmptyState(
        icon: Icons.history_rounded,
        title: 'No recent activity',
        subtitle: 'Actions across the platform will appear here.',
      );
    }

    return Column(
      children: [
        for (var i = 0; i < items.length; i++)
          _ActivityRow(
            item: items[i],
            isLast: i == items.length - 1,
          ),
      ],
    );
  }
}

class _ActivityRow extends StatelessWidget {
  const _ActivityRow({required this.item, required this.isLast});

  final ActivityItem item;
  final bool isLast;

  @override
  Widget build(BuildContext context) {
    final meta = _activityMeta(item.type);
    return IntrinsicHeight(
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Column(
            children: [
              Container(
                width: 36,
                height: 36,
                decoration: BoxDecoration(
                  color: meta.color.withValues(alpha: 0.12),
                  shape: BoxShape.circle,
                ),
                child: Icon(meta.icon, size: 18, color: meta.color),
              ),
              if (!isLast)
                Expanded(
                  child: Container(
                    width: 2,
                    margin: const EdgeInsets.symmetric(vertical: 4),
                    color: AdminTheme.border,
                  ),
                ),
            ],
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Padding(
              padding: EdgeInsets.only(bottom: isLast ? 0 : 18),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    item.label,
                    style: const TextStyle(
                      fontWeight: FontWeight.w600,
                      fontSize: 14,
                      color: AdminTheme.textPrimary,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    '${meta.title} · ${_relativeTime(item.at)}',
                    style: Theme.of(context).textTheme.bodySmall,
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  static ({IconData icon, Color color, String title}) _activityMeta(String type) {
    return switch (type) {
      'report' => (icon: Icons.flag_rounded, color: AdminTheme.danger, title: 'Report'),
      'listing' => (icon: Icons.inventory_2_rounded, color: AdminTheme.info, title: 'Listing'),
      'audit' => (icon: Icons.verified_user_rounded, color: AdminTheme.success, title: 'Admin action'),
      _ => (icon: Icons.notifications_rounded, color: AdminTheme.warning, title: 'Activity'),
    };
  }

  static String _relativeTime(String iso) {
    final dt = DateTime.tryParse(iso);
    if (dt == null) return iso;
    final diff = DateTime.now().toUtc().difference(dt.toUtc());
    if (diff.inMinutes < 1) return 'Just now';
    if (diff.inMinutes < 60) return '${diff.inMinutes} min ago';
    if (diff.inHours < 24) return '${diff.inHours}h ago';
    return '${diff.inDays}d ago';
  }
}

// ── Management cards ────────────────────────────────────────────────────────

class AdminEntityCard extends StatelessWidget {
  const AdminEntityCard({
    super.key,
    required this.title,
    required this.subtitle,
    required this.status,
    this.badge,
    this.trailing,
    this.onTap,
    this.avatarLabel,
    this.avatarColor = AdminTheme.primary,
  });

  final String title;
  final String subtitle;
  final String status;
  final String? badge;
  final Widget? trailing;
  final VoidCallback? onTap;
  final String? avatarLabel;
  final Color avatarColor;

  @override
  Widget build(BuildContext context) {
    final initial = avatarLabel ?? (title.isNotEmpty ? title[0].toUpperCase() : '?');
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(AdminTheme.radiusXl),
        child: Ink(
          padding: const EdgeInsets.all(16),
          decoration: AdminTheme.cardDecoration(),
          child: Row(
            children: [
              CircleAvatar(
                radius: 24,
                backgroundColor: avatarColor.withValues(alpha: 0.12),
                child: Text(
                  initial,
                  style: TextStyle(
                    color: avatarColor,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(title, style: Theme.of(context).textTheme.titleSmall),
                    const SizedBox(height: 2),
                    Text(
                      subtitle,
                      style: Theme.of(context).textTheme.bodySmall,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                    const SizedBox(height: 8),
                    Row(
                      children: [
                        AdminStatusBadge(status: status),
                        if (badge != null) ...[
                          const SizedBox(width: 8),
                          AdminStatusBadge(status: badge!, filled: false),
                        ],
                      ],
                    ),
                  ],
                ),
              ),
              trailing ?? const Icon(Icons.more_horiz_rounded, color: AdminTheme.textTertiary),
            ],
          ),
        ),
      ),
    );
  }
}

class AdminStatusBadge extends StatelessWidget {
  const AdminStatusBadge({super.key, required this.status, this.filled = true});

  final String status;
  final bool filled;

  @override
  Widget build(BuildContext context) {
    final color = _colorForStatus(status);
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      decoration: BoxDecoration(
        color: filled ? color.withValues(alpha: 0.12) : Colors.transparent,
        borderRadius: BorderRadius.circular(20),
        border: filled ? null : Border.all(color: color.withValues(alpha: 0.4)),
      ),
      child: Text(
        status.replaceAll('_', ' '),
        style: TextStyle(
          fontSize: 11,
          fontWeight: FontWeight.w700,
          color: color,
        ),
      ),
    );
  }

  static Color _colorForStatus(String status) {
    return switch (status.toLowerCase()) {
      'active' || 'verified' || 'resolved' => AdminTheme.success,
      'pending' || 'open' || 'reviewing' => AdminTheme.warning,
      'suspended' || 'rejected' || 'deleted' => AdminTheme.danger,
      'premium' || 'admin' || 'super_admin' => AdminTheme.primary,
      _ => AdminTheme.textSecondary,
    };
  }
}

// ── Section header ──────────────────────────────────────────────────────────

class AdminSectionHeader extends StatelessWidget {
  const AdminSectionHeader({
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
      padding: const EdgeInsets.only(bottom: 14),
      child: Row(
        children: [
          Text(title, style: Theme.of(context).textTheme.titleLarge),
          const Spacer(),
          if (actionLabel != null && onAction != null)
            TextButton(
              onPressed: onAction,
              child: Text(actionLabel!),
            ),
        ],
      ),
    );
  }
}

// ── Empty state ─────────────────────────────────────────────────────────────

class AdminEmptyState extends StatelessWidget {
  const AdminEmptyState({
    super.key,
    required this.icon,
    required this.title,
    required this.subtitle,
    this.actionLabel,
    this.onAction,
  });

  final IconData icon;
  final String title;
  final String subtitle;
  final String? actionLabel;
  final VoidCallback? onAction;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 32, horizontal: 24),
      child: Column(
        children: [
          Container(
            width: 72,
            height: 72,
            decoration: BoxDecoration(
              color: AdminTheme.primary.withValues(alpha: 0.08),
              borderRadius: BorderRadius.circular(20),
            ),
            child: Icon(icon, size: 36, color: AdminTheme.primary.withValues(alpha: 0.6)),
          ),
          const SizedBox(height: 16),
          Text(title, style: Theme.of(context).textTheme.titleMedium),
          const SizedBox(height: 6),
          Text(
            subtitle,
            textAlign: TextAlign.center,
            style: Theme.of(context).textTheme.bodySmall,
          ),
          if (actionLabel != null && onAction != null) ...[
            const SizedBox(height: 20),
            FilledButton(onPressed: onAction, child: Text(actionLabel!)),
          ],
        ],
      ),
    );
  }
}

// ── Search overlay ────────────────────────────────────────────────────────

class AdminSearchSheet extends StatefulWidget {
  const AdminSearchSheet({super.key});

  @override
  State<AdminSearchSheet> createState() => _AdminSearchSheetState();
}

class _AdminSearchSheetState extends State<AdminSearchSheet> {
  final _controller = TextEditingController();

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: EdgeInsets.only(
        bottom: MediaQuery.viewInsetsOf(context).bottom,
      ),
      child: Container(
        padding: const EdgeInsets.fromLTRB(20, 16, 20, 24),
        decoration: const BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.vertical(top: Radius.circular(AdminTheme.radiusXl)),
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Center(
              child: Container(
                width: 40,
                height: 4,
                decoration: BoxDecoration(
                  color: AdminTheme.border,
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
            ),
            const SizedBox(height: 16),
            Text('Search admin', style: Theme.of(context).textTheme.titleLarge),
            const SizedBox(height: 14),
            TextField(
              controller: _controller,
              autofocus: true,
              decoration: const InputDecoration(
                hintText: 'Users, sellers, listings, reports…',
                prefixIcon: Icon(Icons.search_rounded),
              ),
              onSubmitted: (_) => Navigator.pop(context, _controller.text.trim()),
            ),
            const SizedBox(height: 12),
            Wrap(
              spacing: 8,
              children: [
                _SearchChip(label: 'Users', icon: Icons.people_outline),
                _SearchChip(label: 'Sellers', icon: Icons.storefront_outlined),
                _SearchChip(label: 'Listings', icon: Icons.inventory_2_outlined),
                _SearchChip(label: 'Reports', icon: Icons.flag_outlined),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

class _SearchChip extends StatelessWidget {
  const _SearchChip({required this.label, required this.icon});

  final String label;
  final IconData icon;

  @override
  Widget build(BuildContext context) {
    return Chip(
      avatar: Icon(icon, size: 16, color: AdminTheme.primary),
      label: Text(label, style: const TextStyle(fontSize: 12)),
      backgroundColor: AdminTheme.primary.withValues(alpha: 0.08),
      side: BorderSide.none,
    );
  }
}

// ── Helpers ───────────────────────────────────────────────────────────────

String adminGreeting() {
  final hour = DateTime.now().hour;
  if (hour < 12) return 'Good Morning';
  if (hour < 17) return 'Good Afternoon';
  return 'Good Evening';
}

String adminDateLabel() {
  final now = DateTime.now();
  const months = [
    'Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun',
    'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec',
  ];
  return '${months[now.month - 1]} ${now.day}, ${now.year}';
}

double adminTrendPercent(List<GrowthPoint> points) {
  if (points.length < 14) return 0;
  final recent = points.skip(points.length - 7).fold<int>(0, (s, p) => s + p.count);
  final prev = points.skip(points.length - 14).take(7).fold<int>(0, (s, p) => s + p.count);
  if (prev == 0) return recent > 0 ? 100 : 0;
  return ((recent - prev) / prev) * 100;
}

List<int> adminSparkline(List<GrowthPoint> points, {int take = 7}) {
  if (points.length <= take) return points.map((p) => p.count).toList();
  return points.skip(points.length - take).map((p) => p.count).toList();
}

String adminFormatCount(int n) {
  if (n >= 1000000) return '${(n / 1000000).toStringAsFixed(1)}M';
  if (n >= 1000) return '${(n / 1000).toStringAsFixed(1)}K';
  return '$n';
}

void adminHaptic() => HapticFeedback.lightImpact();
