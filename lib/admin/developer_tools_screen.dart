// lib/admin/developer_tools_screen.dart
import 'dart:async';
import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:http/http.dart' as http;

import 'package:decanat_progect/constants.dart';
import 'package:decanat_progect/widgets/custom_app_bar.dart';
import 'package:decanat_progect/ui/overlay_toast.dart';
import 'package:decanat_progect/screens/profile_screen.dart';

class DeveloperToolsScreen extends StatefulWidget {
  const DeveloperToolsScreen({super.key});

  @override
  State<DeveloperToolsScreen> createState() => _DeveloperToolsScreenState();
}

class _DeveloperToolsScreenState extends State<DeveloperToolsScreen>
    with SingleTickerProviderStateMixin {
  // Приложение показывает время в UTC+6 (MSK+3)
  static const int kAppTzOffsetHoursFromUtc = 6;
  static const bool kNaiveIsMsk = false;

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
    _loadUsers();
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
        _toast('Ошибка загрузки пользователей', icon: Icons.warning_amber_rounded);
        setState(() => _isLoading = false);
      }
    } catch (_) {
      _toast('Ошибка подключения к серверу', icon: Icons.warning_amber_rounded);
      setState(() => _isLoading = false);
    }
  }

  void _sortAndFilterUsers() {
    _users.sort((a, b) {
      if (a['user_id'] == '000000') return -1;
      if (b['user_id'] == '000000') return 1;

      const roleOrder = {'developer': 0, 'admin': 1, 'teacher': 2, 'student': 3, 'user': 4};
      final ar = a['role'] ?? 'user';
      final br = b['role'] ?? 'user';
      final cmpRole = (roleOrder[ar] ?? 4).compareTo(roleOrder[br] ?? 4);
      if (cmpRole != 0) return cmpRole;

      final au = (a['user_id'] ?? '').toString();
      final bu = (b['user_id'] ?? '').toString();
      return au.compareTo(bu);
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

  // ===== Уведомления (кастомные тосты) =====
  void _toast(String msg, {IconData icon = Icons.info_outline_rounded, Color? accent}) {
    OverlayToast.instance.show(msg, icon: icon, accent: accent ?? AppColors.accent);
  }

  // ===== Работа со временем и таймзонами =====
  bool _hasTz(String s) => s.endsWith('Z') || RegExp(r'[+\-]\d{2}:\d{2}$').hasMatch(s);

  DateTime _parseServerTimeToUtc(String isoMaybeNaive) {
    final s = isoMaybeNaive.trim();
    if (_hasTz(s)) {
      final dt = DateTime.parse(s);
      return dt.isUtc ? dt : dt.toUtc();
    }
    final naive = DateTime.parse(s);
    if (kNaiveIsMsk) {
      final utc = DateTime.utc(
        naive.year, naive.month, naive.day,
        naive.hour, naive.minute, naive.second, naive.millisecond, naive.microsecond,
      ).subtract(const Duration(hours: 3));
      return utc;
    } else {
      return DateTime.utc(
        naive.year, naive.month, naive.day,
        naive.hour, naive.minute, naive.second, naive.millisecond, naive.microsecond,
      );
    }
  }

  DateTime _toAppTz(DateTime utc) => utc.add(const Duration(hours: kAppTzOffsetHoursFromUtc));

  String _tzSuffix() => 'UTC${kAppTzOffsetHoursFromUtc >= 0 ? '+' : ''}$kAppTzOffsetHoursFromUtc';

  String _formatDateTimeAppTz(String iso) {
    try {
      if (iso.isEmpty) return '—';
      final utc = _parseServerTimeToUtc(iso);
      final local = _toAppTz(utc);
      final m = local.month.toString().padLeft(2, '0');
      final d = local.day.toString().padLeft(2, '0');
      final hh = local.hour.toString().padLeft(2, '0');
      final mm = local.minute.toString().padLeft(2, '0');
      return '$d.$m.${local.year} $hh:$mm';
    } catch (_) {
      return iso;
    }
  }

  String _formatLastSeenRelativeAppTz(String iso) {
    try {
      if (iso.isEmpty) return 'офлайн';
      final utc = _parseServerTimeToUtc(iso);
      final local = _toAppTz(utc);
      final nowLocal = _toAppTz(DateTime.now().toUtc());
      final diff = nowLocal.difference(local);

      if (diff.inSeconds.abs() <= 30) return 'только что';
      if (diff.inMinutes < 1) return '${diff.inSeconds} сек назад';
      if (diff.inHours < 1) return '${diff.inMinutes} мин назад';
      if (diff.inHours < 12) return '${diff.inHours} ч назад';

      return _formatDateTimeAppTz(iso);
    } catch (_) {
      return _formatDateTimeAppTz(iso);
    }
  }

  // ===== Роли/цвета/иконки =====
  Color _getRoleColor(String role) {
    switch (role) {
      case 'developer':
        return Colors.purple;
      case 'admin':
        return Colors.blue;
      case 'teacher':
        return Colors.green;
      case 'student':
        return Colors.orange;
      default:
        return Colors.grey;
    }
  }

  String _getRoleName(String role) {
    switch (role) {
      case 'developer':
        return 'Разработчик';
      case 'admin':
        return 'Администратор';
      case 'teacher':
        return 'Преподаватель';
      case 'student':
        return 'Студент';
      default:
        return 'Пользователь';
    }
  }

  IconData _getRoleIcon(String role) {
    switch (role) {
      case 'developer':
        return Icons.developer_mode;
      case 'admin':
        return Icons.admin_panel_settings;
      case 'teacher':
        return Icons.person;
      case 'student':
        return Icons.school;
      default:
        return Icons.person_outline;
    }
  }

  // ===== Действия с ролями =====
  void _confirmMakeDeveloper(Map<String, dynamic> user) {
    showDialog(
      context: context,
      builder: (_) => AlertDialog(
        title: const Text('Подтверждение'),
        content: Text(
          'Сделать пользователя ${user['user_id']} разработчиком?\n\n'
              '⚠️ Это действие необратимо (полный доступ).',
          style: const TextStyle(fontSize: 14),
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context), child: const Text('Отмена')),
          TextButton(
            onPressed: () {
              Navigator.pop(context);
              _updateUserRole(user['user_id'], 'developer');
            },
            style: TextButton.styleFrom(foregroundColor: Colors.redAccent),
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
        _toast('Роль обновлена', icon: Icons.check_circle_rounded, accent: Colors.green);
        _loadUsers();
      } else {
        _toast('Ошибка обновления роли', icon: Icons.warning_amber_rounded);
      }
    } catch (_) {
      _toast('Ошибка подключения', icon: Icons.warning_amber_rounded);
    }
  }

  Future<void> _removeAdminRole(String userId) async {
    try {
      final response = await http.delete(Uri.parse('${AppConfig.serverUrl}/api/users/$userId/admin'));
      if (response.statusCode == 200) {
        _toast('Права администратора сняты', icon: Icons.check_circle_rounded, accent: Colors.green);
        _loadUsers();
      } else {
        final errorData = json.decode(response.body);
        _toast(errorData['detail'] ?? 'Ошибка снятия прав', icon: Icons.warning_amber_rounded);
      }
    } catch (e) {
      _toast('Ошибка подключения: $e', icon: Icons.warning_amber_rounded);
    }
  }

  // ===== Профиль =====
  void _openUserProfile(Map<String, dynamic> user) {
    final String uid = (user['user_id'] ?? '').toString();
    final String role = (user['role'] ?? 'user').toString();

    if (uid.isEmpty) {
      _toast('Некорректный ID пользователя', icon: Icons.warning_amber_rounded);
      return;
    }

    final bool canEdit = _userRole == 'developer';

    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => ProfileScreen(
          userIdOverride: uid,
          roleOverride: role,
          readOnly: !canEdit,
        ),
      ),
    );
  }

  // ===== Виджеты статистики/списков =====
  Widget _buildStatCard(String title, int count, Color color) {
    return Container(
      margin: const EdgeInsets.only(right: 8),
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
      decoration: BoxDecoration(
        border: Border.all(color: color.withOpacity(.5)),
        borderRadius: BorderRadius.circular(10),
        color: color.withOpacity(.06),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(title, style: TextStyle(fontSize: 12, color: Colors.grey[700])),
          const SizedBox(height: 2),
          Text('$count', style: TextStyle(fontSize: 15, fontWeight: FontWeight.bold, color: color)),
        ],
      ),
    );
  }

  Widget _buildStatistics(List<dynamic> users, bool isAllUsersTab) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 8, 16, 8),
      child: SingleChildScrollView(
        scrollDirection: Axis.horizontal,
        child: Row(
          children: [
            _buildStatCard('Всего', users.length, Colors.grey),
            if (isAllUsersTab)
              _buildStatCard('Админы', users.where((u) => u['role'] == 'admin').length, Colors.blue),
            if (!isAllUsersTab)
              _buildStatCard('Преподаватели', users.where((u) => u['role'] == 'teacher').length, Colors.green),
            if (!isAllUsersTab)
              _buildStatCard('Студенты', users.where((u) => u['role'] == 'student').length, Colors.orange),
            if (isAllUsersTab)
              _buildStatCard('Пользователи', users.where((u) => u['role'] == 'user').length, Colors.grey[600]!),
            _buildStatCard('Онлайн', users.where((u) => (u['online'] ?? false) == true).length, Colors.green),
          ],
        ),
      ),
    );
  }

  // ===== Карточка пользователя =====
  Widget _buildUserCard(Map<String, dynamic> user) {
    final isCurrentUser = user['user_id'] == _userId;
    final isSystemDeveloper = user['user_id'] == '000000';

    final role = (user['role'] ?? 'user') as String;
    final String uid = (user['user_id'] ?? '').toString();
    final String? fullName = user['full_name'];
    final String login = (user['login'] ?? '').toString();
    final String? groupName = user['group_name'];

    final bool online = (user['online'] ?? false) == true;
    final String lastSeenIso = (user['last_seen'] ?? '') as String;

    final roleColor = _getRoleColor(role);
    final roleIcon = _getRoleIcon(role);

    // Выпадающее меню ролей (с иконками и цветами)
    Widget roleMenu() {
      return PopupMenuButton<String>(
        tooltip: 'Назначить роль',
        onSelected: (value) {
          if (value == 'developer') {
            _confirmMakeDeveloper(user);
          } else if (value == 'remove_admin') {
            _removeAdminRole(uid);
          } else {
            _updateUserRole(uid, value);
          }
        },
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        itemBuilder: (ctx) => [
          _roleItem('developer', 'Разработчик', Icons.developer_mode, Colors.purple),
          _roleItem('admin', 'Администратор', Icons.admin_panel_settings, Colors.blue),
          _roleItem('teacher', 'Преподаватель', Icons.person, Colors.green),
          _roleItem('student', 'Студент', Icons.school, Colors.orange),
          _roleItem('user', 'Пользователь', Icons.person_outline, Colors.grey),
          if (role == 'admin')
            _roleItem('remove_admin', 'Снять админа', Icons.remove_moderator, Colors.red),
        ],
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
          decoration: BoxDecoration(
            border: Border.all(color: roleColor.withOpacity(.4)),
            borderRadius: BorderRadius.circular(10),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(roleIcon, color: roleColor, size: 18),
              const SizedBox(width: 6),
              Text(_getRoleName(role),
                  style: TextStyle(fontWeight: FontWeight.w600, color: roleColor, fontSize: 13)),
              const SizedBox(width: 4),
              Icon(Icons.arrow_drop_down, color: roleColor, size: 18),
            ],
          ),
        ),
      );
    }

    // онлайн/офлайн компактно
    Widget onlineChip() {
      final label = online ? 'Онлайн' : (lastSeenIso.isNotEmpty ? _formatLastSeenRelativeAppTz(lastSeenIso) : 'Офлайн');
      return Container(
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
        decoration: BoxDecoration(
          color: (online ? Colors.green : Colors.grey).withOpacity(.12),
          border: Border.all(color: online ? Colors.green : Colors.grey),
          borderRadius: BorderRadius.circular(999),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(width: 8, height: 8, decoration: BoxDecoration(color: online ? Colors.green : Colors.grey, shape: BoxShape.circle)),
            const SizedBox(width: 6),
            Text(label, style: const TextStyle(fontSize: 12)),
          ],
        ),
      );
    }

    // Карточка
    return InkWell(
      onTap: () => _openUserProfile(user),
      borderRadius: BorderRadius.circular(14),
      child: Container(
        margin: const EdgeInsets.only(bottom: 10),
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: Theme.of(context).colorScheme.surface,
          borderRadius: BorderRadius.circular(14),
          border: Border.all(color: Theme.of(context).dividerColor),
          boxShadow: [
            BoxShadow(color: Colors.black.withOpacity(.06), blurRadius: 8, offset: const Offset(0, 4)),
          ],
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Верхняя строка: ИКОНКА + ID + меню ролей
            Row(
              crossAxisAlignment: CrossAxisAlignment.center,
              children: [
                // круглая иконка роли слева
                Container(
                  width: 36,
                  height: 36,
                  decoration: BoxDecoration(
                    color: roleColor.withOpacity(.12),
                    shape: BoxShape.circle,
                  ),
                  child: Icon(roleIcon, color: roleColor, size: 20),
                ),
                const SizedBox(width: 10),
                // КРУПНО: ID
                Expanded(
                  child: Text(
                    'ID: $uid',
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(fontSize: 16.5, fontWeight: FontWeight.w700),
                  ),
                ),
                const SizedBox(width: 8),
                if (user['user_id'] == '000000')
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                    decoration: BoxDecoration(
                      color: Colors.purple.withOpacity(.1),
                      border: Border.all(color: Colors.purple),
                      borderRadius: BorderRadius.circular(999),
                    ),
                    child: const Text('Системный разработчик', style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: Colors.purple)),
                  )
                else
                  roleMenu(),
              ],
            ),

            const SizedBox(height: 6),

            // ФИО/логин в одну компактную строку
            Row(
              children: [
                Icon(Icons.person_outline, size: 16, color: Colors.grey[600]),
                const SizedBox(width: 6),
                Flexible(
                  child: Text(
                    (fullName != null && fullName.isNotEmpty) ? fullName : (login.isNotEmpty ? login : 'Без имени'),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(fontSize: 13.5, color: Theme.of(context).colorScheme.onSurface.withOpacity(.85)),
                  ),
                ),
                if (isCurrentUser) ...[
                  const SizedBox(width: 8),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                    decoration: BoxDecoration(
                      color: Colors.orange.withOpacity(.15),
                      border: Border.all(color: Colors.orange),
                      borderRadius: BorderRadius.circular(999),
                    ),
                    child: const Text('Вы', style: TextStyle(fontSize: 11, fontWeight: FontWeight.w600, color: Colors.orange)),
                  ),
                ],
              ],
            ),

            if (role == 'student' && (groupName ?? '').isNotEmpty) ...[
              const SizedBox(height: 6),
              Row(
                children: [
                  Icon(Icons.group_outlined, size: 16, color: Colors.grey[600]),
                  const SizedBox(width: 6),
                  Text('Группа: $groupName', style: const TextStyle(fontSize: 12.5)),
                ],
              ),
            ],

            const SizedBox(height: 8),
            // нижняя строка: online + создан
            Row(
              children: [
                onlineChip(),
                const SizedBox(width: 10),
                Icon(Icons.event, size: 16, color: Colors.grey[600]),
                const SizedBox(width: 6),
                Text(
                  'Создан: ${_formatDateTimeAppTz(user['created_at'] ?? '')}',
                  style: const TextStyle(fontSize: 12),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  PopupMenuItem<String> _roleItem(String value, String title, IconData icon, Color color) {
    return PopupMenuItem<String>(
      value: value,
      child: Row(
        children: [
          Icon(icon, color: color, size: 18),
          const SizedBox(width: 10),
          Text(title, style: TextStyle(color: color, fontWeight: FontWeight.w600)),
        ],
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
      padding: const EdgeInsets.fromLTRB(16, 8, 16, 16),
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

    final scheme = Theme.of(context).colorScheme;

    return Scaffold(
      appBar: AppBar(
        title: const Text('Управление пользователями'),
        leading: IconButton(icon: const Icon(Icons.arrow_back), onPressed: () => Navigator.pop(context)),
        backgroundColor: AppColors.primary,
        foregroundColor: Colors.white,
        bottom: TabBar(
          controller: _tabController,
          labelColor: Colors.white,
          unselectedLabelColor: Colors.white70,
          indicatorColor: scheme.onPrimary,
          tabs: const [
            Tab(text: 'Пользователи'),
            Tab(text: 'Студ. и препод.'),
          ],
        ),
      ),
      body: Column(
        children: [
          // Поиск
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 12, 16, 8),
            child: TextField(
              controller: _searchController,
              decoration: InputDecoration(
                labelText: 'Поиск по ID, ФИО, логину, группе и т.д.',
                prefixIcon: const Icon(Icons.search),
                border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                isDense: true,
                suffixIcon: _searchController.text.isNotEmpty
                    ? IconButton(icon: const Icon(Icons.clear), onPressed: _searchController.clear)
                    : null,
              ),
            ),
          ),
          // Контент вкладок
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
                          : RefreshIndicator(
                        onRefresh: _loadUsers,
                        child: _buildUsersList(_filteredUsers),
                      ),
                    ),
                  ],
                ),
                Column(
                  children: [
                    _buildStatistics(_filteredStudentsTeachers, false),
                    Expanded(
                      child: _isLoading
                          ? const Center(child: CircularProgressIndicator())
                          : RefreshIndicator(
                        onRefresh: _loadUsers,
                        child: _buildUsersList(_filteredStudentsTeachers),
                      ),
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
