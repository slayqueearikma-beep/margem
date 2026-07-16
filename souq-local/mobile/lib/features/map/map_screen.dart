import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';

import '../../core/models/models.dart';
import '../../core/services/api_service.dart';
import '../../core/theme/app_theme.dart';
import '../home/home_shell.dart';

class MapScreen extends ConsumerStatefulWidget {
  const MapScreen({super.key});

  @override
  ConsumerState<MapScreen> createState() => _MapScreenState();
}

class _MapScreenState extends ConsumerState<MapScreen> {
  GoogleMapController? _controller;

  @override
  Widget build(BuildContext context) {
    final city = ref.watch(selectedCityProvider);

    return FutureBuilder<(List<MapPinModel>, List<WarningZoneModel>)>(
      future: _loadMapData(city),
      builder: (context, snapshot) {
        if (!snapshot.hasData) {
          return const Center(child: CircularProgressIndicator());
        }

        final pins = snapshot.data!.$1;
        final warnings = snapshot.data!.$2;

        final sellerMarkers = pins.map((pin) {
          return Marker(
            markerId: MarkerId(pin.id),
            position: LatLng(pin.latitude, pin.longitude),
            infoWindow: InfoWindow(
              title: pin.businessName,
              snippet: '${pin.averageRating} ★ · ${pin.achievementStars} achievement stars',
              onTap: () => context.push('/seller/${pin.id}'),
            ),
            icon: pin.achievementStars > 0
                ? BitmapDescriptor.defaultMarkerWithHue(BitmapDescriptor.hueOrange)
                : BitmapDescriptor.defaultMarker,
          );
        }).toSet();

        final warningMarkers = warnings.map((zone) {
          return Marker(
            markerId: MarkerId('warning-${zone.id}'),
            position: LatLng(zone.latitude, zone.longitude),
            icon: BitmapDescriptor.defaultMarkerWithHue(BitmapDescriptor.hueRed),
            infoWindow: InfoWindow(title: '⚠ ${zone.name}', snippet: zone.description),
          );
        }).toSet();

        final initial = pins.isNotEmpty
            ? LatLng(pins.first.latitude, pins.first.longitude)
            : const LatLng(33.5731, -7.5898); // Casablanca

        return Stack(
          children: [
            GoogleMap(
              initialCameraPosition: CameraPosition(target: initial, zoom: 13),
              markers: {...sellerMarkers, ...warningMarkers},
              onMapCreated: (controller) => _controller = controller,
              myLocationButtonEnabled: true,
              myLocationEnabled: true,
            ),
            Positioned(
              top: MediaQuery.of(context).padding.top + 12,
              left: 16,
              right: 16,
              child: Card(
                child: Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                  child: Row(
                    children: [
                      const Icon(Icons.location_on_outlined, color: AppColors.orange),
                      const SizedBox(width: 8),
                      Text(city, style: const TextStyle(fontWeight: FontWeight.w600)),
                      const Spacer(),
                      if (warnings.isNotEmpty)
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                          decoration: BoxDecoration(
                            color: Colors.red.withValues(alpha: 0.12),
                            borderRadius: BorderRadius.circular(12),
                          ),
                          child: Text('${warnings.length} warning zone(s)', style: const TextStyle(color: Colors.red, fontSize: 12)),
                        ),
                    ],
                  ),
                ),
              ),
            ),
          ],
        );
      },
    );
  }

  Future<(List<MapPinModel>, List<WarningZoneModel>)> _loadMapData(String city) async {
    final results = await Future.wait([
      apiServiceProvider.fetchMapPins(city: city),
      apiServiceProvider.fetchWarningZones(city: city),
    ]);
    return (results[0] as List<MapPinModel>, results[1] as List<WarningZoneModel>);
  }
}
