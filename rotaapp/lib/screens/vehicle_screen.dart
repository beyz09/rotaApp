import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../providers/vehicle_provider.dart';
import '../models/vehicle.dart';
import 'add_vehicle_screen.dart';
// import '../widgets/vehicle_info_widget.dart'; // Eğer ayrı bir widget oluşturulursa

class VehicleScreen extends StatefulWidget {
  const VehicleScreen({super.key});

  @override
  State<VehicleScreen> createState() => _VehicleScreenState();
}

class _VehicleScreenState extends State<VehicleScreen> {
  @override
  void initState() {
    super.initState();
    // Araç listesini yükle (Genellikle provider constructor'ında veya main.dart'ta yapılır)
    // Provider.of<VehicleProvider>(context, listen: false).loadVehicles();
    // Örnek araç ekleyelim başlangıçta
    WidgetsBinding.instance.addPostFrameCallback((_) {
      final vehicleProvider = Provider.of<VehicleProvider>(
        context,
        listen: false,
      );
      if (vehicleProvider.vehicles.isEmpty) {
        vehicleProvider.addVehicle(
          Vehicle(
            id: 'car1',
            brand: 'TOYOTA',
            model: 'Corolla 1.6X',
            fuelType: 'Benzin',
            cityConsumption: 7.2,
            highwayConsumption: 5.1,
            vehicleType: 1,
          ),
        );
        vehicleProvider.addVehicle(
          Vehicle(
            id: 'car2',
            brand: 'FORD',
            model: 'Focus 1.5 Dizel',
            fuelType: 'Dizel',
            cityConsumption: 6.0,
            highwayConsumption: 4.5,
            vehicleType: 1,
          ),
        );
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    final vehicleProvider = Provider.of<VehicleProvider>(context);
    final selectedVehicle = vehicleProvider.selectedVehicle;

    const Color backgroundColor = Color(0xFFDCF0D8); // Figma'daki yeşil tonu

    return Scaffold(
      backgroundColor: backgroundColor, // Arka plan rengi
      // AppBar'ı Bottom Nav Bar'ın olduğu ana yapıya taşıyabiliriz
      // body kısmında kart içeriğini göstereceğiz
      body: Center(
        // İçeriği ortalayabiliriz veya DraggableScrollableSheet kullanabiliriz
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            // Üstteki tutma çubuğu (Eğer bottom sheet gibi açılıyorsa)
            Container(
              margin: const EdgeInsets.symmetric(vertical: 8),
              height: 5,
              width: 40,
              decoration: BoxDecoration(
                color: Colors.grey[300],
                borderRadius: BorderRadius.circular(10),
              ),
            ),
            const SizedBox(height: 16),
            const Text(
              'Araç Bilgilerim',
              style: TextStyle(
                fontSize: 20,
                fontWeight: FontWeight.bold,
                color: Colors.black87,
              ),
            ),
            const SizedBox(height: 16),

            if (vehicleProvider.vehicles.isEmpty)
              // Araç bilgisi yok kartı
              Card(
                margin: const EdgeInsets.symmetric(horizontal: 16),
                elevation: 2,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Padding(
                  padding: const EdgeInsets.all(24.0),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      const Text(
                        'Araç bilgisi yok.',
                        style: TextStyle(fontSize: 16, color: Colors.grey),
                      ),
                      const SizedBox(height: 16),
                      FloatingActionButton(
                        // Figma'daki '+' butonu
                        onPressed: () {
                          // Araç Ekle ekranına veya modalına git
                          Navigator.push(
                            context,
                            MaterialPageRoute(
                              builder: (context) => const AddVehicleScreen(),
                            ),
                          );
                        },
                        backgroundColor:
                            Theme.of(context).colorScheme.primary,
                        child: const Icon(Icons.add), // Tema rengi
                      ),
                    ],
                  ),
                ),
              )
            else
              // Kayıtlı araçları listele (Horizontal ListView veya Column içinde Cardlar)
              Expanded(
                // Liste için Expanded kullan
                child: ListView.builder(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 16.0,
                    vertical: 8.0,
                  ),
                  itemCount: vehicleProvider.vehicles.length,
                  itemBuilder: (context, index) {
                    final vehicle = vehicleProvider.vehicles[index];
                    final isSelected =
                        vehicleProvider.selectedVehicle?.id == vehicle.id;

                    return _buildVehicleCard(context, vehicle, isSelected, () {
                      vehicleProvider.selectVehicle(
                        vehicle,
                      ); // Tıklanınca aracı seç
                    });
                  },
                ),
              ),

            // Figma'daki '+' butonu sadece araç yokken gösteriliyor gibi duruyor.
            // Eğer her zaman gösterilecekse buraya ekleyebiliriz.
            // if(vehicleProvider.vehicles.isNotEmpty) // Eğer liste varken de + butonu olacaksa
            // FloatingActionButton( ... )
          ],
        ),
      ),
    );
  }

  // Araç Bilgileri Kartı Widget'ı
  Widget _buildVehicleCard(
    BuildContext context,
    Vehicle vehicle,
    bool isSelected,
    VoidCallback onTap,
  ) {
    return Card(
      margin: const EdgeInsets.only(bottom: 12), // Kartlar arasına boşluk
      elevation: isSelected ? 4 : 2, // Seçiliyse daha yüksek gölge
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
        side:
            isSelected
                ? BorderSide(
                  color: Theme.of(context).colorScheme.primary,
                  width: 2,
                )
                : BorderSide.none, // Seçiliyse kenarlık
      ),
      child: InkWell(
        // Tıklanabilir olması için
        onTap: onTap,
        borderRadius: BorderRadius.circular(12),
        child: Padding(
          padding: const EdgeInsets.all(16.0),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  // Marka Logosu - Şimdilik yer tutucu
                  Icon(
                    Icons.directions_car_rounded,
                    size: 30,
                    color: Theme.of(context).colorScheme.primary,
                  ),
                  const SizedBox(width: 8),
                  Text(
                    '${vehicle.brand} ${vehicle.model}',
                    style: TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                      color:
                          isSelected
                              ? Theme.of(context).colorScheme.primary
                              : Colors.black87,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 12),
              Row(
                children: [
                  Icon(
                    Icons.local_gas_station,
                    size: 20,
                    color: Colors.grey[600],
                  ),
                  const SizedBox(width: 4),
                  Text(
                    vehicle.fuelType,
                    style: const TextStyle(fontSize: 15, color: Colors.black87),
                  ),
                ],
              ),
              const SizedBox(height: 8),
              Row(
                children: [
                  Icon(Icons.location_city, size: 20, color: Colors.grey[600]),
                  const SizedBox(width: 4),
                  Text(
                    'Şehir içi: ${vehicle.cityConsumption}L/100km',
                    style: const TextStyle(fontSize: 15, color: Colors.black87),
                  ),
                ],
              ),
              const SizedBox(height: 4),
              Row(
                children: [
                  Icon(Icons.landscape, size: 20, color: Colors.grey[600]),
                  const SizedBox(width: 4),
                  Text(
                    'Şehir dışı: ${vehicle.highwayConsumption}L/100km',
                    style: const TextStyle(fontSize: 15, color: Colors.black87),
                  ),
                ],
              ),
              const SizedBox(height: 12),
              // Seçildi butonu (Sadece seçiliyse göster)
              if (isSelected)
                Align(
                  alignment: Alignment.centerRight,
                  child: ElevatedButton(
                    onPressed: null,
                    style: ElevatedButton.styleFrom(
                      backgroundColor:
                          Theme.of(context).colorScheme.primary, // Tema rengi
                      foregroundColor: Colors.white,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(20),
                      ),
                    ), // Pasif buton
                    child: const Text('Seçildi'),
                  ),
                ),
            ],
          ),
        ),
      ),
    );
  }
}
