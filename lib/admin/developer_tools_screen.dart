import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:decanat_progect/constants.dart';
import 'package:decanat_progect/widgets/custom_app_bar.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';
import 'package:decanat_progect/admin/admin_schedule_teacher_editor.dart';
import 'dart:async';


class DeveloperToolsScreen extends StatefulWidget {
  const DeveloperToolsScreen({super.key});

  @override
  State<DeveloperToolsScreen> createState() => _DeveloperToolsScreenState();
}

class _DeveloperToolsScreenState extends State<DeveloperToolsScreen> with SingleTickerProviderStateMixin {
  List<dynamic> _users = [];
  List<dynamic> _filteredUsers = [];
  List<dynamic> _filteredStudentsTeachers = [];
  bool _isLoading = true;
  String? _userId;
  String _userRole = 'user';
  final TextEditingController _searchController = TextEditingController();
  late TabController _tabController;

  final List<String> _studentsTeachersRoles = ['teacher', 'student'];

  @override
  void initState() {
    super.initState();
    _searchController.addListener(_filterUsers);
    _loadUserData();
    _loadUsers(); // берём расширенный /api/users (с ФИО/группой/online)
    _tabController = TabController(length: 2, vsync: this);
  }

  @override
  void dispose() {
    _searchController.dispose();
    _tabController.dispose();
    super.dispose();
  }

  Future<void> _loadUserData() async {
    final prefs = await SharedPreferences.getInstance();
    setState(() {
      _userId = prefs.getString('userId');
      _userRole = prefs.getString('userRole') ?? 'user';
    });
  }

  Future<void> _loadUsers() async {
    try {
      final resp = await http.get(Uri.parse('${AppConfig.serverUrl}/api/users'));
      if (resp.statusCode == 200) {
        final data = json.decode(resp.body);
        setState(() {
          _users = List<Map<String, dynamic>>.from(data);
          _sortAndFilterUsers();
          _isLoading = false;
        });
      } else {
        _showSnackBar('Ошибка загрузки пользователей');
        setState(() => _isLoading = false);
      }
    } catch (e) {
      _showSnackBar('Ошибка подключения к серверу');
      setState(() => _isLoading = false);
    }
  }

  void _sortAndFilterUsers() {
    _users.sort((a, b) {
      const roleOrder = {'developer': 0, 'admin': 1, 'teacher': 2, 'student': 3, 'user': 4};
      final ar = a['role'] ?? 'user';
      final br = b['role'] ?? 'user';
      return (roleOrder[ar] ?? 4).compareTo(roleOrder[br] ?? 4);
    });
    _filterUsers();
  }

  void _filterUsers() {
    final q = _searchController.text.toLowerCase().trim();

    List<dynamic> allUsersFiltered;
    if (q.isEmpty) {
      allUsersFiltered = _users.where((u) => !_studentsTeachersRoles.contains(u['role'])).toList();
    } else {
      allUsersFiltered = _users.where((u) {
        if (_studentsTeachersRoles.contains(u['role'])) return false;
        final userId = (u['user_id'] ?? '').toString().toLowerCase();
        final role = _getRoleName(u['role'] ?? 'user').toLowerCase();
        final fullName = (u['full_name'] ?? '').toString().toLowerCase();
        final login = (u['login'] ?? '').toString().toLowerCase();
        // device_info убран из поиска
        return userId.contains(q) || role.contains(q) || fullName.contains(q) || login.contains(q);
      }).toList();
    }

    List<dynamic> studentsTeachersFiltered;
    if (q.isEmpty) {
      studentsTeachersFiltered = _users.where((u) => _studentsTeachersRoles.contains(u['role'])).toList();
    } else {
      studentsTeachersFiltered = _users.where((u) {
        if (!_studentsTeachersRoles.contains(u['role'])) return false;
        final userId = (u['user_id'] ?? '').toString().toLowerCase();
        final role = _getRoleName(u['role'] ?? 'user').toLowerCase();
        final fullName = (u['full_name'] ?? '').toString().toLowerCase();
        final login = (u['login'] ?? '').toString().toLowerCase();
        final groupName = (u['group_name'] ?? '').toString().toLowerCase();
        final department = (u['department'] ?? '').toString().toLowerCase();
        final position = (u['position'] ?? '').toString().toLowerCase();
        return userId.contains(q) ||
            role.contains(q) ||
            fullName.contains(q) ||
            login.contains(q) ||
            groupName.contains(q) ||
            department.contains(q) ||
            position.contains(q);
      }).toList();
    }

    setState(() {
      _filteredUsers = allUsersFiltered;
      _filteredStudentsTeachers = studentsTeachersFiltered;
    });
  }

