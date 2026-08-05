import 'package:flutter/foundation.dart';
import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';

import '../../l10n/app_localizations.dart';
import '../config/app_config.dart';
import '../theme/app_colors.dart';
import '../theme/app_spacing.dart';
import '../utils/directional_ui.dart';

/// Full-screen map picker — never embed inside a [ScrollView].
class MapLocationPickerPage extends StatefulWidget {
  const MapLocationPickerPage({
    super.key,
    required this.initial,
    required this.title,
  });

  final LatLng initial;
  final String title;

  static Future<LatLng?> open(
    BuildContext context, {
    required LatLng initial,
    String? title,
  }) {
    final l10n = AppLocalizations.get(context).strings;
    return Navigator.of(context).push<LatLng>(
      MaterialPageRoute(
        fullscreenDialog: true,
        builder: (_) => MapLocationPickerPage(
          initial: initial,
          title: title ?? l10n.storeLocation,
        ),
      ),
    );
  }

  @override
  State<MapLocationPickerPage> createState() => _MapLocationPickerPageState();
}

class _MapLocationPickerPageState extends State<MapLocationPickerPage> {
  late LatLng _position;

  @override
  void initState() {
    super.initState();
    _position = widget.initial;
  }

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    return Scaffold(
      appBar: AppBar(
        title: Text(widget.title),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, _position),
            child: Text(
              l10n.done,
              style: const TextStyle(fontWeight: FontWeight.w700),
            ),
          ),
        ],
      ),
      body: SafeGoogleMap(
        initialTarget: _position,
        zoom: 14,
        markers: AppConfig.hasGoogleMapsApiKey
            ? {
                Marker(markerId: const MarkerId('pick'), position: _position),
              }
            : {},
        onTap: AppConfig.hasGoogleMapsApiKey
            ? (pos) => setState(() => _position = pos)
            : null,
      ),
    );
  }
}

class SafeGoogleMap extends StatelessWidget {
  const SafeGoogleMap({
    super.key,
    required this.initialTarget,
    required this.markers,
    this.zoom = 13,
    this.myLocationEnabled = false,
    this.onMapCreated,
    this.onTap,
  });

  final LatLng initialTarget;
  final Set<Marker> markers;
  final double zoom;
  final bool myLocationEnabled;
  final void Function(GoogleMapController)? onMapCreated;
  final void Function(LatLng)? onTap;

  @override
  Widget build(BuildContext context) {
    if (!AppConfig.hasGoogleMapsApiKey) {
      return MapUnavailablePlaceholder(
        cityCenter: initialTarget,
        markerCount: markers.length,
      );
    }

    return GoogleMap(
      initialCameraPosition: CameraPosition(target: initialTarget, zoom: zoom),
      markers: markers,
      myLocationButtonEnabled: myLocationEnabled,
      myLocationEnabled: myLocationEnabled,
      onMapCreated: onMapCreated,
      onTap: onTap,
      gestureRecognizers: {
        Factory<OneSequenceGestureRecognizer>(() => EagerGestureRecognizer())
      },
    );
  }
}

class MapUnavailablePlaceholder extends StatelessWidget {
  const MapUnavailablePlaceholder({
    super.key,
    required this.cityCenter,
    this.markerCount = 0,
    this.usingDemoData = false,
  });

  final LatLng cityCenter;
  final int markerCount;
  final bool usingDemoData;

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    return Container(
      color: AppColors.surfaceMuted,
      child: Center(
        child: Padding(
          padding: const EdgeInsets.all(AppSpacing.xl),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              const Icon(Icons.map_outlined, size: 64, color: AppColors.primary),
              const SizedBox(height: AppSpacing.md),
              Text(
                usingDemoData ? l10n.mapDemoModeTitle : l10n.mapPreviewTitle,
                style: Theme.of(context)
                    .textTheme
                    .titleMedium
                    ?.copyWith(fontWeight: FontWeight.w700),
              ),
              const SizedBox(height: AppSpacing.sm),
              Text(
                usingDemoData
                    ? l10n.demoBusinessesMapHint
                    : l10n.mapApiKeyHint,
                textAlign: TextAlign.center,
                style: Theme.of(context)
                    .textTheme
                    .bodyMedium
                    ?.copyWith(color: AppColors.onSurfaceVariant(context)),
              ),
              if (markerCount > 0) ...[
                const SizedBox(height: AppSpacing.md),
                Text(
                  l10n.mapLocationsInArea(markerCount),
                  style: const TextStyle(fontWeight: FontWeight.w600),
                ),
              ],
              const SizedBox(height: AppSpacing.sm),
              Text(
                '${cityCenter.latitude.toStringAsFixed(4)}, ${cityCenter.longitude.toStringAsFixed(4)}',
                style: const TextStyle(
                  color: AppColors.textTertiary,
                  fontSize: 12,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class StoreLocationPickerTile extends StatelessWidget {
  const StoreLocationPickerTile({
    super.key,
    required this.location,
    required this.onLocationChanged,
    this.label,
    this.hint,
  });

  final LatLng location;
  final ValueChanged<LatLng> onLocationChanged;
  final String? label;
  final String? hint;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        if (label != null)
          Text(
            label!,
            style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                  color: AppColors.onSurfaceVariant(context),
                ),
          ),
        if (label != null) const SizedBox(height: AppSpacing.sm),
        Material(
          color: Theme.of(context).colorScheme.surfaceContainerHighest,
          borderRadius: BorderRadius.circular(AppSpacing.inputRadius),
          child: InkWell(
            onTap: () async {
              final picked = await MapLocationPickerPage.open(
                context,
                initial: location,
                title: label,
              );
              if (picked != null) onLocationChanged(picked);
            },
            borderRadius: BorderRadius.circular(AppSpacing.inputRadius),
            child: Container(
              width: double.infinity,
              padding: const EdgeInsets.all(AppSpacing.lg),
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(AppSpacing.inputRadius),
                border: Border.all(color: AppColors.border),
              ),
              child: Row(
                children: [
                  Container(
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: AppColors.primary.withValues(alpha: 0.1),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: const Icon(
                      Icons.location_on_outlined,
                      color: AppColors.primary,
                    ),
                  ),
                  const SizedBox(width: AppSpacing.md),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          '${location.latitude.toStringAsFixed(5)}, ${location.longitude.toStringAsFixed(5)}',
                          style: const TextStyle(fontWeight: FontWeight.w600),
                        ),
                        if (hint != null) ...[
                          const SizedBox(height: 4),
                          Text(
                            hint!,
                            style: TextStyle(
                              color: AppColors.onSurfaceVariant(context),
                              fontSize: 13,
                            ),
                          ),
                        ],
                      ],
                    ),
                  ),
                  Icon(DirectionalUi.forwardChevron(context)),
                ],
              ),
            ),
          ),
        ),
      ],
    );
  }
}
