import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

// Provider importları
import '../providers/auth_provider.dart';
import '../providers/vehicle_provider.dart';
import '../providers/route_provider.dart';

// Model importları
import '../models/vehicle.dart'; // Bu import, vehicleProvider.vehicles.map((v) => v.cityConsumption) gibi erişimler için gerekli.
// import '../models/route_option.dart'; // Eğer CompletedRoute veya başka bir yerde kullanılmıyorsa kaldırılabilir. Şimdilik bırakıyorum.

// CompletedRoute sınıfı ya burada tanımlı olmalı ya da ayrı bir dosyadan import edilmeli.
// Bir önceki mesajda route_provider.dart içinde tanımlıydı. Eğer öyleyse,
// ve RouteProvider bu dosyadan import ediliyorsa, CompletedRoute'a erişim sağlanır.
// Eğer CompletedRoute ayrı bir dosyadaysa, o dosyayı import etmelisiniz.
// Şimdilik, CompletedRoute'un RouteProvider üzerinden erişilebilir olduğunu varsayıyorum
// veya route_provider.dart içinde tanımlı olduğunu (bir önceki mesajınızdaki gibi).

class ProfileScreen extends StatelessWidget {
  const ProfileScreen({super.key});

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

   Widget _buildCompletedRouteItem(BuildContext context, CompletedRoute route) {
     return Card(
        margin: const EdgeInsets.symmetric(vertical: 4.0),
        child: Padding(
          padding: const EdgeInsets.all(12.0),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                   Icon(Icons.route, size: 20, color: Theme.of(context).colorScheme.primary),
                   const SizedBox(width: 8),
                   Expanded(
                     child: Text(
                       '${route.startPoint} - ${route.endPoint}',
                       style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
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
                       Text('Mesafe', style: TextStyle(fontSize: 12, color: Colors.grey[600])),
                       Text('${route.distance.toStringAsFixed(1)} km', style: const TextStyle(fontSize: 14)),
                    ],
                  ),
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                       Text('Yakıt', style: TextStyle(fontSize: 12, color: Colors.grey[600])),
                       Text('${route.consumption.toStringAsFixed(1)} L', style: const TextStyle(fontSize: 14)),
                    ],
                  ),
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                       Text('Maliyet', style: TextStyle(fontSize: 12, color: Colors.grey[600])),
                       Text('${route.cost.toStringAsFixed(2)} ₺',
                           style: TextStyle(
                             fontSize: 14,
                             fontWeight: FontWeight.bold,
                             color: Theme.of(context).colorScheme.primary,
                           )
                       ),
                    ],
                  ),
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                       Text('Tarih', style: TextStyle(fontSize: 12, color: Colors.grey[600])),
                       Text('${route.completedAt.day}/${route.completedAt.month}/${route.completedAt.year}', style: const TextStyle(fontSize: 14)),
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
    const Color backgroundColor = Color(0xFFDCF0D8);

    final authProvider = Provider.of<AuthProvider>(context);
    final vehicleProvider = Provider.of<VehicleProvider>(context);
    final routeProvider = Provider.of<RouteProvider>(context);

    final totalTrips = routeProvider.completedRoutes.length;
    final totalVehicles = vehicleProvider.vehicles.length;

    // DÜZELTME: Nullable değerler için ?? 0.0 eklendi
    final double totalCityConsumptionSum = vehicleProvider.vehicles
        .map((v) => v.cityConsumption ?? 0.0) // Null ise 0.0 kullan
        .fold(0.0, (sum, consumption) => sum + consumption);
    final double totalHighwayConsumptionSum = vehicleProvider.vehicles
        .map((v) => v.highwayConsumption ?? 0.0) // Null ise 0.0 kullan
        .fold(0.0, (sum, consumption) => sum + consumption);

    final double averageCityConsumption = totalVehicles == 0 ? 0.0 : totalCityConsumptionSum / totalVehicles;
    final double averageHighwayConsumption = totalVehicles == 0 ? 0.0 : totalHighwayConsumptionSum / totalVehicles;

    final double simpleAverageConsumption = (averageCityConsumption + averageHighwayConsumption) / 2;


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
          Card(
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
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

          const Text(
            'İstatistikler',
            style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
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
            // Eğer cityConsumption ve highwayConsumption her zaman null ise,
            // simpleAverageConsumption da 0.0 olacaktır.
            // Bu durumda belki farklı bir metrik göstermek isteyebilirsiniz.
            // Şimdilik olduğu gibi bırakıyorum.
            totalVehicles > 0 && (averageCityConsumption > 0 || averageHighwayConsumption > 0)
              ? '${simpleAverageConsumption.toStringAsFixed(1)} L/100km'
              : 'Hesaplanamadı',
            Icons.local_gas_station,
            isFullWidth: true,
          ),

          const SizedBox(height: 24),

          const Text(
            'Son Yolculuklar',
            style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
          ),
          const SizedBox(height: 16),

          if (routeProvider.completedRoutes.isEmpty)
            Card(
               shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
               elevation: 2,
              child: const Padding(
                padding: EdgeInsets.all(16.0),
                child: Center(child: Text('Henüz yolculuk kaydı bulunmuyor')),
              ),
            )
          else
            ...routeProvider.completedRoutes.take(3).map(
                  (route) => _buildCompletedRouteItem(context, route),
                ).toList(),

           if (routeProvider.completedRoutes.length > 3)
             Padding(
               padding: const EdgeInsets.symmetric(vertical: 8.0),
               child: TextButton(
                 onPressed: () {
                    ScaffoldMessenger.of(context).showSnackBar(
                       const SnackBar(content: Text('Tüm yolculukları gör ekranına yönlendirilecek...')),
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