import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';

import '../constants.dart';
import '../widgets/custom_app_bar.dart';
import 'package:decanat_progect/ui/overlay_toast.dart';

class AttendanceJournalScreen extends StatefulWidget {
  const AttendanceJournalScreen({super.key});

  @override
  State<AttendanceJournalScreen> createState() => _AttendanceJournalScreenState();
}

class _AttendanceJournalScreenState extends State<AttendanceJournalScreen> {
  DateTime _date = DateTime.now();

  String? _teacherFullName;   // для фолбэка/подписи
  String? _teacherUserId;     // КЛЮЧЕВОЕ: берём из SharedPreferences(userId)
  String? _selectedGroup;
  String? _selectedSubject;

  bool _loadingMeta = true;
  bool _loadingData = false;

  final Map<String, List<String>> _groupsSubjects = {};
  List<_AttendanceRow> _rows = [];

  @override
  void initState() {
    super.initState();
    _loadTeacherAndMeta();
  }

  Future<void> _loadTeacherAndMeta() async {
    setState(() { _loadingMeta = true; });
    try {
      final prefs = await SharedPreferences.getInstance();
      _teacherUserId = prefs.getString('userId'); // <— главный источник правды
      _teacherFullName = prefs.getString('teacherFullName') ?? prefs.getString('selectedTeacher');

      if ((_teacherUserId == null || _teacherUserId!.isEmpty) &&
          (_teacherFullName == null || _teacherFullName!.trim().isEmpty)) {
        OverlayToast.instance.warning('Не удалось определить преподавателя');
        setState(() { _loadingMeta = false; });
        return;
      }

      // 1) грузим пары (group, subject)
      http.Response r;
      if (_teacherUserId != null && _teacherUserId!.isNotEmpty) {
        final uri = Uri.parse(
          '${AppConfig.serverUrl}/api/teacher-schedule/teacher_groups_by_id'
              '?teacher_user_id=${Uri.encodeComponent(_teacherUserId!)}',
        );
        r = await http.get(uri).timeout(const Duration(seconds: 10));
      } else {
        // фолбэк на старый маршрут по ФИО
        final uri = Uri.parse(
          '${AppConfig.serverUrl}/api/teacher-schedule/teacher_groups'
              '?teacher=${Uri.encodeComponent(_teacherFullName!)}',
        );
        r = await http.get(uri).timeout(const Duration(seconds: 10));
      }

      if (r.statusCode == 200) {
        final data = json.decode(r.body) as List<dynamic>;
        _groupsSubjects.clear();
        for (final e in data) {
          final m = (e as Map<String, dynamic>);
          final g = (m['group_name'] ?? '').toString();
          final s = (m['subject'] ?? '').toString();
          if (g.isEmpty || s.isEmpty) continue;
          _groupsSubjects.putIfAbsent(g, () => []);
          if (!_groupsSubjects[g]!.contains(s)) _groupsSubjects[g]!.add(s);
        }
        if (_groupsSubjects.isNotEmpty) {
          _selectedGroup ??= (_groupsSubjects.keys.toList()..sort()).first;
          final subs = _groupsSubjects[_selectedGroup]!..sort();
          if (subs.isNotEmpty) _selectedSubject ??= subs.first;
        }
      } else {
        OverlayToast.instance.error('Не удалось загрузить список групп/предметов');
      }
    } on TimeoutException {
      OverlayToast.instance.error('Сервер недоступен: таймаут', icon: Icons.cloud_off_rounded);
    } on SocketException {
      OverlayToast.instance.error('Нет подключения к интернету', icon: Icons.wifi_off_rounded);
    } catch (_) {
      OverlayToast.instance.error('Ошибка при загрузке метаданных');
    } finally {
      setState(() { _loadingMeta = false; });
      _reloadAttendance();
    }
  }

