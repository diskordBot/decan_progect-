import 'package:flutter/material.dart';
import 'package:decanat_progect/widgets/bubble_button.dart';
import 'package:decanat_progect/screens/department_detail_screen.dart';
import 'package:decanat_progect/screens/webview_screen.dart';


class StudentHomeContent extends StatelessWidget {
  const StudentHomeContent({super.key});

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
}