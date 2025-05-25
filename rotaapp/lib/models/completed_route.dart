// lib/models/completed_route.dart
// import 'package:latlong2/latlong.dart'; // Kullanılmadığı için kaldırıldı

class CompletedRoute {
  final String id;
  final String startLocation;
  final String endLocation;
  final double distanceInKm;
  final int durationInMinutes;
  final String vehicleId;
  final double fuelCost; // Maliyet (TL)
  // final double consumption; // Bu alan modelde yoktu, fuelCost var.
  // Eğer litre cinsinden tüketim de saklanacaksa, buraya 'fuelConsumptionLiters' gibi bir alan eklenmeli.
  final DateTime completedAt;

  CompletedRoute({
    required this.id,
    required this.startLocation,
    required this.endLocation,
    required this.distanceInKm,
    required this.durationInMinutes,
    required this.vehicleId,
    required this.fuelCost, // 'cost' yerine 'fuelCost' kullanıyoruz
    required this.completedAt,
  });

  // Getter'lar (durationInMinutes ve fuelCost zaten doğrudan alan olarak var,
  // distanceInKm de doğrudan alan. Bu getter'lar aslında gereksiz ama kalabilir.)
  // double get distanceInKm => distance; // 'distance' alanı yok, 'distanceInKm' var
  // int get durationInMinutes => (distanceInKm / 50 * 60).round(); // 'durationInMinutes' zaten bir alan
  // double get fuelCost => cost; // 'cost' alanı yok, 'fuelCost' var
}