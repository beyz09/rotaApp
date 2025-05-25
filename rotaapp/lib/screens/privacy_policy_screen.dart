import 'package:flutter/material.dart';

class PrivacyPolicyScreen extends StatelessWidget {
  const PrivacyPolicyScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Gizlilik Politikası'),
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Gizlilik Politikası',
              style: Theme.of(context).textTheme.headlineMedium,
            ),
            const SizedBox(height: 16),
            Text(
              'Son Güncelleme: 1 Mart 2024',
              style: Theme.of(context).textTheme.bodyMedium,
            ),
            const SizedBox(height: 24),
            _buildSection(
              context,
              '1. Toplanan Bilgiler',
              'Uygulamamız, size daha iyi hizmet sunabilmek için aşağıdaki bilgileri toplar:\n\n'
                  '• Araç bilgileri (marka, model, plaka, yakıt tüketimi)\n'
                  '• Rota bilgileri\n'
                  '• Konum bilgileri (sadece rota oluştururken)\n'
                  '• Kullanıcı tercihleri ve ayarlar',
            ),
            _buildSection(
              context,
              '2. Bilgilerin Kullanımı',
              'Topladığımız bilgiler şu amaçlarla kullanılır:\n\n'
                  '• Rota hesaplamaları ve optimizasyonu\n'
                  '• Yakıt tüketimi analizi\n'
                  '• Kişiselleştirilmiş öneriler\n'
                  '• Uygulama performansının iyileştirilmesi',
            ),
            _buildSection(
              context,
              '3. Bilgi Güvenliği',
              'Verilerinizin güvenliği bizim için önemlidir. Bu nedenle:\n\n'
                  '• Tüm veriler şifrelenerek saklanır\n'
                  '• Düzenli güvenlik güncellemeleri yapılır\n'
                  '• Üçüncü taraflarla veri paylaşımı yapılmaz',
            ),
            _buildSection(
              context,
              '4. Kullanıcı Hakları',
              'Kullanıcılarımız:\n\n'
                  '• Verilerini görüntüleme\n'
                  '• Verilerini düzeltme\n'
                  '• Verilerini silme\n'
                  '• Veri toplamayı reddetme\n'
                  'haklarına sahiptir.',
            ),
            _buildSection(
              context,
              '5. İletişim',
              'Gizlilik politikamız hakkında sorularınız için:\n\n'
                  'E-posta: beyzanurbagi@gmail.com\n'
                  'Telefon: +90 (212) XXX XX XX',
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildSection(BuildContext context, String title, String content) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 24.0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            title,
            style: Theme.of(context).textTheme.titleLarge?.copyWith(
                  fontWeight: FontWeight.bold,
                ),
          ),
          const SizedBox(height: 8),
          Text(
            content,
            style: Theme.of(context).textTheme.bodyLarge,
          ),
        ],
      ),
    );
  }
}
