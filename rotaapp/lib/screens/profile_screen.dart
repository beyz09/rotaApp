import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

// Provider importları
import '../providers/auth_provider.dart';
import '../providers/vehicle_provider.dart';
import '../providers/route_provider.dart';

// Model importları (CompletedRoute ve Vehicle modellerine buradan erişiliyor)
import '../models/vehicle.dart'; // Vehicle modelini import edin (Ortalama tüketim için)
import '../models/route_option.dart'; // CompletedRoute buradan türetilmiş veya ilgili

class ProfileScreen extends StatelessWidget {
  const ProfileScreen({super.key});

  // İstatistik kartlarını oluşturan yardımcı metod (Değişiklik Yok)
  Widget _buildStatCard(
    BuildContext context,
    String title,
    String value,
    IconData icon, {
    bool isFullWidth = false, // isFullWidth şu an kullanımda değil ama metotta bırakıldı
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

  // Son yolculuk öğelerini oluşturan yardımcı metod (Opsiyonel, ListTile yerine Card içinde Column da olabilir)
   Widget _buildCompletedRouteItem(BuildContext context, CompletedRoute route) {
     return Card( // ListTile yerine Card içinde düzenleyelim
        margin: const EdgeInsets.symmetric(vertical: 4.0), // Kartlar arasına boşluk
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
                       Text('${route.cost.toStringAsFixed(2)} ₺', // Maliyeti de gösteriyoruz
                           style: TextStyle(
                             fontSize: 14,
                             fontWeight: FontWeight.bold,
                             color: Theme.of(context).colorScheme.primary,
                           )
                       ),
                    ],
                  ),
                   // Tamamlanma zamanını da gösterebiliriz
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
    const Color backgroundColor = Color(0xFFDCF0D8); // Figma'daki yeşil tonu

    // Provider'ları dinleyerek gerekli verilere erişim
    final authProvider = Provider.of<AuthProvider>(context);
    final vehicleProvider = Provider.of<VehicleProvider>(context);
    final routeProvider = Provider.of<RouteProvider>(context);

    // İstatistikler
    // DEĞİŞİKLİK 1: routeProvider.routes yerine routeProvider.completedRoutes kullanıldı
    final totalTrips = routeProvider.completedRoutes.length;
    final totalVehicles = vehicleProvider.vehicles.length; // VehicleProvider'daki vehicles listesi doğru

    // Ortalama tüketim hesaplama
    final double totalCityConsumptionSum = vehicleProvider.vehicles
        .map((v) => v.cityConsumption)
        .fold(0.0, (sum, consumption) => sum + consumption);
    final double totalHighwayConsumptionSum = vehicleProvider.vehicles
        .map((v) => v.highwayConsumption)
        .fold(0.0, (sum, consumption) => sum + consumption);

    final double averageCityConsumption = totalVehicles == 0 ? 0.0 : totalCityConsumptionSum / totalVehicles;
    final double averageHighwayConsumption = totalVehicles == 0 ? 0.0 : totalHighwayConsumptionSum / totalVehicles;

    // Ortalama olarak şehir içi ve şehir dışının ortalamasını alabiliriz veya sadece şehir içini gösterebiliriz
    // Şimdilik iki ortalamayı da hesapladık, sadece birini gösterebilirsiniz veya ikisini birden.
    // İstatistik kartında tek bir ortalama göstereceksek, basitleştirilmiş bir ortalama (örn: ikisinin ortalaması) kullanabiliriz.
    final double simpleAverageConsumption = (averageCityConsumption + averageHighwayConsumption) / 2;


    return Scaffold(
      backgroundColor: backgroundColor,
      appBar: AppBar(
        title: const Text('Profil'),
        backgroundColor: backgroundColor,
        elevation: 0,
        // İsteğe bağlı: AppBar'a logo ekleyebilirsiniz
        // actions: [
        //   Padding(
        //     padding: const EdgeInsets.all(8.0),
        //     child: Image.asset(
        //        'assets/images/app_logo.png', // Uygulama içi kullanacağınız logo yolunu yazın
        //         height: 30, // Boyutunu ayarlayın
        //     ),
        //   ),
        // ],
      ),
      body: ListView(
        padding: const EdgeInsets.all(16.0),
        children: [
          // Kullanıcı Bilgileri Kartı (Değişiklik Yok)
          Card(
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)), // Köşeleri yuvarlak yap
            elevation: 2,
            child: Padding(
              padding: const EdgeInsets.all(16.0),
              child: Column(
                children: [
                  const CircleAvatar(
                    radius: 40,
                    backgroundColor: Colors.grey, // Avatar arkaplan rengi
                    child: Icon(Icons.person, size: 40, color: Colors.white), // İkon rengi
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
                  // İsteğe bağlı: Profili Düzenle butonu eklenebilir
                ],
              ),
            ),
          ),

          const SizedBox(height: 24),

          // İstatistikler Başlığı (Değişiklik Yok)
          const Text(
            'İstatistikler',
            style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
          ),
          const SizedBox(height: 16),

          // İstatistik Kartları (Değişiklik Yok, sadece ortalama tüketim hesaplaması güncellendi)
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
          // Ortalama tüketimi basit ortalama olarak gösterelim
          _buildStatCard(
            context,
            'Ortalama Tüketim',
            '${simpleAverageConsumption.toStringAsFixed(1)} L/100km', // Basit ortalama kullanıldı
            Icons.local_gas_station,
            isFullWidth: true, // Bu kartın tam genişlik olması için
          ),
           // Eğer isterseniz şehir içi ve şehir dışı ortalamalarını ayrı kartlarda gösterebilirsiniz

          const SizedBox(height: 24),

          // Son Yolculuklar Başlığı (Değişiklik Yok)
          const Text(
            'Son Yolculuklar',
            style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
          ),
          const SizedBox(height: 16),

          // Son Yolculuklar Listesi
          // DEĞİŞİKLİK 2: routeProvider.routes yerine routeProvider.completedRoutes kullanıldı
          // ve liste öğeleri _buildCompletedRouteItem yardımcı metodu ile oluşturuldu.
          if (routeProvider.completedRoutes.isEmpty) // Listenin boş olup olmadığını kontrol et
            Card(
               shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)), // Köşeleri yuvarlak yap
               elevation: 2,
              child: const Padding(
                padding: EdgeInsets.all(16.0),
                child: Center(child: Text('Henüz yolculuk kaydı bulunmuyor')),
              ),
            )
          else
            // İlk 3 yolculuğu göster
            ...routeProvider.completedRoutes.take(3).map(
                  (route) => _buildCompletedRouteItem(context, route), // Yardımcı metodu kullan
                ).toList(), // Map sonucunu Listeye çeviriyoruz

           // İsteğe bağlı: Tüm yolculukları gör butonu
           if (routeProvider.completedRoutes.length > 3) // 3'ten fazla yolculuk varsa
             Padding(
               padding: const EdgeInsets.symmetric(vertical: 8.0),
               child: TextButton(
                 onPressed: () {
                   // Tüm yolculukları gösteren başka bir ekrana yönlendirme yapılabilir.
                   // Navigator.pushNamed(context, '/completedRoutes');
                    ScaffoldMessenger.of(context).showSnackBar( // Geçici SnackBar
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