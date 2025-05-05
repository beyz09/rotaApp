import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../providers/auth_provider.dart';
import '../providers/vehicle_provider.dart';
import '../providers/route_provider.dart';

class ProfileScreen extends StatelessWidget {
  const ProfileScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final Color backgroundColor = Color(0xFFDCF0D8); // Figma'daki yeşil tonu
    final authProvider = Provider.of<AuthProvider>(context);
    final vehicleProvider = Provider.of<VehicleProvider>(context);
    final routeProvider = Provider.of<RouteProvider>(context);

    // Örnek istatistikler (gerçek verilerle değiştirilecek)
    final totalTrips = routeProvider.routes.length;
    final totalVehicles = vehicleProvider.vehicles.length;
    final averageConsumption =
        vehicleProvider.vehicles.isEmpty
            ? 0.0
            : vehicleProvider.vehicles
                    .map((v) => (v.cityConsumption + v.highwayConsumption) / 2)
                    .reduce((a, b) => a + b) /
                totalVehicles;

    return Scaffold(
      backgroundColor: backgroundColor,
      appBar: AppBar(
        title: const Text('Profil'),
        backgroundColor: backgroundColor,
        elevation: 0,
      ),
      body: ListView(
        padding: const EdgeInsets.all(16.0),
        children: [
          // Kullanıcı Bilgileri Kartı
          Card(
            child: Padding(
              padding: const EdgeInsets.all(16.0),
              child: Column(
                children: [
                  const CircleAvatar(
                    radius: 40,
                    child: Icon(Icons.person, size: 40),
                  ),
                  const SizedBox(height: 16),
                  Text(
                    authProvider.currentUser?.name ?? 'Misafir Kullanıcı',
                    style: const TextStyle(
                      fontSize: 20,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    authProvider.currentUser?.email ?? 'Giriş yapılmamış',
                    style: TextStyle(fontSize: 16, color: Colors.grey[600]),
                  ),
                ],
              ),
            ),
          ),

          const SizedBox(height: 24),

          // İstatistikler Başlığı
          const Text(
            'İstatistikler',
            style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
          ),
          const SizedBox(height: 16),

          // İstatistik Kartları
          Row(
            children: [
              Expanded(
                child: _buildStatCard(
                  context,
                  'Toplam Yolculuk',
                  totalTrips.toString(),
                  Icons.directions_car,
                ),
              ),
              const SizedBox(width: 16),
              Expanded(
                child: _buildStatCard(
                  context,
                  'Araç Sayısı',
                  totalVehicles.toString(),
                  Icons.local_shipping,
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          _buildStatCard(
            context,
            'Ortalama Tüketim',
            '${averageConsumption.toStringAsFixed(1)} L/100km',
            Icons.local_gas_station,
            isFullWidth: true,
          ),

          const SizedBox(height: 24),

          // Son Yolculuklar
          const Text(
            'Son Yolculuklar',
            style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
          ),
          const SizedBox(height: 16),
          if (routeProvider.routes.isEmpty)
            const Card(
              child: Padding(
                padding: EdgeInsets.all(16.0),
                child: Center(child: Text('Henüz yolculuk kaydı bulunmuyor')),
              ),
            )
          else
            ...routeProvider.routes
                .take(3)
                .map(
                  (route) => Card(
                    child: ListTile(
                      leading: const Icon(Icons.route),
                      title: Text('${route.startPoint} - ${route.endPoint}'),
                      subtitle: Text('${route.distance.toStringAsFixed(1)} km'),
                      trailing: Text(
                        '${route.consumption.toStringAsFixed(1)} L',
                        style: const TextStyle(
                          fontWeight: FontWeight.bold,
                          color: Colors.green,
                        ),
                      ),
                    ),
                  ),
                ),
        ],
      ),
    );
  }

  Widget _buildStatCard(
    BuildContext context,
    String title,
    String value,
    IconData icon, {
    bool isFullWidth = false,
  }) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          children: [
            Icon(icon, size: 32, color: Theme.of(context).colorScheme.primary),
            const SizedBox(height: 8),
            Text(
              value,
              style: const TextStyle(fontSize: 24, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 4),
            Text(
              title,
              style: TextStyle(fontSize: 14, color: Colors.grey[600]),
              textAlign: TextAlign.center,
            ),
          ],
        ),
      ),
    );
  }
}
