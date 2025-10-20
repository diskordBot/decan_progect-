// lib/screens/attendance_mark_screen.dart
import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';

import '../constants.dart';
import '../widgets/custom_app_bar.dart';
import 'package:decanat_progect/ui/overlay_toast.dart';

class AttendanceMarkScreen extends StatefulWidget {
  final String groupName;
  final String subject;
  final int lessonNumber;
  final String classroom;
  final String weekType;          // 'upper' | 'lower'
  final String teacherFullName;   // ФИО преподавателя

  const AttendanceMarkScreen({
    super.key,
    required this.groupName,
    required this.subject,
    required this.lessonNumber,
    required this.classroom,
    required this.weekType,
    required this.teacherFullName,
  });

  @override
  State<AttendanceMarkScreen> createState() => _AttendanceMarkScreenState();
}

class _AttendanceMarkScreenState extends State<AttendanceMarkScreen> {
  bool _loading = true;
  bool _submitting = false;
  List<_Student> _students = [];
  final Map<String, bool> _present = {}; // userId -> present?

  late final DateTime _today;

  @override
  void initState() {
    super.initState();
    _today = DateTime.now();
    _loadStudents();
  }

  Future<void> _loadStudents() async {
    setState(() => _loading = true);
    try {
      final uri = Uri.parse(
        '${AppConfig.serverUrl}/api/students?group=${Uri.encodeComponent(widget.groupName)}',
      );
      final r = await http.get(uri).timeout(const Duration(seconds: 12));

      if (r.statusCode == 200) {
        final list = json.decode(r.body) as List<dynamic>;
        _students = list.map((e) => _Student.fromJson(e as Map<String, dynamic>)).toList();

        // По умолчанию теперь НИКТО не отмечен
        for (final s in _students) {
          _present[s.userId] = false;
        }

        setState(() => _loading = false);
      } else {
        _students = [];
        setState(() => _loading = false);
        OverlayToast.instance.error('Не удалось загрузить студентов группы');
      }
    } on TimeoutException {
      setState(() => _loading = false);
      OverlayToast.instance.error('Сервер недоступен: таймаут', icon: Icons.cloud_off_rounded);
    } on SocketException {
      setState(() => _loading = false);
      OverlayToast.instance.error('Нет подключения к интернету', icon: Icons.wifi_off_rounded);
    } catch (_) {
      setState(() => _loading = false);
      OverlayToast.instance.error('Ошибка при загрузке списка студентов');
    }
  }

  Future<void> _submitAttendance() async {
    if (_submitting) return;
    setState(() => _submitting = true);

    try {
      final prefs = await SharedPreferences.getInstance();
      final userId = prefs.getString('userId') ?? '';

      final payload = {
        'date': _fmtIsoDate(_today),
        'weekday': _weekdayRu(_today.weekday),
        'group_name': widget.groupName,
        'subject': widget.subject,
        'lesson_number': widget.lessonNumber,
        'classroom': widget.classroom,
        'week_type': widget.weekType,
        'teacher_full_name': widget.teacherFullName,
        'teacher_user_id': userId,
        'records': _students.map((s) {
          return {
            'student_user_id': s.userId,
            'student_full_name': s.fullName,
            'present': _present[s.userId] ?? false,
          };
        }).toList(),
      };

      final uri = Uri.parse('${AppConfig.serverUrl}/api/attendance/mark');
      final r = await http
          .post(uri, headers: {'Content-Type': 'application/json'}, body: json.encode(payload))
          .timeout(const Duration(seconds: 15));

      if (r.statusCode == 200 || r.statusCode == 201) {
        OverlayToast.instance.success('Посещаемость сохранена');
        if (mounted) Navigator.of(context).pop(true);
      } else {
        OverlayToast.instance.error('Не удалось сохранить посещаемость');
      }
    } on TimeoutException {
      OverlayToast.instance.error('Сервер недоступен: таймаут', icon: Icons.cloud_off_rounded);
    } on SocketException {
      OverlayToast.instance.error('Нет подключения к интернету', icon: Icons.wifi_off_rounded);
    } catch (_) {
      OverlayToast.instance.error('Ошибка при сохранении посещаемости');
    } finally {
      if (mounted) setState(() => _submitting = false);
    }
  }

