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
  String _searchTerm = "";

  List<Vehicle> get vehicles => _filteredVehicles;
  List<Vehicle> get allVehicles => _allVehicles;
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
    // Başlangıçta notifyListeners() çağrısını kaldırdım, finally bloğu yeterli olacaktır.
    // notifyListeners(); 

    try {
      final querySnapshot = await _firestore
          .collection('araclar') // Koleksiyon adınızın 'araclar' olduğundan emin olun
          .withConverter<Vehicle>(
            fromFirestore: Vehicle.fromFirestore,
            toFirestore: (Vehicle vehicle, _) => vehicle.toFirestore(),
          )
          .get();

      _allVehicles = querySnapshot.docs.map((doc) => doc.data()).toList();
      _applySearchFilter(); 
      debugPrint('VehicleProvider: ${_allVehicles.length} araç çekildi.');

      if (_filteredVehicles.isNotEmpty) {
        if (_selectedVehicle == null || !_filteredVehicles.any((v) => v.id == _selectedVehicle!.id)) {
          _selectedVehicle = _filteredVehicles.first;
        }
      } else {
        _selectedVehicle = null;
      }

    } catch (error) {
      _errorMessage = "Araçlar yüklenirken bir hata oluştu: $error";
      debugPrint('VehicleProvider Hata: $_errorMessage');
    } finally {
      _isLoading = false;
      notifyListeners(); // Tüm işlemler bittikten sonra UI'ı güncelle
    }
  }

  void selectVehicle(Vehicle? vehicle) {
    _selectedVehicle = vehicle;
    notifyListeners();
  }

  Future<void> addNewVehicleToFirestore(Vehicle vehicleData) async {
    _isLoading = true;
    _errorMessage = null;
    notifyListeners(); // Yükleme başladığını bildir
    try {
      final docRef = await _firestore.collection('araclar').add(vehicleData.toFirestore());
      debugPrint('Yeni araç eklendi, ID: ${docRef.id}');
      await fetchVehicles(); // Listeyi yenile, filtreyi uygula ve UI'ı güncelle (bu zaten notifyListeners içerir)
    } catch (e) {
      _errorMessage = "Yeni araç eklenirken hata: $e";
      debugPrint('VehicleProvider Ekleme Hatası: $_errorMessage');
      // Hata durumunda da isLoading'i false yap ve UI'ı güncelle
      _isLoading = false; 
      notifyListeners(); 
    } 
    // fetchVehicles() kendi finally bloğunda isLoading'i false yapıp notifyListeners çağıracağı için,
    // buradaki finally bloğu gereksiz hale gelebilir. Eğer fetchVehicles() her zaman çağrılıyorsa.
    // Ancak catch bloğunda fetchVehicles() çağrılmıyorsa, catch bloğu sonunda isLoading ve notifyListeners olmalı.
    // Mevcut yapıda fetchVehicles() try bloğunda çağrıldığı için, catch bloğunda da isLoading ve notifyListeners olmalı.
  }

  // <<--- YENİ EKLENEN METOT --->>
  Future<void> updateVehicle(Vehicle updatedVehicle) async {
    _isLoading = true;
    _errorMessage = null;
    notifyListeners(); // Yükleme başladığını bildir

    try {
      await _firestore
          .collection('araclar') // Firestore koleksiyon adınız
          .doc(updatedVehicle.id) // Güncellenecek aracın ID'si
          .update(updatedVehicle.toFirestore()); // Vehicle modelindeki toFirestore()
      debugPrint('Araç güncellendi, ID: ${updatedVehicle.id}');

      // Yerel listeleri de güncelle
      final allVehicleIndex = _allVehicles.indexWhere((v) => v.id == updatedVehicle.id);
      if (allVehicleIndex != -1) {
        _allVehicles[allVehicleIndex] = updatedVehicle;
      }
      
      // _applySearchFilter, _filteredVehicles listesini _allVehicles ve _searchTerm'e göre yeniden oluşturur.
      // Bu yüzden _allVehicles güncellendikten sonra bu metodu çağırmak yeterlidir.
      _applySearchFilter(); 

      // Seçili aracı da güncelle (eğer güncellenen araç seçili ise)
      if (_selectedVehicle?.id == updatedVehicle.id) {
        _selectedVehicle = updatedVehicle;
      }
      
    } catch (error) {
      _errorMessage = "Araç güncellenirken hata: $error";
      debugPrint('VehicleProvider Güncelleme Hatası: $_errorMessage');
      // rethrow; // İsteğe bağlı olarak hatayı UI katmanına iletebilirsiniz
    } finally {
      _isLoading = false;
      notifyListeners(); // Tüm işlemler bittikten sonra UI'ı güncelle
    }
  }
  
  // İsteğe bağlı: Araç silme metodu
  Future<void> deleteVehicle(String vehicleId) async {
    _isLoading = true;
    _errorMessage = null;
    notifyListeners();

    try {
      await _firestore.collection('araclar').doc(vehicleId).delete();
      debugPrint('Araç silindi, ID: $vehicleId');

      _allVehicles.removeWhere((vehicle) => vehicle.id == vehicleId);
      _applySearchFilter(); // Silme sonrası filtreyi yeniden uygula

      if (_selectedVehicle?.id == vehicleId) {
        _selectedVehicle = _filteredVehicles.isNotEmpty ? _filteredVehicles.first : null;
      }
    } catch (error) {
      _errorMessage = "Araç silinirken hata: $error";
      debugPrint('VehicleProvider Silme Hatası: $_errorMessage');
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }


  void searchVehicles(String term) {
    _searchTerm = term;
    _applySearchFilter();
    // _applySearchFilter zaten notifyListeners() çağırıyor, bu yüzden burada tekrar gerek yok.
  }

  void _applySearchFilter() {
    if (_searchTerm.isEmpty) {
      _filteredVehicles = List.from(_allVehicles);
    } else {
      final lowerCaseTerm = _searchTerm.toLowerCase();
      _filteredVehicles = _allVehicles.where((vehicle) {
        final brandMatch = vehicle.marka.toLowerCase().contains(lowerCaseTerm);
        final modelMatch = vehicle.model.toLowerCase().contains(lowerCaseTerm);
        final seriMatch = vehicle.seri.toLowerCase().contains(lowerCaseTerm);
        return brandMatch || modelMatch || seriMatch;
      }).toList();
    }

    // Arama sonrası seçili aracın filtrelenmiş listede olup olmadığını kontrol et
    if (_selectedVehicle != null && !_filteredVehicles.any((v) => v.id == _selectedVehicle!.id)) {
        _selectedVehicle = _filteredVehicles.isNotEmpty ? _filteredVehicles.first : null;
    } else if (_selectedVehicle == null && _filteredVehicles.isNotEmpty) {
        // Eğer hiç seçili araç yoksa ve filtrelenmiş liste boş değilse ilkini seç
        _selectedVehicle = _filteredVehicles.first;
    }
    notifyListeners(); // Filtreleme sonrası UI'ı her zaman güncelle
  }
}