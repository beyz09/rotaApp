// models/route_step.dart
import 'package:latlong2/latlong.dart'; // Coğrafi koordinatlar için

// Bir rotanın tek bir adımını (manevrasını) temsil eden model sınıfı.
// Örneğin, "Sağa dön", "Düz git", "Varış" gibi adımlar.
class RouteStep {
  final String name; // Adımın geçtiği cadde veya yolun adı (örn: "Atatürk Bulvarı")
  final double distance; // Bu adımın mesafesi (metre cinsinden)
  final double duration; // Bu adımın tahmini süresi (saniye cinsinden)
  final String maneuverType; // Manevranın tipi (örn: 'turn', 'merge', 'roundabout', 'arrive')
  final String? maneuverModifier; // Manevranın yönü veya detayı (örn: 'left', 'slight right', 'uturn')
  final String? instruction; // OSRM gibi rota servislerinin sağladığı adım için kullanıcıya gösterilecek talimat metni (örn: "Sağa dönün")
  final LatLng location; // Manevranın gerçekleştiği coğrafi konum (enlem, boylam)

  RouteStep({
    required this.name,
    required this.distance,
    required this.duration,
    required this.maneuverType,
    required this.location, // Manevra konumu zorunlu
    this.maneuverModifier, // Manevra yönü opsiyonel
    this.instruction,      // Talimat metni opsiyonel
  });

  // JSON formatındaki bir API yanıtından RouteStep nesnesi oluşturmak için kullanılan fabrika (factory) metodu.
  // Bu, OSRM (Open Source Routing Machine) gibi servislerden gelen veriyi parse etmek için kullanışlıdır.
  factory RouteStep.fromJson(Map<String, dynamic> json) {
    LatLng? maneuverLocation; // Manevra konumu için geçici değişken

    // JSON verisindeki 'maneuver' -> 'location' alanından koordinatları almaya çalış
    final List<dynamic>? coords = json['maneuver']?['location'];
    if (coords != null && coords.length == 2) { // Koordinatlar [boylam, enlem] formatında olmalı
      final double? lon = (coords[0] as num?)?.toDouble(); // Boylamı al ve double'a çevir
      final double? lat = (coords[1] as num?)?.toDouble(); // Enlemi al ve double'a çevir
      if (lat != null && lon != null) { // Başarılı bir şekilde alındıysa LatLng nesnesi oluştur
        maneuverLocation = LatLng(lat, lon);
      }
    }

    // Eğer 'maneuverLocation' yukarıdaki işlemler sonucunda hala null ise (yani koordinatlar alınamadıysa),
    // varsayılan bir konum (örn: 0,0) ata. Bu, uygulamanın çökmesini engeller.
    // Normalde, rota servisleri her adım için bir konum sağlamalıdır.
    maneuverLocation ??= const LatLng(0.0, 0.0); // Güvenlik için varsayılan (fallback) konum

    return RouteStep(
      // 'name' alanı yoksa veya null ise varsayılan olarak "İsimsiz Yol" ata
      name: json['name']?.toString() ?? 'İsimsiz Yol',
      // 'distance' alanı yoksa, null ise veya sayıya çevrilemiyorsa varsayılan olarak 0.0 ata
      distance: (json['distance'] as num?)?.toDouble() ?? 0.0,
      // 'duration' alanı yoksa, null ise veya sayıya çevrilemiyorsa varsayılan olarak 0.0 ata
      duration: (json['duration'] as num?)?.toDouble() ?? 0.0,
      // 'maneuver' -> 'type' alanı yoksa veya null ise varsayılan olarak "Bilinmiyor" ata
      maneuverType: json['maneuver']?['type']?.toString() ?? 'Bilinmiyor',
      // Parse edilen veya varsayılan olarak atanan manevra konumunu kullan
      location: maneuverLocation,
      // 'maneuver' -> 'modifier' alanı varsa string'e çevir, yoksa null bırak
      maneuverModifier: json['maneuver']?['modifier']?.toString(),
      // 'maneuver' -> 'instruction' alanı varsa string'e çevir, yoksa null bırak
      instruction: json['maneuver']?['instruction']?.toString(),
    );
  }
}