  Future<void> _reloadAttendance() async {
    if (_selectedGroup == null || _selectedSubject == null) {
      setState(() { _rows = []; });
      return;
    }
    setState(() { _loadingData = true; });
    try {
      final dateStr = _fmtIsoDate(_date);
      final uri = Uri.parse(
        '${AppConfig.serverUrl}/api/attendance'
            '?date=$dateStr'
            '&group_name=${Uri.encodeComponent(_selectedGroup!)}'
            '&subject=${Uri.encodeComponent(_selectedSubject!)}'
            '&limit=1000',
      );
      final r = await http.get(uri).timeout(const Duration(seconds: 12));
      if (r.statusCode == 200) {
        final list = json.decode(r.body) as List<dynamic>;
        _rows = list.map((e) => _AttendanceRow.fromJson(e as Map<String, dynamic>)).toList();
      } else {
        _rows = [];
      }
    } on TimeoutException {
      OverlayToast.instance.error('Сервер недоступен: таймаут', icon: Icons.cloud_off_rounded);
    } on SocketException {
      OverlayToast.instance.error('Нет подключения к интернету', icon: Icons.wifi_off_rounded);
    } catch (_) {
      OverlayToast.instance.error('Ошибка при загрузке посещаемости');
    } finally {
      if (mounted) setState(() { _loadingData = false; });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: const CustomAppBar(title: 'Журнал посещаемости', showBackButton: true),
      body: _loadingMeta
          ? const Center(child: CircularProgressIndicator())
          : Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          children: [
            _dateAndFilters(context),
            const SizedBox(height: 12),
            Expanded(
              child: _loadingData
                  ? const Center(child: CircularProgressIndicator())
                  : _rows.isEmpty
                  ? _emptyState(context)
                  : _list(context),
            ),
          ],
        ),
      ),
    );
  }

  Widget _dateAndFilters(BuildContext context) {
    final groups = _groupsSubjects.keys.toList()..sort();
    final subjects = (_selectedGroup == null) ? <String>[] : (_groupsSubjects[_selectedGroup]!..sort());

    return Material(
      elevation: 1,
      borderRadius: BorderRadius.circular(14),
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Column(
          children: [
            Row(
              children: [
                Icon(Icons.event, color: Theme.of(context).colorScheme.primary),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    _fmtHumanDate(_date),
                    style: TextStyle(
                      fontWeight: FontWeight.w700,
                      color: Theme.of(context).colorScheme.onSurface,
                    ),
                  ),
                ),
                IconButton(
                  tooltip: 'Выбрать дату',
                  onPressed: () async {
                    final picked = await showDatePicker(
                      context: context,
                      initialDate: _date,
                      firstDate: DateTime(2023, 1, 1),
                      lastDate: DateTime.now().add(const Duration(days: 365)),
                    );
                    if (picked != null) {
                      setState(() => _date = picked);
                      _reloadAttendance();
                    }
                  },
                  icon: const Icon(Icons.calendar_today),
                ),
              ],
            ),
            const SizedBox(height: 8),
            Row(
              children: [
                Expanded(
                  child: _DropdownField<String>(
                    label: 'Группа',
                    value: _selectedGroup,
                    items: groups,
                    onChanged: (v) {
                      setState(() {
                        _selectedGroup = v;
                        final subs = _groupsSubjects[v] ?? [];
                        _selectedSubject = subs.isNotEmpty ? subs.first : null;
                      });
                      _reloadAttendance();
                    },
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: _DropdownField<String>(
                    label: 'Предмет',
                    value: _selectedSubject,
                    items: subjects,
                    onChanged: (v) {
                      setState(() => _selectedSubject = v);
                      _reloadAttendance();
                    },
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _list(BuildContext context) {
    final rows = List<_AttendanceRow>.from(_rows)
      ..sort((a, b) => a.studentFullName.compareTo(b.studentFullName));

    return Material(
      elevation: 1,
      borderRadius: BorderRadius.circular(12),
      clipBehavior: Clip.antiAlias,
      child: ListView.separated(
        itemCount: rows.length,
        separatorBuilder: (_, __) =>
            Divider(height: 1, color: Theme.of(context).dividerColor.withOpacity(.6)),
        itemBuilder: (_, i) {
          final r = rows[i];
          return ListTile(
            dense: true,
            leading: CircleAvatar(child: Text(_initials(r.studentFullName))),
            title: Text(r.studentFullName, style: const TextStyle(fontWeight: FontWeight.w600)),
            subtitle: Text('ID: ${r.studentUserId}'),
            trailing: _PresenceChip(present: r.present),
          );
        },
      ),
    );
  }

  Widget _emptyState(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.surface,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Theme.of(context).dividerColor.withOpacity(.35)),
      ),
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 24),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(Icons.menu_book_outlined, size: 42, color: Theme.of(context).colorScheme.primary),
          const SizedBox(height: 12),
          Text(
            'Ещё не отмечено',
            style: TextStyle(fontWeight: FontWeight.w700, color: Theme.of(context).colorScheme.onSurface),
          ),
          const SizedBox(height: 6),
          Text(
            'Для выбранной даты/группы/предмета нет записей посещаемости.',
            textAlign: TextAlign.center,
            style: TextStyle(color: Theme.of(context).colorScheme.onSurfaceVariant),
          ),
        ],
      ),
    );
  }

  String _fmtHumanDate(DateTime dt) {
    final dd = dt.day.toString().padLeft(2, '0');
    final mm = dt.month.toString().padLeft(2, '0');
    final yyyy = dt.year.toString();
    return '${_weekdayRu(dt.weekday)}, $dd.$mm.$yyyy';
  }

  String _fmtIsoDate(DateTime dt) =>
      '${dt.year.toString().padLeft(4, '0')}-${dt.month.toString().padLeft(2, '0')}-${dt.day.toString().padLeft(2, '0')}';

  String _weekdayRu(int w) {
    switch (w) {
      case 1: return 'Понедельник';
      case 2: return 'Вторник';
      case 3: return 'Среда';
      case 4: return 'Четверг';
      case 5: return 'Пятница';
      case 6: return 'Суббота';
      case 7: return 'Воскресенье';
      default: return '';
    }
  }

  String _initials(String fullName) {
    final parts = fullName.trim().split(RegExp(r'\s+'));
    if (parts.isEmpty) return '?';
    if (parts.length == 1) return parts.first.characters.first.toUpperCase();
    final b = StringBuffer();
    for (var i = 1; i < parts.length && i < 3; i++) {
      if (parts[i].isNotEmpty) b.write(parts[i][0].toUpperCase());
    }
    return b.isEmpty ? parts.first[0].toUpperCase() : b.toString();
  }
}

