import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';

import '../../core/config/app_config.dart';
import '../../core/data/city_coordinates.dart';
import '../../core/data/demo_map_data.dart';
import '../../core/models/models.dart';
import '../../core/services/api_service.dart';
import '../../core/services/location_service.dart';
import '../../core/navigation/margem_navigation_leading.dart';
import '../../core/theme/app_spacing.dart';
import '../../core/theme/theme_context.dart';
import '../../core/widgets/async_error_view.dart';
import '../../core/widgets/buyer_ui_components.dart';
import '../../core/widgets/map_widgets.dart';
import '../../l10n/app_localizations.dart';
import '../../core/providers/city_providers.dart';

class MapScreen extends ConsumerStatefulWidget {
  const MapScreen({super.key});

  @override
  ConsumerState<MapScreen> createState() => _MapScreenState();
}

class _MapScreenState extends ConsumerState<MapScreen> {
  late Future<_MapData> _mapFuture;
  String? _loadedCity;
  bool _locationEnabled = false;

  @override
  void initState() {
    super.initState();
    _initLocation();
  }

  Future<void> _initLocation() async {
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(context.l10n.locationUsageNotice),
          duration: const Duration(seconds: 4),
        ),
      );
    }
    final granted = await LocationService.ensurePermission();
    if (mounted) setState(() => _locationEnabled = granted);
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    final city = ref.read(buyerCityProvider);
    if (_loadedCity != city) {
      _loadedCity = city;
      _mapFuture = _loadMapData(city);
    }
  }

  void _reload(String city) {
    setState(() {
      _loadedCity = city;
      _mapFuture = _loadMapData(city);
    });
  }

  @override
  Widget build(BuildContext context) {
    final city = ref.watch(buyerCityProvider);
    final l10n = context.l10n;

    if (!AppConfig.hasGoogleMapsApiKey) {
      return BuyerScreenScaffold(
        appBar: BuyerAppBar(
          title: l10n.mapPreviewTitle,
          leading: const MargemBackLeading(),
        ),
        body: MapUnavailablePlaceholder(
          cityCenter: CityCoordinates.centerFor(city),
          usingDemoData: false,
        ),
      );
    }

    return FutureBuilder<_MapData>(
      future: _mapFuture,
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return BuyerScreenScaffold(
            appBar: BuyerAppBar(
              title: l10n.mapPreviewTitle,
              leading: const MargemBackLeading(),
            ),
            body: const Center(child: CircularProgressIndicator()),
          );
        }

        if (snapshot.hasError) {
          return BuyerScreenScaffold(
            appBar: BuyerAppBar(
              title: l10n.mapPreviewTitle,
              leading: const MargemBackLeading(),
            ),
            body: AsyncErrorView.fromError(
              snapshot.error!,
              onRetry: () => _reload(city),
            ),
          );
        }

        final data = snapshot.data!;
        final pins = data.pins;
        final warnings = data.warnings;
        final usingDemo = data.usingDemo;

        final initial = pins.isNotEmpty
            ? LatLng(pins.first.latitude, pins.first.longitude)
            : CityCoordinates.centerFor(city);

        final markers = <Marker>{
          ...pins.map((pin) {
            return Marker(
              markerId: MarkerId(pin.id),
              position: LatLng(pin.latitude, pin.longitude),
              infoWindow: InfoWindow(
                title: pin.businessName,
                snippet: pin.goldenCrowns > 0
                    ? '${pin.averageRating} ★ · ${pin.goldenCrowns} golden crown(s)'
                    : '${pin.averageRating} ★ · ${pin.achievementStars} achievement stars',
                onTap: () => context.push('/seller/${pin.id}'),
              ),
              icon: pin.goldenCrowns > 0
                  ? BitmapDescriptor.defaultMarkerWithHue(
                      BitmapDescriptor.hueYellow)
                  : pin.achievementStars > 0
                      ? BitmapDescriptor.defaultMarkerWithHue(
                          BitmapDescriptor.hueOrange)
                      : BitmapDescriptor.defaultMarker,
            );
          }),
          ...warnings.map((zone) {
            return Marker(
              markerId: MarkerId('warning-${zone.id}'),
              position: LatLng(zone.latitude, zone.longitude),
              icon: BitmapDescriptor.defaultMarkerWithHue(BitmapDescriptor.hueRed),
              infoWindow: InfoWindow(title: '⚠ ${zone.name}', snippet: zone.description),
            );
          }),
        };

        return Stack(
          children: [
            SafeGoogleMap(
              initialTarget: initial,
              zoom: 13,
              markers: markers,
              myLocationEnabled: _locationEnabled,
            ),
            Positioned(
              top: MediaQuery.of(context).padding.top + 8,
              left: AppSpacing.screenHorizontal,
              child: Material(
                color: context.colors.surface,
                shape: const CircleBorder(),
                clipBehavior: Clip.antiAlias,
                child: MargemBackLeading(),
              ),
            ),
            Positioned(
              top: MediaQuery.of(context).padding.top + 12,
              left: AppSpacing.screenHorizontal + 52,
              right: AppSpacing.screenHorizontal,
              child: BuyerSurfaceCard(
                child: Padding(
                  padding: EdgeInsets.symmetric(
                    horizontal: AppSpacing.md,
                    vertical: 12,
                  ),
                  child: Row(
                    children: [
                      Icon(
                        Icons.location_on_rounded,
                        color: context.colors.primary,
                      ),
                      SizedBox(width: AppSpacing.sm),
                      Text(
                        city,
                        style: TextStyle(fontWeight: FontWeight.w700),
                      ),
                      Spacer(),
                      if (usingDemo)
                        Container(
                          padding: EdgeInsets.symmetric(
                            horizontal: 10,
                            vertical: 4,
                          ),
                          decoration: BoxDecoration(
                            color: context.colors.warningMuted,
                            borderRadius: BorderRadius.circular(12),
                          ),
                          child: Text(
                            l10n.demoLabel,
                            style: TextStyle(
                              color: context.colors.warning,
                              fontSize: 12,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        )
                      else if (warnings.isNotEmpty)
                        Container(
                          padding: EdgeInsets.symmetric(
                            horizontal: 10,
                            vertical: 4,
                          ),
                          decoration: BoxDecoration(
                            color: context.colors.errorMuted,
                            borderRadius: BorderRadius.circular(12),
                          ),
                          child: Text(
                            l10n.warningZones(warnings.length),
                            style: TextStyle(
                              color: context.colors.error,
                              fontSize: 12,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        ),
                    ],
                  ),
                ),
              ),
            ),
            if (usingDemo)
              Positioned(
                bottom: AppSpacing.lg,
                left: AppSpacing.screenHorizontal,
                right: AppSpacing.screenHorizontal,
                child: BuyerSurfaceCard(
                  child: Padding(
                    padding: const EdgeInsets.all(AppSpacing.md),
                    child: Text(
                      l10n.demoBusinessesMapHint,
                      style: Theme.of(context).textTheme.bodySmall,
                    ),
                  ),
                ),
              ),
          ],
        );
      },
    );
  }

  Future<_MapData> _loadMapData(String city) async {
    try {
      final results = await Future.wait([
        apiServiceProvider.fetchMapPins(city: city),
        apiServiceProvider.fetchWarningZones(city: city),
      ]);
      return _MapData(
        pins: results[0] as List<MapPinModel>,
        warnings: results[1] as List<WarningZoneModel>,
        usingDemo: false,
      );
    } catch (e) {
      if (AppConfig.allowDemoData) {
        return _MapData.demo(city);
      }
      rethrow;
    }
  }
}

class _MapData {
  const _MapData({
    required this.pins,
    required this.warnings,
    required this.usingDemo,
  });

  final List<MapPinModel> pins;
  final List<WarningZoneModel> warnings;
  final bool usingDemo;

  factory _MapData.demo(String city) {
    return _MapData(
      pins: DemoMapData.pinsForCity(city),
      warnings: const [],
      usingDemo: true,
    );
  }
}
