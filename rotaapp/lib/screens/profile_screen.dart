// lib/screens/profile_screen.dart
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
// import 'package:intl/intl.dart';

import '../providers/auth_provider.dart';
import '../providers/vehicle_provider.dart';
import '../providers/route_provider.dart';

import '../models/vehicle.dart';
import '../models/completed_route.dart';

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
          mainAxisAlignment: MainAxisAlignment.center,
          crossAxisAlignment: CrossAxisAlignment.center,
          children: [
            Icon(icon, size: 32, color: Theme.of(context).colorScheme.primary),
            const SizedBox(height: 8),
            Text(
              value,
              style: Theme.of(context).textTheme.titleLarge?.copyWith(
                    fontWeight: FontWeight.bold,
                  ),
              textAlign: TextAlign.center,
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
                    '${route.startLocation} - ${route.endLocation}', // DÜZELTİLDİ
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
                    '${route.distanceInKm.toStringAsFixed(1)} km'),
                // 'consumption' alanı modelde yok, 'fuelCost' var.
                // Eğer litre cinsinden tüketim de saklanıyorsa model güncellenmeli.
                // Şimdilik sadece maliyeti gösteriyoruz.
                _buildRouteInfoColumn(
                    context, 'Maliyet', '${route.fuelCost.toStringAsFixed(2)} ₺'), // DÜZELTİLDİ
                _buildRouteInfoColumn(
                  context,
                  'Tarih',
                  '${route.completedAt.day.toString().padLeft(2, '0')}/${route.completedAt.month.toString().padLeft(2, '0')}/${route.completedAt.year}',
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
    return Expanded(
      child: Column(
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
            overflow: TextOverflow.ellipsis,
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final authProvider = Provider.of<AuthProvider>(context);
    final vehicleProvider = Provider.of<VehicleProvider>(context);
    final routeProvider = Provider.of<RouteProvider>(context);
    final isDark = Theme.of(context).brightness == Brightness.dark;

    final List<CompletedRoute> completedRoutes = routeProvider.completedRoutes;
    final List<Vehicle> vehicles = vehicleProvider.vehicles;

    final totalTrips = completedRoutes.length;
    final totalVehicles = vehicles.length;

    final double totalDistance = completedRoutes.fold(0.0, (sum, route) => sum + route.distanceInKm);
    final int totalDurationMinutes = completedRoutes.fold(0, (sum, route) => sum + route.durationInMinutes);
    final double totalFuelCost = completedRoutes.fold(0.0, (sum, route) => sum + route.fuelCost);

    Vehicle? mostUsedVehicle;
    if (completedRoutes.isNotEmpty && vehicles.isNotEmpty) {
      final Map<String, int> usageCounts = {};
      for (var route in completedRoutes) {
        usageCounts[route.vehicleId] = (usageCounts[route.vehicleId] ?? 0) + 1;
      }
      if (usageCounts.isNotEmpty) {
        final mostUsedId = usageCounts.entries.reduce((a, b) => a.value > b.value ? a : b).key;
        try {
          mostUsedVehicle = vehicles.firstWhere((v) => v.id == mostUsedId);
        } catch (e) {
          mostUsedVehicle = null;
          debugPrint("En çok kullanılan araç ID'si ($mostUsedId) araç listesinde bulunamadı.");
        }
      }
    }

    final double averageTripDistance = totalTrips > 0 ? totalDistance / totalTrips : 0.0;
    final double averageTripDurationMinutes = totalTrips > 0 ? totalDurationMinutes.toDouble() / totalTrips : 0.0;

    return Scaffold(
      appBar: AppBar(
        title: const Text('Profilim'),
      ),
      body: SingleChildScrollView(
        child: Padding(
          padding: const EdgeInsets.all(16.0),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
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
                            backgroundColor: Theme.of(context).colorScheme.primary,
                            child: Text(
                              authProvider.userName != null && authProvider.userName!.isNotEmpty
                                  ? authProvider.userName!.substring(0, 1).toUpperCase()
                                  : '?',
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
                                  style: Theme.of(context).textTheme.titleLarge?.copyWith(
                                        fontWeight: FontWeight.bold,
                                      ),
                                ),
                                const SizedBox(height: 4),
                                Text(
                                  authProvider.userEmail ?? 'E-posta bilgisi yok',
                                  style: Theme.of(context).textTheme.bodyMedium,
                                ),
                              ],
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 16),
                      if (!authProvider.isAuthenticated)
                        SizedBox(
                          width: double.infinity,
                          child: ElevatedButton.icon(
                            onPressed: () {
                              Navigator.pushReplacementNamed(context, '/login');
                            },
                            icon: const Icon(Icons.login),
                            label: const Text('Giriş Yap / Kayıt Ol'),
                            style: ElevatedButton.styleFrom(
                              backgroundColor: Theme.of(context).colorScheme.primary,
                              foregroundColor: Theme.of(context).colorScheme.onPrimary,
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

              Text(
                'İstatistiklerim',
                style: Theme.of(context).textTheme.titleLarge?.copyWith(
                      fontWeight: FontWeight.bold,
                    ),
              ),
              const SizedBox(height: 16),

              GridView.count(
                crossAxisCount: 2,
                shrinkWrap: true,
                physics: const NeverScrollableScrollPhysics(),
                mainAxisSpacing: 16,
                crossAxisSpacing: 16,
                childAspectRatio: 1.2,
                children: [
                  _buildStatCard(context, 'Toplam Yolculuk', totalTrips.toString(), Icons.directions_car_filled),
                  _buildStatCard(context, 'Araç Sayısı', totalVehicles.toString(), Icons.no_crash),
                  _buildStatCard(context, 'Toplam Mesafe', '${totalDistance.toStringAsFixed(1)} km', Icons.route),
                  _buildStatCard(context, 'Toplam Süre', '${(totalDurationMinutes / 60).toStringAsFixed(1)} saat', Icons.timer),
                  _buildStatCard(context, 'Toplam Yakıt Maliyeti', '${totalFuelCost.toStringAsFixed(2)} ₺', Icons.local_gas_station),
                  _buildStatCard(
                      context,
                      'Favori Araç',
                      mostUsedVehicle != null
                          ? '${mostUsedVehicle.marka} ${mostUsedVehicle.model}'
                          : '-',
                      Icons.star_rounded),
                  _buildStatCard(context, 'Ort. Yolculuk Mesafesi', '${averageTripDistance.toStringAsFixed(1)} km', Icons.straighten_rounded),
                  _buildStatCard(context, 'Ort. Yolculuk Süresi', '${(averageTripDurationMinutes).toStringAsFixed(0)} dk', Icons.timelapse_rounded),
                ],
              ),
              const SizedBox(height: 24),

              Text(
                'Son Yolculuklarım',
                style: Theme.of(context).textTheme.titleLarge?.copyWith(
                      fontWeight: FontWeight.bold,
                    ),
              ),
              const SizedBox(height: 16),

              if (completedRoutes.isEmpty)
                Card(
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                  child: Padding(
                    padding: const EdgeInsets.all(16.0),
                    child: Center(
                      child: Text('Henüz tamamlanmış yolculuk bulunmuyor.', style: Theme.of(context).textTheme.bodyLarge),
                    ),
                  ),
                )
              else
                ListView.builder(
                  shrinkWrap: true,
                  physics: const NeverScrollableScrollPhysics(),
                  itemCount: completedRoutes.length > 3 ? 3 : completedRoutes.length,
                  itemBuilder: (context, index) {
                    final route = completedRoutes[index]; // RouteProvider'da başa eklediğimiz için zaten en yeni başta
                    return _buildCompletedRouteItem(context, route);
                  },
                ),

              if (completedRoutes.length > 3)
                Padding(
                  padding: const EdgeInsets.only(top: 16.0),
                  child: Center(
                    child: TextButton.icon(
                      onPressed: () {
                        // TODO: Tüm yolculukları gösteren bir sayfaya yönlendir
                        ScaffoldMessenger.of(context).showSnackBar(
                          const SnackBar(content: Text('Tüm yolculuklar sayfası yakında...')),
                        );
                      },
                      icon: const Icon(Icons.read_more),
                      label: const Text('Tüm Yolculukları Gör'),
                    ),
                  ),
                ),
              const SizedBox(height: 24),
              if (authProvider.isAuthenticated)
                SizedBox(
                  width: double.infinity,
                  child: ElevatedButton.icon(
                    onPressed: () async {
                      final bool? confirmLogout = await showDialog<bool>(
                        context: context,
                        builder: (BuildContext context) {
                          return AlertDialog(
                            title: const Text('Çıkış Yap'),
                            content: const Text('Çıkış yapmak istediğinizden emin misiniz?'),
                            actions: <Widget>[
                              TextButton(
                                child: const Text('İptal'),
                                onPressed: () {
                                  Navigator.of(context).pop(false);
                                },
                              ),
                              TextButton(
                                child: const Text('Çıkış Yap'),
                                onPressed: () {
                                  Navigator.of(context).pop(true);
                                },
                              ),
                            ],
                          );
                        },
                      );

                      if (confirmLogout == true && context.mounted) {
                        await authProvider.signOut();
                        Navigator.pushNamedAndRemoveUntil(context, '/login', (Route<dynamic> route) => false);
                      }
                    },
                    icon: const Icon(Icons.logout),
                    label: const Text('Çıkış Yap'),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: isDark ? Colors.red.shade800 : Colors.red.shade600,
                      foregroundColor: Colors.white,
                      padding: const EdgeInsets.symmetric(vertical: 12),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(8),
                      ),
                    ),
                  ),
                ),
              const SizedBox(height: 20),
            ],
          ),
        ),
      ),
    );
  }
}