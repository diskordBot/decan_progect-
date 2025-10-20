import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:decanat_progect/widgets/bubble_button.dart';
import 'package:decanat_progect/screens/department_detail_screen.dart';
import 'package:decanat_progect/screens/webview_screen.dart';

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


  @override
  Widget build(BuildContext context) {
    // Если роль пользователя - student, admin или developer, показываем студенческий контент
    // Если роль user - показываем кнопки авторизации
    if (_userRole == 'student' || _userRole == 'admin' || _userRole == 'developer') {
      return _buildStudentContent();
    } else {
      return Padding(
        padding: const EdgeInsets.all(20.0),
        child: _buildStudentContent(),
      );
    }
  }
}