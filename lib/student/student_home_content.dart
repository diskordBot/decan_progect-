import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:decanat_progect/widgets/bubble_button.dart';
import 'package:decanat_progect/screens/department_detail_screen.dart';
import 'package:decanat_progect/screens/webview_screen.dart';
import 'package:decanat_progect/student/student_auth_screen.dart'; // новый импорт

class StudentHomeContent extends StatefulWidget {
  const StudentHomeContent({super.key});

  @override
  _StudentHomeContentState createState() => _StudentHomeContentState();
}

class _StudentHomeContentState extends State<StudentHomeContent> {
  String _userRole = 'user';

  @override
  void initState() {
    super.initState();
    _loadUserRole();
  }

  Future<void> _loadUserRole() async {
    final prefs = await SharedPreferences.getInstance();
    setState(() {
      _userRole = prefs.getString('userRole') ?? 'user';
    });
  }

  Widget _buildStudentContent() {
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
          primaryColor: Colors.blue[700]!,
          onTap: () => Navigator.pushNamed(context, '/schedule'),
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

  Widget _buildAuthButtons() {
    return Column(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        Icon(
          Icons.school,
          size: 64,
          color: Colors.grey[400],
        ),
        const SizedBox(height: 20),
        Text(
          'Доступ только для студентов',
          style: TextStyle(
            fontSize: 18,
            fontWeight: FontWeight.bold,
            color: Colors.grey[600],
          ),
          textAlign: TextAlign.center,
        ),
        const SizedBox(height: 10),
        Text(
          'Войдите или зарегистрируйтесь,\nчтобы получить доступ к функции студента',
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
                  builder: (context) => StudentAuthScreen(isLogin: true),
                ),
              ).then((success) {
                if (success == true) {
                  // Обновляем роль после успешной авторизации
                  _loadUserRole();
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
                  builder: (context) => StudentAuthScreen(isLogin: false),
                ),
              ).then((success) {
                if (success == true) {
                  // Обновляем роль после успешной регистрации
                  _loadUserRole();
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

  @override
  Widget build(BuildContext context) {
    // Если роль пользователя - student, admin или developer, показываем студенческий контент
    // Если роль user - показываем кнопки авторизации
    if (_userRole == 'student' || _userRole == 'admin' || _userRole == 'developer') {
      return _buildStudentContent();
    } else {
      return Padding(
        padding: const EdgeInsets.all(20.0),
        child: _buildAuthButtons(),
      );
    }
  }
}