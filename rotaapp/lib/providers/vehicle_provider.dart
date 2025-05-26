// lib/providers/vehicle_provider.dart
import 'package:flutter/foundation.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import '../models/vehicle.dart'; // Vehicle modelinizin yolu

class VehicleProvider with ChangeNotifier {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  List<Vehicle> _allVehicles = [];
  List<Vehicle> _filteredVehicles = [];
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
    debugPrint("VehicleProvider oluşturuldu.");
  }

  Future<void> fetchVehicles({String? userId}) async {
    if (_isLoading) return;

    _isLoading = true;
    _errorMessage = null;
    notifyListeners();

    try {
      debugPrint(userId != null
          ? 'VehicleProvider: Kullanıcı ($userId) için araçlar çekiliyor...'
          : 'VehicleProvider: Tüm araçlar çekiliyor...');

      Query<Vehicle> query = _firestore
          .collection('araclar')
          .withConverter<Vehicle>(
            fromFirestore: Vehicle.fromFirestore,
            toFirestore: (Vehicle vehicle, _) => vehicle.toFirestore(),
          );

      // if (userId != null && userId.isNotEmpty) {
      //   query = query.where('ownerId', isEqualTo: userId);
      // }

      final querySnapshot = await query.get();
      _allVehicles = querySnapshot.docs.map((doc) => doc.data()).toList();
      _applySearchFilter(); // Hata burada değil, _applySearchFilter tanımlanmalı.
      debugPrint('VehicleProvider: ${_allVehicles.length} araç çekildi.');

    } catch (error) {
      _errorMessage = "Araçlar yüklenirken bir hata oluştu: $error";
      debugPrint('VehicleProvider Hata: $_errorMessage');
      _allVehicles = [];
      _filteredVehicles = [];
      _selectedVehicle = null;
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  // *** EKSİK METOTLARI EKLEYELİM ***

  void selectVehicle(Vehicle? vehicle) {
    _selectedVehicle = vehicle;
    notifyListeners();
  }

  void searchVehicles(String term) {
    _searchTerm = term.trim(); // Baştaki ve sondaki boşlukları temizle
    _applySearchFilter();
    // _applySearchFilter zaten notifyListeners() çağırıyor.
  }

  void _applySearchFilter() {
    if (_searchTerm.isEmpty) {
      _filteredVehicles = List.from(_allVehicles);
    } else {
      final lowerCaseTerm = _searchTerm.toLowerCase();
      _filteredVehicles = _allVehicles.where((vehicle) {
        // Kendi Vehicle modelinizdeki alanlara göre arama yapın
        final brandMatch = vehicle.marka.toLowerCase().contains(lowerCaseTerm);
        final modelMatch = vehicle.model.toLowerCase().contains(lowerCaseTerm);
        final seriMatch = vehicle.seri.toLowerCase().contains(lowerCaseTerm); // seri alanı varsa
        // Diğer alanlar için de ekleyebilirsiniz: vehicle.yil.toString().contains(lowerCaseTerm)
        return brandMatch || modelMatch || seriMatch;
      }).toList();
    }

    // Arama sonrası seçili aracın filtrelenmiş listede olup olmadığını kontrol et
    if (_selectedVehicle != null && !_filteredVehicles.any((v) => v.id == _selectedVehicle!.id)) {
        // Eğer seçili araç artık filtrelenmiş listede yoksa,
        // ya seçimi kaldır ya da filtrelenmiş listenin ilkini seç
        _selectedVehicle = _filteredVehicles.isNotEmpty ? _filteredVehicles.first : null;
    } else if (_selectedVehicle == null && _filteredVehicles.isNotEmpty) {
        // Eğer hiç seçili araç yoksa ve filtrelenmiş liste boş değilse ilkini seç
        _selectedVehicle = _filteredVehicles.first;
    }
    // Bu metodun sonunda notifyListeners() çağrılmalıydı, ancak searchVehicles ve fetchVehicles
    // gibi onu çağıran public metotlar zaten sonunda notifyListeners çağırıyor.
    // Yine de, doğrudan çağrıldığı durumlar için (veya emin olmak için) eklenebilir.
    // Ancak döngüsel çağrılara dikkat edin. Şimdilik public metotlara bırakalım.
    // Eğer fetchVehicles gibi yerlerdeki çağrılarda sorun olursa buraya ekleriz.
    // Şimdilik bu satırı yorumda bırakalım, çünkü fetchVehicles ve searchVehicles bunu yönetiyor.
    // notifyListeners();
  }

  // *** DİĞER METOTLARINIZ (addNewVehicleToFirestore, updateVehicle, deleteVehicle, clearVehiclesLocally) BURADA KALACAK ***
  // Bu metotlar önceki önerideki gibi kalabilir.

  Future<void> addNewVehicleToFirestore(Vehicle vehicleData, {String? userId}) async {
    _isLoading = true;
    _errorMessage = null;
    notifyListeners();
    try {
      final docRef = await _firestore.collection('araclar').add(vehicleData.toFirestore());
      debugPrint('Yeni araç eklendi, ID: ${docRef.id}');
      await fetchVehicles(userId: userId);
    } catch (e) {
      _errorMessage = "Yeni araç eklenirken hata: $e";
      debugPrint('VehicleProvider Ekleme Hatası: $_errorMessage');
      _isLoading = false;
      notifyListeners();
    }
  }

  Future<void> updateVehicle(Vehicle updatedVehicle, {String? userId}) async {
    _isLoading = true;
    _errorMessage = null;
    notifyListeners();
    try {
      await _firestore
          .collection('araclar')
          .doc(updatedVehicle.id)
          .update(updatedVehicle.toFirestore());
      debugPrint('Araç güncellendi, ID: ${updatedVehicle.id}');
      await fetchVehicles(userId: userId);
    } catch (error) {
      _errorMessage = "Araç güncellenirken hata: $error";
      debugPrint('VehicleProvider Güncelleme Hatası: $_errorMessage');
      _isLoading = false; notifyListeners();
    }
  }

  Future<void> deleteVehicle(String vehicleId, {String? userId}) async {
    _isLoading = true;
    _errorMessage = null;
    notifyListeners();
    try {
      await _firestore.collection('araclar').doc(vehicleId).delete();
      debugPrint('Araç silindi, ID: $vehicleId');
      await fetchVehicles(userId: userId);
    } catch (error) {
      _errorMessage = "Araç silinirken hata: $error";
      debugPrint('VehicleProvider Silme Hatası: $_errorMessage');
      _isLoading = false; notifyListeners();
    }
  }

  void clearVehiclesLocally() {
    _allVehicles = [];
    _filteredVehicles = [];
    _selectedVehicle = null;
    _searchTerm = "";
    _errorMessage = null;
    notifyListeners();
    debugPrint('VehicleProvider: Yerel araç verileri temizlendi.');
  }
}