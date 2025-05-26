// lib/providers/route_provider.dart
import 'package:flutter/material.dart';
import 'package:latlong2/latlong.dart'; // Coğrafi koordinatlar (enlem, boylam) için
import '../models/route_option.dart'; // Rota seçenekleri modeli
// import '../models/vehicle.dart'; // Bu provider'da doğrudan kullanılmıyor, yorumlandı
import '../models/completed_route.dart'; // Tamamlanmış rota modeli

// Rota ile ilgili durumları (state) yönetmek için ChangeNotifier sınıfından türetilmiş bir provider.
// Uygulamanın farklı yerlerinden rota verilerine erişmek ve bu veriler değiştiğinde UI'ı güncellemek için kullanılır.
class RouteProvider extends ChangeNotifier {
  // Rota için başlangıç ve bitiş konumları
  LatLng? startLocation; // Başlangıç noktasının koordinatları
  LatLng? endLocation;   // Bitiş noktasının koordinatları

  // Seçilen rota için bilgiler
  List<LatLng>? routePoints; // Rota üzerindeki tüm koordinat noktaları (çizim için)
  String? routeDistance;     // Rotanın toplam mesafesi (örn: "10.5 km")
  String? routeDuration;     // Rotanın tahmini süresi (örn: "25 dk")

  // Kullanıcıya sunulan farklı rota seçenekleri
  List<RouteOption> routeOptions = []; // OSRM'den gelen alternatif rotalar
  RouteOption? selectedRouteOption;    // Kullanıcının seçtiği rota seçeneği

  // Kullanıcının geçmişte tamamladığı rotaların listesi
  final List<CompletedRoute> _completedRoutes = [];

  // Tamamlanmış rotalara dışarıdan erişim için getter (listenin değiştirilemez bir kopyasını döndürür)
  List<CompletedRoute> get completedRoutes => List.unmodifiable(_completedRoutes);
  // Rota seçeneklerine dışarıdan erişim için getter (listenin değiştirilemez bir kopyasını döndürür)
  List<RouteOption> get routeOptionsList => List.unmodifiable(routeOptions);

  // Başlangıç konumunu ayarlar ve mevcut rota sonuçlarını temizler.
  void setStartLocation(LatLng? location) {
    startLocation = location;
    clearRouteResults(); // Yeni bir başlangıç noktası seçildiğinde eski rota geçersiz olur
    notifyListeners();   // Değişiklikleri dinleyen widget'lara bildir
  }

  // Bitiş konumunu ayarlar ve mevcut rota sonuçlarını temizler.
  void setEndLocation(LatLng? location) {
    endLocation = location;
    clearRouteResults(); // Yeni bir bitiş noktası seçildiğinde eski rota geçersiz olur
    notifyListeners();
  }

  // Hesaplanan rota seçeneklerini ayarlar.
  // Eğer seçenekler varsa, ilkini varsayılan olarak seçer.
  void setRouteOptions(List<RouteOption> options) {
    routeOptions = options;
    if (options.isNotEmpty) {
      selectRouteOption(options.first); // Gelen ilk rotayı otomatik seç
    } else {
      clearRouteResults(); // Hiç rota seçeneği yoksa mevcutları temizle
    }
    // notifyListeners() burada çağrılmıyor çünkü selectRouteOption veya clearRouteResults zaten çağıracak.
  }

  // Belirli bir rota seçeneğini aktif rota olarak ayarlar.
  void selectRouteOption(RouteOption option) {
    selectedRouteOption = option;
    routePoints = option.points;     // Seçilen rotanın noktalarını al
    routeDistance = option.distance; // Seçilen rotanın mesafesini al
    routeDuration = option.duration; // Seçilen rotanın süresini al
    notifyListeners();
  }

  // Hesaplanan rota ile ilgili tüm verileri (noktalar, mesafe, süre, seçenekler) temizler.
  // Başlangıç ve bitiş noktaları kalır.
  void clearRouteResults() {
    routePoints = null;
    routeDistance = null;
    routeDuration = null;
    routeOptions = [];
    selectedRouteOption = null;
    notifyListeners();
  }

  // Rota ile ilgili TÜM verileri (başlangıç/bitiş noktaları dahil) temizler.
  // Genellikle yeni bir arama işlemine başlarken veya ekranı sıfırlarken kullanılır.
  void clearAllRouteData() {
    startLocation = null;
    endLocation = null;
    clearRouteResults(); // Diğer rota verilerini de temizle
    // notifyListeners() zaten clearRouteResults içinde çağrılıyor.
  }

  // Tamamlanmış bir rotayı listeye ekler.
  void addCompletedRoute(CompletedRoute route) {
    _completedRoutes.insert(0, route); // Yeni tamamlanan rotayı listenin başına ekle (en son tamamlanan en üstte)
    // Alternatif olarak, rotaları tamamlanma tarihine göre sıralayabilirsiniz:
    // _completedRoutes.sort((a, b) => b.completedAt.compareTo(a.completedAt));
    notifyListeners();
  }

  // Sadece seçili olan rota seçeneğini temizler.
  // Bu, örneğin bir rota tamamlandıktan sonra haritada rotanın çizili kalmasını istemediğimizde,
  // ancak başlangıç/bitiş noktalarının veya diğer rota seçeneklerinin korunması gerektiğinde kullanılabilir.
  // (profile_screen'de bir rota detayı gösterildikten sonra haritaya dönüldüğünde kullanılmak üzere eklenmiş.)
  void clearSelectedRouteOptionOnly() {
    selectedRouteOption = null;
    routePoints = null;
    routeDistance = null;
    routeDuration = null;
    notifyListeners();
  }
}