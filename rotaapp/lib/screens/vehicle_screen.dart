// lib/screens/vehicle_screen.dart
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../providers/vehicle_provider.dart';
import '../models/vehicle.dart';
import 'add_vehicle_screen.dart'; // Bu dosyanın var olduğundan emin olun

class VehicleScreen extends StatefulWidget {
  const VehicleScreen({Key? key}) : super(key: key);

  @override
  State<VehicleScreen> createState() => _VehicleScreenState();
}

class _VehicleScreenState extends State<VehicleScreen> {
  final TextEditingController _searchController = TextEditingController();

  @override
  void initState() {
    super.initState();
    // Arama çubuğundaki değişiklikleri dinle
    _searchController.addListener(() {
      Provider.of<VehicleProvider>(context, listen: false)
          .searchVehicles(_searchController.text);
    });
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final vehicleProvider = context.watch<VehicleProvider>();
    const Color backgroundColor = Colors.white;

    return Scaffold(
      backgroundColor: backgroundColor,
      appBar: AppBar(
        title: const Text('Araçlarım'),
        backgroundColor: backgroundColor,
        elevation: 0,
        actions: [
          IconButton(
            icon: Icon(Icons.refresh,
                color: Theme.of(context).colorScheme.primary),
            onPressed: () {
              _searchController.clear(); // Arama terimini temizle
              vehicleProvider.fetchVehicles();
            },
          ),
        ],
      ),
      body: Column(
        // Ana yapıyı Column olarak değiştirdik
        children: [
          // ARAMA ÇUBUĞU
          Padding(
            padding: const EdgeInsets.all(16.0),
            child: TextField(
              controller: _searchController,
              decoration: InputDecoration(
                hintText: 'Marka, model veya seri ara...',
                hintStyle:
                    TextStyle(color: const Color.fromARGB(255, 116, 116, 116)),
                prefixIcon: const Icon(Icons.search),
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(25.0),
                  borderSide: BorderSide.none,
                ),
                filled: true,
                fillColor: Colors.grey[200],
                contentPadding:
                    const EdgeInsets.symmetric(vertical: 0, horizontal: 20),
                // Arama çubuğunu temizleme butonu (opsiyonel)
                suffixIcon: _searchController.text.isNotEmpty
                    ? IconButton(
                        icon: const Icon(Icons.clear),
                        onPressed: () {
                          _searchController
                              .clear(); // Provider'ı tetikler (listener sayesinde)
                        },
                      )
                    : null,
              ),
            ),
          ),
          // ARAÇ LİSTESİ
          Expanded(
            // ListView'ın Column içinde doğru boyutlanması için
            child: _buildVehicleListBody(context, vehicleProvider),
          ),
        ],
      ),
      floatingActionButton: FloatingActionButton(
        onPressed: () {
          Navigator.push(
            context,
            MaterialPageRoute(
              builder: (context) => const AddVehicleScreen(),
            ),
          ).then((yeniAracEklendi) {
            if (yeniAracEklendi == true) {
              // AddVehicleScreen'den true dönerse, araç eklenmiştir.
              // VehicleProvider.fetchVehicles zaten çağrılacak
              // (addNewVehicleToFirestore içinde çağrıldığı için).
              // Eğer AddVehicleScreen sadece lokalde ekleyip true döndürüyorsa
              // o zaman burada fetchVehicles'ı tekrar çağırmak gerekebilir.
              // Şimdilik provider'daki mantığa güveniyoruz.
              // vehicleProvider.fetchVehicles();
              _searchController
                  .clear(); // Yeni araç eklendiğinde arama temizlenebilir
            }
          });
        },
        backgroundColor: Theme.of(context).colorScheme.primary,
        child: const Icon(Icons.add, color: Colors.white),
        tooltip: 'Yeni Araç Ekle',
      ),
    );
  }

  Widget _buildVehicleListBody(
      BuildContext context, VehicleProvider vehicleProvider) {
    // ... (Bu metot bir önceki cevaptaki gibi kalabilir, sadece vehicles listesini kullanır)
    // ÖNEMLİ: Bu metot artık vehicleProvider.vehicles (filtrelenmiş liste) kullanmalı.
    // Zaten öyleydi, bir değişiklik yapmaya gerek yok.

    if (vehicleProvider.isLoading && vehicleProvider.vehicles.isEmpty) {
      return const Center(child: CircularProgressIndicator());
    }

    if (vehicleProvider.errorMessage != null) {
      return Center(/* ... Hata mesajı ... */);
    }

    // Arama sonucu boşsa ama yükleme devam etmiyorsa ve genel araç listesi de boş değilse
    // (yani arama sonucu bulunamadı durumu)
    if (vehicleProvider.vehicles.isEmpty &&
        !vehicleProvider.isLoading &&
        vehicleProvider.searchTerm.isNotEmpty && // Arama yapılıyorsa
        vehicleProvider.allVehicles.isNotEmpty) {
      // Ama genel liste doluysa
      return Center(
        child: Text(
          '"${vehicleProvider.searchTerm}" için sonuç bulunamadı.',
          style: const TextStyle(fontSize: 18, color: Colors.grey),
          textAlign: TextAlign.center,
        ),
      );
    }

    if (vehicleProvider.vehicles.isEmpty && !vehicleProvider.isLoading) {
      return Center(
          /* ... Kayıtlı araç bulunamadı mesajı ve ekle butonu ... */);
    }

    return ListView.builder(
      padding: const EdgeInsets.only(
          left: 8.0, right: 8.0, bottom: 80.0), // FAB için altta boşluk
      itemCount:
          vehicleProvider.vehicles.length, // Filtrelenmiş listeyi kullanır
      itemBuilder: (context, index) {
        final Vehicle vehicle = vehicleProvider.vehicles[index];
        final bool isSelected =
            vehicleProvider.selectedVehicle?.id == vehicle.id;

        return Card(
          // ... (Card içeriği aynı kalabilir) ...
          margin: const EdgeInsets.symmetric(vertical: 6.0, horizontal: 8.0),
          elevation: isSelected ? 5 : 2,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12),
            side: isSelected
                ? BorderSide(
                    color: Theme.of(context).colorScheme.primary, width: 2.5)
                : BorderSide.none,
          ),
          child: InkWell(
            onTap: () {
              vehicleProvider.selectVehicle(vehicle);
              _showVehicleDetailsDialog(context, vehicle);
            },
            borderRadius: BorderRadius.circular(12),
            child: Padding(
              padding: const EdgeInsets.all(16.0),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Flexible(
                        child: Text(
                          '${vehicle.marka} ${vehicle.model}',
                          style: TextStyle(
                            fontSize: 18,
                            fontWeight: FontWeight.bold,
                            color: isSelected
                                ? Theme.of(context).colorScheme.primary
                                : Colors.black87,
                          ),
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                      if (isSelected)
                        Chip(
                          label: const Text('Seçili',
                              style: TextStyle(color: Colors.white)),
                          backgroundColor:
                              Theme.of(context).colorScheme.primary,
                          padding: const EdgeInsets.symmetric(
                              horizontal: 8, vertical: 2),
                        )
                    ],
                  ),
                  const SizedBox(height: 8),
                  Text('Yıl: ${vehicle.yil}'),
                  Text('Yakıt: ${vehicle.yakitTipi} - Vites: ${vehicle.vites}'),
                  Text('Motor: ${vehicle.motorGucu} / ${vehicle.motorHacmi}'),
                  Text(
                      'Kasa Tipi: ${vehicle.kasaTipi} - Çekiş: ${vehicle.cekis}'),
                ],
              ),
            ),
          ),
        );
      },
    );
  }

  void _showVehicleDetailsDialog(BuildContext context, Vehicle vehicle) {
    // ... (Bu metot aynı kalabilir) ...
    showDialog(
      context: context,
      builder: (BuildContext context) {
        return AlertDialog(
          title: Text('${vehicle.marka} ${vehicle.model}'),
          content: SingleChildScrollView(
            child: ListBody(
              children: <Widget>[
                Text('ID: ${vehicle.id}'),
                Text('Seri: ${vehicle.seri}'),
                Text('Yıl: ${vehicle.yil}'),
                Text('Yakıt Tipi: ${vehicle.yakitTipi}'),
                Text('Vites: ${vehicle.vites}'),
                Text('Kasa Tipi: ${vehicle.kasaTipi}'),
                Text('Motor Gücü: ${vehicle.motorGucu}'),
                Text('Motor Hacmi: ${vehicle.motorHacmi}'),
                Text('Çekiş: ${vehicle.cekis}'),
                Text(
                    'Şehir İçi Tüketim: ${vehicle.cityConsumption?.toStringAsFixed(1) ?? 'Belirtilmemiş'} L/100km'),
                Text(
                    'Şehir Dışı Tüketim: ${vehicle.highwayConsumption?.toStringAsFixed(1) ?? 'Belirtilmemiş'} L/100km'),
              ],
            ),
          ),
          actions: <Widget>[
            TextButton(
              child: const Text('Kapat'),
              onPressed: () {
                Navigator.of(context).pop();
              },
            ),
          ],
        );
      },
    );
  }
}
