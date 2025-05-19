import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

// Provider importları
import '../providers/auth_provider.dart';
import '../providers/vehicle_provider.dart';
import '../providers/route_provider.dart';

// Model importları (CompletedRoute ve Vehicle modellerine buradan erişiliyor)
// Vehicle modelini import edin (Ortalama tüketim için)
// CompletedRoute buradan türetilmiş veya ilgili

class ProfileScreen extends StatelessWidget {
  const ProfileScreen({super.key});

  // İstatistik kartlarını oluşturan yardımcı metod (Değişiklik Yok)
  Widget _buildStatCard(
    BuildContext context,
    String title,
    String value,
    IconData icon, {
    bool isFullWidth =
        false, // isFullWidth şu an kullanımda değil ama metotta bırakıldı
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
              style: TextStyle(
                fontSize: 24,
                fontWeight: FontWeight.bold,
                color: Theme.of(context).textTheme.bodyLarge?.color,
              ),
            ),
            const SizedBox(height: 4),
            Text(
              title,
              style: TextStyle(
                fontSize: 14,
                color: Theme.of(context).textTheme.bodyMedium?.color,
              ),
              textAlign: TextAlign.center,
            ),
          ],
        ),
      ),
    );
  }

  // Son yolculuk öğelerini oluşturan yardımcı metod (Opsiyonel, ListTile yerine Card içinde Column da olabilir)
  Widget _buildCompletedRouteItem(BuildContext context, CompletedRoute route) {
    return Card(
      // ListTile yerine Card içinde düzenleyelim
      margin:
          const EdgeInsets.symmetric(vertical: 4.0), // Kartlar arasına boşluk
      child: Padding(
        padding: const EdgeInsets.all(12.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(Icons.route,
                    size: 20, color: Theme.of(context).colorScheme.primary),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    '${route.startPoint} - ${route.endPoint}',
                    style: TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.bold,
                      color: Theme.of(context).textTheme.bodyLarge?.color,
                    ),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 8),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text('Mesafe',
                        style: TextStyle(
                            fontSize: 12,
                            color:
                                Theme.of(context).textTheme.bodyMedium?.color)),
                    Text('${route.distance.toStringAsFixed(1)} km',
                        style: TextStyle(
                            fontSize: 14,
                            color:
                                Theme.of(context).textTheme.bodyLarge?.color)),
                  ],
                ),
                Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text('Yakıt',
                        style: TextStyle(
                            fontSize: 12,
                            color:
                                Theme.of(context).textTheme.bodyMedium?.color)),
                    Text('${route.consumption.toStringAsFixed(1)} L',
                        style: TextStyle(
                            fontSize: 14,
                            color:
                                Theme.of(context).textTheme.bodyLarge?.color)),
                  ],
                ),
                Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text('Maliyet',
                        style: TextStyle(
                            fontSize: 12,
                            color:
                                Theme.of(context).textTheme.bodyMedium?.color)),
                    Text(
                        '${route.cost.toStringAsFixed(2)} ₺', // Maliyeti de gösteriyoruz
                        style: TextStyle(
                          fontSize: 14,
                          fontWeight: FontWeight.bold,
                          color: Theme.of(context).colorScheme.primary,
                        )),
                  ],
                ),
                // Tamamlanma zamanını da gösterebiliriz
                Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text('Tarih',
                        style: TextStyle(
                            fontSize: 12,
                            color:
                                Theme.of(context).textTheme.bodyMedium?.color)),
                    Text(
                        '${route.completedAt.day}/${route.completedAt.month}/${route.completedAt.year}',
                        style: TextStyle(
                            fontSize: 14,
                            color:
                                Theme.of(context).textTheme.bodyLarge?.color)),
                  ],
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final authProvider = Provider.of<AuthProvider>(context);
    final vehicleProvider = Provider.of<VehicleProvider>(context);
    final routeProvider = Provider.of<RouteProvider>(context);

    final totalTrips = routeProvider.completedRoutes.length;
    final totalVehicles = vehicleProvider.vehicles.length;

    final double totalCityConsumptionSum = vehicleProvider.vehicles
        .map((v) => v.cityConsumption)
        .fold(0.0, (sum, consumption) => sum + consumption);
    final double totalHighwayConsumptionSum = vehicleProvider.vehicles
        .map((v) => v.highwayConsumption)
        .fold(0.0, (sum, consumption) => sum + consumption);

    final double averageCityConsumption =
        totalVehicles == 0 ? 0.0 : totalCityConsumptionSum / totalVehicles;
    final double averageHighwayConsumption =
        totalVehicles == 0 ? 0.0 : totalHighwayConsumptionSum / totalVehicles;
    final double simpleAverageConsumption =
        (averageCityConsumption + averageHighwayConsumption) / 2;

    return Scaffold(
      appBar: AppBar(
        title: const Text('Profil'),
      ),
      body: ListView(
        padding: const EdgeInsets.all(16.0),
        children: [
          Card(
            shape:
                RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
            elevation: 2,
            child: Padding(
              padding: const EdgeInsets.all(16.0),
              child: Column(
                children: [
                  const CircleAvatar(
                    radius: 40,
                    backgroundColor: Colors.grey,
                    child: Icon(Icons.person, size: 40, color: Colors.white),
                  ),
                  const SizedBox(height: 16),
                  Text(
                    authProvider.currentUser?.name ?? 'Misafir Kullanıcı',
                    style: TextStyle(
                      fontSize: 20,
                      fontWeight: FontWeight.bold,
                      color: Theme.of(context).textTheme.bodyLarge?.color,
                    ),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    authProvider.currentUser?.email ?? 'Giriş yapılmamış',
                    style: TextStyle(
                      fontSize: 16,
                      color: Theme.of(context).textTheme.bodyMedium?.color,
                    ),
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 24),
          Text(
            'İstatistikler',
            style: TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.bold,
              color: Theme.of(context).textTheme.bodyLarge?.color,
            ),
          ),
          const SizedBox(height: 16),
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
            '${simpleAverageConsumption.toStringAsFixed(1)} L/100km',
            Icons.local_gas_station,
            isFullWidth: true,
          ),
          const SizedBox(height: 24),
          Text(
            'Son Yolculuklar',
            style: TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.bold,
              color: Theme.of(context).textTheme.bodyLarge?.color,
            ),
          ),
          const SizedBox(height: 16),
          if (routeProvider.completedRoutes.isEmpty)
            Card(
              shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12)),
              elevation: 2,
              child: Padding(
                padding: const EdgeInsets.all(16.0),
                child: Center(
                  child: Text(
                    'Henüz yolculuk kaydı bulunmuyor',
                    style: TextStyle(
                      color: Theme.of(context).textTheme.bodyLarge?.color,
                    ),
                  ),
                ),
              ),
            )
          else
            ...routeProvider.completedRoutes
                .take(3)
                .map(
                  (route) => _buildCompletedRouteItem(context, route),
                )
                .toList(),
          if (routeProvider.completedRoutes.length > 3)
            Padding(
              padding: const EdgeInsets.symmetric(vertical: 8.0),
              child: TextButton(
                onPressed: () {
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(
                        content: Text(
                            'Tüm yolculukları gör ekranına yönlendirilecek...')),
                  );
                },
                child: const Text('Tümünü Gör'),
              ),
            ),
        ],
      ),
    );
  }
}
