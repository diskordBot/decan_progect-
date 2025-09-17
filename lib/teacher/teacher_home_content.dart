import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:decanat_progect/providers/auth_provider.dart';
import 'teacher_login_screen.dart';
import 'package:decanat_progect/screens/department_detail_screen.dart';

class TeacherHomeContent extends StatelessWidget {
  const TeacherHomeContent({super.key});

  @override
  Widget build(BuildContext context) {
    return Consumer<AuthProvider>(
      builder: (context, authProvider, child) {
        if (!authProvider.isAuthenticated || !authProvider.isTeacher) {
          return Center(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                const Text(
                  'Доступ только для преподавателей',
                  style: TextStyle(
                    fontSize: 20,
                    fontWeight: FontWeight.bold,
                    color: Colors.white,
                  ),
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: 8),
                const Text(
                  'Войдите или зарегистрируйтесь, чтобы получить\n доступ к функции преподавателя',
                  style: TextStyle(
                    fontSize: 14,
                    color: Colors.grey,
                    height: 1.4,
                  ),
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: 24),
                // Кнопки без иконок
                _buildSimpleButton(
                  title: 'Войти',
                  color: Colors.green[700]!,
                  onTap: () {
                    Navigator.push(
                      context,
                      MaterialPageRoute(builder: (context) => const TeacherLoginScreen()),
                    );
                  },
                ),
                const SizedBox(height: 16),
                _buildSimpleButton(
                  title: 'Зарегистрироваться',
                  color: Colors.purple[700]!,
                  onTap: () {
                    Navigator.push(
                      context,
                      MaterialPageRoute(builder: (context) => const TeacherLoginScreen()),
                    );
                  },
                ),
              ],
            ),
          );
        }

        return Column(
          children: [
            Padding(
              padding: const EdgeInsets.all(16.0),
              child: Text(
                'Добро пожаловать, ${authProvider.currentUser!.fullName}!',
                style: TextStyle(
                  fontSize: 18,
                  color: authProvider.currentUser!.roleColor,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ),
            Expanded(
              child: GridView.count(
                crossAxisCount: 2,
                shrinkWrap: true,
                padding: const EdgeInsets.all(16),
                crossAxisSpacing: 16,
                mainAxisSpacing: 16,
                childAspectRatio: 1.0,
                children: [
                  _buildSimpleButton(
                    title: 'Расписание',
                    color: Colors.blue[700]!,
                    onTap: () => Navigator.pushNamed(context, '/schedule'),
                  ),
                  _buildSimpleButton(
                    title: 'Факультет',
                    color: Colors.green[700]!,
                    onTap: () => Navigator.pushNamed(context, '/faculty'),
                  ),
                  _buildSimpleButton(
                    title: 'Кафедра',
                    color: Colors.orange[700]!,
                    onTap: () => Navigator.push(
                      context,
                      MaterialPageRoute(builder: (context) => const DepartmentDetailScreen()),
                    ),
                  ),
                ],
              ),
            ),
          ],
        );
      },
    );
  }

  // Простая кнопка без иконки
  Widget _buildSimpleButton({
    required String title,
    required Color color,
    required VoidCallback onTap,
  }) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        decoration: BoxDecoration(
          color: color,
          borderRadius: BorderRadius.circular(20),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(0.3),
              blurRadius: 10,
              offset: const Offset(0, 5),
            ),
          ],
        ),
        child: Center(
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 20),
            child: Text(
              title,
              style: const TextStyle(
                color: Colors.white,
                fontSize: 16,
                fontWeight: FontWeight.bold,
              ),
              textAlign: TextAlign.center,
              maxLines: 2,
            ),
          ),
        ),
      ),
    );
  }
}