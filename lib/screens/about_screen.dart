import 'package:flutter/material.dart';
import '../widgets/custom_app_bar.dart';
import '../constants.dart';
import 'package:url_launcher/url_launcher.dart';

class AboutScreen extends StatelessWidget {
  const AboutScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Theme.of(context).colorScheme.background,
      appBar: const CustomAppBar(
        title: 'О Факультете',
        showBackButton: false,
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const SizedBox(height: 20),
            _buildInfoCard(
              context,
              'Факультет интеллектуальных систем и программирования — ведущий центр региона '
                  'по подготовке специалистов в области компьютерных наук, искусственного интеллекта и программирования.',
            ),
            const SizedBox(height: 20),
            _buildSectionTitle(context, 'Выпускники'),
            const SizedBox(height: 10),
            _buildInfoCard(
              context,
              'Наши выпускники востребованы в России и за рубежом, успешно работают в международных '
                  'компаниях и IT-корпорациях.',
            ),
            const SizedBox(height: 20),
            _buildSectionTitle(context, 'Аккредитация'),
            const SizedBox(height: 10),
            _buildInfoCard(
              context,
              'Все направления аккредитованы в Российской Федерации, выпускники получают российские дипломы, '
                  'соответствующие современным требованиям рынка труда.',
            ),
            const SizedBox(height: 20),
            _buildSectionTitle(context, 'Перспективы'),
            const SizedBox(height: 10),
            _buildInfoCard(
              context,
              'Факультет предлагает качественное образование по наиболее перспективным и востребованным '
                  'IT-специальностям, открывая широкие возможности для успешной карьеры и профессионального роста.',
            ),
            const SizedBox(height: 30),
            _buildSectionTitle(context, 'Контакты'),
            const SizedBox(height: 10),
            _buildContactItem(
              context,
              icon: Icons.location_on,
              iconColor: Colors.red,
              label: 'Адрес',
              value: 'ДНР, г. Донецк, ул. Артема, 58, 4-й корпус',
            ),
            _buildContactItem(
              context,
              icon: Icons.phone,
              iconColor: Colors.green,
              label: 'Телефон',
              value: '+7 (856) 301-08-04',
              onTap: () => _launchUrl("tel:+78563010804"),
            ),
            _buildContactItem(
              context,
              icon: Icons.email,
              iconColor: Colors.blue,
              label: 'E-mail',
              value: 'fisp@donntu.ru',
              onTap: () => _launchUrl("mailto:fisp@donntu.ru"),
            ),
            _buildContactItem(
              context,
              icon: Icons.public,
              iconColor: Colors.purple,
              label: 'Сайт',
              value: 'fisp.iknt.donntu.ru',
              onTap: () => _launchUrl("http://fisp.iknt.donntu.ru/"),
            ),
            const SizedBox(height: 30),
          ],
        ),
      ),
    );
  }

  Widget _buildSectionTitle(BuildContext context, String title) {
    return Text(
      title,
      style: TextStyle(
        fontSize: 20,
        fontWeight: FontWeight.bold,
        color: Theme.of(context).colorScheme.onBackground,
      ),
    );
  }

  Widget _buildInfoCard(BuildContext context, String text) {
    return Card(
      elevation: 4,
      margin: const EdgeInsets.only(bottom: 16),
      color: Theme.of(context).cardColor,
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Text(
          text,
          style: TextStyle(
            fontSize: 16,
            color: Theme.of(context).colorScheme.onBackground,
          ),
        ),
      ),
    );
  }

  Widget _buildContactItem(
      BuildContext context, {
        required IconData icon,
        required Color iconColor,
        required String label,
        required String value,
        VoidCallback? onTap,
      }) {
    return Card(
      elevation: 2,
      margin: const EdgeInsets.symmetric(vertical: 6),
      child: ListTile(
        leading: Icon(icon, color: iconColor, size: 28),
        title: Text(
          label,
          style: const TextStyle(fontWeight: FontWeight.bold),
        ),
        subtitle: Text(value),
        onTap: onTap,
      ),
    );
  }

  void _launchUrl(String url) async {
    final Uri uri = Uri.parse(url);
    if (await canLaunchUrl(uri)) {
      await launchUrl(uri, mode: LaunchMode.externalApplication);
    }
  }
}
