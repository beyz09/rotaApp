import 'package:latlong2/latlong.dart';
import 'vehicle.dart';

class FuelCostCalculator {
  final Vehicle vehicle;
  final double fuelPricePerLiter;
  final double cityPercentage; // Şehir içi yolculuk yüzdesi (0-100)

  FuelCostCalculator({
    required this.vehicle,
    required this.fuelPricePerLiter,
    this.cityPercentage = 50.0, // Varsayılan olarak %50 şehir içi
  });

  // Rota maliyetini hesapla (min ve max değerler)
  Map<String, double> calculateRouteCost(double distanceInKm) {
    // Şehir içi ve şehir dışı mesafeleri hesapla
    final double cityDistance = (distanceInKm * cityPercentage) / 100;
    final double highwayDistance = distanceInKm - cityDistance;

    // Şehir içi ve şehir dışı yakıt tüketimlerini hesapla
    final double cityFuelConsumption =
        (cityDistance * vehicle.cityConsumption) / 100;
    final double highwayFuelConsumption =
        (highwayDistance * vehicle.highwayConsumption) / 100;

    // Toplam yakıt tüketimi
    final double totalFuelConsumption =
        cityFuelConsumption + highwayFuelConsumption;

    // Minimum ve maksimum maliyet hesaplama (%10 sapma ile)
    final double baseCost = totalFuelConsumption * fuelPricePerLiter;
    final double minCost = baseCost * 0.9; // %10 daha az
    final double maxCost = baseCost * 1.1; // %10 daha fazla

    return {'minCost': minCost, 'maxCost': maxCost};
  }

  // Rota detaylarını hesapla
  Map<String, dynamic> calculateRouteDetails(double distanceInKm) {
    final double cityDistance = (distanceInKm * cityPercentage) / 100;
    final double highwayDistance = distanceInKm - cityDistance;

    final double cityFuelConsumption =
        (cityDistance * vehicle.cityConsumption) / 100;
    final double highwayFuelConsumption =
        (highwayDistance * vehicle.highwayConsumption) / 100;

    final double totalFuelConsumption =
        cityFuelConsumption + highwayFuelConsumption;

    final double baseCost = totalFuelConsumption * fuelPricePerLiter;
    final double minCost = baseCost * 0.9;
    final double maxCost = baseCost * 1.1;

    return {
      'totalDistance': distanceInKm,
      'cityDistance': cityDistance,
      'highwayDistance': highwayDistance,
      'cityFuelConsumption': cityFuelConsumption,
      'highwayFuelConsumption': highwayFuelConsumption,
      'totalFuelConsumption': totalFuelConsumption,
      'minCost': minCost,
      'maxCost': maxCost,
    };
  }
}
