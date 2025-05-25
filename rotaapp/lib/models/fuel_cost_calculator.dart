// lib/models/fuel_cost_calculator.dart
import 'vehicle.dart';

class FuelCostCalculator {
  final Vehicle vehicle;
  final double fuelPricePerLiter;
  final double cityPercentage; // Şehir içi yolculuk yüzdesi (0-100)

  FuelCostCalculator({
    required this.vehicle,
    required this.fuelPricePerLiter,
    this.cityPercentage = 50.0,
  });

  // Rota maliyetini hesapla (min ve max değerler)
  Map<String, double> calculateRouteCost(
    double distanceInKm, {
    double additionalTollCost = 0.0,
  }) {
    // Nullable alanlar için varsayılan değerler veya hata yönetimi
    // Eğer bu alanlar null ise, bir varsayılan değer kullanabilir veya
    // hesaplama yapılamayacağına dair bir hata/uyarı döndürebilirsiniz.
    // Şimdilik, eğer null ise 0.0 olarak varsayalım, ama bu projenizin
    // mantığına göre değişebilir.
    final double vehicleCityConsumption = vehicle.cityConsumption ?? 0.0;
    final double vehicleHighwayConsumption = vehicle.highwayConsumption ?? 0.0;

    // Eğer tüketim değerleri 0 ise ve bu bir hata durumunu gösteriyorsa,
    // burada erken bir dönüş yapabilir veya bir exception fırlatabilirsiniz.
    // Örneğin:
    // if (vehicleCityConsumption <= 0 || vehicleHighwayConsumption <= 0) {
    //   print("Uyarı: Araç için geçerli şehir içi veya şehir dışı tüketim değeri bulunamadı.");
    //   return {'minCost': additionalTollCost, 'maxCost': additionalTollCost}; // Sadece ek maliyet döner
    // }

    final double cityDistance = (distanceInKm * cityPercentage) / 100;
    final double highwayDistance = distanceInKm - cityDistance;

    final double cityFuelConsumption =
        (cityDistance * vehicleCityConsumption) / 100;
    final double highwayFuelConsumption =
        (highwayDistance * vehicleHighwayConsumption) / 100;

    final double totalFuelConsumption =
        cityFuelConsumption + highwayFuelConsumption;

    final double baseFuelCost = totalFuelConsumption * fuelPricePerLiter;
    final double baseTotalCost = baseFuelCost + additionalTollCost;

    final double minCost = baseTotalCost * 0.9;
    final double maxCost = baseTotalCost * 1.1;

    return {
      'minCost': minCost > 0 ? minCost : 0.0,
      'maxCost': maxCost > 0 ? maxCost : 0.0
    };
  }

  // Rota detaylarını hesapla
  Map<String, dynamic> calculateRouteDetails(
    double distanceInKm, {
    double additionalTollCost = 0.0,
  }) {
    final double vehicleCityConsumption = vehicle.cityConsumption ?? 0.0;
    final double vehicleHighwayConsumption = vehicle.highwayConsumption ?? 0.0;

    // if (vehicleCityConsumption <= 0 || vehicleHighwayConsumption <= 0) {
    //   // ... yukarıdaki gibi bir hata yönetimi veya varsayılan değer ataması ...
    // }

    final double cityDistance = (distanceInKm * cityPercentage) / 100;
    final double highwayDistance = distanceInKm - cityDistance;

    final double cityFuelLitres =
        (cityDistance * vehicleCityConsumption) / 100;
    final double highwayFuelLitres =
        (highwayDistance * vehicleHighwayConsumption) / 100;

    final double totalFuelLitres =
        cityFuelLitres + highwayFuelLitres;

    final double baseFuelCost = totalFuelLitres * fuelPricePerLiter;
    final double baseTotalCost = baseFuelCost + additionalTollCost;

    final double minCost = baseTotalCost * 0.9;
    final double maxCost = baseTotalCost * 1.1;

    return {
      'totalDistance': distanceInKm,
      'cityDistance': cityDistance,
      'highwayDistance': highwayDistance,
      'cityFuelConsumption': cityFuelLitres, // Litre cinsinden
      'highwayFuelConsumption': highwayFuelLitres, // Litre cinsinden
      'totalFuelConsumption': totalFuelLitres, // Litre cinsinden
      'minCost': minCost > 0 ? minCost : 0.0,
      'maxCost': maxCost > 0 ? maxCost : 0.0,
      'additionalTollCost': additionalTollCost,
    };
  }
}