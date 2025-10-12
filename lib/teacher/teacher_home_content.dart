
import 'package:decanat_progect/teacher/teacher_schedule_screen.dart';
import 'package:flutter/material.dart';
import 'package:decanat_progect/widgets/bubble_button.dart';
import 'package:decanat_progect/screens/department_detail_screen.dart';
import 'package:decanat_progect/screens/webview_screen.dart';
import 'package:decanat_progect/teacher/teacher_auth_screen.dart';
import 'package:shared_preferences/shared_preferences.dart'; // добавим импорт

class TeacherHomeContent extends StatefulWidget {
  final String userRole;
  final String? userId;
  final VoidCallback onRoleChanged;

  const TeacherHomeContent({
    super.key,
    required this.userRole,
    this.userId,
    required this.onRoleChanged,
  });

  @override
  State<TeacherHomeContent> createState() => _TeacherHomeContentState();
}

class _TeacherHomeContentState extends State<TeacherHomeContent> {
  String _currentUserRole = 'user';

  @override
  void initState() {
    super.initState();
    _loadUserRole();
  }

  Future<void> _loadUserRole() async {
    final prefs = await SharedPreferences.getInstance();
    setState(() {
      _currentUserRole = prefs.getString('userRole') ?? 'user';
    });
  }

  Widget _buildTeacherContent() {
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
          icon: Icons.backup_table,
          primaryColor: Colors.blue[700]!,
          onTap: () => Navigator.push(
            context,
            MaterialPageRoute(builder: (context) => const TeacherScheduleScreen()),
          ),
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
            MaterialPageRoute(builder: (context) => const DepartmentDetailScreen()),
          ),
        ),
      ],
    );
  }

  Widget _buildAuthButtons() {
    return Column(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        Icon(
          Icons.person,
          size: 64,
          color: Colors.grey[400],
        ),
        const SizedBox(height: 20),
        Text(
          'Доступ только для преподавателей',
          style: TextStyle(
            fontSize: 18,
            fontWeight: FontWeight.bold,
            color: Colors.grey[600],
          ),
          textAlign: TextAlign.center,
        ),
        const SizedBox(height: 10),
        Text(
          'Войдите или зарегистрируйтесь,\nчтобы получить доступ к функциям преподавателя',
          style: TextStyle(
            fontSize: 14,
            color: Colors.grey[500],
          ),
          textAlign: TextAlign.center,
        ),
        const SizedBox(height: 30),

        // Кнопка Войти
        SizedBox(
          width: double.infinity,
          child: ElevatedButton(
            onPressed: () {
              Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (context) => TeacherAuthScreen(isLogin: true),
                ),
              ).then((success) {
                if (success == true) {
                  // Обновляем роль после успешной авторизации
                  _loadUserRole();
                  widget.onRoleChanged();
                }
              });
            },
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.blue[700],
              foregroundColor: Colors.white,
              padding: const EdgeInsets.symmetric(vertical: 16),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(12),
              ),
            ),
            child: const Text(
              'Войти',
              style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
            ),
          ),
        ),
        const SizedBox(height: 16),

        // Кнопка Зарегистрироваться
        SizedBox(
          width: double.infinity,
          child: OutlinedButton(
            onPressed: () {
              Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (context) => TeacherAuthScreen(isLogin: false),
                ),
              ).then((success) {
                if (success == true) {
                  // Обновляем роль после успешной регистрации
                  _loadUserRole();
                  widget.onRoleChanged();
                }
              });
            },
            style: OutlinedButton.styleFrom(
              backgroundColor: Colors.green[50],
              foregroundColor: Colors.green[700],
              padding: const EdgeInsets.symmetric(vertical: 16),
              side: BorderSide(color: Colors.green[700]!),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(12),
              ),
            ),
            child: const Text(
              'Зарегистрироваться',
              style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildStudentContent() {
    return Container(
      padding: const EdgeInsets.all(20),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(
            Icons.school_outlined,
            size: 64,
            color: Colors.orange[400],
          ),
          const SizedBox(height: 16),
          const Text(
            'Студентам недоступен доступ',
            style: TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.bold,
            ),
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 12),
          const Text(
            'Функции преподавателя недоступны для студентов. '
                'Пожалуйста, используйте вкладку "Студент" для доступа к вашему функционалу.',
            textAlign: TextAlign.center,
            style: TextStyle(
              fontSize: 14,
              color: Colors.grey,
            ),
          ),
          const SizedBox(height: 24),
          ElevatedButton(
            onPressed: () {
              // TODO: Возможно добавить навигацию на студенческую вкладку
              print('Перейти к студенческому функционалу');
            },
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.orange[700],
              foregroundColor: Colors.white,
              padding: const EdgeInsets.symmetric(horizontal: 30, vertical: 12),
            ),
            child: const Text('Понятно'),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    // Если роль пользователя - teacher, admin или developer, показываем преподавательский контент
    // Если роль student - показываем сообщение о недоступности
    // Если роль user - показываем кнопки авторизации
    if (_currentUserRole == 'teacher' || _currentUserRole == 'admin' || _currentUserRole == 'developer') {
      return _buildTeacherContent();
    } else if (_currentUserRole == 'student') {
      return _buildStudentContent();
    } else {
      return Padding(
        padding: const EdgeInsets.all(20.0),
        child: _buildAuthButtons(),
      );
    }
  }
}