  void _confirmMakeDeveloper(Map<String, dynamic> user) {
    showDialog(
      context: context,
      builder: (_) => AlertDialog(
        title: const Text('Подтверждение действия'),
        content: Text(
          'Вы уверены, что хотите сделать пользователя ${user['user_id']} разработчиком?\n\n'
              '⚠️ Это действие нельзя будет отменить! Разработчики имеют полный доступ.',
          style: const TextStyle(fontSize: 14),
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context), child: const Text('Отмена')),
          TextButton(
            onPressed: () {
              Navigator.pop(context);
              _updateUserRole(user['user_id'], 'developer');
            },
            style: TextButton.styleFrom(foregroundColor: Colors.red),
            child: const Text('Сделать разработчиком'),
          ),
        ],
      ),
    );
  }

  Future<void> _updateUserRole(String userId, String newRole) async {
    try {
      final response = await http.put(
        Uri.parse('${AppConfig.serverUrl}/api/users/role'),
        headers: {'Content-Type': 'application/json'},
        body: json.encode({'user_id': userId, 'role': newRole}),
      );
      if (response.statusCode == 200) {
        _showSnackBar('Роль пользователя обновлена');
        _loadUsers();
      } else {
        _showSnackBar('Ошибка обновления роли');
      }
    } catch (_) {
      _showSnackBar('Ошибка подключения');
    }
  }

  Future<void> _removeAdminRole(String userId) async {
    try {
      final response = await http.delete(Uri.parse('${AppConfig.serverUrl}/api/users/$userId/admin'));
      if (response.statusCode == 200) {
        _showSnackBar('Права администратора сняты');
        _loadUsers();
      } else {
        final errorData = json.decode(response.body);
        _showSnackBar(errorData['detail'] ?? 'Ошибка снятия прав');
      }
    } catch (e) {
      _showSnackBar('Ошибка подключения: $e');
    }
  }

  void _showSnackBar(String message) {
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(message), duration: const Duration(seconds: 2)));
  }

  String _formatDateTime(String dateTime) {
    try {
      final date = DateTime.parse(dateTime);
      final m = date.month.toString().padLeft(2, '0');
      final d = date.day.toString().padLeft(2, '0');
      final hh = date.hour.toString().padLeft(2, '0');
      final mm = date.minute.toString().padLeft(2, '0');
      return '$d.$m.${date.year} $hh:$mm';
    } catch (_) {
      return dateTime;
    }
  }

  Color _getRoleColor(String role) {
    switch (role) {
      case 'developer': return Colors.purple;
      case 'admin': return Colors.blue;
      case 'teacher': return Colors.green;
      case 'student': return Colors.orange;
      default: return Colors.grey;
    }
  }

  String _getRoleName(String role) {
    switch (role) {
      case 'developer': return 'Разработчик';
      case 'admin': return 'Администратор';
      case 'teacher': return 'Преподаватель';
      case 'student': return 'Студент';
      default: return 'Пользователь';
    }
  }

  IconData _getRoleIcon(String role) {
    switch (role) {
      case 'developer': return Icons.developer_mode;
      case 'admin': return Icons.admin_panel_settings;
      case 'teacher': return Icons.person;
      case 'student': return Icons.school;
      default: return Icons.person;
    }
  }

  Widget _buildOnlineChip(Map<String, dynamic> user) {
    final bool online = (user['online'] ?? false) == true;
    final String? lastSeen = user['last_seen'] as String?;
    return Chip(
      labelPadding: const EdgeInsets.symmetric(horizontal: 8),
      avatar: CircleAvatar(
        radius: 6,
        backgroundColor: online ? Colors.green : Colors.grey,
      ),
      label: Text(
        online ? 'Онлайн' : 'Офлайн${lastSeen != null ? ' • ${_formatDateTime(lastSeen)}' : ''}',
        style: const TextStyle(fontSize: 12),
      ),
      backgroundColor: (online ? Colors.green : Colors.grey).withOpacity(0.12),
      side: BorderSide(color: online ? Colors.green : Colors.grey),
    );
  }

  Widget _buildStatCard(String title, int count, Color color) {
    return Card(
      elevation: 2,
      child: Padding(
        padding: const EdgeInsets.all(8),
        child: Column(
          children: [
            Text(title, style: TextStyle(fontSize: 12, color: Colors.grey[600])),
            Text('$count', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: color)),
          ],
        ),
      ),
    );
  }

  Widget _buildStatistics(List<dynamic> users, bool isAllUsersTab) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      child: SingleChildScrollView(
        scrollDirection: Axis.horizontal,
        child: Row(
          children: [
            _buildStatCard('Всего', users.length, Colors.grey),
            if (isAllUsersTab) _buildStatCard('Разработчики', users.where((u) => u['role'] == 'developer').length, Colors.purple),
            if (isAllUsersTab) _buildStatCard('Админы', users.where((u) => u['role'] == 'admin').length, Colors.blue),
            if (!isAllUsersTab) _buildStatCard('Преподаватели', users.where((u) => u['role'] == 'teacher').length, Colors.green),
            if (!isAllUsersTab) _buildStatCard('Студенты', users.where((u) => u['role'] == 'student').length, Colors.orange),
            if (isAllUsersTab) _buildStatCard('Пользователи', users.where((u) => u['role'] == 'user').length, Colors.grey[600]!),
            _buildStatCard('Онлайн', users.where((u) => (u['online'] ?? false) == true).length, Colors.green),
          ],
        ),
      ),
    );
  }

  Widget _buildUserCard(Map<String, dynamic> user) {
    final isCurrentUser = user['user_id'] == _userId;
    final isSystemDeveloper = user['user_id'] == '000000';
    final role = (user['role'] ?? 'user') as String;

    final String? fullName = user['full_name'];
    final String? groupName = user['group_name'];

    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Верхняя строка
            Row(
              children: [
                Container(
                  width: 40,
                  height: 40,
                  decoration: BoxDecoration(
                    color: _getRoleColor(role).withOpacity(0.1),
                    shape: BoxShape.circle,
                  ),
                  child: Icon(_getRoleIcon(role), color: _getRoleColor(role), size: 20),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text('ID: ${user['user_id']}', style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
                      Text(_getRoleName(role), style: TextStyle(color: _getRoleColor(role), fontSize: 14, fontWeight: FontWeight.w500)),
                    ],
                  ),
                ),
                if (isCurrentUser)
                  const Chip(label: Text('Вы', style: TextStyle(fontSize: 12)), backgroundColor: Colors.orange),
              ],
            ),

            const SizedBox(height: 8),

            // ФИО
            if (fullName != null && fullName.isNotEmpty)
              Text('ФИО: $fullName', style: const TextStyle(fontSize: 13)),

            // Группа только для студентов
            if (role == 'student' && groupName != null && groupName.isNotEmpty)
              Text('Группа: $groupName', style: const TextStyle(fontSize: 13)),

            // Даты
            const SizedBox(height: 6),
            Text('Создан: ${_formatDateTime(user['created_at'] ?? '')}', style: const TextStyle(fontSize: 12)),
            if (user['updated_at'] != null)
              Text('Обновлён: ${_formatDateTime(user['updated_at'])}', style: const TextStyle(fontSize: 12)),

            const SizedBox(height: 8),

            // Онлайн/офлайн
            _buildOnlineChip(user),

            const SizedBox(height: 12),

            if (!isSystemDeveloper)
              Wrap(
                spacing: 8,
                runSpacing: 8,
                children: [
                  if (role == 'admin')
                    ElevatedButton(
                      onPressed: () => _removeAdminRole(user['user_id']),
                      style: ElevatedButton.styleFrom(backgroundColor: Colors.red, foregroundColor: Colors.white),
                      child: const Text('Снять админа'),
                    ),
                  if (role == 'user' || role == 'student' || role == 'teacher')
                    ElevatedButton(
                      onPressed: () => _updateUserRole(user['user_id'], 'admin'),
                      style: ElevatedButton.styleFrom(backgroundColor: Colors.blue, foregroundColor: Colors.white),
                      child: const Text('Сделать админом'),
                    ),
                  if (role == 'admin')
                    ElevatedButton(
                      onPressed: () => _confirmMakeDeveloper(user),
                      style: ElevatedButton.styleFrom(backgroundColor: Colors.purple, foregroundColor: Colors.white),
                      child: const Text('В разработчики'),
                    ),
                  if (role == 'admin' || role == 'developer' || role == 'teacher')
                    ElevatedButton(
                      onPressed: () => _updateUserRole(user['user_id'], 'user'),
                      style: ElevatedButton.styleFrom(backgroundColor: Colors.green, foregroundColor: Colors.white),
                      child: const Text('В пользователи'),
                    ),
                  if (role == 'user' || role == 'admin' || role == 'developer')
                    ElevatedButton(
                      onPressed: () => _updateUserRole(user['user_id'], 'teacher'),
                      style: ElevatedButton.styleFrom(backgroundColor: Colors.teal, foregroundColor: Colors.white),
                      child: const Text('В преподаватели'),
                    ),
                  if (role == 'user' || role == 'admin' || role == 'developer' || role == 'teacher')
                    ElevatedButton(
                      onPressed: () => _updateUserRole(user['user_id'], 'student'),
                      style: ElevatedButton.styleFrom(backgroundColor: Colors.orange, foregroundColor: Colors.white),
                      child: const Text('В студенты'),
                    ),
                ],
              ),
            if (isSystemDeveloper)
              Text('Системный разработчик (нельзя изменить)', style: TextStyle(color: Colors.grey[600], fontSize: 12)),
          ],
        ),
      ),
    );
  }

  Widget _buildUsersList(List<dynamic> users) {
    if (users.isEmpty) {
      return Center(
        child: Text(
          _searchController.text.isEmpty ? 'Нет пользователей' : 'Пользователи не найдены',
          style: const TextStyle(fontSize: 16, color: Colors.grey),
        ),
      );
    }
    return ListView.builder(
      padding: const EdgeInsets.all(16),
      itemCount: users.length,
      itemBuilder: (_, i) => _buildUserCard(users[i]),
    );
  }

  @override
  Widget build(BuildContext context) {
    if (_userRole != 'developer') {
      return const Scaffold(
        appBar: CustomAppBar(title: 'Список пользователей', showBackButton: true),
        body: Center(child: Text('Доступно только разработчикам', style: TextStyle(fontSize: 16))),
      );
    }

    return Scaffold(
      appBar: AppBar(
        title: const Text('Управление пользователями'),
        leading: IconButton(icon: const Icon(Icons.arrow_back), onPressed: () => Navigator.pop(context)),
        bottom: TabBar(
          controller: _tabController,
          labelColor: Colors.white,
          unselectedLabelColor: Colors.white70,
          indicatorColor: Colors.yellowAccent,
          tabs: const [Tab(text: 'Пользователи'), Tab(text: 'Студ. и препод.')],
        ),
      ),
      body: Column(
        children: [
          Padding(
            padding: const EdgeInsets.all(16),
            child: TextField(
              controller: _searchController,
              decoration: InputDecoration(
                labelText: 'Поиск по ID, ФИО, логину, группе и т.д.',
                prefixIcon: const Icon(Icons.search),
                border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                suffixIcon: _searchController.text.isNotEmpty
                    ? IconButton(icon: const Icon(Icons.clear), onPressed: _searchController.clear)
                    : null,
              ),
            ),
          ),
          Expanded(
            child: TabBarView(
              controller: _tabController,
              children: [
                Column(
                  children: [
                    _buildStatistics(_filteredUsers, true),
                    Expanded(
                      child: _isLoading
                          ? const Center(child: CircularProgressIndicator())
                          : RefreshIndicator(onRefresh: _loadUsers, child: _buildUsersList(_filteredUsers)),
                    ),
                  ],
                ),
                Column(
                  children: [
                    _buildStatistics(_filteredStudentsTeachers, false),
                    Expanded(
                      child: _isLoading
                          ? const Center(child: CircularProgressIndicator())
                          : RefreshIndicator(onRefresh: _loadUsers, child: _buildUsersList(_filteredStudentsTeachers)),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
