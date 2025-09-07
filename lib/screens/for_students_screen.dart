//for_students_screen.dart
import 'package:flutter/material.dart';
import '../widgets/custom_app_bar.dart';
import '../constants.dart';

class ForStudentsScreen extends StatelessWidget {
  const ForStudentsScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: const CustomAppBar(title: ''),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'Информация для студентов',
              style: TextStyle(
                fontSize: 24,
                fontWeight: FontWeight.bold,
                color: AppColors.primary,
              ),
            ),
            const SizedBox(height: 20),
            _buildSectionTitle('Расписание занятий'),
            const SizedBox(height: 10),
            _buildInfoCard('НИЖНЯЯ НЕДЕЛЯ (№0)'),
            const SizedBox(height: 20),
            _buildSectionTitle('Общежития'),
            const SizedBox(height: 10),
            _buildDormitoryInfo(
              'Общежитие №5',
              'г. Донецк, ул. Челюскинцев, 186а',
              '+7(856)336-46-11',
            ),
            _buildDormitoryInfo(
              'Общежитие №8',
              'г. Донецк, ул. Б. Хмельницкого, 100',
              '+7(856)336-60-90',
            ),
            _buildDormitoryInfo(
              'Общежитие №9',
              'г. Донецк, ул. Челюскинцев, 186а',
              '+7(856)336-46-48',
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

  Widget _buildDormitoryInfo(String name, String address, String phone) {
    return Card(
      margin: const EdgeInsets.only(bottom: 16),
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              name,
              style: const TextStyle(
                fontWeight: FontWeight.bold,
                fontSize: 16,
              ),
            ),
            const SizedBox(height: 8),
            Text(address),
            const SizedBox(height: 8),
            Text(phone),
          ],
        ),
      ),
    );
  }
}
