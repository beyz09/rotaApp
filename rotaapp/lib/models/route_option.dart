import 'package:latlong2/latlong.dart';

class RouteOption {
  final String name;
  final String distance;
  final String duration;
  final bool isTollRoad;
  final List<LatLng> points;
  // Figma'daki maliyet bilgisi için eklenebilir
  final double? cost; // double? null olabilir

  RouteOption({
    required this.name,
    required this.distance,
    required this.duration,
    required this.isTollRoad,
    required this.points,
    this.cost, // Maliyet opsiyonel
  });
}