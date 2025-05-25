// lib/models/vehicle.dart
import 'package:cloud_firestore/cloud_firestore.dart';

class Vehicle {
  final String id;
  final String marka;
  final String seri;
  final String model;
  final int yil;
  final String yakitTipi;
  final String vites;
  final String kasaTipi;
  final String motorGucu;
  final String motorHacmi;
  final String cekis;
  // YENİ EKLENEN ALANLAR (nullable olabilirler)
  final double? cityConsumption;
  final double? highwayConsumption;

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
    this.cityConsumption, // Constructor'a opsiyonel olarak eklendi
    this.highwayConsumption, // Constructor'a opsiyonel olarak eklendi
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
      // Eğer Firestore'da bu alanlar yoksa, bu satırlar null atayacaktır.
      // Firestore'daki alan adının 'CityConsumption' ve 'HighwayConsumption' olduğunu varsayıyorum.
      // Lütfen kendi Firestore alan adlarınızla değiştirin.
      cityConsumption: (data?['CityConsumption'] as num?)?.toDouble(),
      highwayConsumption: (data?['HighwayConsumption'] as num?)?.toDouble(),
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
      // Eğer bu alanlar null değilse Firestore'a yaz
      if (cityConsumption != null) "CityConsumption": cityConsumption,
      if (highwayConsumption != null) "HighwayConsumption": highwayConsumption,
    };
  }
}
