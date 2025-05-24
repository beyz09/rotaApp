import 'package:flutter/material.dart';
import '../models/vehicle.dart'; // Model import edildi

class VehicleProvider extends ChangeNotifier {
  final List<Vehicle> _vehicles = []; // Kayıtlı araçlar listesi
  Vehicle? _selectedVehicle; // Seçili araç

  List<Vehicle> get vehicles => _vehicles;
  Vehicle? get selectedVehicle => _selectedVehicle;

  // Örnek araç ekleme (Gerçek uygulamada depolama servisi kullanılmalı)
  void addVehicle(Vehicle vehicle) {
    _vehicles.add(vehicle);
    // İlk eklenen aracı otomatik seç
    if (_vehicles.length == 1) {
      _selectedVehicle = vehicle;
    }
    notifyListeners();
  }

  void updateVehicle(Vehicle updatedVehicle) {
    final index = _vehicles.indexWhere((v) => v.id == updatedVehicle.id);
    if (index != -1) {
      _vehicles[index] = updatedVehicle;
      notifyListeners();
    }
  }

  void removeVehicle(String id) {
    // ... existing code ...
  }

  void selectVehicle(Vehicle vehicle) {
    _selectedVehicle = vehicle;
    notifyListeners();
  }

  void clearSelection() {
    _selectedVehicle = null;
    notifyListeners();
  }

  // Araç listesini yükleme (Başlangıçta veya eklendiğinde)
  // Bu metot, gerçek uygulamada bir storage_service'i çağıracaktır.
  Future<void> loadVehicles() async {
    // Buraya yükleme mantığı gelecek
    // _vehicles = await StorageService().loadVehicles();
    // _selectedVehicle = _vehicles.isNotEmpty ? _vehicles.first : null; // İlkini seç
    // notifyListeners();
  }
  // ... araç silme, düzenleme metotları eklenebilir
}
