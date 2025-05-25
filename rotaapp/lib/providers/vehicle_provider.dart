// lib/providers/vehicle_provider.dart
import 'package:flutter/foundation.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import '../models/vehicle.dart';

class VehicleProvider with ChangeNotifier {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  List<Vehicle> _allVehicles = []; // Firestore'dan çekilen tüm araçlar
  List<Vehicle> _filteredVehicles = []; // Arama sonuçlarına göre filtrelenmiş araçlar
  bool _isLoading = false;
  String? _errorMessage;
  Vehicle? _selectedVehicle;
  String _searchTerm = ""; // Arama terimini tutmak için

  List<Vehicle> get vehicles => _filteredVehicles; // UI artık filtrelenmiş listeyi kullanacak
  List<Vehicle> get allVehicles => _allVehicles; // Tüm araçlara erişim (opsiyonel)
  bool get isLoading => _isLoading;
  String? get errorMessage => _errorMessage;
  Vehicle? get selectedVehicle => _selectedVehicle;
  String get searchTerm => _searchTerm;

  VehicleProvider() {
    fetchVehicles();
  }

  Future<void> fetchVehicles() async {
    _isLoading = true;
    _errorMessage = null;
    notifyListeners();

    try {
      final querySnapshot = await _firestore
          .collection('araclar')
          .withConverter<Vehicle>(
            fromFirestore: Vehicle.fromFirestore,
            toFirestore: (Vehicle vehicle, _) => vehicle.toFirestore(),
          )
          .get();

      _allVehicles = querySnapshot.docs.map((doc) => doc.data()).toList();
      _applySearchFilter(); // Arama filtresini uygula (başlangıçta boş olabilir)
      print('VehicleProvider: ${_allVehicles.length} araç çekildi.');

      if (_filteredVehicles.isNotEmpty) {
        if (_selectedVehicle == null || !_filteredVehicles.any((v) => v.id == _selectedVehicle!.id)) {
          _selectedVehicle = _filteredVehicles.first;
        }
      } else {
        _selectedVehicle = null;
      }

    } catch (error) {
      _errorMessage = "Araçlar yüklenirken bir hata oluştu: $error";
      print('VehicleProvider Hata: $_errorMessage');
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  void selectVehicle(Vehicle? vehicle) {
    _selectedVehicle = vehicle;
    notifyListeners();
  }

  Future<void> addNewVehicleToFirestore(Vehicle vehicleData) async {
    // ... (Bu metot aynı kalabilir)
    _isLoading = true;
    _errorMessage = null;
    notifyListeners();
    try {
      await _firestore.collection('araclar').add(vehicleData.toFirestore());
      await fetchVehicles(); // Listeyi yenile ve filtreyi tekrar uygula
    } catch (e) {
      _errorMessage = "Yeni araç eklenirken hata: $e";
      print('VehicleProvider Ekleme Hatası: $_errorMessage');
      _isLoading = false;
      notifyListeners();
    }
  }

  // Arama terimini güncelleyen ve filtreyi uygulayan metot
  void searchVehicles(String term) {
    _searchTerm = term;
    _applySearchFilter();
  }

  // Arama filtresini uygulayan özel metot
  void _applySearchFilter() {
    if (_searchTerm.isEmpty) {
      _filteredVehicles = List.from(_allVehicles); // Arama terimi boşsa tüm araçları göster
    } else {
      final lowerCaseTerm = _searchTerm.toLowerCase();
      _filteredVehicles = _allVehicles.where((vehicle) {
        // Marka, model veya seride arama yapabilirsiniz
        final brandMatch = vehicle.marka.toLowerCase().contains(lowerCaseTerm);
        final modelMatch = vehicle.model.toLowerCase().contains(lowerCaseTerm);
        final seriMatch = vehicle.seri.toLowerCase().contains(lowerCaseTerm);
        // İsteğe bağlı: Yıl veya diğer alanlarda da arama eklenebilir
        // final yilMatch = vehicle.yil.toString().contains(lowerCaseTerm);
        return brandMatch || modelMatch || seriMatch; // || yilMatch;
      }).toList();
    }
    notifyListeners(); // UI'ı güncelle
  }
}