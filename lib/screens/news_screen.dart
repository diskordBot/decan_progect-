import 'package:flutter/material.dart';
import '../constants.dart';

class NewsScreen extends StatelessWidget {
  const NewsScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text(
          'Новости ДонНТУ',
          style: TextStyle(fontSize: 24, fontWeight: FontWeight.bold),
        ),
        backgroundColor: AppColors.primary,
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _buildNewsItem(
              'Команда Hyper-KCT ДонНТУ – победитель Кубка России по продуктовому программированию',
              '01.07.2025',
            ),
            _buildNewsItem(
              'В ДонНТУ прошла XXI Международная научно-техническая конференция',
              '15.06.2025',
            ),
            // Добавьте больше новостей по мере необходимости
          ],
        ),
      ),
    );
  }

  Widget _buildNewsItem(String title, String date) {
    return Card(
      margin: const EdgeInsets.only(bottom: 16),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              title,
              style: const TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              date,
              style: TextStyle(
                fontSize: 14,
                color: AppColors.gray,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
