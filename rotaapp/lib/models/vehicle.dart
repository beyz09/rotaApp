// lib/models/vehicle.dart
import 'package:cloud_firestore/cloud_firestore.dart';

class Vehicle {
  final String id;
  final String marka; // map_screen.dart'ta 'brand' yerine bu kullanılacak
  final String seri;
  final String model; // map_screen.dart'ta bu doğru kullanılıyordu
  final int yil;
  final String yakitTipi;
  final String vites;
  final String kasaTipi;
  final String motorGucu;
  final String motorHacmi;
  final String cekis;
  final double? cityConsumption; // fuel_cost_calculator.dart için önemli
  final double? highwayConsumption; // fuel_cost_calculator.dart için önemli

  Vehicle({
    required this.id,
    required this.marka,
    required this.seri,
    required this.model,
    required this.yil,
    required this.yakitTipi,
    required this.vites,
    required this.kasaTipi,
    required this.motorGucu,
    required this.motorHacmi,
    required this.cekis,
    this.cityConsumption,
    this.highwayConsumption,
  });

  factory Vehicle.fromFirestore(DocumentSnapshot<Map<String, dynamic>> snapshot,
      SnapshotOptions? options) {
    final data = snapshot.data();
    return Vehicle(
      id: snapshot.id,
      marka: data?['Marka'] as String? ?? 'Bilinmiyor',
      seri: data?['Seri'] as String? ?? 'Bilinmiyor',
      model: data?['Model'] as String? ?? 'Bilinmiyor',
      yil: int.tryParse(data?['Yıl']?.toString() ?? '0') ?? 0,
      yakitTipi: data?['Yakıt Tipi'] as String? ?? 'Bilinmiyor',
      vites: data?['Vites'] as String? ?? 'Bilinmiyor',
      kasaTipi: data?['Kasa Tipi'] as String? ?? 'Bilinmiyor',
      motorGucu: data?['Motor Gücü'] as String? ?? 'Bilinmiyor',
      motorHacmi: data?['Motor Hacmi'] as String? ?? 'Bilinmiyor',
      cekis: data?['Çekiş'] as String? ?? 'Bilinmiyor',
      // Firestore'daki alan adlarınızı buraya yazın.
      // Örneğin: 'city_consumption' veya 'CityConsumption'
      cityConsumption: (data?['CityConsumption'] as num?)?.toDouble(), // Firestore alan adını kontrol edin
      highwayConsumption: (data?['HighwayConsumption'] as num?)?.toDouble(), // Firestore alan adını kontrol edin
    );
  }

  Map<String, dynamic> toFirestore() {
    return {
      "Marka": marka,
      "Seri": seri,
      "Model": model,
      "Yıl": yil,
      "Yakıt Tipi": yakitTipi,
      "Vites": vites,
      "Kasa Tipi": kasaTipi,
      "Motor Gücü": motorGucu,
      "Motor Hacmi": motorHacmi,
      "Çekiş": cekis,
      if (cityConsumption != null) "CityConsumption": cityConsumption, // Firestore alan adını kontrol edin
      if (highwayConsumption != null) "HighwayConsumption": highwayConsumption, // Firestore alan adını kontrol edin
    };
  }
}