import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../providers/vehicle_provider.dart';
import '../models/vehicle.dart';
import 'add_vehicle_screen.dart';
import 'vehicle_detail_screen.dart';
// import '../widgets/vehicle_info_widget.dart'; // Eğer ayrı bir widget oluşturulursa

class VehicleScreen extends StatefulWidget {
  const VehicleScreen({super.key});

  @override
  State<VehicleScreen> createState() => _VehicleScreenState();
}

class _VehicleScreenState extends State<VehicleScreen> {
  String? _selectedVehicleId;

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
            plate: '34ABC123',
            year: 2020,
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
            plate: '34XYZ789',
            year: 2021,
            fuelType: 'Dizel',
            cityConsumption: 6.0,
            highwayConsumption: 4.5,
            vehicleType: 1,
          ),
        );
        vehicleProvider.addVehicle(
          Vehicle(
            id: 'car3',
            brand: 'MAZDA',
            model: '3 2.0 Skyactiv-G',
            plate: '34DEF456',
            year: 2022,
            fuelType: 'Benzin',
            cityConsumption: 6.8,
            highwayConsumption: 4.9,
            vehicleType: 1,
          ),
        );
      }
    });
  }

  void _onVehicleSelected(String vehicleId) {
    setState(() {
      _selectedVehicleId = vehicleId;
    });
  }

  @override
  Widget build(BuildContext context) {
    final vehicleProvider = Provider.of<VehicleProvider>(context);
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Scaffold(
      appBar: AppBar(
        title: const Text('Araçlarım'),
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () {
          Navigator.push(
            context,
            MaterialPageRoute(builder: (context) => const AddVehicleScreen()),
          );
        },
        icon: const Icon(Icons.add),
        label: const Text('Araç Ekle'),
      ),
      body: vehicleProvider.vehicles.isEmpty
          ? Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(
                    Icons.directions_car_outlined,
                    size: 64,
                    color: isDark ? Colors.grey[600] : Colors.grey[400],
                  ),
                  const SizedBox(height: 16),
                  Text(
                    'Henüz araç eklenmemiş',
                    style: Theme.of(context).textTheme.titleLarge,
                  ),
                  const SizedBox(height: 8),
                  Text(
                    'Araç eklemek için sağ alttaki butonu kullanın',
                    style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                          color: isDark ? Colors.grey[400] : Colors.grey[600],
                        ),
                  ),
                ],
              ),
            )
          : ListView.builder(
              padding: const EdgeInsets.all(16),
              itemCount: vehicleProvider.vehicles.length,
              itemBuilder: (context, index) {
                final vehicle = vehicleProvider.vehicles[index];
                return _buildVehicleCard(
                  context,
                  vehicle,
                  vehicle.id == _selectedVehicleId,
                  () => _onVehicleSelected(vehicle.id),
                );
              },
            ),
    );
  }

  Widget _buildVehicleCard(
    BuildContext context,
    Vehicle vehicle,
    bool isSelected,
    VoidCallback onTap,
  ) {
    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      elevation: isSelected ? 4 : 2,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
        side: isSelected
            ? BorderSide(
                color: Theme.of(context).colorScheme.primary,
                width: 2,
              )
            : BorderSide.none,
      ),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(12),
        child: Padding(
          padding: const EdgeInsets.all(16.0),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Icon(
                    Icons.directions_car_rounded,
                    size: 30,
                    color: Theme.of(context).colorScheme.primary,
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      '${vehicle.brand} ${vehicle.model}',
                      style: TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                        color: isSelected
                            ? Theme.of(context).colorScheme.primary
                            : Theme.of(context).textTheme.bodyLarge?.color,
                      ),
                    ),
                  ),
                  IconButton(
                    icon: const Icon(Icons.info_outline),
                    onPressed: () {
                      Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder: (context) => VehicleDetailScreen(
                            vehicle: vehicle,
                          ),
                        ),
                      );
                    },
                  ),
                ],
              ),
              const SizedBox(height: 12),
              Row(
                children: [
                  Icon(
                    Icons.local_gas_station,
                    size: 20,
                    color: Theme.of(context).textTheme.bodyMedium?.color,
                  ),
                  const SizedBox(width: 4),
                  Text(
                    vehicle.fuelType,
                    style: TextStyle(
                      fontSize: 15,
                      color: Theme.of(context).textTheme.bodyLarge?.color,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 8),
              Row(
                children: [
                  Icon(
                    Icons.location_city,
                    size: 20,
                    color: Theme.of(context).textTheme.bodyMedium?.color,
                  ),
                  const SizedBox(width: 4),
                  Text(
                    'Şehir içi: ${vehicle.cityConsumption}L/100km',
                    style: TextStyle(
                      fontSize: 15,
                      color: Theme.of(context).textTheme.bodyLarge?.color,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 4),
              Row(
                children: [
                  Icon(
                    Icons.landscape,
                    size: 20,
                    color: Theme.of(context).textTheme.bodyMedium?.color,
                  ),
                  const SizedBox(width: 4),
                  Text(
                    'Şehir dışı: ${vehicle.highwayConsumption}L/100km',
                    style: TextStyle(
                      fontSize: 15,
                      color: Theme.of(context).textTheme.bodyLarge?.color,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 12),
              if (isSelected)
                Align(
                  alignment: Alignment.centerRight,
                  child: ElevatedButton(
                    onPressed: null,
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Theme.of(context).colorScheme.primary,
                      foregroundColor: Colors.white,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(20),
                      ),
                    ),
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
