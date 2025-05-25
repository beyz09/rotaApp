import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../providers/theme_provider.dart';
import '../providers/auth_provider.dart';

class SettingsScreen extends StatelessWidget {
  const SettingsScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final themeProvider = Provider.of<ThemeProvider>(context);
    final authProvider = Provider.of<AuthProvider>(context);
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return ListView(
      padding: const EdgeInsets.all(16.0),
      children: [
        // Görünüm Ayarları
        Card(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Padding(
                padding: const EdgeInsets.all(16.0),
                child: Text(
                  'Görünüm',
                  style: Theme.of(context).textTheme.titleLarge,
                ),
              ),
              SwitchListTile(
                title: const Text('Karanlık Mod'),
                subtitle: const Text('Uygulamayı karanlık temada kullan'),
                value: themeProvider.themeMode == ThemeMode.dark,
                onChanged: (value) {
                  themeProvider.toggleTheme();
                },
              ),
            ],
          ),
        ),
        const SizedBox(height: 16),

        // Bildirim Ayarları
        Card(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Padding(
                padding: const EdgeInsets.all(16.0),
                child: Text(
                  'Bildirimler',
                  style: Theme.of(context).textTheme.titleLarge,
                ),
              ),
              SwitchListTile(
                title: const Text('Yakıt Uyarıları'),
                subtitle:
                    const Text('Yakıt seviyesi düşük olduğunda bildirim al'),
                value: true, // TODO: Provider ile yönetilecek
                onChanged: (value) {
                  // TODO: Bildirim ayarları provider'ı eklenecek
                },
              ),
              SwitchListTile(
                title: const Text('Bakım Hatırlatıcıları'),
                subtitle: const Text('Bakım zamanı geldiğinde bildirim al'),
                value: true, // TODO: Provider ile yönetilecek
                onChanged: (value) {
                  // TODO: Bildirim ayarları provider'ı eklenecek
                },
              ),
            ],
          ),
        ),
        const SizedBox(height: 16),

        // Yakıt Fiyatı Takibi
        Card(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Padding(
                padding: const EdgeInsets.all(16.0),
                child: Text(
                  'Yakıt Fiyatı Takibi',
                  style: Theme.of(context).textTheme.titleLarge,
                ),
              ),
              ListTile(
                title: const Text('Yakıt Fiyatları'),
                subtitle: const Text('Güncel yakıt fiyatlarını görüntüle'),
                trailing: const Icon(Icons.local_gas_station),
                onTap: () {
                  // TODO: Yakıt fiyatları sayfasına yönlendir
                },
              ),
              ListTile(
                title: const Text('Fiyat Alarmları'),
                subtitle: const Text('Yakıt fiyatı düştüğünde bildirim al'),
                trailing: const Icon(Icons.notifications),
                onTap: () {
                  // TODO: Fiyat alarmları sayfasına yönlendir
                },
              ),
            ],
          ),
        ),
        const SizedBox(height: 16),

        // Veri Yönetimi
        Card(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Padding(
                padding: const EdgeInsets.all(16.0),
                child: Text(
                  'Veri Yönetimi',
                  style: Theme.of(context).textTheme.titleLarge,
                ),
              ),
              ListTile(
                title: const Text('Verileri Yedekle'),
                subtitle: const Text('Araç ve rota verilerinizi yedekleyin'),
                trailing: const Icon(Icons.backup),
                onTap: () {
                  // TODO: Yedekleme işlevi eklenecek
                },
              ),
              ListTile(
                title: const Text('Verileri Geri Yükle'),
                subtitle: const Text('Yedeklenen verileri geri yükleyin'),
                trailing: const Icon(Icons.restore),
                onTap: () {
                  // TODO: Geri yükleme işlevi eklenecek
                },
              ),
              ListTile(
                title: const Text('Verileri Temizle'),
                subtitle: const Text('Tüm verileri sil'),
                trailing: const Icon(Icons.delete_forever),
                onTap: () {
                  showDialog(
                    context: context,
                    builder: (context) => AlertDialog(
                      title: const Text('Verileri Temizle'),
                      content: const Text(
                          'Tüm verileriniz silinecek. Bu işlem geri alınamaz.'),
                      actions: [
                        TextButton(
                          onPressed: () => Navigator.pop(context),
                          child: const Text('İptal'),
                        ),
                        TextButton(
                          onPressed: () {
                            // TODO: Veri temizleme işlevi eklenecek
                            Navigator.pop(context);
                          },
                          child: const Text('Temizle'),
                        ),
                      ],
                    ),
                  );
                },
              ),
            ],
          ),
        ),
        const SizedBox(height: 16),

        // Uygulama Hakkında
        Card(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Padding(
                padding: const EdgeInsets.all(16.0),
                child: Text(
                  'Uygulama Hakkında',
                  style: Theme.of(context).textTheme.titleLarge,
                ),
              ),
              ListTile(
                title: const Text('Sürüm'),
                subtitle: const Text('1.0.0'),
                trailing: const Icon(Icons.info_outline),
              ),
              ListTile(
                title: const Text('Gizlilik Politikası'),
                trailing: const Icon(Icons.privacy_tip_outlined),
                onTap: () {
                  Navigator.pushNamed(context, '/privacy-policy');
                },
              ),
              ListTile(
                title: const Text('Kullanım Koşulları'),
                trailing: const Icon(Icons.description_outlined),
                onTap: () {
                  Navigator.pushNamed(context, '/terms-of-service');
                },
              ),
            ],
          ),
        ),
        const SizedBox(height: 16),

        // Çıkış Yap Butonu
        if (authProvider.isAuthenticated)
          ElevatedButton.icon(
            onPressed: () {
              authProvider.signOut();
              Navigator.pushReplacementNamed(context, '/login');
            },
            icon: const Icon(Icons.logout),
            label: const Text('Çıkış Yap'),
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.red,
              foregroundColor: Colors.white,
              padding: const EdgeInsets.symmetric(vertical: 16),
            ),
          ),
      ],
    );
  }
}
