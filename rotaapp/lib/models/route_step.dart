// models/route_step.dart
import 'package:latlong2/latlong.dart';

class RouteStep {
  final String name; // Cadde/Yol adı
  final double distance; // Adımın mesafesi (metre)
  final double duration; // Adımın süresi (saniye)
  final String maneuverType; // Dönüş tipi (örn: 'turn', 'merge', 'arrive')
  final String? maneuverModifier; // Manevra yönü (sağa, sola, vb.)
  final String? instruction; // OSRM'nin sağladığı talimat metni
  final LatLng location; // Manevra konumu

  RouteStep({
    required this.name,
    required this.distance,
    required this.duration,
    required this.maneuverType,
    required this.location,
    this.maneuverModifier,
    this.instruction,
  });

  // API yanıtından RouteStep nesnesi oluşturmak için fabrika metodu
  factory RouteStep.fromJson(Map<String, dynamic> json) {
    LatLng? maneuverLocation;
    // Step verisinden manevra konumunu al
    final List<dynamic>? coords = json['maneuver']?['location'];
    if (coords != null && coords.length == 2) {
      final double? lon = (coords[0] as num?)?.toDouble();
      final double? lat = (coords[1] as num?)?.toDouble();
      if (lat != null && lon != null) {
        maneuverLocation = LatLng(lat, lon);
      }
    }
    // Eğer maneuverLocation hala null ise (yani yukarıdaki parse işlemi başarısız olduysa veya 'location' alanı yoksa)
    // o zaman varsayılan bir değer ata.
    maneuverLocation ??= const LatLng(0.0, 0.0); // Fallback location

    return RouteStep(
      name: json['name']?.toString() ?? 'İsimsiz Yol',
      distance: (json['distance'] as num?)?.toDouble() ?? 0.0,
      duration: (json['duration'] as num?)?.toDouble() ?? 0.0,
      maneuverType: json['maneuver']?['type']?.toString() ?? 'Bilinmiyor',
      location: maneuverLocation, // Artık burası doğru LatLng veya fallback LatLng(0.0, 0.0) olacak
      maneuverModifier: json['maneuver']?['modifier']?.toString(),
      instruction: json['maneuver']?['instruction']?.toString(),
    );
  }
}