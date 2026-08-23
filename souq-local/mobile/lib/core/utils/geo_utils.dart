/// Distance formatting for local discovery.
class GeoUtils {
  GeoUtils._();

  static String formatDistanceKm(double km) {
    if (km < 1) return '${(km * 1000).round()} m';
    return '${km.toStringAsFixed(1)} km';
  }
}
