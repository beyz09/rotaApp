// models/route_option.dart
import 'package:latlong2/latlong.dart'; // Coğrafi koordinatlar için
import 'route_step.dart'; // Rota adımlarını temsil eden RouteStep modelini import et

// Kullanıcıya sunulan bir rota alternatifini temsil eden model sınıfı.
// Örneğin, "En Hızlı Rota", "Alternatif Rota 1" gibi.
class RouteOption {
  final String name; // Rotanın adı (örn: "En Hızlı Rota")
  final String distance; // Rotanın toplam mesafesi, kullanıcı dostu string formatında (örn: "123.4 km")
  final String duration; // Rotanın tahmini süresi, kullanıcı dostu string formatında (örn: "45 dk")
  final bool isTollRoad; // Bu rota ücretli yol içeriyor mu? (Bu alan `routeDetails` içinde daha detaylı yönetilebilir)
  final List<LatLng> points; // Rota çizgisini oluşturan coğrafi koordinatların listesi (haritada çizim için)
  final Map<String, double>? costRange; // Rota için tahmini toplam maliyet aralığı (örn: {'minCost': 50.0, 'maxCost': 75.0})
  final Map<String, dynamic>? routeDetails; // Rota hakkında ek detaylar: yakıt tüketimi, gişe maliyeti, ücretli segmentler vb.
  final List<RouteStep> steps; // Rota için adım adım yol tarifi talimatlarının listesi
  final List<String> intermediatePlaces; // Rota üzerinde geçilmesi beklenen önemli yerlerin (örn: il, ilçe) listesi

  RouteOption({
    required this.name,
    required this.distance,
    required this.duration,
    required this.isTollRoad, // Bu alanın kullanımı gözden geçirilebilir, routeDetails daha kapsamlı bilgi sunabilir.
    required this.points,
    this.costRange, // Opsiyonel, araç seçilmemişse veya hesaplanamamışsa null olabilir
    this.routeDetails, // Opsiyonel, detaylı maliyet bilgileri
    required this.steps, // Rota adımları zorunlu
    this.intermediatePlaces = const [], // Varsayılan olarak boş liste, eğer ara noktalar belirlenmemişse
  });

  // 'distance' string'inden (örn: "123.4 km") sayısal kilometre değerini almak için bir getter metodu.
  // Hesaplamalarda veya karşılaştırmalarda kullanışlıdır.
  double get distanceInKm {
    // " km" ifadesini kaldırır, boşlukları temizler ve double tipine çevirmeye çalışır.
    // Başarısız olursa (örn: format hatalıysa) varsayılan olarak 0.0 döner.
    return double.tryParse(distance.replaceAll(' km', '').trim()) ?? 0.0;
  }

  // 'duration' string'inden (örn: "45 dk") sayısal dakika değerini almak için bir getter metodu.
  int get durationInMinutes {
    // " dk" ifadesini kaldırır, boşlukları temizler ve integer tipine çevirmeye çalışır.
    // Başarısız olursa varsayılan olarak 0 döner.
    return int.tryParse(duration.replaceAll(' dk', '').trim()) ?? 0;
  }

  // RouteOption nesnelerinin birbirleriyle karşılaştırılabilmesi için `operator ==` ve `hashCode` metodlarını override eder.
  // Bu, özellikle listelerde veya setlerde RouteOption nesnelerini ararken veya karşılaştırırken önemlidir.
  @override
  bool operator ==(Object other) =>
      identical(this, other) || // Aynı referans mı kontrolü
      other is RouteOption && // Diğer nesne RouteOption tipinde mi
          runtimeType == other.runtimeType && // Çalışma zamanı tipleri aynı mı
          name == other.name && // İsimler aynı mı
          distance == other.distance && // Mesafeler aynı mı
          duration == other.duration && // Süreler aynı mı
          // points listesinin uzunluğunu karşılaştırmak basit bir kontrol,
          // daha detaylı bir karşılaştırma için listenin elemanları da tek tek karşılaştırılabilir.
          points.length == other.points.length;

  // `operator ==` override edildiğinde `hashCode` da override edilmelidir.
  // Nesnenin hash kodunu, karşılaştırmada kullanılan alanlara göre üretir.
  @override
  int get hashCode =>
      name.hashCode ^
      distance.hashCode ^
      duration.hashCode ^
      points.length.hashCode; // Basit bir hashcode üretimi
}