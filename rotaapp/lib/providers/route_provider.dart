// lib/providers/route_provider.dart
import 'package:flutter/material.dart';
import 'package:latlong2/latlong.dart';
import '../models/route_option.dart';
// import '../models/vehicle.dart'; // Kullanılmıyorsa kaldırıldı
import '../models/completed_route.dart'; // Doğru import

class RouteProvider extends ChangeNotifier {
  LatLng? startLocation;
  LatLng? endLocation;
  List<LatLng>? routePoints;
  String? routeDistance;
  String? routeDuration;
  List<RouteOption> routeOptions = [];
  RouteOption? selectedRouteOption;

  final List<CompletedRoute> _completedRoutes = [];

  List<CompletedRoute> get completedRoutes => List.unmodifiable(_completedRoutes);
  List<RouteOption> get routeOptionsList => List.unmodifiable(routeOptions);

  void setStartLocation(LatLng? location) {
    startLocation = location;
    clearRouteResults();
    notifyListeners();
  }

  void setEndLocation(LatLng? location) {
    endLocation = location;
    clearRouteResults();
    notifyListeners();
  }

  void setRouteOptions(List<RouteOption> options) {
    routeOptions = options;
    if (options.isNotEmpty) {
      selectRouteOption(options.first);
    } else {
      clearRouteResults();
    }
  }

  void selectRouteOption(RouteOption option) {
    selectedRouteOption = option;
    routePoints = option.points;
    routeDistance = option.distance;
    routeDuration = option.duration;
    notifyListeners();
  }

  void clearRouteResults() {
    routePoints = null;
    routeDistance = null;
    routeDuration = null;
    routeOptions = [];
    selectedRouteOption = null;
    notifyListeners();
  }

  void clearAllRouteData() {
    startLocation = null;
    endLocation = null;
    clearRouteResults();
    notifyListeners();
  }

  void addCompletedRoute(CompletedRoute route) {
    _completedRoutes.insert(0, route); // En yeni en başa eklensin
    // _completedRoutes.sort((a, b) => b.completedAt.compareTo(a.completedAt)); // Veya tarihe göre sırala
    notifyListeners();
  }

  void clearSelectedRouteOptionOnly() { // profile_screen için eklendi
    selectedRouteOption = null;
    routePoints = null;
    routeDistance = null;
    routeDuration = null;
    notifyListeners();
  }
}