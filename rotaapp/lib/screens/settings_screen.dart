import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../providers/auth_provider.dart';

class SettingsScreen extends StatelessWidget {
  const SettingsScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final Color backgroundColor = Color(0xFFDCF0D8); // Figma'daki yeşil tonu
    final authProvider = Provider.of<AuthProvider>(context);

    return Scaffold(
      backgroundColor: backgroundColor,
      appBar: AppBar(
        title: const Text('Ayarlar'),
        backgroundColor: backgroundColor,
        elevation: 0,
      ),
      body: ListView(
        padding: const EdgeInsets.all(16.0),
        children: [
          // Hesap Ayarları
          const Text(
            'Hesap Ayarları',
            style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
          ),
          const SizedBox(height: 16),
          Card(
            child: ListTile(
              leading: const Icon(Icons.person),
              title: const Text('Profil Bilgileri'),
              trailing: const Icon(Icons.chevron_right),
              onTap: () {
                // Profil bilgileri sayfasına git
              },
            ),
          ),
          Card(
            child: ListTile(
              leading: const Icon(Icons.notifications),
              title: const Text('Bildirim Ayarları'),
              trailing: const Icon(Icons.chevron_right),
              onTap: () {
                // Bildirim ayarları sayfasına git
              },
            ),
          ),

          const SizedBox(height: 24),

          // Uygulama Ayarları
          const Text(
            'Uygulama Ayarları',
            style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
          ),
          const SizedBox(height: 16),
          Card(
            child: ListTile(
              leading: const Icon(Icons.language),
              title: const Text('Dil'),
              trailing: const Icon(Icons.chevron_right),
              onTap: () {
                // Dil ayarları sayfasına git
              },
            ),
          ),
          Card(
            child: ListTile(
              leading: const Icon(Icons.dark_mode),
              title: const Text('Tema'),
              trailing: const Icon(Icons.chevron_right),
              onTap: () {
                // Tema ayarları sayfasına git
              },
            ),
          ),

          const SizedBox(height: 24),

          // Oturum İşlemleri
          const Text(
            'Oturum',
            style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
          ),
          const SizedBox(height: 16),
          Card(
            child: ListTile(
              leading: const Icon(Icons.logout, color: Colors.red),
              title: const Text(
                'Çıkış Yap',
                style: TextStyle(color: Colors.red),
              ),
              onTap: () {
                // Çıkış yapma işlemi
                showDialog(
                  context: context,
                  builder:
                      (context) => AlertDialog(
                        title: const Text('Çıkış Yap'),
                        content: const Text(
                          'Çıkış yapmak istediğinize emin misiniz?',
                        ),
                        actions: [
                          TextButton(
                            onPressed: () => Navigator.pop(context),
                            child: const Text('İptal'),
                          ),
                          TextButton(
                            onPressed: () {
                              authProvider.logout();
                              Navigator.pop(context);
                            },
                            child: const Text(
                              'Çıkış Yap',
                              style: TextStyle(color: Colors.red),
                            ),
                          ),
                        ],
                      ),
                );
              },
            ),
          ),
        ],
      ),
    );
  }
}
