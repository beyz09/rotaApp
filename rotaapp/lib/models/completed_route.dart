import 'package:latlong2/latlong.dart';

class CompletedRoute {
  final String id;
  final String startLocation;
  final String endLocation;
  final double distanceInKm;
  final int durationInMinutes;
  final String vehicleId;
  final double fuelCost;
  final DateTime completedAt;

  CompletedRoute({
    required this.id,
    required this.startLocation,
    required this.endLocation,
    required this.distanceInKm,
    required this.durationInMinutes,
    required this.vehicleId,
    required this.fuelCost,
    required this.completedAt,
  });
}
