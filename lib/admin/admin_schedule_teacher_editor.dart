// lib/admin/admin_schedule_teacher_editor.dart
import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';

import 'package:decanat_progect/constants.dart';
import 'package:decanat_progect/ui/overlay_toast.dart'; // 👈 кастомные уведомления

/// Диалог выбора действия при несохранённых изменениях
enum _SaveAction { save, discard, cancel }

class AdminScheduleTeacherEditor extends StatefulWidget {
  const AdminScheduleTeacherEditor({super.key});

  @override
  State<AdminScheduleTeacherEditor> createState() =>
      _AdminScheduleTeacherEditorState();
}

class _AdminScheduleTeacherEditorState
    extends State<AdminScheduleTeacherEditor> {
  // ---------- Источники данных ----------
  List<String> teachers = [];
  String? selectedTeacher;

  // ---------- UI-состояние ----------
  bool isLoading = true;
  bool isLoadingSchedule = false;
  bool isEditingExisting = false;
  bool _isDropdownOpen = false;
  bool _isDirty = false;

  // ---------- Недели/дни ----------
  String selectedWeek = 'upper'; // 'upper' | 'lower'
  final List<String> daysOfWeek = const [
    'Понедельник',
    'Вторник',
    'Среда',
    'Четверг',
    'Пятница',
    'Суббота',
  ];
  final List<String> lessonTypes = const ['лекц', 'пр', 'лб'];

  // ---------- Данные расписания ----------
  final Map<String, List<TeacherScheduleItem>> upperWeekSchedule = {};
  final Map<String, List<TeacherScheduleItem>> lowerWeekSchedule = {};

  // ---------- Контроллеры ввода ----------
  final Map<String, TextEditingController> subjectControllers = {};
  final Map<String, TextEditingController> classroomControllers = {};
  final Map<String, TextEditingController> groupControllers = {};

  // ---------- Жизненный цикл ----------
  @override
  void initState() {
    super.initState();
    _loadTeachers();
  }

  @override
  void dispose() {
    _disposeAndClearAllControllers();
    super.dispose();
  }

  // ========================================================================
  //                              УТИЛИТЫ
  // ========================================================================

  // красивый верхний тост (использует выбранный пользователем стиль)
  void _toast(
      String message, {
        IconData icon = Icons.info_outline_rounded,
        Color? accent,
        Duration duration = const Duration(seconds: 2),
      }) {
    OverlayToast.instance.show(
      message,
      icon: icon,
      accent: accent ?? AppColors.accent,
      duration: duration,
    );
  }

  void _ensureEmptyStructure() {
    for (final d in daysOfWeek) {
      upperWeekSchedule.putIfAbsent(d, () => []);
      lowerWeekSchedule.putIfAbsent(d, () => []);
    }
  }

  void _disposeAndClearAllControllers() {
    for (final c in subjectControllers.values) c.dispose();
    for (final c in classroomControllers.values) c.dispose();
    for (final c in groupControllers.values) c.dispose();
    subjectControllers.clear();
    classroomControllers.clear();
    groupControllers.clear();
  }

  void _dropControllersForDayWeek(String day, String week) {
    final prefix = '$day-';
    final suffix = '-$week';

    void removeMatching(Map<String, TextEditingController> map) {
      final toRemove = <String>[];
      map.forEach((k, v) {
        if (k.startsWith(prefix) && k.endsWith(suffix)) {
          v.dispose();
          toRemove.add(k);
        }
      });
      for (final k in toRemove) {
        map.remove(k);
      }
    }

    removeMatching(subjectControllers);
    removeMatching(classroomControllers);
    removeMatching(groupControllers);
  }

  void _dropControllersForWeek(String week) {
    final suffix = '-$week';

    void removeMatching(Map<String, TextEditingController> map) {
      final toRemove = <String>[];
      map.forEach((k, v) {
        if (k.endsWith(suffix)) {
          v.dispose();
          toRemove.add(k);
        }
      });
      for (final k in toRemove) {
        map.remove(k);
      }
    }

    removeMatching(subjectControllers);
    removeMatching(classroomControllers);
    removeMatching(groupControllers);
  }

  String _ctrlKey(String day, int index, String week) => '$day-$index-$week';

  Map<String, List<TeacherScheduleItem>> get _weekMap =>
      selectedWeek == 'upper' ? upperWeekSchedule : lowerWeekSchedule;

  // ========================================================================
  //                             ЗАГРУЗКА ДАННЫХ
  // ========================================================================

  Future<void> _loadTeachers() async {
    try {
      final resp =
      await http.get(Uri.parse('${AppConfig.serverUrl}/api/teachers'));
      if (resp.statusCode == 200) {
        final List<dynamic> data = json.decode(resp.body);
        teachers = data
            .map((t) => (t as Map<String, dynamic>)['full_name'] as String)
            .toList();

        // кэш
        final prefs = await SharedPreferences.getInstance();
        await prefs.setStringList('teachersList', teachers);

        setState(() => isLoading = false);
        return;
      }
      _loadLocalTeachers();
    } catch (_) {
      _loadLocalTeachers();
    }
  }

  Future<void> _loadLocalTeachers() async {
    final prefs = await SharedPreferences.getInstance();
    final cached = prefs.getStringList('teachersList');
    setState(() {
      teachers = cached ??
          [
            'Иванов И.И.',
            'Петров П.П.',
            'Сидоров С.С.',
            'Кузнецова А.В.',
            'Смирнов Д.О.',
            'Васильева Е.П.',
            'Николаев М.С.',
            'Орлова Т.К.',
          ];
      isLoading = false;
    });
  }

  Future<void> _loadExistingSchedule() async {
    if (selectedTeacher == null) return;

    setState(() => isLoadingSchedule = true);

    try {
      final resp = await http.get(Uri.parse(
          '${AppConfig.serverUrl}/api/teacher-schedule/$selectedTeacher'));

      _disposeAndClearAllControllers();
      upperWeekSchedule.clear();
      lowerWeekSchedule.clear();
      _ensureEmptyStructure();

      if (resp.statusCode == 200) {
        final Map<String, dynamic> data =
        json.decode(resp.body) as Map<String, dynamic>;

        if (data['upper_week'] != null) {
          final Map<String, dynamic> u =
          (data['upper_week'] as Map).cast<String, dynamic>();
          u.forEach((day, lessons) {
            upperWeekSchedule[day] = (lessons as List)
                .map((e) =>
                TeacherScheduleItem.fromJson(e).copyWith(weekType: 'upper'))
                .toList();
          });
        }

        if (data['lower_week'] != null) {
          final Map<String, dynamic> l =
          (data['lower_week'] as Map).cast<String, dynamic>();
          l.forEach((day, lessons) {
            lowerWeekSchedule[day] = (lessons as List)
                .map((e) =>
                TeacherScheduleItem.fromJson(e).copyWith(weekType: 'lower'))
                .toList();
          });
        }

        setState(() {
          isEditingExisting = true;
          isLoadingSchedule = false;
          _isDirty = false;
        });

        if (mounted) {
          _toast('Расписание преподавателя загружено',
              icon: Icons.cloud_download_rounded, accent: Colors.green);
        }
      } else {
        setState(() {
          isEditingExisting = false;
          isLoadingSchedule = false;
          _isDirty = false;
        });
        _ensureEmptyStructure();
      }
    } catch (e) {
      setState(() {
        isEditingExisting = false;
        isLoadingSchedule = false;
        _isDirty = false;
      });
      _ensureEmptyStructure();
      if (mounted) {
        _toast('Ошибка загрузки: $e',
            icon: Icons.warning_amber_rounded, accent: Colors.redAccent);
      }
    }
  }

  // ========================================================================
  //                              СОХРАНЕНИЕ
  // ========================================================================

  Future<void> _saveSchedule() async {
    if (selectedTeacher == null) {
      _toast('Выберите преподавателя',
          icon: Icons.person_search_rounded, accent: Colors.redAccent);
      return;
    }

    // Не удаляем пустые пары — проставляем «—» и перенумеровываем
    const String kEmptyPlaceholder = '—';
    for (final map in [upperWeekSchedule, lowerWeekSchedule]) {
      map.forEach((_, items) {
        for (int i = 0; i < items.length; i++) {
          final it = items[i];
          if (it.subject.trim().isEmpty) {
            items[i] = it.copyWith(subject: kEmptyPlaceholder);
          }
          items[i] = items[i].copyWith(lessonNumber: i + 1);
        }
      });
    }

    try {
      final body = {
        'teacher_name': selectedTeacher,
        'upper_week': _convertScheduleToJson(upperWeekSchedule),
        'lower_week': _convertScheduleToJson(lowerWeekSchedule),
      };

      final resp = await http.post(
        Uri.parse('${AppConfig.serverUrl}/api/teacher-schedule'),
        headers: {'Content-Type': 'application/json'},
        body: json.encode(body),
      );

      if (resp.statusCode == 200 && mounted) {
        setState(() {
          isEditingExisting = true;
          _isDirty = false;
        });

        // Подтянуть сохранённое состояние
        await _loadExistingSchedule();

        _toast(
          'Расписание преподавателя сохранено. Пустые пары отмечены «—».',
          icon: Icons.check_circle_rounded,
          accent: Colors.green,
        );
      } else {
        throw Exception('Код ответа: ${resp.statusCode}');
      }
    } catch (e) {
      if (mounted) {
        _toast('Ошибка сохранения: $e',
            icon: Icons.error_outline_rounded, accent: Colors.redAccent);
      }
    }
  }

  Map<String, dynamic> _convertScheduleToJson(
      Map<String, List<TeacherScheduleItem>> schedule) {
    final result = <String, dynamic>{};
    schedule.forEach((day, items) {
      final sorted = [...items]
        ..sort((a, b) => a.lessonNumber.compareTo(b.lessonNumber));
      result[day] = sorted.map((e) => e.toJson()).toList();
    });
    return result;
  }

  // ========================================================================
  //                           ОПЕРАЦИИ С ПАРАМИ
  // ========================================================================

  void _addLesson(String day) {
    final schedule = _weekMap;
    schedule.putIfAbsent(day, () => []);
    setState(() {
      schedule[day]!.add(TeacherScheduleItem(
        lessonNumber: schedule[day]!.length + 1,
        subject: '',
        groupName: '',
        classroom: '',
        type: 'лекц',
        weekType: selectedWeek,
      ));
      _isDirty = true;
    });
  }

  void _removeLesson(String day, int index) {
    final schedule = _weekMap;
    if (!schedule.containsKey(day) || index >= schedule[day]!.length) return;
    setState(() {
      schedule[day]!.removeAt(index);
      for (int i = 0; i < schedule[day]!.length; i++) {
        schedule[day]![i] = schedule[day]![i].copyWith(lessonNumber: i + 1);
      }
      _dropControllersForDayWeek(day, selectedWeek);
      _isDirty = true;
    });
  }

  void _updateLesson(String day, int index, TeacherScheduleItem updated) {
    final schedule = _weekMap;
    if (!schedule.containsKey(day) || index >= schedule[day]!.length) return;
    setState(() {
      schedule[day]![index] = updated;
      _isDirty = true;
    });
  }

  void _clearSchedule() {
    setState(() {
      for (final d in daysOfWeek) {
        upperWeekSchedule[d] = [];
        lowerWeekSchedule[d] = [];
      }
      isEditingExisting = false;
      _isDirty = true;
      _disposeAndClearAllControllers();
    });
  }

  void _copyUpperToLowerWeek() {
    setState(() {
      lowerWeekSchedule.clear();
      for (final d in daysOfWeek) {
        final src = upperWeekSchedule[d] ?? [];
        lowerWeekSchedule[d] =
            src.map((x) => x.copyWith(weekType: 'lower')).toList();
      }
      _dropControllersForWeek('lower');
      _isDirty = true;
    });
    _toast('Скопировано: Верхняя → Нижняя',
        icon: Icons.copy_rounded, accent: Colors.green);
  }

  void _copyLowerToUpperWeek() {
    setState(() {
      upperWeekSchedule.clear();
      for (final d in daysOfWeek) {
        final src = lowerWeekSchedule[d] ?? [];
        upperWeekSchedule[d] =
            src.map((x) => x.copyWith(weekType: 'upper')).toList();
      }
      _dropControllersForWeek('upper');
      _isDirty = true;
    });
    _toast('Скопировано: Нижняя → Верхняя',
        icon: Icons.copy_all_rounded, accent: Colors.green);
  }

  // ========================================================================
  //                            GUARD / НАВИГАЦИЯ
  // ========================================================================

  Future<_SaveAction?> _askSaveDialog() async {
    return showDialog<_SaveAction>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Несохранённые изменения'),
        content: const Text('Сохранить изменения перед выходом?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, _SaveAction.cancel),
            child: const Text('Отмена'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(ctx, _SaveAction.discard),
            child: const Text('Не сохранять'),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(ctx, _SaveAction.save),
            child: const Text('Сохранить'),
          ),
        ],
      ),
    );
  }

  Future<void> _guardedChange(VoidCallback applyChange) async {
    if (!_isDirty) {
      setState(applyChange);
      return;
    }
    final action = await _askSaveDialog();
    if (!mounted || action == null) return;

    if (action == _SaveAction.save) {
      await _saveSchedule();
      if (!_isDirty) setState(applyChange);
    } else if (action == _SaveAction.discard) {
      setState(applyChange);
    }
  }

  Future<bool> _onWillPopGuard() async {
    if (!_isDirty) return true;
    final action = await _askSaveDialog();
    if (!mounted || action == null) return false;

    if (action == _SaveAction.save) {
      await _saveSchedule();
      return !_isDirty;
    } else if (action == _SaveAction.discard) {
      return true;
    }
    return false;
  }

  void _onWeekChanged(String week) {
    if (week == selectedWeek) return;
    _guardedChange(() {
      selectedWeek = week;
    });
  }

  // ========================================================================
  //                                UI
  // ========================================================================

  @override
  Widget build(BuildContext context) {
    return WillPopScope(
      onWillPop: _onWillPopGuard,
      child: Scaffold(
        backgroundColor: Theme.of(context).colorScheme.background,
        appBar: AppBar(
          title: Text(
            'Редактор расписания преподавателей',
            style: TextStyle(
              color: Theme.of(context).colorScheme.onPrimary,
              fontWeight: FontWeight.bold,
            ),
          ),
          backgroundColor: AppColors.primary,
          centerTitle: true,
          elevation: 0,
          iconTheme:
          IconThemeData(color: Theme.of(context).colorScheme.onPrimary),
          actions: [
            IconButton(
              tooltip: 'Сохранить расписание',
              icon: const Icon(Icons.save_rounded),
              onPressed: _saveSchedule,
            ),
          ],
        ),

        // 👇 Плавающая кнопка "Сохранить" всегда поверх, по центру
        floatingActionButton: FloatingActionButton.extended(
          onPressed: _saveSchedule,
          label: const Text('Сохранить расписание'),
          icon: const Icon(Icons.save_rounded),
          backgroundColor: AppColors.primary,
          foregroundColor: Colors.white,
        ),
        floatingActionButtonLocation: FloatingActionButtonLocation.centerFloat,

        body: isLoading
            ? const Center(child: CircularProgressIndicator())
            : SingleChildScrollView(
          padding: const EdgeInsets.fromLTRB(16, 16, 16, 96),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              _buildTeacherSelector(),
              const SizedBox(height: 20),
              if (selectedTeacher != null) ...[
                if (!isEditingExisting && !isLoadingSchedule)
                  Card(
                    elevation: 3,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(16),
                    ),
                    child: Container(
                      padding: const EdgeInsets.all(16),
                      decoration: BoxDecoration(
                        borderRadius: BorderRadius.circular(16),
                        border: Border.all(
                          color: Theme.of(context).dividerColor,
                          width: 1,
                        ),
                      ),
                      child: Column(
                        children: [
                          Text(
                            'Создание нового расписания',
                            style: TextStyle(
                              fontWeight: FontWeight.bold,
                              fontSize: 16,
                              color: Theme.of(context)
                                  .colorScheme
                                  .onBackground,
                            ),
                          ),
                          const SizedBox(height: 10),
                          TextButton(
                            onPressed: _clearSchedule,
                            child: const Text(
                                'Начать создание нового расписания'),
                          ),
                        ],
                      ),
                    ),
                  ),
                if (!isLoadingSchedule) ...[
                  const SizedBox(height: 20),
                  _buildWeekSelectorWithCopyButtons(),
                  const SizedBox(height: 20),
                  ..._buildScheduleEditor(),
                  const SizedBox(height: 120), // место под FAB
                ],
              ],
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildTeacherSelector() {
    return Card(
      elevation: 3,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      color: Theme.of(context).cardColor,
      child: Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(16),
          border: Border.all(
            color: Theme.of(context).dividerColor,
            width: 1,
          ),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Выберите преподавателя:',
              style: TextStyle(
                fontWeight: FontWeight.bold,
                fontSize: 16,
                color: Theme.of(context).colorScheme.onBackground,
              ),
            ),
            const SizedBox(height: 10),
            _buildAnimatedDropdown(),
          ],
        ),
      ),
    );
  }

  Widget _buildAnimatedDropdown() {
    return Column(
      children: [
        Material(
          color: Colors.transparent,
          child: InkWell(
            onTap: () {
              setState(() => _isDropdownOpen = !_isDropdownOpen);
            },
            borderRadius: BorderRadius.circular(12),
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
              decoration: BoxDecoration(
                border: Border.all(
                  color: Theme.of(context).dividerColor,
                  width: 1,
                ),
                borderRadius: BorderRadius.circular(12),
              ),
              child: Row(
                children: [
                  Icon(Icons.person,
                      color: Theme.of(context).colorScheme.primary, size: 20),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Text(
                      selectedTeacher ?? 'Выберите преподавателя',
                      style: TextStyle(
                        color: selectedTeacher != null
                            ? Theme.of(context).colorScheme.onBackground
                            : Theme.of(context)
                            .colorScheme
                            .onSurface
                            .withOpacity(0.6),
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                  ),
                  Transform.rotate(
                    angle: _isDropdownOpen ? 3.1415 : 0.0,
                    child: Icon(
                      Icons.arrow_drop_down,
                      color: Theme.of(context).colorScheme.primary,
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
        const SizedBox(height: 8),
        AnimatedContainer(
          duration: const Duration(milliseconds: 250),
          curve: Curves.easeInOut,
          height: _isDropdownOpen ? 200 : 0,
          decoration: BoxDecoration(
            color: Theme.of(context).cardColor,
            borderRadius: BorderRadius.circular(12),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withOpacity(0.08),
                blurRadius: 8,
                offset: const Offset(0, 4),
              ),
            ],
          ),
          child: _isDropdownOpen
              ? Material(
            color: Colors.transparent,
            child: ListView(
              padding: EdgeInsets.zero,
              children: teachers.map((t) {
                final selected = selectedTeacher == t;
                return ListTile(
                  leading: Icon(
                    Icons.person,
                    size: 20,
                    color: selected
                        ? Theme.of(context).colorScheme.primary
                        : Theme.of(context).colorScheme.onSurface,
                  ),
                  title: Text(
                    t,
                    style: TextStyle(
                      color: selected
                          ? Theme.of(context).colorScheme.primary
                          : Theme.of(context)
                          .colorScheme
                          .onBackground,
                      fontWeight: selected
                          ? FontWeight.bold
                          : FontWeight.normal,
                    ),
                  ),
                  trailing: selected
                      ? Icon(Icons.check,
                      size: 20,
                      color: Theme.of(context).colorScheme.primary)
                      : null,
                  onTap: () {
                    _guardedChange(() {
                      selectedTeacher = t;
                      _isDropdownOpen = false;
                      isLoadingSchedule = true;
                      _disposeAndClearAllControllers();
                    });
                    _loadExistingSchedule();
                  },
                );
              }).toList(),
            ),
          )
              : const SizedBox.shrink(),
        ),
      ],
    );
  }

  Widget _buildWeekSelectorWithCopyButtons() {
    return Card(
      elevation: 3,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      color: Theme.of(context).cardColor,
      child: Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(16),
          border: Border.all(
            color: Theme.of(context).dividerColor,
            width: 1,
          ),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Выберите неделю:',
              style: TextStyle(
                fontWeight: FontWeight.bold,
                fontSize: 16,
                color: Theme.of(context).colorScheme.onBackground,
              ),
            ),
            const SizedBox(height: 10),
            Row(
              children: [
                Expanded(
                  child: ElevatedButton(
                    style: ElevatedButton.styleFrom(
                      backgroundColor: selectedWeek == 'upper'
                          ? AppColors.primary
                          : Colors.grey,
                      foregroundColor: Colors.white,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                      padding: const EdgeInsets.symmetric(vertical: 16),
                    ),
                    onPressed: () => _onWeekChanged('upper'),
                    child: const Text('ВЕРХНЯЯ НЕДЕЛЯ'),
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: ElevatedButton(
                    style: ElevatedButton.styleFrom(
                      backgroundColor: selectedWeek == 'lower'
                          ? Colors.green
                          : Colors.grey,
                      foregroundColor: Colors.white,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                      padding: const EdgeInsets.symmetric(vertical: 16),
                    ),
                    onPressed: () => _onWeekChanged('lower'),
                    child: const Text('НИЖНЯЯ НЕДЕЛЯ'),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 16),
            Text(
              'Копирование расписания:',
              style: TextStyle(
                fontWeight: FontWeight.bold,
                fontSize: 14,
                color: Theme.of(context).colorScheme.onBackground,
              ),
            ),
            const SizedBox(height: 10),
            Row(
              children: [
                Expanded(
                  child: OutlinedButton(
                    style: OutlinedButton.styleFrom(
                      foregroundColor: AppColors.primary,
                      side: BorderSide(color: AppColors.primary),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(8),
                      ),
                    ),
                    onPressed: _copyUpperToLowerWeek,
                    child: const Text('Верхняя → Нижняя'),
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: OutlinedButton(
                    style: OutlinedButton.styleFrom(
                      foregroundColor: Colors.green,
                      side: const BorderSide(color: Colors.green),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(8),
                      ),
                    ),
                    onPressed: _copyLowerToUpperWeek,
                    child: const Text('Нижняя → Верхняя'),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  List<Widget> _buildScheduleEditor() {
    final schedule = _weekMap;

    return daysOfWeek.map((day) {
      final dayLessons = schedule[day] ?? [];

      return Card(
        elevation: 3,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(16),
        ),
        margin: const EdgeInsets.only(bottom: 16),
        color: Theme.of(context).cardColor,
        child: Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(16),
            border: Border.all(
              color: Theme.of(context).dividerColor,
              width: 1,
            ),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Text(
                    day,
                    style: TextStyle(
                      fontWeight: FontWeight.bold,
                      fontSize: 18,
                      color: Theme.of(context).colorScheme.onBackground,
                    ),
                  ),
                  const Spacer(),
                  IconButton(
                    icon: Icon(Icons.add, color: AppColors.primary),
                    onPressed: () => _addLesson(day),
                  ),
                ],
              ),
              Divider(color: Theme.of(context).dividerColor),
              if (dayLessons.isEmpty)
                const Center(
                  child: Padding(
                    padding: EdgeInsets.symmetric(vertical: 8),
                    child: Text(
                      'Нет занятий',
                      style: TextStyle(
                        color: Colors.grey,
                        fontStyle: FontStyle.italic,
                      ),
                    ),
                  ),
                )
              else
                ...dayLessons.asMap().entries.map((entry) {
                  final index = entry.key;
                  final lesson = entry.value;
                  return _buildLessonEditor(day, index, lesson);
                }),
            ],
          ),
        ),
      );
    }).toList();
  }

  Widget _buildLessonEditor(
      String day, int index, TeacherScheduleItem lesson) {
    final key = _ctrlKey(day, index, selectedWeek);

    // Создаём контроллеры один раз и сразу вешаем листенеры (без дублирования)
    subjectControllers.putIfAbsent(key, () {
      final c = TextEditingController(text: lesson.subject);
      c.addListener(() {
        final schedule = _weekMap;
        if (schedule.containsKey(day) && index < schedule[day]!.length) {
          final curr = schedule[day]![index];
          _updateLesson(day, index, curr.copyWith(subject: c.text));
        }
      });
      return c;
    });

    classroomControllers.putIfAbsent(key, () {
      final c = TextEditingController(text: lesson.classroom);
      c.addListener(() {
        final schedule = _weekMap;
        if (schedule.containsKey(day) && index < schedule[day]!.length) {
          final curr = schedule[day]![index];
          _updateLesson(day, index, curr.copyWith(classroom: c.text));
        }
      });
      return c;
    });

    groupControllers.putIfAbsent(key, () {
      final c = TextEditingController(text: lesson.groupName);
      c.addListener(() {
        final schedule = _weekMap;
        if (schedule.containsKey(day) && index < schedule[day]!.length) {
          final curr = schedule[day]![index];
          _updateLesson(day, index, curr.copyWith(groupName: c.text));
        }
      });
      return c;
    });

    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.surface,
        border: Border.all(color: Theme.of(context).dividerColor),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Column(
        children: [
          Row(
            children: [
              Text(
                '${lesson.lessonNumber} пара:',
                style: TextStyle(
                  fontWeight: FontWeight.bold,
                  color: Theme.of(context).colorScheme.onBackground,
                ),
              ),
              const Spacer(),
              IconButton(
                icon: const Icon(Icons.delete, color: Colors.red),
                onPressed: () => _removeLesson(day, index),
              ),
            ],
          ),
          const SizedBox(height: 8),
          TextField(
            controller: subjectControllers[key],
            decoration: InputDecoration(
              labelText: 'Название предмета',
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(12),
              ),
            ),
            textInputAction: TextInputAction.next,
          ),
          const SizedBox(height: 8),
          TextField(
            controller: groupControllers[key],
            decoration: InputDecoration(
              labelText: 'Группа студентов',
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(12),
              ),
            ),
            textInputAction: TextInputAction.next,
          ),
          const SizedBox(height: 8),
          Row(
            children: [
              Expanded(
                flex: 1,
                child: TextField(
                  controller: classroomControllers[key],
                  decoration: InputDecoration(
                    labelText: 'Кабинет',
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                  ),
                  textInputAction: TextInputAction.next,
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                flex: 2,
                child: DropdownButtonFormField<String>(
                  value: lesson.type,
                  decoration: InputDecoration(
                    labelText: 'Тип занятия',
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                  ),
                  items: lessonTypes
                      .map((t) => DropdownMenuItem(
                    value: t,
                    child: Text(_typeName(t)),
                  ))
                      .toList(),
                  onChanged: (v) {
                    if (v != null) {
                      final schedule = _weekMap;
                      if (schedule.containsKey(day) &&
                          index < schedule[day]!.length) {
                        final curr = schedule[day]![index];
                        _updateLesson(day, index, curr.copyWith(type: v));
                      }
                    }
                  },
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  String _typeName(String t) {
    switch (t) {
      case 'лекц':
        return 'Лекция';
      case 'пр':
        return 'Практика';
      case 'лб':
        return 'Лабораторная';
      default:
        return t;
    }
  }
}

// ==========================================================================
//                              МОДЕЛЬ
// ==========================================================================

class TeacherScheduleItem {
  final int lessonNumber;
  final String subject;
  final String groupName;
  final String classroom;
  final String type;
  final String weekType;

  TeacherScheduleItem({
    required this.lessonNumber,
    required this.subject,
    required this.groupName,
    required this.classroom,
    required this.type,
    required this.weekType,
  });

  TeacherScheduleItem copyWith({
    int? lessonNumber,
    String? subject,
    String? groupName,
    String? classroom,
    String? type,
    String? weekType,
  }) {
    return TeacherScheduleItem(
      lessonNumber: lessonNumber ?? this.lessonNumber,
      subject: subject ?? this.subject,
      groupName: groupName ?? this.groupName,
      classroom: classroom ?? this.classroom,
      type: type ?? this.type,
      weekType: weekType ?? this.weekType,
    );
  }

  Map<String, dynamic> toJson() => {
    'lesson_number': lessonNumber,
    'subject': subject,
    'group_name': groupName,
    'classroom': classroom,
    'type': type,
  };

  static TeacherScheduleItem fromJson(Map<String, dynamic> json) {
    return TeacherScheduleItem(
      lessonNumber: (json['lesson_number'] ?? 0) as int,
      subject: (json['subject'] ?? '') as String,
      groupName: (json['group_name'] ?? '') as String,
      classroom: (json['classroom'] ?? '') as String,
      type: (json['type'] ?? 'лекц') as String,
      weekType: '', // позже подставляется copyWith при загрузке
    );
  }
}
