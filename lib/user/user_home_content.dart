// lib/user/user_home_content.dart
import 'package:flutter/material.dart';
import 'package:decanat_progect/widgets/bubble_button.dart';
import 'package:decanat_progect/screens/department_detail_screen.dart';
import 'package:decanat_progect/screens/webview_screen.dart';
import 'package:decanat_progect/utils/auth_hint_bus.dart';

class UserHomeContent extends StatelessWidget {
  const UserHomeContent({super.key});

  void _openProfileWithHint(BuildContext context) {
    // Открываем выдвижную панель профиля
    Scaffold.maybeOf(context)?.openDrawer();

    // Даем ей начать открываться и запускаем плавное мерцание (3 цикла)
    Future.delayed(const Duration(milliseconds: 220), () {
      AuthHintBus.instance.triggerSequence(
        cycles: 3,
        up: const Duration(milliseconds: 450),
        down: const Duration(milliseconds: 550),
        pause: const Duration(milliseconds: 120),
      );
    });
  }

  @override
  Widget build(BuildContext context) {
    return GridView.count(
      crossAxisCount: 2,
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      crossAxisSpacing: 16,
      mainAxisSpacing: 16,
      childAspectRatio: 1.0,
      children: [
        // ✅ Первая плитка — ровно как остальные (квадратная), красная
        BubbleButton(
          title: 'Зарегистрироваться',
          icon: Icons.app_registration_outlined,
          primaryColor: Colors.red[700]!,
          onTap: () => _openProfileWithHint(context),
        ),

        BubbleButton(
          title: 'Факультет',
          icon: Icons.account_balance,
          primaryColor: Colors.green[700]!,
          onTap: () => Navigator.pushNamed(context, '/faculty'),
        ),
        BubbleButton(
          title: 'Кафедра',
          icon: Icons.people,
          primaryColor: Colors.orange[700]!,
          onTap: () => Navigator.push(
            context,
            MaterialPageRoute(
              builder: (context) => const DepartmentDetailScreen(),
            ),
          ),
        ),
        BubbleButton(
          title: 'Для поступающих',
          icon: Icons.school,
          primaryColor: Colors.purple[700]!,
          onTap: () => Navigator.push(
            context,
            MaterialPageRoute(
              builder: (context) => WebViewScreen(
                url: 'https://donntu.ru/portal-abiturientov',
                title: 'Портал абитуриентов',
              ),
            ),
          ),
        ),
      ],
    );
  }
}
