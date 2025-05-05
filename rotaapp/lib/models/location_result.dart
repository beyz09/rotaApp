import 'package:latlong2/latlong.dart';

class LocationResult {
  final String displayName;
  final LatLng coordinates;
  final String type;

  LocationResult({
    required this.displayName,
    required this.coordinates,
    required this.type,
  });
}