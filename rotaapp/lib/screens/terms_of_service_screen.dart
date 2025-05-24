import 'package:flutter/material.dart';

class TermsOfServiceScreen extends StatelessWidget {
  const TermsOfServiceScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Kullanım Koşulları'),
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Kullanım Koşulları',
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
              '1. Genel Hükümler',
              'RotaApp uygulamasını kullanarak aşağıdaki koşulları kabul etmiş sayılırsınız:\n\n'
                  '• Uygulamayı yasal amaçlar için kullanacağınızı\n'
                  '• Doğru ve güncel bilgiler sağlayacağınızı\n'
                  '• Hesap güvenliğinizi koruyacağınızı\n'
                  '• Başkalarının haklarına saygı göstereceğinizi',
            ),
            _buildSection(
              context,
              '2. Hizmet Kullanımı',
              'Uygulamamızı kullanırken:\n\n'
                  '• Trafik kurallarına uymanız\n'
                  '• Güvenli sürüş yapmanız\n'
                  '• Rota önerilerini dikkate almanız\n'
                  '• Yakıt tüketimi hesaplamalarını referans almanız\n'
                  'beklenmektedir.',
            ),
            _buildSection(
              context,
              '3. Sorumluluk Reddi',
              'RotaApp:\n\n'
                  '• Rota önerilerinin kesin doğruluğunu garanti etmez\n'
                  '• Trafik durumundaki değişikliklerden sorumlu değildir\n'
                  '• Yakıt tüketimi hesaplamalarının kesin doğruluğunu garanti etmez\n'
                  '• Kullanıcı hatalarından kaynaklanan sonuçlardan sorumlu değildir',
            ),
            _buildSection(
              context,
              '4. Hesap Güvenliği',
              'Hesabınızın güvenliği için:\n\n'
                  '• Güçlü şifre kullanın\n'
                  '• Şifrenizi kimseyle paylaşmayın\n'
                  '• Düzenli olarak şifrenizi değiştirin\n'
                  '• Şüpheli durumları bize bildirin',
            ),
            _buildSection(
              context,
              '5. Değişiklikler',
              'Bu koşullar zaman zaman güncellenebilir. Önemli değişiklikler olması durumunda size bildirim gönderilecektir.',
            ),
            _buildSection(
              context,
              '6. İletişim',
              'Kullanım koşullarımız hakkında sorularınız için:\n\n'
                  'E-posta: beyzanurbagi@gmail.com\n'
                  'Telefon: +90 (552) XXX XX XX',
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
