import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

// Provider importları
import '../providers/auth_provider.dart';
import '../providers/vehicle_provider.dart';
import '../providers/route_provider.dart';

// Model importları
import '../models/vehicle.dart';

// Model importları (CompletedRoute ve Vehicle modellerine buradan erişiliyor)
// Vehicle modelini import edin (Ortalama tüketim için)
// CompletedRoute buradan türetilmiş veya ilgili

class ProfileScreen extends StatelessWidget {
  const ProfileScreen({super.key});

  Widget _buildStatCard(
      BuildContext context, String title, String value, IconData icon) {
    return Card(
      elevation: 2,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
      ),
      child: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          children: [
            Icon(icon, size: 32, color: Theme.of(context).colorScheme.primary),
            const SizedBox(height: 8),
            Text(
              value,
              style: Theme.of(context).textTheme.titleLarge?.copyWith(
                    fontWeight: FontWeight.bold,
                  ),
            ),
            const SizedBox(height: 4),
            Text(
              title,
              style: Theme.of(context).textTheme.bodyMedium,
              textAlign: TextAlign.center,
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildCompletedRouteItem(BuildContext context, CompletedRoute route) {
    return Card(
      margin: const EdgeInsets.symmetric(vertical: 4.0),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
      ),
      child: Padding(
        padding: const EdgeInsets.all(16.0),
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
                    style: Theme.of(context).textTheme.titleMedium?.copyWith(
                          fontWeight: FontWeight.bold,
                        ),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                _buildRouteInfoColumn(context, 'Mesafe',
                    '${route.distance.toStringAsFixed(1)} km'),
                _buildRouteInfoColumn(context, 'Yakıt',
                    '${route.consumption.toStringAsFixed(1)} L'),
                _buildRouteInfoColumn(
                    context, 'Maliyet', '${route.cost.toStringAsFixed(2)} ₺'),
                _buildRouteInfoColumn(
                  context,
                  'Tarih',
                  '${route.completedAt.day}/${route.completedAt.month}/${route.completedAt.year}',
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildRouteInfoColumn(
      BuildContext context, String label, String value) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label,
          style: Theme.of(context).textTheme.bodySmall,
        ),
        const SizedBox(height: 4),
        Text(
          value,
          style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                fontWeight: FontWeight.w500,
              ),
        ),
      ],
    );
  }

  @override
  Widget build(BuildContext context) {
    final authProvider = Provider.of<AuthProvider>(context);
    final vehicleProvider = Provider.of<VehicleProvider>(context);
    final routeProvider = Provider.of<RouteProvider>(context);
    final isDark = Theme.of(context).brightness == Brightness.dark;

    final totalTrips = routeProvider.completedRoutes.length;
    final totalVehicles = vehicleProvider.vehicles.length;

    // Toplam mesafe hesaplama
    final double totalDistance = routeProvider.completedRoutes
        .fold(0.0, (sum, route) => sum + route.distanceInKm);

    // Toplam süre hesaplama (dakika cinsinden)
    final int totalDuration = routeProvider.completedRoutes
        .fold(0, (sum, route) => sum + route.durationInMinutes);

    // Toplam yakıt maliyeti hesaplama
    final double totalFuelCost = routeProvider.completedRoutes
        .fold(0.0, (sum, route) => sum + route.fuelCost);

    // En çok kullanılan araç
    final mostUsedVehicle = routeProvider.completedRoutes.isNotEmpty
        ? routeProvider.completedRoutes
            .map((route) => route.vehicleId)
            .toSet()
            .map((id) => vehicleProvider.vehicles.firstWhere((v) => v.id == id,
                orElse: () => vehicleProvider.vehicles.first))
            .reduce((a, b) => routeProvider.completedRoutes
                        .where((r) => r.vehicleId == a.id)
                        .length >
                    routeProvider.completedRoutes
                        .where((r) => r.vehicleId == b.id)
                        .length
                ? a
                : b)
        : null;

    // Ortalama yolculuk mesafesi
    final double averageTripDistance =
        totalTrips > 0 ? totalDistance / totalTrips : 0.0;

    // Ortalama yolculuk süresi
    final double averageTripDuration =
        totalTrips > 0 ? totalDuration / totalTrips : 0.0;

    return Scaffold(
      appBar: AppBar(
        title: const Text('Profil'),
      ),
      body: SingleChildScrollView(
        child: Padding(
          padding: const EdgeInsets.all(16.0),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Kullanıcı Bilgileri Kartı
              Card(
                elevation: 2,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Padding(
                  padding: const EdgeInsets.all(16.0),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          CircleAvatar(
                            radius: 30,
                            backgroundColor:
                                Theme.of(context).colorScheme.primary,
                            child: Text(
                              authProvider.userName
                                      ?.substring(0, 1)
                                      .toUpperCase() ??
                                  '?',
                              style: const TextStyle(
                                fontSize: 24,
                                fontWeight: FontWeight.bold,
                                color: Colors.white,
                              ),
                            ),
                          ),
                          const SizedBox(width: 16),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  authProvider.userName ?? 'Misafir Kullanıcı',
                                  style: Theme.of(context)
                                      .textTheme
                                      .titleLarge
                                      ?.copyWith(
                                        fontWeight: FontWeight.bold,
                                      ),
                                ),
                                const SizedBox(height: 4),
                                Text(
                                  authProvider.userEmail ?? 'E-posta yok',
                                  style: Theme.of(context).textTheme.bodyMedium,
                                ),
                              ],
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 16),
                      SizedBox(
                        width: double.infinity,
                        child: ElevatedButton.icon(
                          onPressed: () async {
                            await authProvider.signOut();
                            if (context.mounted) {
                              Navigator.pushReplacementNamed(context, '/login');
                            }
                          },
                          icon: const Icon(Icons.logout),
                          label: const Text('Çıkış Yap'),
                          style: ElevatedButton.styleFrom(
                            backgroundColor:
                                isDark ? Colors.red[700] : Colors.red,
                            foregroundColor: Colors.white,
                            padding: const EdgeInsets.symmetric(vertical: 12),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(8),
                            ),
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
              const SizedBox(height: 24),

              // İstatistikler Başlığı
              Text(
                'İstatistikler',
                style: Theme.of(context).textTheme.titleLarge?.copyWith(
                      fontWeight: FontWeight.bold,
                    ),
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
              Row(
                children: [
                  Expanded(
                    child: _buildStatCard(
                      context,
                      'Toplam Mesafe',
                      '${totalDistance.toStringAsFixed(1)} km',
                      Icons.route,
                    ),
                  ),
                  const SizedBox(width: 16),
                  Expanded(
                    child: _buildStatCard(
                      context,
                      'Toplam Süre',
                      '${(totalDuration / 60).toStringAsFixed(1)} saat',
                      Icons.timer,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 16),
              Row(
                children: [
                  Expanded(
                    child: _buildStatCard(
                      context,
                      'Toplam Yakıt Maliyeti',
                      '${totalFuelCost.toStringAsFixed(2)} ₺',
                      Icons.local_gas_station,
                    ),
                  ),
                  const SizedBox(width: 16),
                  Expanded(
                    child: _buildStatCard(
                      context,
                      'En Çok Kullanılan Araç',
                      mostUsedVehicle != null
                          ? '${mostUsedVehicle.brand} ${mostUsedVehicle.model}'
                          : '-',
                      Icons.star,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 16),
              Row(
                children: [
                  Expanded(
                    child: _buildStatCard(
                      context,
                      'Ortalama Yolculuk Mesafesi',
                      '${averageTripDistance.toStringAsFixed(1)} km',
                      Icons.straighten,
                    ),
                  ),
                  const SizedBox(width: 16),
                  Expanded(
                    child: _buildStatCard(
                      context,
                      'Ortalama Yolculuk Süresi',
                      '${(averageTripDuration / 60).toStringAsFixed(1)} saat',
                      Icons.timer_outlined,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 24),

              // Son Yolculuklar Başlığı
              Text(
                'Son Yolculuklar',
                style: Theme.of(context).textTheme.titleLarge?.copyWith(
                      fontWeight: FontWeight.bold,
                    ),
              ),
              const SizedBox(height: 16),

              // Son Yolculuklar Listesi
              if (routeProvider.completedRoutes.isEmpty)
                Card(
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Padding(
                    padding: const EdgeInsets.all(16.0),
                    child: Center(
                      child: Text(
                        'Henüz yolculuk kaydı bulunmuyor',
                        style: Theme.of(context).textTheme.bodyLarge,
                      ),
                    ),
                  ),
                )
              else
                ...routeProvider.completedRoutes
                    .take(3)
                    .map((route) => _buildCompletedRouteItem(context, route))
                    .toList(),

              if (routeProvider.completedRoutes.length > 3)
                Padding(
                  padding: const EdgeInsets.symmetric(vertical: 8.0),
                  child: Center(
                    child: TextButton.icon(
                      onPressed: () {
                        ScaffoldMessenger.of(context).showSnackBar(
                          const SnackBar(
                            content: Text(
                                'Tüm yolculukları gör ekranına yönlendirilecek...'),
                          ),
                        );
                      },
                      icon: const Icon(Icons.list_alt),
                      label: const Text('Tümünü Gör'),
                    ),
                  ),
                ),
            ],
          ),
        ),
      ),
    );
  }
}
