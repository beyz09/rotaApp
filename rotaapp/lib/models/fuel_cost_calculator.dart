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

  Map<String, double> calculateRouteCost(
    double distanceInKm, {
    double additionalTollCost = 0.0,
  }) {
    final double calculatedFuelCost = _calculateFuelCost(distanceInKm);

    final double minFuelCost = calculatedFuelCost * 0.9;
    final double maxFuelCost = calculatedFuelCost * 1.1;

    final double minCost = minFuelCost + additionalTollCost;
    final double maxCost = maxFuelCost + additionalTollCost;

    return {
      'minCost': minCost > 0 ? minCost : 0.0,
      'maxCost': maxCost > 0 ? maxCost : 0.0
    };
  }

  double _calculateFuelCost(double distanceInKm) {
    final double cityDistance = (distanceInKm * cityPercentage) / 100;
    final double highwayDistance = distanceInKm - cityDistance;

    final double cityFuelConsumption =
        (cityDistance * (vehicle.cityConsumption ?? 0.0)) / 100; // DÜZELTİLDİ
    final double highwayFuelConsumption =
        (highwayDistance * (vehicle.highwayConsumption ?? 0.0)) / 100; // DÜZELTİLDİ

    final double totalFuelConsumption =
        cityFuelConsumption + highwayFuelConsumption;

    return totalFuelConsumption * fuelPricePerLiter;
  }

  double calculateTotalFuelConsumption(double distanceInKm) {
    final double cityDistance = (distanceInKm * cityPercentage) / 100;
    final double highwayDistance = distanceInKm - cityDistance;

    final double cityFuelConsumption =
        (cityDistance * (vehicle.cityConsumption ?? 0.0)) / 100; // DÜZELTİLDİ
    final double highwayFuelConsumption =
        (highwayDistance * (vehicle.highwayConsumption ?? 0.0)) / 100; // DÜZELTİLDİ

    return cityFuelConsumption + highwayFuelConsumption;
  }

  Map<String, dynamic> calculateRouteDetails(
    double distanceInKm, {
    double additionalTollCost = 0.0,
  }) {
    final double cityDistance = (distanceInKm * cityPercentage) / 100;
    final double highwayDistance = distanceInKm - cityDistance;

    final double totalFuelConsumption =
        calculateTotalFuelConsumption(distanceInKm);
    final double calculatedFuelCost =
        totalFuelConsumption * fuelPricePerLiter;

    final Map<String, double> costRange =
        calculateRouteCost(distanceInKm, additionalTollCost: additionalTollCost);

    return {
      'totalDistance': distanceInKm,
      'cityDistance': cityDistance,
      'highwayDistance': highwayDistance,
      'totalFuelConsumption': totalFuelConsumption,
      'calculatedFuelCost': calculatedFuelCost,
      'minCost': costRange['minCost'],
      'maxCost': costRange['maxCost'],
      'additionalTollCost': additionalTollCost,
    };
  }
}