class _DropdownField<T> extends StatelessWidget {
  final String label;
  final T? value;
  final List<T> items;
  final ValueChanged<T?> onChanged;

  const _DropdownField({
    required this.label,
    required this.value,
    required this.items,
    required this.onChanged,
  });

  @override
  Widget build(BuildContext context) {
    return InputDecorator(
      decoration: InputDecoration(
        labelText: label,
        border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
        contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      ),
      child: DropdownButtonHideUnderline(
        child: DropdownButton<T>(
          isExpanded: true,
          value: value,
          items: items.map((e) => DropdownMenuItem<T>(value: e, child: Text(e.toString()))).toList(),
          onChanged: onChanged,
        ),
      ),
    );
  }
}

class _PresenceChip extends StatelessWidget {
  final bool present;
  const _PresenceChip({required this.present});

  @override
  Widget build(BuildContext context) {
    final c = present ? Colors.green : Theme.of(context).colorScheme.outline;
    final t = present ? 'Был' : 'Не был';
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(24),
        color: c.withOpacity(.12),
        border: Border.all(color: c.withOpacity(.35)),
      ),
      child: Text(t, style: TextStyle(color: c, fontWeight: FontWeight.w700, fontSize: 12)),
    );
  }
}

class _AttendanceRow {
  final String studentUserId;
  final String studentFullName;
  final bool present;

  _AttendanceRow({
    required this.studentUserId,
    required this.studentFullName,
    required this.present,
  });

  factory _AttendanceRow.fromJson(Map<String, dynamic> json) {
    return _AttendanceRow(
      studentUserId: (json['student_user_id'] ?? '').toString(),
      studentFullName: (json['student_full_name'] ?? '').toString(),
      present: (json['present'] ?? 0) == 1 || json['present'] == true,
    );
  }
}
