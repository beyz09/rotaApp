// lib/models/fuel_cost_calculator.dart
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
  // additionalTollCost: Yakıt maliyetine ek olarak sabit ücretli yol maliyeti (TL)
  Map<String, double> calculateRouteCost(
    double distanceInKm, {
    double additionalTollCost = 0.0,
  }) {
    // Şehir içi ve şehir dışı mesafeleri hesapla
    final double cityDistance = (distanceInKm * cityPercentage) / 100;
    final double highwayDistance = distanceInKm - cityDistance;

    // Şehir içi ve şehir dışı yakıt tüketimlerini hesapla
    final double cityFuelConsumption =
        (cityDistance * vehicle.cityConsumption) / 100; // litre
    final double highwayFuelConsumption =
        (highwayDistance * vehicle.highwayConsumption) / 100; // litre

    // Toplam yakıt tüketimi (litre)
    final double totalFuelConsumption =
        cityFuelConsumption + highwayFuelConsumption;

    // Temel yakıt maliyeti (TL)
    final double baseFuelCost = totalFuelConsumption * fuelPricePerLiter;

    // Toplam temel maliyet (yakıt + ek maliyet)
    final double baseTotalCost = baseFuelCost + additionalTollCost;

    // Minimum ve maksimum maliyet hesaplama (%10 sapma ile)
    // Sapmayı sadece yakıt maliyetine uygulayabiliriz veya toplam maliyete.
    // Toplam maliyete uygulayalım, daha basit.
    final double minCost = baseTotalCost * 0.9; // %10 daha az
    final double maxCost = baseTotalCost * 1.1; // %10 daha fazla

    // Maliyetin negatif olmamasına dikkat et
    return {'minCost': minCost > 0 ? minCost : 0.0, 'maxCost': maxCost > 0 ? maxCost : 0.0};
  }

  // Rota detaylarını hesapla
  // additionalTollCost: Yakıt maliyetine ek olarak sabit ücretli yol maliyeti (TL)
  Map<String, dynamic> calculateRouteDetails(
    double distanceInKm, {
    double additionalTollCost = 0.0,
  }) {
    final double cityDistance = (distanceInKm * cityPercentage) / 100;
    final double highwayDistance = distanceInKm - cityDistance;

    final double cityFuelConsumption =
        (cityDistance * vehicle.cityConsumption) / 100;
    final double highwayFuelConsumption =
        (highwayDistance * vehicle.highwayConsumption) / 100;

    final double totalFuelConsumption =
        cityFuelConsumption + highwayFuelConsumption;

    final double baseFuelCost = totalFuelConsumption * fuelPricePerLiter;
    final double baseTotalCost = baseFuelCost + additionalTollCost;

    final double minCost = baseTotalCost * 0.9;
    final double maxCost = baseTotalCost * 1.1;

    return {
      'totalDistance': distanceInKm,
      'cityDistance': cityDistance,
      'highwayDistance': highwayDistance,
      'cityFuelConsumption': cityFuelConsumption,
      'highwayFuelConsumption': highwayFuelConsumption,
      'totalFuelConsumption': totalFuelConsumption,
      'minCost': minCost > 0 ? minCost : 0.0,
      'maxCost': maxCost > 0 ? maxCost : 0.0,
      'additionalTollCost': additionalTollCost, // Ek ücretli yol maliyetini de detaylara ekleyelim
    };
  }
}