//for_applicants_screen.dart
import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';
import '../constants.dart';

class ForApplicantsScreen extends StatelessWidget {
  const ForApplicantsScreen({super.key});

  Future<void> _launchUrl(BuildContext context, String urlString) async {
    final Uri url = Uri.parse(urlString);
    if (!await launchUrl(url)) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Не удалось открыть $url')),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Абитуриенту ДонНТУ'),
        backgroundColor: AppColors.primary, // Сапфировый цвет
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _buildTitle('Абитуриенту ДонНТУ'),
            const SizedBox(height: 20),
            _buildInfoCardWithIcon(
              Icons.contact_phone,
              'Телефон: +7 (856) 123-45-67\nEmail: prkom@donntu.ru\nАдрес: г. Донецк, ул. Артема, 58, каб. 101\nЧасы работы: Пн-Пт 9:00-17:00, обед 13:00-14:00',
            ),
            _buildClickableCard(
              context,
              'Электронная подача документов',
              'https://pkdist.donntu.ru/',
              Icons.cloud_upload,
            ),
            _buildDateItem('01.06.2025', 'Начало приема документов'),
            _buildEventCard('11 сентября 2025', 'Главный корпус, ауд. 101', 'Начало в 10:00', Icons.event),
          ],
        ),
      ),
    );
  }

  Widget _buildTitle(String title) {
    return Text(
      title,
      style: TextStyle(
        fontSize: 24,
        fontWeight: FontWeight.bold,
        color: AppColors.sapphire, // Сапфировый цвет для заголовков
      ),
    );
  }

  Widget _buildInfoCardWithIcon(IconData icon, String text) {
    return Card(
      elevation: 4,
      margin: const EdgeInsets.only(bottom: 16),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Row(
          children: [
            Icon(icon, size: 40, color: AppColors.sapphire),
            const SizedBox(width: 16),
            Expanded(child: Text(text, style: const TextStyle(fontSize: 16))),
          ],
        ),
      ),
    );
  }

  Widget _buildClickableCard(BuildContext context, String title, String url, IconData icon) {
    return Card(
      elevation: 4,
      margin: const EdgeInsets.only(bottom: 16),
      child: InkWell(
        onTap: () => _launchUrl(context, url),
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Row(
            children: [
              Icon(icon, size: 30, color: AppColors.sapphire),
              const SizedBox(width: 16),
              Expanded(child: Text(title, style: const TextStyle(fontSize: 16))),
              const Icon(Icons.chevron_right),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildDateItem(String date, String event) {
    return Card(
      elevation: 2,
      margin: const EdgeInsets.only(bottom: 8),
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Row(
          children: [
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
              decoration: BoxDecoration(
                color: AppColors.sapphire.withOpacity(0.2),
                borderRadius: BorderRadius.circular(8),
              ),
              child: Text(
                date,
                style: const TextStyle(
                  fontWeight: FontWeight.bold,
                  color: AppColors.sapphire,
                ),
              ),
            ),
            const SizedBox(width: 16),
            Expanded(child: Text(event, style: const TextStyle(fontSize: 16))),
          ],
        ),
      ),
    );
  }

  Widget _buildEventCard(String date, String location, String time, IconData icon) {
    return Card(
      elevation: 4,
      margin: const EdgeInsets.only(bottom: 16),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(icon, size: 30, color: AppColors.sapphire),
                const SizedBox(width: 10),
                Text(date, style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
              ],
            ),
            const SizedBox(height: 10),
            Text(location, style: const TextStyle(fontSize: 16)),
            const SizedBox(height: 5),
            Text(time, style: const TextStyle(fontSize: 16)),
          ],
        ),
      ),
    );
  }
}