  void _toggleAll(bool value) {
    setState(() {
      for (final s in _students) {
        _present[s.userId] = value;
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    final dateStr = _fmtHumanDate(_today);

    return Scaffold(
      appBar: const CustomAppBar(
        title: 'Отметка присутствующих',
        showBackButton: true,
      ),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              _headerCard(context, dateStr),
              const SizedBox(height: 10),
              _groupCard(context),
              const SizedBox(height: 10),

              // --- Первая строка кнопок ---
              Row(
                children: [
                  Expanded(
                    child: _PrimaryOutlinedButton(
                      icon: Icons.done_all,
                      label: 'Отметить всех',
                      onPressed: () => _toggleAll(true),
                    ),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: _SecondaryOutlinedButton(
                      icon: Icons.clear_all,
                      label: 'Снять все',
                      onPressed: () => _toggleAll(false),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 10),

              // --- Вторая строка: Сохранить (по центру, ширина поменьше) ---
              Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  ConstrainedBox(
                    constraints: const BoxConstraints(maxWidth: 320),
                    child: SizedBox(
                      width: double.infinity,
                      child: FilledButton.icon(
                        onPressed: _submitting ? null : _submitAttendance,
                        icon: _submitting
                            ? const SizedBox(
                            width: 18, height: 18, child: CircularProgressIndicator(strokeWidth: 2))
                            : const Icon(Icons.save),
                        label: Text(_submitting ? 'Сохранение...' : 'Сохранить'),
                        style: FilledButton.styleFrom(
                          padding: const EdgeInsets.symmetric(vertical: 12),
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                        ),
                      ),
                    ),
                  ),
                ],
              ),

              const SizedBox(height: 12),
              Expanded(
                child: Material(
                  elevation: 1,
                  borderRadius: BorderRadius.circular(12),
                  clipBehavior: Clip.antiAlias,
                  child: ListView.separated(
                    itemCount: _students.length,
                    separatorBuilder: (_, __) => Divider(
                      height: 1,
                      color: Theme.of(context).dividerColor.withOpacity(.6),
                    ),
                    itemBuilder: (_, i) {
                      final s = _students[i];
                      final present = _present[s.userId] ?? false;
                      return InkWell(
                        onTap: () => setState(() => _present[s.userId] = !present),
                        child: AnimatedContainer(
                          duration: const Duration(milliseconds: 160),
                          curve: Curves.easeInOut,
                          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 6),
                          color: present
                              ? Theme.of(context).colorScheme.primary.withOpacity(0.06)
                              : Colors.transparent,
                          child: Row(
                            children: [
                              // Индикатор статуса
                              _StatusDot(color: present
                                  ? Colors.green
                                  : Theme.of(context).colorScheme.outline),

                              const SizedBox(width: 10),
                              CircleAvatar(
                                radius: 16,
                                child: Text(_initials(s.fullName)),
                              ),
                              const SizedBox(width: 12),
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text(
                                      s.fullName,
                                      style: TextStyle(
                                        fontWeight: FontWeight.w600,
                                        color: Theme.of(context).colorScheme.onSurface,
                                      ),
                                      maxLines: 1,
                                      overflow: TextOverflow.ellipsis,
                                    ),
                                    const SizedBox(height: 2),
                                    Text(
                                      'ID: ${s.userId}',
                                      style: TextStyle(
                                        fontSize: 12,
                                        color: Theme.of(context).colorScheme.onSurfaceVariant,
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                              const SizedBox(width: 8),
                              Checkbox.adaptive(
                                value: present,
                                onChanged: (v) => setState(() => _present[s.userId] = v ?? false),
                              ),
                            ],
                          ),
                        ),
                      );
                    },
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _headerCard(BuildContext context, String dateStr) {
    final weekChipColor = widget.weekType == 'upper'
        ? Colors.blue
        : Colors.deepPurple;

    return Container(
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.surface,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: Theme.of(context).dividerColor.withOpacity(.4)),
      ),
      padding: const EdgeInsets.all(12),
      child: Row(
        children: [
          Icon(Icons.event, color: Theme.of(context).colorScheme.primary),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              dateStr,
              style: TextStyle(
                fontWeight: FontWeight.w700,
                color: Theme.of(context).colorScheme.onSurface,
              ),
            ),
          ),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
            decoration: BoxDecoration(
              color: weekChipColor.withOpacity(.12),
              borderRadius: BorderRadius.circular(24),
              border: Border.all(color: weekChipColor.withOpacity(.35)),
            ),
            child: Text(
              widget.weekType == 'upper' ? 'Верхняя' : 'Нижняя',
              style: TextStyle(
                fontWeight: FontWeight.w700,
                color: weekChipColor,
                fontSize: 12,
                letterSpacing: .2,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _groupCard(BuildContext context) {
    final labelStyle = TextStyle(
      color: Theme.of(context).colorScheme.onSurfaceVariant,
      fontSize: 12,
      letterSpacing: .2,
    );
    final valueStyle = TextStyle(
      color: Theme.of(context).colorScheme.onSurface,
      fontWeight: FontWeight.w600,
    );

    Widget row(IconData ic, String label, String value) {
      return Padding(
        padding: const EdgeInsets.symmetric(vertical: 2),
        child: Row(
          children: [
            Icon(ic, size: 16, color: Theme.of(context).colorScheme.primary),
            const SizedBox(width: 8),
            Text(label, style: labelStyle),
            const SizedBox(width: 6),
            Expanded(
              child: Text(value, style: valueStyle, overflow: TextOverflow.ellipsis),
            ),
          ],
        ),
      );
    }

    return Container(
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.surface,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: Theme.of(context).dividerColor.withOpacity(.4)),
      ),
      padding: const EdgeInsets.all(12),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          row(Icons.group, 'Группа:', widget.groupName),
          row(Icons.book, 'Предмет:', widget.subject),
          row(Icons.confirmation_number, 'Пара:', '${widget.lessonNumber}'),
          if (widget.classroom.isNotEmpty) row(Icons.room, 'Аудитория:', widget.classroom),
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

  String _fmtIsoDate(DateTime dt) {
    return '${dt.year.toString().padLeft(4, '0')}-'
        '${dt.month.toString().padLeft(2, '0')}-'
        '${dt.day.toString().padLeft(2, '0')}';
  }

  String _weekdayRu(int w) {
    switch (w) {
      case 1:
        return 'Понедельник';
      case 2:
        return 'Вторник';
      case 3:
        return 'Среда';
      case 4:
        return 'Четверг';
      case 5:
        return 'Пятница';
      case 6:
        return 'Суббота';
      case 7:
        return 'Воскресенье';
      default:
        return '';
    }
  }

  String _initials(String fullName) {
    final parts = fullName.trim().split(RegExp(r'\s+'));
    if (parts.length == 1) return parts.first.characters.first.toUpperCase();
    final buf = StringBuffer();
    for (var i = 1; i < parts.length && i < 3; i++) {
      if (parts[i].isNotEmpty) buf.write(parts[i][0].toUpperCase());
    }
    return buf.isEmpty ? parts.first[0].toUpperCase() : buf.toString();
  }
}

class _Student {
  final String userId;
  final String fullName;

  _Student({required this.userId, required this.fullName});

  factory _Student.fromJson(Map<String, dynamic> json) {
    return _Student(
      userId: (json['user_id'] ?? json['id'] ?? '').toString(),
      fullName: (json['full_name'] ?? json['fio'] ?? '').toString(),
    );
  }
}

/// Маленькая точка-статус слева от аватара
class _StatusDot extends StatelessWidget {
  final Color color;
  const _StatusDot({required this.color});

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 10,
      height: 10,
      decoration: BoxDecoration(color: color, shape: BoxShape.circle),
    );
  }
}

/// Стильные кнопки (согласованные паддинги/радиус/иконка)
class _PrimaryOutlinedButton extends StatelessWidget {
  final IconData icon;
  final String label;
  final VoidCallback onPressed;
  const _PrimaryOutlinedButton({required this.icon, required this.label, required this.onPressed});

  @override
  Widget build(BuildContext context) {
    return OutlinedButton.icon(
      onPressed: onPressed,
      icon: Icon(icon),
      label: Text(label, overflow: TextOverflow.ellipsis),
      style: OutlinedButton.styleFrom(
        padding: const EdgeInsets.symmetric(vertical: 12),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      ),
    );
  }
}

class _SecondaryOutlinedButton extends StatelessWidget {
  final IconData icon;
  final String label;
  final VoidCallback onPressed;
  const _SecondaryOutlinedButton({required this.icon, required this.label, required this.onPressed});

  @override
  Widget build(BuildContext context) {
    return OutlinedButton.icon(
      onPressed: onPressed,
      icon: Icon(icon),
      label: Text(label, overflow: TextOverflow.ellipsis),
      style: OutlinedButton.styleFrom(
        padding: const EdgeInsets.symmetric(vertical: 12),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      ),
    );
  }
}
