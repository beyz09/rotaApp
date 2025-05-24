class Vehicle {
  final String id; // Benzersiz ID
  final String brand;
  final String model;
  final String plate; // Plaka
  final int year; // Üretim yılı
  final String fuelType; // Benzin, Dizel, Elektrik vb.
  final double cityConsumption; // Şehir içi yakıt tüketimi (L/100km)
  final double highwayConsumption; // Şehir dışı yakıt tüketimi (L/100km)
  // Başka özellikler eklenebilir (Yıl, Motor vb.)

  final int vehicleType; // Araç türü (1-6 arasında)

  Vehicle({
    required this.id,
    required this.brand,
    required this.model,
    required this.plate,
    required this.year,
    required this.fuelType,
    required this.cityConsumption,
    required this.highwayConsumption,
    required this.vehicleType,
  });
}
