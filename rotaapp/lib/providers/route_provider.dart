import 'package:flutter/material.dart';
import 'package:latlong2/latlong.dart';
import '../models/route_option.dart'; // Model import edildi

class RouteProvider extends ChangeNotifier {
  LatLng? startLocation;
  LatLng? endLocation;
  List<LatLng>? routePoints; // Seçili rotanın noktaları
  String? routeDistance; // Seçili rotanın mesafesi
  String? routeDuration; // Seçili rotanın süresi
  List<RouteOption> routeOptions = []; // Bulunan tüm alternatif rotalar
  RouteOption? selectedRouteOption; // Şu anda haritada gösterilen rota

  // Tamamlanan rotalar listesi
  final List<CompletedRoute> completedRoutes = [];

  void setStartLocation(LatLng? location) {
    startLocation = location;
    // notifyListeners(); // setEndLocation veya clearRoute ile birlikte tetiklenir
  }

  void setEndLocation(LatLng? location) {
    endLocation = location;
    // notifyListeners(); // Rota hesaplama tetiklendiğinde tümü güncellenir
  }

  void setRouteOptions(List<RouteOption> options) {
    routeOptions = options;
    if (options.isNotEmpty) {
      selectRouteOption(options.first); // Varsayılan olarak ilk rotayı seç
    } else {
      clearRoute(); // Seçenek yoksa rotayı temizle
    }
    notifyListeners();
  }

  void selectRouteOption(RouteOption option) {
    selectedRouteOption = option;
    routePoints = option.points;
    routeDistance = option.distance;
    routeDuration = option.duration;
    notifyListeners();
  }

  void clearRoute() {
    startLocation = null;
    endLocation = null;
    routePoints = null;
    routeDistance = null;
    routeDuration = null;
    routeOptions = [];
    selectedRouteOption = null;
    notifyListeners();
  }

  // Rota tamamlandığında çağrılacak metod
  void addCompletedRoute(CompletedRoute route) {
    completedRoutes.add(route);
    notifyListeners();
  }

  // Tamamlanan rotaları getir
  List<CompletedRoute> get routes => completedRoutes;
}

// Tamamlanan rota modeli
class CompletedRoute {
  final String startPoint;
  final String endPoint;
  final double distance;
  final double consumption;
  final DateTime completedAt;

  CompletedRoute({
    required this.startPoint,
    required this.endPoint,
    required this.distance,
    required this.consumption,
    required this.completedAt,
  });
}
