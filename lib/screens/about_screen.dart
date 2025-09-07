// about_screen.dart
import 'package:flutter/material.dart';
import '../widgets/custom_app_bar.dart';
import '../constants.dart';

class AboutScreen extends StatelessWidget {
  const AboutScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: const CustomAppBar(
          title: 'Об университете',
          showBackButton: false,),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'Об университете',
              style: TextStyle(
                fontSize: 24,
                fontWeight: FontWeight.bold,
                color: AppColors.primary,
              ),
            ),
            const SizedBox(height: 20),
            _buildInfoCard(
              'ДонНТУ – признанное в мире высшее учебное заведение, активно осуществляющее '
                  'научно-техническое сотрудничество с более чем 70 ведущими университетами '
                  'Российской Федерации.',
            ),
            const SizedBox(height: 20),
            _buildSectionTitle('История'),
            const SizedBox(height: 10),
            _buildInfoCard(
              'С момента основания старейший технический вуз Донбасса подготовил свыше '
                  '250 тысяч высококвалифицированных инженеров для всех отраслей промышленности '
                  'Донбасса и Российской Федерации.',
            ),
            const SizedBox(height: 20),
            _buildSectionTitle('Контакты'),
            const SizedBox(height: 10),
            _buildContactInfo(
              'Адрес главного корпуса:',
              'г. Донецк, ул. Артема, 58',
            ),
            _buildContactInfo(
              'Телефон:',
              '+7 (856) 301-03-60',
            ),
            _buildContactInfo(
              'Email:',
              'rector@donntu.ru',
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildSectionTitle(String title) {
    return Text(
      title,
      style: const TextStyle(
        fontSize: 20,
        fontWeight: FontWeight.bold,
        color: AppColors.textDark,
      ),
    );
  }

  Widget _buildInfoCard(String text) {
    return Card(
      elevation: 4,
      margin: const EdgeInsets.only(bottom: 16),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Text(
          text,
          style: const TextStyle(fontSize: 16),
        ),
      ),
    );
  }

  Widget _buildContactInfo(String label, String value) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 100,
            child: Text(
              label,
              style: const TextStyle(fontWeight: FontWeight.bold),
            ),
          ),
          Expanded(child: Text(value)),
        ],
      ),
    );
  }
}