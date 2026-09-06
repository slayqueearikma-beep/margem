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
import '../../core/providers/buyer_discovery_providers.dart';
import '../buyer/buyer_home_screen.dart';

class MapScreen extends ConsumerStatefulWidget {
  const MapScreen({super.key});

  @override
  ConsumerState<MapScreen> createState() => _MapScreenState();
}

class _MapScreenState extends ConsumerState<MapScreen> {
  late Future<_MapData> _mapFuture;
  String? _loadedCity;
  String? _loadedMarketplace;
  String? _selectedZone;
  bool _locationEnabled = false;
  bool _locationNoticeShown = false;
  bool _showZonePanel = false;

  @override
  void initState() {
    super.initState();
    _initLocation();
  }

  Future<void> _initLocation() async {
    final granted = await LocationService.ensurePermission();
    if (mounted) setState(() => _locationEnabled = granted);
  }

  void _showLocationNoticeIfNeeded() {
    if (_locationNoticeShown) return;
    _locationNoticeShown = true;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(context.l10n.locationUsageNotice),
        duration: const Duration(seconds: 4),
      ),
    );
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) _showLocationNoticeIfNeeded();
    });
    final city = ref.read(buyerCityProvider);
    final marketplace = ref.read(buyerMarketplaceSlugProvider);
    if (_loadedCity != city || _loadedMarketplace != marketplace) {
      _loadedCity = city;
      _loadedMarketplace = marketplace;
      _selectedZone = null;
      _mapFuture = _loadMapData(city, marketplace: marketplace);
    }
  }

  void _reload(String city, {String? marketplace}) {
    setState(() {
      _loadedCity = city;
      _loadedMarketplace = marketplace;
      _selectedZone = null;
      _mapFuture = _loadMapData(city, marketplace: marketplace);
    });
  }

  List<String> _zonesForPins(List<MapPinModel> pins) {
    final zones = <String>{};
    for (final pin in pins) {
      final label = pin.zoneLabel.trim();
      if (label.isNotEmpty) zones.add(label);
    }
    return zones.toList()..sort();
  }

  List<MapPinModel> _filteredPins(List<MapPinModel> pins) {
    if (_selectedZone == null || _selectedZone!.isEmpty) return pins;
    return pins
        .where((pin) => pin.zoneLabel.trim() == _selectedZone)
        .toList();
  }

  Map<String, List<MapPinModel>> _groupPinsByZone(List<MapPinModel> pins) {
    final grouped = <String, List<MapPinModel>>{};
    for (final pin in pins) {
      final key = pin.zoneLabel.trim().isEmpty
          ? context.l10n.mapZoneFilterAll
          : pin.zoneLabel.trim();
      grouped.putIfAbsent(key, () => []).add(pin);
    }
    final sortedKeys = grouped.keys.toList()..sort();
    return {for (final key in sortedKeys) key: grouped[key]!};
  }

  @override
  Widget build(BuildContext context) {
    final city = ref.watch(buyerCityProvider);
    final marketplace = ref.watch(buyerMarketplaceSlugProvider);
    final l10n = context.l10n;

    if (_loadedCity != city || _loadedMarketplace != marketplace) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (!mounted) return;
        _loadedMarketplace = marketplace;
        _reload(city, marketplace: marketplace);
      });
    }

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
              onRetry: () => _reload(city, marketplace: marketplace),
            ),
          );
        }

        final data = snapshot.data!;
        final allPins = data.pins;
        final warnings = data.warnings;
        final usingDemo = data.usingDemo;
        final zones = _zonesForPins(allPins);
        final pins = _filteredPins(allPins);
        final grouped = _groupPinsByZone(allPins);
        final showZoneControls =
            marketplace != null && marketplace.isNotEmpty && zones.isNotEmpty;

        final initial = pins.isNotEmpty
            ? LatLng(pins.first.latitude, pins.first.longitude)
            : CityCoordinates.centerFor(city);

        final markers = <Marker>{
          ...pins.map((pin) {
            final snippet = pin.stallLocationSummary.isNotEmpty
                ? pin.stallLocationSummary
                : pin.goldenCrowns > 0
                    ? '${pin.averageRating} ★ · ${pin.goldenCrowns} golden crown(s)'
                    : '${pin.averageRating} ★ · ${pin.achievementStars} achievement stars';
            return Marker(
              markerId: MarkerId(pin.id),
              position: LatLng(pin.latitude, pin.longitude),
              infoWindow: InfoWindow(
                title: pin.businessName,
                snippet: snippet,
                onTap: () => context.push('/seller/${pin.id}'),
              ),
              icon: pin.isSellerPro
                  ? BitmapDescriptor.defaultMarkerWithHue(
                      BitmapDescriptor.hueAzure)
                  : pin.goldenCrowns > 0
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
            if (showZoneControls)
              Positioned(
                top: MediaQuery.of(context).padding.top + 88,
                left: AppSpacing.screenHorizontal,
                right: AppSpacing.screenHorizontal,
                child: SingleChildScrollView(
                  scrollDirection: Axis.horizontal,
                  child: Row(
                    children: [
                      Padding(
                        padding: const EdgeInsets.only(right: 8),
                        child: FilterChip(
                          label: Text(l10n.mapZoneFilterAll),
                          selected: _selectedZone == null,
                          onSelected: (_) => setState(() => _selectedZone = null),
                        ),
                      ),
                      for (final zone in zones)
                        Padding(
                          padding: const EdgeInsets.only(right: 8),
                          child: FilterChip(
                            label: Text(zone),
                            selected: _selectedZone == zone,
                            onSelected: (_) => setState(() => _selectedZone = zone),
                          ),
                        ),
                    ],
                  ),
                ),
              ),
            if (showZoneControls)
              Positioned(
                bottom: AppSpacing.lg,
                right: AppSpacing.screenHorizontal,
                child: FloatingActionButton.extended(
                  onPressed: () => setState(() => _showZonePanel = !_showZonePanel),
                  icon: Icon(_showZonePanel
                      ? Icons.map_outlined
                      : Icons.view_list_outlined),
                  label: Text(l10n.mapZoneHierarchyTitle),
                ),
              ),
            if (_showZonePanel && showZoneControls)
              Positioned(
                left: AppSpacing.screenHorizontal,
                right: AppSpacing.screenHorizontal,
                bottom: AppSpacing.lg + 56,
                child: ConstrainedBox(
                  constraints: BoxConstraints(
                    maxHeight: MediaQuery.of(context).size.height * 0.34,
                  ),
                  child: BuyerSurfaceCard(
                    child: ListView(
                      padding: const EdgeInsets.all(AppSpacing.md),
                      children: [
                        Text(
                          l10n.mapZoneHierarchyTitle,
                          style: Theme.of(context)
                              .textTheme
                              .titleSmall
                              ?.copyWith(fontWeight: FontWeight.w700),
                        ),
                        const SizedBox(height: AppSpacing.sm),
                        for (final entry in grouped.entries) ...[
                          Text(
                            entry.key,
                            style: TextStyle(
                              color: context.colors.primary,
                              fontWeight: FontWeight.w700,
                            ),
                          ),
                          const SizedBox(height: 4),
                          if (entry.value.isEmpty)
                            Text(l10n.noShopsInZone)
                          else
                            ...entry.value.map(
                              (pin) => ListTile(
                                contentPadding: EdgeInsets.zero,
                                dense: true,
                                title: Text(pin.businessName),
                                subtitle: pin.stallLocationSummary.isNotEmpty
                                    ? Text(pin.stallLocationSummary)
                                    : null,
                                trailing: const Icon(Icons.chevron_right),
                                onTap: () => context.push('/seller/${pin.id}'),
                              ),
                            ),
                          const SizedBox(height: AppSpacing.sm),
                        ],
                      ],
                    ),
                  ),
                ),
              ),
            if (usingDemo)
              Positioned(
                bottom: AppSpacing.lg,
                left: AppSpacing.screenHorizontal,
                right: showZoneControls ? 160 : AppSpacing.screenHorizontal,
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

  Future<_MapData> _loadMapData(String city, {String? marketplace}) async {
    try {
      final results = await Future.wait([
        apiServiceProvider.fetchMapPins(
          city: city,
          marketplace: marketplace,
        ),
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
