import 'package:flutter/material.dart';
import 'package:decanat_progect/constants.dart';
import '../widgets/victory_banner.dart';
import '../widgets/info_card.dart';
import '../widgets/bubble_button.dart';
import 'department_detail_screen.dart';
import 'webview_screen.dart'; // Добавьте этот импорт

class HomeScreen extends StatelessWidget {
  const HomeScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        title: const Text(
          'Кафедра ПМИИ',
          style: TextStyle(
            color: Colors.white,
            fontWeight: FontWeight.bold,
            fontSize: 22,
          ),
        ),
        backgroundColor: AppColors.primary,
        centerTitle: true,
        elevation: 0,
        iconTheme: const IconThemeData(color: Colors.white),
      ),
      body: SingleChildScrollView(
        child: Column(
          children: [
            const VictoryBanner(),

            Padding(
              padding: const EdgeInsets.all(20.0),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  _buildWelcomeCard(),
                  const SizedBox(height: 24),

                  // КРАСИВЫЙ РАЗДЕЛИТЕЛЬ вместо заголовка
                  _buildDivider(),
                  const SizedBox(height: 24),

                  // КНОПКИ БЕЗ ЗАГОЛОВКА
                  _buildBubbleButtonsGrid(context),

                  const SizedBox(height: 32),
                  _buildInfoCard(),
                  const SizedBox(height: 28),
                  _buildSectionTitle('Новости университета'),
                  const SizedBox(height: 16),
                  _buildNewsItem(
                    'День открытых дверей',
                    '25 января 2025',
                    Icons.calendar_today,
                    AppColors.primary,
                  ),
                  const SizedBox(height: 12),
                  _buildNewsItem(
                    'Научная конференция',
                    '15 февраля 2025',
                    Icons.science,
                    Colors.blue[700]!,
                  ),
                  const SizedBox(height: 12),
                  _buildNewsItem(
                    'Спортивные соревнования',
                    '8 марта 2025',
                    Icons.sports,
                    Colors.green[700]!,
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildDivider() {
    return Row(
      children: [
        Expanded(
          child: Container(
            height: 1,
            decoration: BoxDecoration(
              gradient: LinearGradient(
                colors: [
                  Colors.transparent,
                  AppColors.primary.withOpacity(0.3),
                  Colors.transparent,
                ],
              ),
            ),
          ),
        ),
        Container(
          margin: const EdgeInsets.symmetric(horizontal: 12),
          width: 8,
          height: 8,
          decoration: BoxDecoration(
            color: AppColors.primary,
            shape: BoxShape.circle,
          ),
        ),
        Expanded(
          child: Container(
            height: 1,
            decoration: BoxDecoration(
              gradient: LinearGradient(
                colors: [
                  Colors.transparent,
                  AppColors.primary.withOpacity(0.3),
                  Colors.transparent,
                ],
              ),
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildBubbleButtonsGrid(BuildContext context) {
    return GridView.count(
      crossAxisCount: 2,
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      crossAxisSpacing: 16,
      mainAxisSpacing: 16,
      childAspectRatio: 1.0,
      children: [
        BubbleButton(
          title: 'Расписание',
          icon: Icons.schedule,
          primaryColor: AppColors.primary,
          onTap: () {
            Navigator.pushNamed(context, '/schedule');
          },
        ),
        BubbleButton(
          title: 'Факультет',
          icon: Icons.account_balance,
          primaryColor: Colors.blue[700]!,
          onTap: () {
            Navigator.pushNamed(context, '/faculty');
          },
        ),
        BubbleButton(
          title: 'Кафедра',
          icon: Icons.people,
          primaryColor: Colors.green[700]!,
          onTap: () {
            Navigator.push(
              context,
              MaterialPageRoute(builder: (context) => const DepartmentDetailScreen()),
            );
          },
        ),
        BubbleButton(
          title: 'Для поступающих',
          icon: Icons.school,
          primaryColor: Colors.orange[700]!,
          onTap: () {
            Navigator.push(
              context,
              MaterialPageRoute(
                builder: (context) => WebViewScreen(
                  url: 'https://donntu.ru/portal-abiturientov',
                  title: 'Портал абитуриентов',
                ),
              ),
            );
          },
        ),
      ],
    );
  }

  // Остальные методы без изменений
  Widget _buildWelcomeCard() {
    return Card(
      elevation: 3,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(16),
      ),
      child: Container(
        padding: const EdgeInsets.all(24),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(
            color: Colors.grey[200]!,
            width: 1,
          ),
        ),
        child: Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(
                Icons.school,
                size: 40,
                color: AppColors.primary,
              ),
              const SizedBox(height: 16),
              const Text(
                'Добро пожаловать в ДонНТУ!',
                style: TextStyle(
                  color: AppColors.textDark,
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                ),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 8),
              Text(
                'Кафедра прикладной математики и искусственного интеллекта',
                style: TextStyle(
                  color: AppColors.textLight,
                  fontSize: 15,
                ),
                textAlign: TextAlign.center,
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildInfoCard() {
    return Card(
      elevation: 2,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(14),
      ),
      child: Container(
        padding: const EdgeInsets.all(20),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(14),
          border: Border.all(
            color: Colors.grey[200]!,
            width: 1,
          ),
        ),
        child: Column(
          children: [
            Icon(
              Icons.info_outline,
              size: 32,
              color: AppColors.primary,
            ),
            const SizedBox(height: 12),
            Text(
              'НИЖНЯЯ НЕДЕЛЯ (№0)',
              style: TextStyle(
                fontSize: 14,
                color: AppColors.textDark,
                fontWeight: FontWeight.w600,
              ),
            ),
            const SizedBox(height: 12),
            Text(
              'Чтобы показать расписание, необходимо выбрать свою группу',
              style: TextStyle(
                fontSize: 13,
                color: AppColors.textLight,
              ),
              textAlign: TextAlign.center,
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildSectionTitle(String title) {
    return Padding(
      padding: const EdgeInsets.only(left: 4.0),
      child: Text(
        title,
        style: const TextStyle(
          fontSize: 18,
          fontWeight: FontWeight.bold,
          color: AppColors.textDark,
          letterSpacing: -0.5,
        ),
      ),
    );
  }

  Widget _buildNewsItem(String title, String date, IconData icon, Color color) {
    return Card(
      elevation: 1,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(10),
      ),
      child: ListTile(
        leading: Container(
          width: 42,
          height: 42,
          decoration: BoxDecoration(
            color: color.withOpacity(0.08),
            shape: BoxShape.circle,
          ),
          child: Icon(
            icon,
            color: color,
            size: 20,
          ),
        ),
        title: Text(
          title,
          style: const TextStyle(
            fontWeight: FontWeight.w600,
            fontSize: 14,
            color: AppColors.textDark,
          ),
        ),
        subtitle: Text(
          date,
          style: TextStyle(
            color: AppColors.textLight,
            fontSize: 12,
          ),
        ),
        trailing: Icon(
          Icons.arrow_forward_ios,
          size: 16,
          color: AppColors.textLight,
        ),
        onTap: () {},
        contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      ),
    );
  }
}