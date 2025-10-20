import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';
import 'package:decanat_progect/constants.dart';
import 'package:decanat_progect/screens/profile_screen.dart';

class StudentInfoScreen extends StatefulWidget {
  const StudentInfoScreen({super.key});

  @override
  State<StudentInfoScreen> createState() => _StudentInfoScreenState();
}

class _StudentInfoScreenState extends State<StudentInfoScreen> {
  final TextEditingController _search = TextEditingController();

  bool _loadingGroups = false;
  bool _loadingStudents = false;
  bool _error = false;

  List<String> _groups = [];
  String? _selectedGroup;

  List<_StudentRow> _students = [];
  List<_StudentRow> _filtered = [];

  @override
  void initState() {
    super.initState();
    _init();
    _search.addListener(_applyFilter);
  }

  @override
  void dispose() {
    _search.dispose();
    super.dispose();
  }

  Future<void> _init() async {
    await _loadGroups();
    final prefs = await SharedPreferences.getInstance();
    final last = prefs.getString('teacher_last_group');
    if (mounted && last != null && _groups.contains(last)) {
      setState(() => _selectedGroup = last);
      await _loadStudents(last);
    }
  }

  Future<void> _loadGroups() async {
    setState(() {
      _loadingGroups = true;
      _error = false;
    });
    try {
      final uri = Uri.parse('${AppConfig.serverUrl}/api/groups');
      final res = await http.get(uri).timeout(const Duration(seconds: 8));
      if (res.statusCode == 200) {
        final data = jsonDecode(res.body) as List;
        final list = data.map((e) => e.toString()).toList()..sort();
        setState(() => _groups = list);
      } else {
        setState(() => _error = true);
      }
    } catch (_) {
      setState(() => _error = true);
    } finally {
      setState(() => _loadingGroups = false);
    }
  }

  Future<void> _loadStudents(String group) async {
    setState(() {
      _loadingStudents = true;
      _error = false;
    });
    try {
      final uri = Uri.parse(
        '${AppConfig.serverUrl}/api/students?group=${Uri.encodeComponent(group)}',
      );
      final res = await http.get(uri).timeout(const Duration(seconds: 10));
      if (res.statusCode == 200) {
        final data = jsonDecode(res.body) as List;
        final rows = data.map((j) => _StudentRow.fromJson(j)).toList()
          ..sort((a, b) => a.fullName.compareTo(b.fullName));
        setState(() => _students = rows);
        _applyFilter();

        final prefs = await SharedPreferences.getInstance();
        await prefs.setString('teacher_last_group', group);
      } else {
        setState(() => _error = true);
      }
    } catch (_) {
      setState(() => _error = true);
    } finally {
      setState(() => _loadingStudents = false);
    }
  }

  void _applyFilter() {
    final q = _search.text.trim().toLowerCase();
    if (q.isEmpty) {
      setState(() => _filtered = List.of(_students));
      return;
    }
    setState(() {
      _filtered = _students.where((s) {
        return s.fullName.toLowerCase().contains(q) ||
            (s.phone?.toLowerCase().contains(q) ?? false) ||
            (s.email?.toLowerCase().contains(q) ?? false) ||
            (s.recordBook?.toLowerCase().contains(q) ?? false) ||
            s.userId.toLowerCase().contains(q);
      }).toList();
    });
  }

  Future<void> _onRefresh() async {
    final g = _selectedGroup;
    if (g != null) {
      await _loadStudents(g);
    } else {
      await _loadGroups();
    }
  }

