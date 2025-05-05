class Vehicle {
  final String id; // Benzersiz ID
  final String brand;
  final String model;
  final String fuelType; // Benzin, Dizel, Elektrik vb.
  final double cityConsumption; // Şehir içi yakıt tüketimi (L/100km)
  final double highwayConsumption; // Şehir dışı yakıt tüketimi (L/100km)
  // Başka özellikler eklenebilir (Yıl, Motor vb.)

  Vehicle({
    required this.id,
    required this.brand,
    required this.model,
    required this.fuelType,
    required this.cityConsumption,
    required this.highwayConsumption,
  });
}