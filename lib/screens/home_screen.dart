import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'admin_panel_screen.dart';
import 'package:decanat_progect/admin/developer_tools_screen.dart';
import 'package:decanat_progect/constants.dart';
import 'package:decanat_progect/widgets/victory_banner.dart';
import 'package:decanat_progect/widgets/bubble_button.dart';
import 'department_detail_screen.dart';
import 'webview_screen.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';
import 'package:decanat_progect/admin/admin_schedule_editor.dart';

// Импортируем файлы для разных ролей
import 'package:decanat_progect/user/user_home_content.dart';
import 'package:decanat_progect/user/student_home_content.dart';
import 'package:decanat_progect/teacher/teacher_home_content.dart';

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  _HomeScreenState createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> with SingleTickerProviderStateMixin {
  String _userRole = 'user';
  String? _userId;
  final String _serverUrl = "https://0.0.0.0:8000";

  // Для управления вкладками
  late TabController _tabController;
  int _currentTabIndex = 0;

  @override
  void initState() {
    super.initState();
    _loadUserRole();

    // Инициализируем TabController с 3 вкладками
    _tabController = TabController(length: 3, vsync: this);
    _tabController.addListener(_handleTabSelection);
  }

  void _handleTabSelection() {
    if (_tabController.indexIsChanging) {
      setState(() {
        _currentTabIndex = _tabController.index;
      });
    }
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  Future<void> _loadUserRole() async {
    final prefs = await SharedPreferences.getInstance();
    _userId = prefs.getString('userId');

    if (_userId != null) {
      try {
        final response = await http.get(
            Uri.parse('$_serverUrl/api/users/$_userId/role')
        );

        if (response.statusCode == 200) {
          final data = json.decode(response.body);
          setState(() {
            _userRole = data['role'] ?? 'user';
          });
          await prefs.setString('userRole', _userRole);
        }
      } catch (e) {
        print('Ошибка загрузки роли пользователя: $e');
        _userRole = prefs.getString('userRole') ?? 'user';
        setState(() {});
      }
    } else {
      _userRole = prefs.getString('userRole') ?? 'user';
      setState(() {});
    }
  }

  bool get _isAdminOrDeveloper {
    return _userRole == 'admin' || _userRole == 'developer';
  }

  IconData _getRoleIcon() {
    switch (_userRole) {
      case 'admin': return Icons.admin_panel_settings;
      case 'developer': return Icons.developer_mode;
      default: return Icons.person;
    }
  }

  Color _getRoleColor() {
    switch (_userRole) {
      case 'admin': return Colors.blue;
      case 'developer': return Colors.purple;
      default: return Colors.green;
    }
  }

  String _getRoleName() {
    switch (_userRole) {
      case 'admin': return 'Администратор';
      case 'developer': return 'Разработчик';
      default: return 'Пользователь';
    }
  }

  PreferredSizeWidget _buildAppBar() {
    return AppBar(
      title: Row(
        children: [
          Text(
            'Факультет ИСП',
            style: TextStyle(
              color: Theme.of(context).colorScheme.onPrimary,
              fontWeight: FontWeight.bold,
              fontSize: 22,
            ),
          ),
          const SizedBox(width: 8),
          if (_isAdminOrDeveloper) _buildServerStatusIndicator(),
        ],
      ),
      backgroundColor: AppColors.primary,
      centerTitle: true,
      elevation: 0,
      iconTheme: IconThemeData(color: Theme.of(context).colorScheme.onPrimary),
      actions: [
        if (_isAdminOrDeveloper)
          IconButton(
            icon: Icon(
              _userRole == 'developer' ? Icons.developer_mode : Icons.admin_panel_settings,
              color: Theme.of(context).colorScheme.onPrimary,
            ),
            onPressed: _showDeveloperTools,
            tooltip: 'Инструменты разработчика',
          ),
      ],
    );
  }

  Widget _buildServerStatusIndicator() {
    return FutureBuilder(
      future: _checkServerStatus(),
      builder: (context, snapshot) {
        final isOnline = snapshot.data ?? false;
        return Container(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
          decoration: BoxDecoration(
            color: isOnline ? Colors.green.withOpacity(0.1) : Colors.red.withOpacity(0.1),
            borderRadius: BorderRadius.circular(20),
            border: Border.all(
              color: isOnline ? Colors.green : Colors.red,
              width: 1,
            ),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(
                isOnline ? Icons.wifi : Icons.wifi_off,
                size: 14,
                color: isOnline ? Colors.green : Colors.red,
              ),
              const SizedBox(width: 4),
              Text(
                isOnline ? 'Онлайн' : 'Офлайн',
                style: TextStyle(
                  fontSize: 12,
                  color: isOnline ? Colors.green : Colors.red,
                  fontWeight: FontWeight.w500,
                ),
              ),
            ],
          ),
        );
      },
    );
  }

  Future<bool> _checkServerStatus() async {
    try {
      final response = await http
          .get(Uri.parse('$_serverUrl/api/health'))
          .timeout(const Duration(seconds: 5));
      return response.statusCode == 200;
    } catch (e) {
      return false;
    }
  }

  Widget _buildDivider(BuildContext context) {
    return Row(
      children: [
        Expanded(
          child: Container(
            height: 1,
            decoration: BoxDecoration(
              gradient: LinearGradient(
                colors: [
                  Colors.transparent,
                  Theme.of(context).colorScheme.primary.withOpacity(0.3),
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
            color: Theme.of(context).colorScheme.primary,
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
                  Theme.of(context).colorScheme.primary.withOpacity(0.3),
                  Colors.transparent,
                ],
              ),
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildInfoCard(BuildContext context) {
    return FutureBuilder(
      future: _loadTodaySchedule(),
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Center(child: CircularProgressIndicator());
        }

        if (!snapshot.hasData || snapshot.data == null) {
          return Card(
            elevation: 2,
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
            color: Theme.of(context).cardColor,
            child: Container(
              padding: const EdgeInsets.all(20),
              child: Column(
                children: [
                  Icon(Icons.info_outline,
                      size: 32, color: Theme.of(context).colorScheme.primary),
                  const SizedBox(height: 12),
                  const Text(
                    'Сегодня занятий нет',
                    style: TextStyle(fontSize: 14, fontWeight: FontWeight.w600),
                  ),
                ],
              ),
            ),
          );
        }

        final Map<String, dynamic> todayData = snapshot.data as Map<String, dynamic>;
        final String dayName = todayData['dayName'];
        final List lessons = todayData['lessons'];

        return Card(
          elevation: 2,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
          color: Theme.of(context).cardColor,
          child: Container(
            padding: const EdgeInsets.all(20),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Icon(Icons.today,
                        size: 28, color: Theme.of(context).colorScheme.primary),
                    const SizedBox(width: 12),
                    Text(
                      '$dayName (${todayData['weekName']})',
                      style: TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.bold,
                        color: Theme.of(context).colorScheme.onBackground,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 16),
                if (lessons.isEmpty)
                  Text(
                    'Сегодня занятий нет 🎉',
                    style: TextStyle(
                        color: Theme.of(context).colorScheme.onSurface, fontSize: 14),
                  )
                else
                  Column(
                    children: lessons.map((lesson) {
                      return ListTile(
                        contentPadding: EdgeInsets.zero,
                        leading: CircleAvatar(
                          backgroundColor: Colors.blue,
                          child: Text(
                            '${lesson['lesson_number']}',
                            style: const TextStyle(color: Colors.white),
                          ),
                        ),
                        title: Text(
                          lesson['subject'],
                          style: const TextStyle(fontWeight: FontWeight.w600),
                        ),
                        subtitle:
                        Text('${lesson['teacher']} • ${lesson['classroom']}'),
                        trailing: Text(lesson['type']),
                      );
                    }).toList(),
                  ),
              ],
            ),
          ),
        );
      },
    );
  }

  /// Загружаем расписание на сегодня из SharedPreferences
  Future<Map<String, dynamic>?> _loadTodaySchedule() async {
    final prefs = await SharedPreferences.getInstance();
    final group = prefs.getString('selectedGroup');
    final week = prefs.getString('selectedWeek') ?? 'upper';
    if (group == null) return null;

    final cached = prefs.getString('schedule_${group}_$week');
    if (cached == null) return null;

    final scheduleData = json.decode(cached);
    final todayIndex = DateTime.now().weekday; // 1=Пн ... 7=Вс
    const days = ['Понедельник', 'Вторник', 'Среда', 'Четверг', 'Пятница', 'Суббота'];

    if (todayIndex > 6) return null; // воскресенье

    final todayName = days[todayIndex - 1];
    final lessons = (scheduleData[todayName] ?? []) as List;

    return {
      'dayName': todayName,
      'weekName': week == 'upper' ? 'Верхняя неделя' : 'Нижняя неделя',
      'lessons': lessons,
    };
  }

  Widget _buildSectionTitle(BuildContext context, String title) {
    return Padding(
      padding: const EdgeInsets.only(left: 4.0),
      child: Text(
        title,
        style: TextStyle(
          fontSize: 18,
          fontWeight: FontWeight.bold,
          color: Theme.of(context).colorScheme.onBackground,
          letterSpacing: -0.5,
        ),
      ),
    );
  }

  Widget _buildNewsItem(BuildContext context, String title, String date, IconData icon, Color color) {
    return Card(
      elevation: 1,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
      color: Theme.of(context).cardColor,
      child: ListTile(
        leading: Container(
          width: 42,
          height: 42,
          decoration: BoxDecoration(color: color.withOpacity(0.08), shape: BoxShape.circle),
          child: Icon(icon, color: color, size: 20),
        ),
        title: Text(
          title,
          style: TextStyle(
            fontWeight: FontWeight.w600,
            fontSize: 14,
            color: Theme.of(context).colorScheme.onBackground,
          ),
        ),
        subtitle: Text(
          date,
          style: TextStyle(color: Theme.of(context).colorScheme.onSurface, fontSize: 12),
        ),
        trailing: Icon(Icons.arrow_forward_ios, size: 16, color: Theme.of(context).colorScheme.onSurface),
        onTap: () => _showNewsDetails(title, date),
        contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      ),
    );
  }

  void _showNewsDetails(String title, String date) {
    showDialog(
      context: context,
      builder: (BuildContext context) {
        return AlertDialog(
          title: Text(title),
          content: Text(
            'Подробная информация о событии "$title", запланированном на $date. '
                'Для получения дополнительной информации посетите официальный сайт университета.',
          ),
          actions: [
            TextButton(onPressed: () => Navigator.pop(context), child: const Text('Закрыть')),
            TextButton(
              onPressed: () {
                Navigator.pop(context);
                Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (context) => WebViewScreen(
                      url: 'https://donntu.ru/news',
                      title: 'Новости ДонНТУ',
                    ),
                  ),
                );
              },
              child: const Text('Подробнее'),
            ),
          ],
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        );
      },
    );
  }

  Future<void> _updateUserRole(String userId, String newRole) async {
    if (_userRole != 'developer') {
      _showSnackBar('Только разработчики могут изменять роли');
      return;
    }

    try {
      final response = await http.put(
        Uri.parse('$_serverUrl/api/users/role'),
        headers: {'Content-Type': 'application/json'},
        body: json.encode({'user_id': userId, 'role': newRole}),
      );

      if (response.statusCode == 200) {
        _showSnackBar('Роль пользователя обновлена');
      } else {
        _showSnackBar('Ошибка обновления роли');
      }
    } catch (e) {
      _showSnackBar('Ошибка сети: $e');
    }
  }

  void _showSnackBar(String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(message), duration: const Duration(seconds: 2)),
    );
  }

  void _showDeveloperTools() {
    showModalBottomSheet(
      context: context,
      builder: (BuildContext context) {
        return Container(
          padding: const EdgeInsets.all(16),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                'Инструменты разработчика',
                style: TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                  color: Theme.of(context).colorScheme.onBackground,
                ),
              ),
              const SizedBox(height: 16),
              if (_userRole == 'developer') ...[
                _buildDeveloperButton(
                  'Управление расписанием',
                  Icons.schedule,
                      () {
                    Navigator.push(
                      context,
                      MaterialPageRoute(builder: (context) => AdminScheduleEditor()),
                    );
                  },
                ),
                const SizedBox(height: 8),
                _buildDeveloperButton(
                  'Назначить администратора',
                  Icons.admin_panel_settings,
                      () => _showRoleChangeDialog('admin'),
                ),
                const SizedBox(height: 8),
                _buildDeveloperButton(
                  'Снять права администратора',
                  Icons.person_remove,
                      () => _showRemoveAdminDialog(),
                ),
                const SizedBox(height: 8),
              ],
              _buildDeveloperButton(
                'Проверить соединение с сервером',
                Icons.wifi,
                _checkServerConnection,
              ),
              const SizedBox(height: 8),
              _buildDeveloperButton(
                'Информация о пользователе',
                Icons.info,
                _showUserInfo,
              ),
            ],
          ),
        );
      },
    );
  }

  Widget _buildDeveloperButton(String text, IconData icon, VoidCallback onPressed) {
    return ElevatedButton.icon(
      icon: Icon(icon, size: 20),
      label: Text(text),
      onPressed: onPressed,
      style: ElevatedButton.styleFrom(
        backgroundColor: AppColors.primary,
        foregroundColor: Colors.white,
        minimumSize: const Size(double.infinity, 50),
      ),
    );
  }

  Future<void> _checkServerConnection() async {
    try {
      final response = await http.get(Uri.parse('$_serverUrl/api/health'));
      if (response.statusCode == 200) {
        _showSnackBar('Сервер доступен ✓');
      } else {
        _showSnackBar('Сервер недоступен ✗');
      }
    } catch (e) {
      _showSnackBar('Ошибка подключения: $e');
    }
  }

  void _showUserInfo() {
    showDialog(
      context: context,
      builder: (BuildContext context) {
        return AlertDialog(
          title: const Text('Информация о пользователе'),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text('ID: $_userId'),
              Text('Роль: $_userRole'),
              Text('Сервер: $_serverUrl'),
            ],
          ),
          actions: [TextButton(onPressed: () => Navigator.pop(context), child: const Text('OK'))],
        );
      },
    );
  }

  void _showRoleChangeDialog(String role) {
    final roleName = role == 'admin' ? 'администратора' : 'пользователя';
    String userId = '';

    showDialog(
      context: context,
      builder: (BuildContext context) {
        return AlertDialog(
          title: Text('Назначить $roleName'),
          content: TextField(
            decoration: const InputDecoration(
              labelText: 'ID пользователя',
              hintText: 'Введите ID пользователя',
              border: OutlineInputBorder(),
            ),
            onChanged: (value) => userId = value,
            keyboardType: TextInputType.number,
          ),
          actions: [
            TextButton(onPressed: () => Navigator.pop(context), child: const Text('Отмена')),
            TextButton(
              onPressed: () {
                if (userId.isNotEmpty) {
                  _updateUserRole(userId, role);
                  Navigator.pop(context);
                } else {
                  _showSnackBar('Введите ID пользователя');
                }
              },
              child: Text('Назначить $roleName'),
            ),
          ],
        );
      },
    );
  }

  void _showRemoveAdminDialog() {
    String userId = '';

    showDialog(
      context: context,
      builder: (BuildContext context) {
        return AlertDialog(
          title: const Text('Снять права администратора'),
          content: TextField(
            decoration: const InputDecoration(
              labelText: 'ID администратора',
              hintText: 'Введите ID пользователя',
              border: OutlineInputBorder(),
            ),
            onChanged: (value) => userId = value,
            keyboardType: TextInputType.number,
          ),
          actions: [
            TextButton(onPressed: () => Navigator.pop(context), child: const Text('Отмена')),
            TextButton(
              onPressed: () {
                if (userId.isNotEmpty) {
                  _updateUserRole(userId, 'user');
                  Navigator.pop(context);
                } else {
                  _showSnackBar('Введите ID пользователя');
                }
              },
              child: const Text('Снять права'),
            ),
          ],
        );
      },
    );
  }

  // Виджет для верхней части с баннером и TabBar
  Widget _buildHeaderWithTabs() {
    return Column(
      children: [
        const VictoryBanner(),
        Container(
          color: AppColors.primary,
          child: TabBar(
            controller: _tabController,
            indicatorColor: Colors.white,
            labelColor: Colors.white,
            unselectedLabelColor: Colors.white.withOpacity(0.7),
            tabs: const [
              Tab(text: 'Пользователь'),
              Tab(text: 'Студент'),
              Tab(text: 'Преподаватель'),
            ],
          ),
        ),
      ],
    );
  }

  // Контент для каждой вкладки
  Widget _buildTabContent(int tabIndex) {
    switch (tabIndex) {
      case 0: // Пользователь
        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            UserHomeContent(),
            const SizedBox(height: 24),
            _buildDivider(context),
            const SizedBox(height: 24),
            _buildInfoCard(context),
            const SizedBox(height: 28),
            _buildSectionTitle(context, 'Новости университета'),
            const SizedBox(height: 16),
            _buildNewsItem(context, 'День открытых дверей', '25 января 2025', Icons.calendar_today, AppColors.primary),
            const SizedBox(height: 12),
            _buildNewsItem(context, 'Научная конференция', '15 февраля 2025', Icons.science, Colors.blue[700]!),
            const SizedBox(height: 12),
            _buildNewsItem(context, 'Спортивные соревнования', '8 марта 2025', Icons.sports, Colors.green[700]!),
          ],
        );
      case 1: // Студент
        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            StudentHomeContent(),
            const SizedBox(height: 24),
            _buildDivider(context),
            const SizedBox(height: 24),
            _buildInfoCard(context),
            const SizedBox(height: 28),
            _buildSectionTitle(context, 'Новости университета'),
            const SizedBox(height: 16),
            _buildNewsItem(context, 'День открытых дверей', '25 января 2025', Icons.calendar_today, AppColors.primary),
            const SizedBox(height: 12),
            _buildNewsItem(context, 'Научная конференция', '15 февраля 2025', Icons.science, Colors.blue[700]!),
            const SizedBox(height: 12),
            _buildNewsItem(context, 'Спортивные соревнования', '8 марта 2025', Icons.sports, Colors.green[700]!),
          ],
        );
      case 2: // Преподаватель
        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            TeacherHomeContent(),
            const SizedBox(height: 24),
            _buildDivider(context),
            const SizedBox(height: 24),
            _buildInfoCard(context),
            const SizedBox(height: 28),
            _buildSectionTitle(context, 'Новости университета'),
            const SizedBox(height: 16),
            _buildNewsItem(context, 'День открытых дверей', '25 января 2025', Icons.calendar_today, AppColors.primary),
            const SizedBox(height: 12),
            _buildNewsItem(context, 'Научная конференция', '15 февраля 2025', Icons.science, Colors.blue[700]!),
            const SizedBox(height: 12),
            _buildNewsItem(context, 'Спортивные соревнования', '8 марта 2025', Icons.sports, Colors.green[700]!),
          ],
        );
      default:
        return Container();
    }
  }

  @override
  Widget build(BuildContext context) {
    return DefaultTabController(
      length: 3,
      child: Scaffold(
        backgroundColor: Theme.of(context).colorScheme.background,
        appBar: _buildAppBar(),
        body: NestedScrollView(
          headerSliverBuilder: (BuildContext context, bool innerBoxIsScrolled) {
            return [
              SliverToBoxAdapter(
                child: _buildHeaderWithTabs(),
              ),
            ];
          },
          body: TabBarView(
            controller: _tabController,
            children: [
              // Вкладка Пользователь
              SingleChildScrollView(
                padding: const EdgeInsets.all(20.0),
                child: _buildTabContent(0),
              ),

              // Вкладка Студент
              SingleChildScrollView(
                padding: const EdgeInsets.all(20.0),
                child: _buildTabContent(1),
              ),

              // Вкладка Преподаватель
              SingleChildScrollView(
                padding: const EdgeInsets.all(20.0),
                child: _buildTabContent(2),
              ),
            ],
          ),
        ),
        floatingActionButton: _isAdminOrDeveloper
            ? FloatingActionButton(
          onPressed: () {
            if (_userRole == 'developer') {
              Navigator.push(context, MaterialPageRoute(builder: (context) => DeveloperToolsScreen()));
            } else {
              Navigator.push(context, MaterialPageRoute(builder: (context) => AdminPanelScreen()));
            }
          },
          backgroundColor: Colors.transparent,
          elevation: 0,
          child: Container(
            width: 60,
            height: 60,
            decoration: BoxDecoration(
              gradient: LinearGradient(
                colors: _userRole == 'developer'
                    ? [Colors.purple, Colors.blue]
                    : [Colors.blue, Colors.green],
              ),
              borderRadius: BorderRadius.circular(30),
            ),
            child: Icon(
              _userRole == 'developer' ? Icons.developer_mode : Icons.admin_panel_settings_outlined,
              color: Colors.white,
              size: 30,
            ),
          ),
        )
            : null,
      ),
    );
  }
}