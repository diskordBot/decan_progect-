import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:decanat_progect/constants.dart';
import 'package:decanat_progect/widgets/custom_app_bar.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';

class DeveloperToolsScreen extends StatefulWidget {
  const DeveloperToolsScreen({super.key});

  @override
  State<DeveloperToolsScreen> createState() => _DeveloperToolsScreenState();
}

class _DeveloperToolsScreenState extends State<DeveloperToolsScreen> {
  List<dynamic> _users = [];
  List<dynamic> _filteredUsers = [];
  bool _isLoading = true;
  String? _userId;
  String _userRole = 'user';
  TextEditingController _searchController = TextEditingController();

  @override
  void initState() {
    super.initState();
    _searchController.addListener(_filterUsers);
    _loadUserData();
    _loadUsers();
  }

  @override
  void dispose() {
    _searchController.dispose();
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
      final response = await http.get(
        Uri.parse('${AppConfig.serverUrl}/api/users'),
      );

      if (response.statusCode == 200) {
        setState(() {
          _users = json.decode(response.body);
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
    // Сначала сортируем по роли: разработчики -> администраторы -> студенты -> пользователи
    _users.sort((a, b) {
      final roleOrder = {'developer': 0, 'admin': 1, 'student': 2, 'user': 3};
      return roleOrder[a['role']]!.compareTo(roleOrder[b['role']]!);
    });

    // Затем применяем фильтр поиска
    _filterUsers();
  }

  void _filterUsers() {
    final searchText = _searchController.text.toLowerCase().trim();

    if (searchText.isEmpty) {
      setState(() {
        _filteredUsers = List.from(_users);
      });
    } else {
      setState(() {
        _filteredUsers = _users.where((user) {
          final userId = user['user_id'].toString().toLowerCase();
          final deviceInfo = user['device_info']?.toString().toLowerCase() ?? '';
          final role = _getRoleName(user['role']).toLowerCase();

          return userId.contains(searchText) ||
              deviceInfo.contains(searchText) ||
              role.contains(searchText);
        }).toList();
      });
    }
  }

  void _confirmMakeDeveloper(Map<String, dynamic> user) {
    showDialog(
      context: context,
      builder: (BuildContext context) {
        return AlertDialog(
          title: const Text('Подтверждение действия'),
          content: Text(
            'Вы уверены, что хотите сделать пользователя ${user['user_id']} разработчиком?\n\n'
                '⚠️ Это действие нельзя будет отменить! Разработчики имеют полный доступ ко всем функциям системы.',
            style: const TextStyle(fontSize: 14),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('Отмена'),
            ),
            TextButton(
              onPressed: () {
                Navigator.pop(context);
                _updateUserRole(user['user_id'], 'developer');
              },
              style: TextButton.styleFrom(
                foregroundColor: Colors.red,
              ),
              child: const Text('Сделать разработчиком'),
            ),
          ],
        );
      },
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
        _loadUsers(); // Обновляем список
      } else {
        _showSnackBar('Ошибка обновления роли');
      }
    } catch (e) {
      _showSnackBar('Ошибка подключения');
    }
  }

  Future<void> _removeAdminRole(String userId) async {
    try {
      final response = await http.delete(
        Uri.parse('${AppConfig.serverUrl}/api/users/$userId/admin'),
      );

      if (response.statusCode == 200) {
        _showSnackBar('Права администратора сняты');
        _loadUsers(); // Обновляем список
      } else {
        final errorData = json.decode(response.body);
        _showSnackBar(errorData['detail'] ?? 'Ошибка снятия прав');
      }
    } catch (e) {
      _showSnackBar('Ошибка подклюки: $e');
    }
  }

  void _showSnackBar(String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(message), duration: const Duration(seconds: 2)),
    );
  }

  String _formatDateTime(String dateTime) {
    try {
      final date = DateTime.parse(dateTime);
      return '${date.day}.${date.month}.${date.year} ${date.hour}:${date.minute.toString().padLeft(2, '0')}';
    } catch (e) {
      return dateTime;
    }
  }

  Color _getRoleColor(String role) {
    switch (role) {
      case 'developer': return Colors.purple;
      case 'admin': return Colors.blue;
      case 'student': return Colors.orange; // Оранжевый для студентов
      default: return Colors.green;
    }
  }

  String _getRoleName(String role) {
    switch (role) {
      case 'developer': return 'Разработчик';
      case 'admin': return 'Администратор';
      case 'student': return 'Студент'; // Русское название для студента
      default: return 'Пользователь';
    }
  }

  IconData _getRoleIcon(String role) {
    switch (role) {
      case 'developer': return Icons.developer_mode;
      case 'admin': return Icons.admin_panel_settings;
      case 'student': return Icons.school; // Иконка для студента
      default: return Icons.person;
    }
  }

  int _getRolePriority(String role) {
    switch (role) {
      case 'developer': return 0;
      case 'admin': return 1;
      case 'student': return 2;
      default: return 3;
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_userRole != 'developer') {
      return Scaffold(
        appBar: const CustomAppBar(title: 'Список пользователей', showBackButton: true),
        body: const Center(
          child: Text('Доступно только разработчикам', style: TextStyle(fontSize: 16)),
        ),
      );
    }

    return Scaffold(
      appBar: const CustomAppBar(title: 'Список пользователей', showBackButton: true),
      body: Column(
        children: [
          // Строка поиска
          Padding(
            padding: const EdgeInsets.all(16),
            child: TextField(
              controller: _searchController,
              decoration: InputDecoration(
                labelText: 'Поиск по ID, устройству или роли',
                prefixIcon: Icon(Icons.search),
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
                suffixIcon: _searchController.text.isNotEmpty
                    ? IconButton(
                  icon: Icon(Icons.clear),
                  onPressed: () {
                    _searchController.clear();
                  },
                )
                    : null,
              ),
            ),
          ),
          // Статистика
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceAround,
              children: [
                _buildStatCard('Всего', _filteredUsers.length, Colors.grey),
                _buildStatCard('Разработчики',
                    _filteredUsers.where((u) => u['role'] == 'developer').length,
                    Colors.purple
                ),
                _buildStatCard('Админы',
                    _filteredUsers.where((u) => u['role'] == 'admin').length,
                    Colors.blue
                ),
                _buildStatCard('Студенты',
                    _filteredUsers.where((u) => u['role'] == 'student').length,
                    Colors.orange
                ),
                _buildStatCard('Пользователи',
                    _filteredUsers.where((u) => u['role'] == 'user').length,
                    Colors.green
                ),
              ],
            ),
          ),

          // Список пользователей
          Expanded(
            child: _isLoading
                ? const Center(child: CircularProgressIndicator())
                : RefreshIndicator(
              onRefresh: _loadUsers,
              child: _filteredUsers.isEmpty
                  ? Center(
                child: Text(
                  _searchController.text.isEmpty
                      ? 'Нет пользователей'
                      : 'Пользователи не найдены',
                  style: TextStyle(fontSize: 16, color: Colors.grey),
                ),
              )
                  : ListView.builder(
                padding: const EdgeInsets.all(16),
                itemCount: _filteredUsers.length,
                itemBuilder: (context, index) {
                  final user = _filteredUsers[index];
                  return _buildUserCard(user);
                },
              ),
            ),
          ),
        ],
      ),
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

  Widget _buildUserCard(Map<String, dynamic> user) {
    final isCurrentUser = user['user_id'] == _userId;
    final isSystemDeveloper = user['user_id'] == '000000';
    final userRole = user['role'];

    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                // Иконка роли
                Container(
                  width: 40,
                  height: 40,
                  decoration: BoxDecoration(
                    color: _getRoleColor(userRole).withOpacity(0.1),
                    shape: BoxShape.circle,
                  ),
                  child: Icon(
                    _getRoleIcon(userRole),
                    color: _getRoleColor(userRole),
                    size: 20,
                  ),
                ),
                const SizedBox(width: 12),
                // Информация о пользователе
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'ID: ${user['user_id']}',
                        style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
                      ),
                      Text(
                        _getRoleName(userRole),
                        style: TextStyle(
                          color: _getRoleColor(userRole),
                          fontSize: 14,
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                    ],
                  ),
                ),
                // Метка "Вы" для текущего пользователя
                if (isCurrentUser)
                  const Chip(
                    label: Text('Вы', style: TextStyle(fontSize: 12)),
                    backgroundColor: Colors.orange,
                  ),
              ],
            ),
            const SizedBox(height: 8),
            // Дополнительная информация
            if (user['device_info'] != null)
              Text('Устройство: ${user['device_info']}', style: const TextStyle(fontSize: 12)),
            Text('Создан: ${_formatDateTime(user['created_at'])}', style: const TextStyle(fontSize: 12)),
            if (user['updated_at'] != null)
              Text('Обновлен: ${_formatDateTime(user['updated_at'])}', style: const TextStyle(fontSize: 12)),
            const SizedBox(height: 12),
            // Кнопки управления
            if (!isSystemDeveloper)
              Row(
                children: [
                  if (userRole == 'admin')
                    ElevatedButton(
                      onPressed: () => _removeAdminRole(user['user_id']),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Colors.red,
                        foregroundColor: Colors.white,
                        padding: const EdgeInsets.symmetric(horizontal: 12),
                      ),
                      child: const Text('Снять админа'),
                    ),
                  const SizedBox(width: 8),
                  if (userRole == 'user' || userRole == 'student')
                    ElevatedButton(
                      onPressed: () => _updateUserRole(user['user_id'], 'admin'),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Colors.blue,
                        foregroundColor: Colors.white,
                        padding: const EdgeInsets.symmetric(horizontal: 12),
                      ),
                      child: const Text('Сделать админом'),
                    ),
                  const SizedBox(width: 8),
                  if (userRole == 'admin')
                    ElevatedButton(
                      onPressed: () => _confirmMakeDeveloper(user),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Colors.purple,
                        foregroundColor: Colors.white,
                        padding: const EdgeInsets.symmetric(horizontal: 12),
                      ),
                      child: const Text('В разработчики'),
                    ),
                  const SizedBox(width: 8),
                  if (userRole == 'admin' || userRole == 'developer')
                    ElevatedButton(
                      onPressed: () => _updateUserRole(user['user_id'], 'user'),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Colors.green,
                        foregroundColor: Colors.white,
                        padding: const EdgeInsets.symmetric(horizontal: 12),
                      ),
                      child: const Text('В пользователи'),
                    ),
                ],
              ),
            if (isSystemDeveloper)
              Text(
                'Системный разработчик (нельзя изменить)',
                style: TextStyle(color: Colors.grey[600], fontSize: 12),
              ),
          ],
        ),
      ),
    );
  }
}