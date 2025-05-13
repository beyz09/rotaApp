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
    // Yakıt maliyetini hesapla (bu metot sadece toplam aralığı döndürse de, yakıt maliyeti gerekli)
    final double calculatedFuelCost = _calculateFuelCost(distanceInKm);

    // Toplam temel maliyet (yakıt + ek maliyet)
    final double baseTotalCost = calculatedFuelCost + additionalTollCost;

    // Minimum ve maksimum maliyet hesaplama (%10 sapma ile)
    // Sapmayı sadece yakıt maliyetine uygulayabiliriz veya toplam maliyete.
    // Toplam maliyete uygulayalım, daha basit.
    // Daha doğru bir yaklaşım: sadece yakıt maliyetine sapma uygulayıp, gişe maliyetini sabit tutmak.
    // Gİşe maliyeti genellikle sabittir, yakıt tüketimi değişkendir.
    final double minFuelCost = calculatedFuelCost * 0.9; // %10 daha az
    final double maxFuelCost = calculatedFuelCost * 1.1; // %10 daha fazla

    final double minCost = minFuelCost + additionalTollCost;
    final double maxCost = maxFuelCost + additionalTollCost;


    // Maliyetin negatif olmamasına dikkat et
    return {'minCost': minCost > 0 ? minCost : 0.0, 'maxCost': maxCost > 0 ? maxCost : 0.0};
  }

  // Yakıt maliyetini hesaplayan yardımcı metot (TL)
  double _calculateFuelCost(double distanceInKm) {
     // Şehir içi ve şehir dışı mesafeleri hesapla
    final double cityDistance = (distanceInKm * cityPercentage) / 100;
    final double highwayDistance = distanceInKm - cityDistance;

    // Şehir içi ve şehir dışı yakıt tüketimlerini hesapla (litre)
    final double cityFuelConsumption =
        (cityDistance * vehicle.cityConsumption) / 100;
    final double highwayFuelConsumption =
        (highwayDistance * vehicle.highwayConsumption) / 100;

    // Toplam yakıt tüketimi (litre)
    final double totalFuelConsumption =
        cityFuelConsumption + highwayFuelConsumption;

    // Yakıt maliyeti (TL)
    return totalFuelConsumption * fuelPricePerLiter;
  }

   // Toplam yakıt tüketimini hesaplayan yardımcı metot (litre)
  double calculateTotalFuelConsumption(double distanceInKm) {
     final double cityDistance = (distanceInKm * cityPercentage) / 100;
     final double highwayDistance = distanceInKm - cityDistance;

     final double cityFuelConsumption = (cityDistance * vehicle.cityConsumption) / 100;
     final double highwayFuelConsumption = (highwayDistance * vehicle.highwayConsumption) / 100;

     return cityFuelConsumption + highwayFuelConsumption;
  }


  // Rota detaylarını hesapla
  // additionalTollCost: Yakıt maliyetine ek olarak sabit ücretli yol maliyeti (TL)
  Map<String, dynamic> calculateRouteDetails(
    double distanceInKm, {
    double additionalTollCost = 0.0,
  }) {
    final double cityDistance = (distanceInKm * cityPercentage) / 100;
    final double highwayDistance = distanceInKm - cityDistance;

    // Yakıt tüketimi ve maliyetini hesapla
    final double totalFuelConsumption = calculateTotalFuelConsumption(distanceInKm);
    final double calculatedFuelCost = totalFuelConsumption * fuelPricePerLiter; // <-- BURASI YAKIT MALİYETİ (TL)

    // Toplam maliyet aralığını hesapla (FuelCostCalculator'ın kendi mantığına göre)
    final Map<String, double> costRange = calculateRouteCost(distanceInKm, additionalTollCost: additionalTollCost);


    return {
      'totalDistance': distanceInKm,
      'cityDistance': cityDistance,
      'highwayDistance': highwayDistance,
      // 'cityFuelConsumption': cityFuelConsumption, // İsteğe bağlı detaylar, şimdilik toplam yeterli
      // 'highwayFuelConsumption': highwayFuelConsumption, // İsteğe bağlı detaylar
      'totalFuelConsumption': totalFuelConsumption, // Toplam litre
      'calculatedFuelCost': calculatedFuelCost, // <-- YENİ EKLENDİ: Hesaplanan Yakıt Maliyeti (TL)
      'minCost': costRange['minCost'], // Toplam min maliyet (yakıt+gişe+sapma)
      'maxCost': costRange['maxCost'], // Toplam max maliyet (yakıt+gişe+sapma)
      'additionalTollCost': additionalTollCost, // Gelen Gişe Maliyeti (TL)
    };
  }
}