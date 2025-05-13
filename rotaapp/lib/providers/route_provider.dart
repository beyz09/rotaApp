import 'package:flutter/material.dart';
import 'package:latlong2/latlong.dart';
import '../models/route_option.dart';
import '../models/vehicle.dart'; // CompletedRoute için Vehicle modeli gerekebilir
// CompletedRoute için FuelCostCalculator modeli gerekebilir


// Tamamlanan rota modeli (Önceki kodunuzda vardı)
class CompletedRoute {
  final String startPoint;
  final String endPoint;
  final double distance;
  final double consumption; // Yakıt tüketimi (litre)
  final double cost;      // Maliyet (TL), tahmini aralığın ortası veya min/max olarak saklanabilir
  final DateTime completedAt;

  CompletedRoute({
    required this.startPoint,
    required this.endPoint,
    required this.distance,
    required this.consumption,
    required this.cost, // Maliyeti de ekledik
    required this.completedAt,
  });
}

class RouteProvider extends ChangeNotifier {
  LatLng? startLocation;
  LatLng? endLocation;
  List<LatLng>? routePoints; // Seçili rotanın noktaları
  String? routeDistance; // Seçili rotanın mesafesi
  String? routeDuration; // Seçili rotanın süresi
  List<RouteOption> routeOptions = []; // Bulunan tüm alternatif rotalar
  RouteOption? selectedRouteOption; // Şu anda haritada gösterilen rota

  // Tamamlanan rotalar listesi
  final List<CompletedRoute> _completedRoutes = [];

  // Getterlar
  final List<Vehicle> _vehicles = []; // VehicleProvider'dan gelen örnek liste, MapScreen'de Provider.of ile alınıyor ama burada da tutulabilir eğer ihtiyacı olursa

  // Getterlar
  List<CompletedRoute> get completedRoutes => _completedRoutes;
  List<RouteOption> get routeOptionsList => routeOptions;
  // VehicleProvider'dan araç listesi ve seçili aracı al
  // List<Vehicle> get vehicles => _vehicles; // Bu VehicleProvider'da olmalıydı, RouteProvider'da değil

  // Başlangıç ve bitiş noktalarını ayarlar ve eski rota sonuçlarını temizler
  void setStartLocation(LatLng? location) {
    startLocation = location;
    clearRouteResults(); // Başlangıç/bitiş değiştiğinde mevcut rota seçeneklerini temizle
    notifyListeners(); // UI'ı güncelle (örn: marker'lar için)
  }

  void setEndLocation(LatLng? location) {
    endLocation = location;
    clearRouteResults(); // Başlangıç/bitiş değiştiğinde mevcut rota seçeneklerini temizle
    notifyListeners(); // UI'ı güncelle (örn: marker'lar için)
  }

  // Rota seçeneklerini ayarlar ve ilkini seçer
  void setRouteOptions(List<RouteOption> options) {
    routeOptions = options;
    if (options.isNotEmpty) {
      selectRouteOption(options.first); // Varsayılan olarak ilk rotayı seç
    } else {
      clearRouteResults(); // Seçenek yoksa rota sonuçlarını temizle
    }
    // notifyListeners(); // selectRouteOption zaten notifyListeners içeriyor
  }

  // Belirli bir rota seçeneğini seçer
  void selectRouteOption(RouteOption option) {
    selectedRouteOption = option;
    routePoints = option.points;
    routeDistance = option.distance;
    routeDuration = option.duration;
    notifyListeners(); // Seçili rota değiştiği için UI güncellemeli
  }

  // Sadece rota hesaplama sonuçlarını temizler (başlangıç/varış noktalarını bırakır)
  void clearRouteResults() {
    routePoints = null;
    routeDistance = null;
    routeDuration = null;
    routeOptions = [];
    selectedRouteOption = null;
    // notifyListeners(); // Bu metod tek başına çağrılırsa UI güncellemeli, diğer set metodları çağırıyorsa gerekmeyebilir
  }

  // Tüm rota bilgilerini temizler (başlangıç/varış dahil)
  void clearAllRouteData() {
    startLocation = null;
    endLocation = null;
    clearRouteResults(); // Rota sonuçlarını da temizle
    notifyListeners(); // Tüm veri sıfırlandığı için UI güncellemeli
  }

  // Rota tamamlandığında çağrılacak metod
  void addCompletedRoute(CompletedRoute route) {
    _completedRoutes.add(route);
    notifyListeners();
  }
}