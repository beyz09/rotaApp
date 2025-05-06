import 'package:latlong2/latlong.dart';

class RouteOption {
  final String name;
  final String distance;
  final String duration;
  final bool isTollRoad;
  final List<LatLng> points;
  final Map<String, double>? costRange;
  final Map<String, dynamic>? routeDetails;

  RouteOption({
    required this.name,
    required this.distance,
    required this.duration,
    required this.isTollRoad,
    required this.points,
    this.costRange,
    this.routeDetails,
  });

  double get distanceInKm {
    return double.parse(distance.replaceAll(' km', ''));
  }

  int get durationInMinutes {
    return int.parse(duration.replaceAll(' dk', ''));
  }
}
