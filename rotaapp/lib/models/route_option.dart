// models/route_option.dart
import 'package:latlong2/latlong.dart';
import 'route_step.dart'; // RouteStep modelini import et

class RouteOption {
  final String name;
  final String distance; // String formatında (örn: "123.4 km")
  final String duration; // String formatında (örn: "45 dk")
  final bool isTollRoad;
  final List<LatLng> points; // Rota çizgisinin koordinatları
  final Map<String, double>? costRange; // Tahmini yakıt maliyeti aralığı
  final Map<String, dynamic>? routeDetails; // Yakıt tüketimi, ek maliyet vb. detaylar
  final List<RouteStep> steps; // Adım adım talimatların listesi
  final List<String> intermediatePlaces; // <<-- YENİ: Geçilen il/ilçe listesi

  RouteOption({
    required this.name,
    required this.distance,
    required this.duration,
    required this.isTollRoad,
    required this.points,
    this.costRange,
    this.routeDetails,
    required this.steps,
    this.intermediatePlaces = const [], // <<-- YENİ: Constructor'a eklendi, varsayılan boş liste
  });

  // Mesafe stringinden sayısal km değerini almak için getter
  double get distanceInKm {
    // " km" kısmını silip double'a çevirir. Hata durumunda 0.0 döner.
    return double.tryParse(distance.replaceAll(' km', '').trim()) ?? 0.0;
  }

  // Süre stringinden sayısal dakika değerini almak için getter
  int get durationInMinutes {
    // " dk" kısmını silip int'e çevirir. Hata durumunda 0 döner.
    return int.tryParse(duration.replaceAll(' dk', '').trim()) ?? 0;
  }

   // equals ve hashCode metodlarını RouteOption nesnelerini karşılaştırmak için ekleyelim (Eğer önceki adımda eklediyseniz tekrar eklemeye gerek yok, ama burada tam model olması için tuttum)
  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is RouteOption &&
          runtimeType == other.runtimeType &&
          name == other.name &&
          distance == other.distance &&
          duration == other.duration &&
          points.length == other.points.length; // Basit bir eşitlik kontrolü

  @override
  int get hashCode =>
      name.hashCode ^ distance.hashCode ^ duration.hashCode ^ points.length.hashCode;
}