  void _openStudentProfile(_StudentRow s) {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => ProfileScreen(
          userIdOverride: s.userId,
          roleOverride: 'student',
          readOnly: true, // только просмотр, без редактирования/пароля
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Информация о студентах'),
        actions: [
          IconButton(
            onPressed: _onRefresh,
            icon: const Icon(Icons.refresh),
            tooltip: 'Обновить',
          ),
        ],
      ),
      body: Column(
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 12, 16, 8),
            child: Row(
              children: [
                Expanded(
                  child: DecoratedBox(
                    decoration: BoxDecoration(
                      borderRadius: BorderRadius.circular(14),
                      border: Border.all(color: Theme.of(context).dividerColor.withOpacity(0.6)),
                    ),
                    child: Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 12),
                      child: DropdownButtonHideUnderline(
                        child: DropdownButton<String>(
                          value: _selectedGroup,
                          hint: const Text('Выберите группу'),
                          isExpanded: true,
                          items: _groups
                              .map((g) => DropdownMenuItem(value: g, child: Text(g)))
                              .toList(),
                          onChanged: (g) => g == null ? null : _loadStudentsOnSelect(g),
                        ),
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 0, 16, 8),
            child: TextField(
              controller: _search,
              decoration: InputDecoration(
                hintText: 'Поиск: ФИО, телефон, e-mail, зачётка, ID',
                prefixIcon: const Icon(Icons.search),
                isDense: true,
                border: OutlineInputBorder(borderRadius: BorderRadius.circular(14)),
              ),
            ),
          ),
          Expanded(child: _buildBody()),
        ],
      ),
    );
  }

  Future<void> _loadStudentsOnSelect(String group) async {
    setState(() => _selectedGroup = group);
    await _loadStudents(group);
  }

  Widget _buildBody() {
    if (_loadingGroups || _loadingStudents) {
      return const Center(child: CircularProgressIndicator());
    }
    if (_error) {
      return Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(Icons.error_outline, size: 36),
            const SizedBox(height: 8),
            const Text('Не удалось загрузить данные'),
            const SizedBox(height: 12),
            ElevatedButton.icon(
              onPressed: _onRefresh,
              icon: const Icon(Icons.refresh),
              label: const Text('Повторить'),
            ),
          ],
        ),
      );
    }
    if (_selectedGroup == null) {
      return const Center(child: Text('Выберите группу, чтобы увидеть студентов'));
    }
    if (_filtered.isEmpty) {
      return const Center(child: Text('Нет студентов или ничего не найдено'));
    }

    return RefreshIndicator(
      onRefresh: _onRefresh,
      child: ListView.separated(
        padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
        itemCount: _filtered.length,
        separatorBuilder: (_, __) => const SizedBox(height: 10),
        itemBuilder: (_, i) {
          final s = _filtered[i];
          return InkWell(
            onTap: () => _openStudentProfile(s),
            borderRadius: BorderRadius.circular(16),
            child: _StudentCard(student: s),
          );
        },
      ),
    );
  }
}

class _StudentRow {
  final String userId;
  final String fullName;
  final String? phone;
  final String? email;
  final String? recordBook;

  _StudentRow({
    required this.userId,
    required this.fullName,
    this.phone,
    this.email,
    this.recordBook,
  });

  factory _StudentRow.fromJson(Map<String, dynamic> j) {
    String? _nullIfEmpty(dynamic v) {
      final s = v?.toString().trim();
      return (s == null || s.isEmpty) ? null : s;
    }

    return _StudentRow(
      userId: j['user_id']?.toString() ?? '',
      fullName: j['full_name']?.toString() ?? '',
      phone: _nullIfEmpty(j['phone']),
      email: _nullIfEmpty(j['email']),
      recordBook: _nullIfEmpty(j['record_book_number']),
    );
  }
}

class _StudentCard extends StatelessWidget {
  final _StudentRow student;
  const _StudentCard({required this.student});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    String initials = '';
    final parts = student.fullName.split(RegExp(r'\s+')).where((p) => p.isNotEmpty).toList();
    if (parts.isNotEmpty) initials += parts.first[0].toUpperCase();
    if (parts.length > 1) initials += parts.last[0].toUpperCase();

    Widget chip(IconData ic, String text, {bool muted = false}) {
      final color = muted
          ? theme.textTheme.bodySmall?.color?.withOpacity(0.6)
          : theme.textTheme.bodySmall?.color;
      return Container(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(999),
          border: Border.all(color: theme.dividerColor.withOpacity(0.5)),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(ic, size: 16, color: color),
            const SizedBox(width: 6),
            Text(text, style: TextStyle(fontSize: 12.5, color: color)),
          ],
        ),
      );
    }

    return Material(
      color: theme.colorScheme.surface,
      elevation: 0,
      borderRadius: BorderRadius.circular(16),
      child: Container(
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: theme.dividerColor.withOpacity(0.5)),
        ),
        padding: const EdgeInsets.all(14),
        child: Row(
          children: [
            CircleAvatar(radius: 22, child: Text(initials.isEmpty ? '—' : initials)),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(student.fullName, style: const TextStyle(fontWeight: FontWeight.w600)),
                  const SizedBox(height: 6),
                  Wrap(
                    spacing: 14,
                    runSpacing: 6,
                    children: [
                      chip(Icons.badge_outlined, 'ID: ${student.userId}'),
                      chip(Icons.credit_card, student.recordBook ?? 'Зачётка: —', muted: student.recordBook == null),
                      chip(Icons.phone_outlined, student.phone ?? '—', muted: student.phone == null),
                      chip(Icons.mail_outline, student.email ?? '—', muted: student.email == null),
                    ],
                  ),
                ],
              ),
            ),
            const Icon(Icons.chevron_right_rounded),
          ],
        ),
      ),
    );
  }
}
