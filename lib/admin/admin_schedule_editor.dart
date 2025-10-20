// lib/admin/admin_schedule_editor.dart
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';
import 'package:decanat_progect/constants.dart';
import 'package:shared_preferences/shared_preferences.dart';

// 👇 единый сервис всплывающих уведомлений
import 'package:decanat_progect/ui/overlay_toast.dart';

// ------------------------ ENUM ДОЛЖЕН БЫТЬ ВНЕ КЛАССА ------------------------
enum _SaveAction { save, discard, cancel }

// ------------------------ ЭКРАН РЕДАКТОРА ------------------------
class AdminScheduleEditor extends StatefulWidget {
  const AdminScheduleEditor({super.key});

  @override
  _AdminScheduleEditorState createState() => _AdminScheduleEditorState();
}

class _AdminScheduleEditorState extends State<AdminScheduleEditor> {
  // --- Состояние доступа
  String _userRole = 'user';

  // --- Группы
  List<String> groups = [];
  String? selectedGroup;
  bool isLoading = true;
  bool isAddingNewGroup = false;
  bool isLoadingSchedule = false;
  bool isEditingExisting = false;

  // --- Недели
  String selectedWeek = 'upper'; // 'upper' | 'lower'
  final List<String> daysOfWeek = const [
    'Понедельник',
    'Вторник',
    'Среда',
    'Четверг',
    'Пятница',
  ];

  final List<String> lessonTypes = const ['лекц', 'пр', 'лб'];

  // --- Выпадающий список
  bool _isDropdownOpen = false;

  // --- Контроллеры ввода (ключ: 'День-Индекс-Неделя')
  final Map<String, TextEditingController> subjectControllers = {};
  final Map<String, TextEditingController> classroomControllers = {};
  final Map<String, TextEditingController> teacherControllers = {};
  final TextEditingController newGroupController = TextEditingController();

  // --- Данные расписания по неделям
  final Map<String, List<ScheduleItem>> upperWeekSchedule = {};
  final Map<String, List<ScheduleItem>> lowerWeekSchedule = {};

  // --- Флаг «грязности» — несохранённые изменения
  bool _isDirty = false;

  @override
  void initState() {
    super.initState();
    _loadUserRole();
    _loadGroups();
  }

  @override
  void dispose() {
    _disposeAndClearAllControllers();
    newGroupController.dispose();
    super.dispose();
  }

  // --------- короткий helper для тостов ----------
  void _toast(String msg,
      {IconData icon = Icons.info_outline_rounded, Color? accent}) {
    OverlayToast.instance
        .show(msg, icon: icon, accent: accent ?? AppColors.accent);
  }

  Future<void> _loadUserRole() async {
    final prefs = await SharedPreferences.getInstance();
    setState(() {
      _userRole = prefs.getString('userRole') ?? 'user';
    });
  }

  // ====== УТИЛИТЫ ===========================================================
  String _ctrlKey(String day, int index, String week) => '$day-$index-$week';

  Map<String, List<ScheduleItem>> get _weekMap =>
      selectedWeek == 'upper' ? upperWeekSchedule : lowerWeekSchedule;

  void _ensureEmptyStructure() {
    for (final d in daysOfWeek) {
      upperWeekSchedule.putIfAbsent(d, () => []);
      lowerWeekSchedule.putIfAbsent(d, () => []);
    }
  }

  void _disposeAndClearAllControllers() {
    for (final c in subjectControllers.values) c.dispose();
    for (final c in classroomControllers.values) c.dispose();
    for (final c in teacherControllers.values) c.dispose();
    subjectControllers.clear();
    classroomControllers.clear();
    teacherControllers.clear();
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
    removeMatching(teacherControllers);
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
    removeMatching(teacherControllers);
  }

  // ====== ЗАГРУЗКА ГРУПП ====================================================
  Future<void> _loadGroups() async {
    try {
      final response =
      await http.get(Uri.parse('${AppConfig.serverUrl}/api/groups'));

      if (response.statusCode == 200) {
        setState(() {
          groups = List<String>.from(json.decode(response.body));
          isLoading = false;
        });
      } else {
        _loadLocalGroupsFallback();
      }
    } catch (_) {
      _loadLocalGroupsFallback();
    }
  }

  void _loadLocalGroupsFallback() {
    const bachelor = ['ПМК', 'ИВТ', 'ИНФ', 'ПИ', 'САУ'];
    const master = ['ПМКм', 'ИВТм', 'ИНФм', 'ПИм', 'САУм'];
    const yearSuffix = {2025: '25', 2024: '24', 2023: '23', 2022: '22'};

    final generated = <String>[];
    for (final y in [2025, 2024, 2023, 2022]) {
      final suf = yearSuffix[y]!;
      generated.addAll(bachelor.map((p) => '$p-$suf'));
      generated.addAll(master.map((p) => '$p-$suf'));
    }

    setState(() {
      groups = generated;
      isLoading = false;
    });
  }

  // ====== ЗАГРУЗКА ПОЛНОГО РАСПИСАНИЯ =======================================
  Future<void> _loadExistingSchedule() async {
    if (selectedGroup == null) return;

    setState(() {
      isLoadingSchedule = true;
    });

    try {
      final response = await http.get(
        Uri.parse('${AppConfig.serverUrl}/api/schedule/$selectedGroup'),
      );

      // свежий старт: чистим контроллеры и карты
      _disposeAndClearAllControllers();
      upperWeekSchedule.clear();
      lowerWeekSchedule.clear();
      _ensureEmptyStructure();

      if (response.statusCode == 200) {
        final Map<String, dynamic> scheduleData =
        json.decode(response.body) as Map<String, dynamic>;

        if (scheduleData['upper_week'] != null) {
          final Map<String, dynamic> upperWeek =
          scheduleData['upper_week'] as Map<String, dynamic>;
          upperWeek.forEach((day, lessons) {
            upperWeekSchedule[day] = (lessons as List)
                .map((raw) =>
                ScheduleItem.fromJson(raw).copyWith(weekType: 'upper'))
                .toList();
          });
        }

        if (scheduleData['lower_week'] != null) {
          final Map<String, dynamic> lowerWeek =
          scheduleData['lower_week'] as Map<String, dynamic>;
          lowerWeek.forEach((day, lessons) {
            lowerWeekSchedule[day] = (lessons as List)
                .map((raw) =>
                ScheduleItem.fromJson(raw).copyWith(weekType: 'lower'))
                .toList();
          });
        }

        setState(() {
          isEditingExisting = true;
          isLoadingSchedule = false;
          _isDirty = false; // только просмотр после загрузки
        });

        _toast('Расписание загружено',
            icon: Icons.check_circle_rounded, accent: Colors.green);
      } else {
        setState(() {
          isEditingExisting = false;
          isLoadingSchedule = false;
        });
        _ensureEmptyStructure();
      }
    } catch (e) {
      setState(() {
        isEditingExisting = false;
        isLoadingSchedule = false;
      });
      _ensureEmptyStructure();
      _toast('Ошибка загрузки: $e',
          icon: Icons.error_outline_rounded, accent: Colors.red);
    }
  }

  // ====== ДОБАВЛЕНИЕ ГРУППЫ (ОДНОЙ) =========================================
  Future<void> _addNewGroup() async {
    final name = newGroupController.text.trim();
    if (name.isEmpty) return;

    try {
      final response = await http.post(
        Uri.parse('${AppConfig.serverUrl}/api/groups'),
        headers: {'Content-Type': 'application/json'},
        body: json.encode({'group_name': name}),
      );

      setState(() {
        groups.add(name);
        selectedGroup = name;
        isAddingNewGroup = false;
        newGroupController.clear();
        _isDirty = false;
      });

      _disposeAndClearAllControllers();
      _ensureEmptyStructure();

      if (response.statusCode == 200) {
        _toast('Группа добавлена',
            icon: Icons.check_rounded, accent: Colors.green);
      }
    } catch (_) {
      setState(() {
        groups.add(name);
        selectedGroup = name;
        isAddingNewGroup = false;
        newGroupController.clear();
        _isDirty = false;
      });
      _disposeAndClearAllControllers();
      _ensureEmptyStructure();
      _toast('Группа добавлена локально',
          icon: Icons.offline_bolt_rounded);
    }
  }

  // ====== СОХРАНЕНИЕ ОБЕИХ НЕДЕЛЬ ==========================================
  Future<void> _saveSchedule() async {
    if (selectedGroup == null) {
      _toast('Выберите группу',
          icon: Icons.warning_amber_rounded, accent: Colors.red);
      return;
    }

    const String kEmptyPlaceholder = '—';
    for (final map in [upperWeekSchedule, lowerWeekSchedule]) {
      map.forEach((_, items) {
        for (int i = 0; i < items.length; i++) {
          final it = items[i];
          final isEmptySubject = it.subject.trim().isEmpty;
          if (isEmptySubject) {
            items[i] = it.copyWith(subject: kEmptyPlaceholder);
          }
          items[i] = items[i].copyWith(lessonNumber: i + 1);
        }
      });
    }

    try {
      final scheduleData = {
        'group': selectedGroup,
        'upper_week': _convertScheduleToJson(upperWeekSchedule),
        'lower_week': _convertScheduleToJson(lowerWeekSchedule),
      };

      final response = await http.post(
        Uri.parse('${AppConfig.serverUrl}/api/schedule'),
        headers: {'Content-Type': 'application/json'},
        body: json.encode(scheduleData),
      );

      if (response.statusCode == 200) {
        setState(() => isEditingExisting = true);
        _isDirty = false;

        await _loadExistingSchedule();

        _toast(
          'Обе недели сохранены',
          icon: Icons.save_rounded,
          accent: Colors.green,
        );
      } else {
        throw Exception('Код ответа: ${response.statusCode}');
      }
    } catch (e) {
      _toast('Ошибка сохранения: $e',
          icon: Icons.error_outline_rounded, accent: Colors.red);
    }
  }

  Map<String, dynamic> _convertScheduleToJson(
      Map<String, List<ScheduleItem>> schedule,
      ) {
    final result = <String, dynamic>{};
    schedule.forEach((day, items) {
      final sorted = [...items]
        ..sort((a, b) => a.lessonNumber.compareTo(b.lessonNumber));
      result[day] = sorted.map((it) => it.toJson()).toList();
    });
    return result;
  }

  // ====== ОПЕРАЦИИ С УРОКАМИ ================================================
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
      _toast('Изменения не сохранены',
          icon: Icons.history_toggle_off_rounded);
    }
  }

  void _onWeekChanged(String week) {
    if (week == selectedWeek) return;
    _guardedChange(() {
      selectedWeek = week;
    });
  }

  void _addLesson(String day) {
    final schedule = _weekMap;
    schedule.putIfAbsent(day, () => []);
    setState(() {
      schedule[day]!.add(ScheduleItem(
        lessonNumber: schedule[day]!.length + 1,
        subject: '',
        teacher: '',
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
    _toast('Пара удалена',
        icon: Icons.delete_outline_rounded, accent: Colors.red);
  }

  void _updateLesson(String day, int index, ScheduleItem updatedItem) {
    final schedule = _weekMap;
    if (!schedule.containsKey(day) || index >= schedule[day]!.length) return;

    setState(() {
      schedule[day]![index] = updatedItem;
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
    _toast('Новое расписание: пустой шаблон',
        icon: Icons.note_add_outlined);
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
        icon: Icons.copy_all_rounded);
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
        icon: Icons.copy_all_rounded);
  }

  // ====== GUARD НА ВОЗВРАТ ==================================================
  Future<bool> _onWillPopGuard() async {
    if (!_isDirty) return true;
    final action = await _askSaveDialog();
    if (!mounted || action == null) return false;

    if (action == _SaveAction.save) {
      await _saveSchedule();
      return !_isDirty;
    } else if (action == _SaveAction.discard) {
      _toast('Изменения не сохранены',
          icon: Icons.history_toggle_off_rounded);
      return true;
    }
    return false;
  }

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

  // ====== UI ================================================================
  @override
  Widget build(BuildContext context) {
    if (_userRole != 'admin' && _userRole != 'developer') {
      return Scaffold(
        backgroundColor: Theme.of(context).colorScheme.background,
        appBar: AppBar(
          title: const Text('Доступ запрещен'),
          backgroundColor: AppColors.primary,
        ),
        body: const Center(
          child: Text(
            'У вас нет прав для доступа к этому разделу',
            style: TextStyle(fontSize: 18),
          ),
        ),
      );
    }

    return WillPopScope(
      onWillPop: _onWillPopGuard,
      child: Scaffold(
        backgroundColor: Theme.of(context).colorScheme.background,
        appBar: AppBar(
          title: Text(
            'Редактор расписания',
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
              tooltip: 'Доп. действия',
              icon: const Icon(Icons.tune_rounded),
              onPressed: _openAdvancedActionsSheet,
            ),
            IconButton(
              tooltip: 'Сохранить обе недели',
              icon: const Icon(Icons.save_rounded),
              onPressed: _saveSchedule,
            ),
          ],
        ),
        floatingActionButton: FloatingActionButton.extended(
          onPressed: _saveSchedule,
          label: const Text('Сохранить обе недели'),
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
              _buildGroupSelector(),
              const SizedBox(height: 20),
              if (selectedGroup != null) ...[
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

  Widget _buildGroupSelector() {
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
              'Выберите группу:',
              style: TextStyle(
                fontWeight: FontWeight.bold,
                fontSize: 16,
                color: Theme.of(context).colorScheme.onBackground,
              ),
            ),
            const SizedBox(height: 10),
            if (isAddingNewGroup)
              Column(
                children: [
                  TextField(
                    controller: newGroupController,
                    decoration: InputDecoration(
                      labelText: 'Название новой группы',
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                    ),
                    textInputAction: TextInputAction.done,
                  ),
                  const SizedBox(height: 10),
                  Row(
                    children: [
                      ElevatedButton(
                        onPressed: _addNewGroup,
                        style: ElevatedButton.styleFrom(
                          backgroundColor: AppColors.primary,
                          foregroundColor: Colors.white,
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(8),
                          ),
                        ),
                        child: const Text('Добавить'),
                      ),
                      const SizedBox(width: 10),
                      TextButton(
                        onPressed: () {
                          setState(() {
                            isAddingNewGroup = false;
                          });
                        },
                        child: const Text('Отмена'),
                      ),
                    ],
                  ),
                ],
              )
            else
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
              padding:
              const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
              decoration: BoxDecoration(
                border: Border.all(
                  color: Theme.of(context).dividerColor,
                  width: 1,
                ),
                borderRadius: BorderRadius.circular(12),
              ),
              child: Row(
                children: [
                  Icon(Icons.group,
                      color: Theme.of(context).colorScheme.primary, size: 20),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Text(
                      selectedGroup ?? 'Выберите группу',
                      style: TextStyle(
                        color: selectedGroup != null
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
              children: [
                ListTile(
                  leading: const Icon(Icons.add, size: 20),
                  title: Text(
                    '+ Добавить новую группу',
                    style: TextStyle(color: AppColors.primary),
                  ),
                  onTap: () {
                    setState(() {
                      _isDropdownOpen = false;
                      isAddingNewGroup = true;
                    });
                  },
                ),
                const Divider(height: 1),
                ...groups.map((g) {
                  final selected = selectedGroup == g;
                  return ListTile(
                    leading: Icon(
                      Icons.school,
                      size: 20,
                      color: selected
                          ? Theme.of(context).colorScheme.primary
                          : Theme.of(context).colorScheme.onSurface,
                    ),
                    title: Text(
                      g,
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
                        color: Theme.of(context)
                            .colorScheme
                            .primary)
                        : null,
                    onTap: () {
                      _guardedChange(() {
                        selectedGroup = g;
                        _isDropdownOpen = false;
                        isLoadingSchedule = true;
                      });
                      _loadExistingSchedule();
                    },
                  );
                }),
              ],
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
                      backgroundColor:
                      selectedWeek == 'lower' ? Colors.green : Colors.grey,
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
                  child: Text(
                    'Нет занятий',
                    style: TextStyle(
                      color: Colors.grey,
                      fontStyle: FontStyle.italic,
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

  Widget _buildLessonEditor(String day, int index, ScheduleItem lesson) {
    final key = _ctrlKey(day, index, selectedWeek);

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

    teacherControllers.putIfAbsent(key, () {
      final c = TextEditingController(text: lesson.teacher);
      c.addListener(() {
        final schedule = _weekMap;
        if (schedule.containsKey(day) && index < schedule[day]!.length) {
          final curr = schedule[day]![index];
          _updateLesson(day, index, curr.copyWith(teacher: c.text));
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
            controller: teacherControllers[key],
            decoration: InputDecoration(
              labelText: 'ФИО преподавателя',
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

  // ======================= РАСШИРЕННЫЕ ДЕЙСТВИЯ (ГРУППЫ) ====================

  // Нормализуем год: "22" или "2022" → "22"
  String _normalizeYearSuffix(String input) {
    final s = input.trim();
    if (s.isEmpty) return '';
    final onlyDigits = s.replaceAll(RegExp(r'\D+'), '');
    if (onlyDigits.length == 2) return onlyDigits;
    if (onlyDigits.length == 4) return onlyDigits.substring(2);
    return '';
  }

  // Кнопка в AppBar → bottom sheet
  void _openAdvancedActionsSheet() {
    showModalBottomSheet(
      context: context,
      showDragHandle: true,
      isScrollControlled: false,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(16)),
      ),
      builder: (ctx) {
        return SafeArea(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              ListTile(
                leading: const Icon(Icons.delete_forever_rounded),
                title: const Text('Удалить устаревшие группы (по году)'),
                subtitle: const Text('Двухэтапное подтверждение'),
                onTap: () {
                  Navigator.pop(ctx);
                  _askDeleteByYearFlow();
                },
              ),
              const Divider(height: 1),
              ListTile(
                leading: const Icon(Icons.group_add_rounded),
                title: const Text('Добавить набор новых групп (пачкой)'),
                subtitle: const Text('Сгенерировать все префиксы за год'),
                onTap: () {
                  Navigator.pop(ctx);
                  _bulkAddCohortFlow();
                },
              ),
              const SizedBox(height: 8),
            ],
          ),
        );
      },
    );
  }

  // Диалог ввода года (строка)
  Future<String?> _askYearDialog({
    required String title,
    required String hint,
  }) async {
    final ctrl = TextEditingController();
    return showDialog<String>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text(title),
        content: TextField(
          controller: ctrl,
          keyboardType: TextInputType.number,
          decoration: const InputDecoration(
            labelText: 'Год',
            hintText: 'Например: 22 или 2022',
            border: OutlineInputBorder(),
          ),
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Отмена')),
          ElevatedButton(
            onPressed: () => Navigator.pop(ctx, ctrl.text),
            child: const Text('Продолжить'),
          ),
        ],
      ),
    );
  }

  // Удаление по году: 2 подтверждения → сервер
  Future<void> _askDeleteByYearFlow() async {
    final raw = await _askYearDialog(
      title: 'Удаление групп по году',
      hint: 'Введите год (22 или 2022)',
    );
    if (raw == null) return;
    final suf = _normalizeYearSuffix(raw);
    if (suf.isEmpty) {
      _toast('Некорректный год', icon: Icons.error_outline_rounded, accent: Colors.red);
      return;
    }

    final toDelete = groups.where((g) => g.endsWith('-$suf')).toList();
    if (toDelete.isEmpty) {
      _toast('Групп с суффиксом $suf не найдено');
      return;
    }

    // Подтверждение #1
    final ok1 = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Вы уверены?'),
        content: Text('Удалить данные этих групп по году $suf? Найдено: ${toDelete.length}'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Отмена')),
          ElevatedButton(onPressed: () => Navigator.pop(ctx, true), child: const Text('Да')),
        ],
      ),
    );
    if (ok1 != true) return;

    // Подтверждение #2 (детальный список + предупреждение)
    final ok2 = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Подтверждение удаления'),
        content: SizedBox(
          width: 420,
          child: SingleChildScrollView(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('Будут удалены ${toDelete.length} групп(ы):'),
                const SizedBox(height: 8),
                Text(toDelete.join(', ')),
                const SizedBox(height: 12),
                const Text(
                  'ВНИМАНИЕ: Это действие нельзя отменить.',
                  style: TextStyle(fontWeight: FontWeight.bold),
                ),
              ],
            ),
          ),
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Отмена')),
          ElevatedButton(
            style: ElevatedButton.styleFrom(backgroundColor: Colors.red, foregroundColor: Colors.white),
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('Удалить безвозвратно'),
          ),
        ],
      ),
    );
    if (ok2 != true) return;

    await _deleteGroupsOnServerBySuffix(suf, toDelete);
  }

  // Серверный вызов удаления: сначала /by-yearcode, если нет — явный список
  Future<void> _deleteGroupsOnServerBySuffix(String suffix, List<String> toDelete) async {
    try {
      // 1) Пытаемся удалить по коду года
      http.Response? resp;
      try {
        resp = await http.post(
          Uri.parse('${AppConfig.serverUrl}/api/groups/delete/by-yearcode'),
          headers: {'Content-Type': 'application/json'},
          body: json.encode({'year_code': suffix}),
        );
      } catch (_) {
        // игнор — попробуем через явный список
      }

      if (resp == null || resp.statusCode == 404) {
        // 2) Fallback — удаляем явным списком
        resp = await http.post(
          Uri.parse('${AppConfig.serverUrl}/api/groups/delete'),
          headers: {'Content-Type': 'application/json'},
          body: json.encode({'groups': toDelete}),
        );
      }

      if (resp.statusCode == 200) {
        setState(() {
          groups.removeWhere((g) => g.endsWith('-$suffix'));
          if (selectedGroup != null && selectedGroup!.endsWith('-$suffix')) {
            selectedGroup = null;
            upperWeekSchedule.clear();
            lowerWeekSchedule.clear();
            _disposeAndClearAllControllers();
          }
        });
        _toast('Удалено групп: ${toDelete.length}',
            icon: Icons.delete_forever_rounded, accent: Colors.red);
      } else {
        throw Exception('Код ответа: ${resp.statusCode}');
      }
    } catch (e) {
      _toast('Ошибка удаления: $e',
          icon: Icons.error_outline_rounded, accent: Colors.red);
    }
  }

  // Добавление «кохорты» (набор бакалавр+магистр)
  Future<void> _bulkAddCohortFlow() async {
    final raw = await _askYearDialog(
      title: 'Добавление набора групп',
      hint: 'Введите год (26 или 2026)',
    );
    if (raw == null) return;
    final suf = _normalizeYearSuffix(raw);
    if (suf.isEmpty) {
      _toast('Некорректный год',
          icon: Icons.error_outline_rounded, accent: Colors.red);
      return;
    }

    // Предпросмотр набора: бакалавр + магистр
    const bachelor = ['ПМК', 'ИВТ', 'ИНФ', 'ПИ', 'САУ'];
    const master = ['ПМКм', 'ИВТм', 'ИНФм', 'ПИм', 'САУм'];
    final preview = [
      ...bachelor.map((p) => '$p-$suf'),
      ...master.map((p) => '$p-$suf'),
    ];

    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text('Создать группы за 20$suf?'),
        content: SizedBox(
          width: 420,
          child: SingleChildScrollView(child: Text(preview.join(', '))),
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Отмена')),
          ElevatedButton(onPressed: () => Navigator.pop(ctx, true), child: const Text('Создать')),
        ],
      ),
    );
    if (ok != true) return;

    await _createCohortOnServer(suf);
  }

  // Серверный вызов создания когорты
  Future<void> _createCohortOnServer(String suffix) async {
    try {
      final yy = int.parse(suffix);
      final yearFull = 2000 + yy;

      final resp = await http.post(
        Uri.parse('${AppConfig.serverUrl}/api/groups/generate'),
        headers: {'Content-Type': 'application/json'},
        body: json.encode({'year': yearFull}),
      );

      if (resp.statusCode == 200) {
        // Рекомендуется: сервер возвращает полный список групп
        final List<dynamic> data = json.decode(resp.body);
        setState(() {
          groups = data.map((e) => e.toString()).toList();
        });
        _toast('Группы за $yearFull добавлены',
            icon: Icons.check_circle_rounded, accent: Colors.green);
      } else {
        throw Exception('Код ответа: ${resp.statusCode}');
      }
    } catch (e) {
      // Фолбэк — локально сгенерим и добавим недостающие, чтобы не блокировать UX.
      const bachelor = ['ПМК', 'ИВТ', 'ИНФ', 'ПИ', 'САУ'];
      const master = ['ПМКм', 'ИВТм', 'ИНФм', 'ПИм', 'САУм'];
      final local = [
        ...bachelor.map((p) => '$p-$suffix'),
        ...master.map((p) => '$p-$suffix'),
      ];
      setState(() {
        final set = {...groups, ...local};
        groups = set.toList()..sort();
      });
      _toast('Сервер недоступен — набор добавлен локально',
          icon: Icons.offline_bolt_rounded);
    }
  }
}

// ====== МОДЕЛЬ ДЛЯ ЭТОГО ЭКРАНА =============================================
class ScheduleItem {
  final int lessonNumber;
  final String subject;
  final String teacher;
  final String classroom;
  final String type;
  final String weekType;

  ScheduleItem({
    required this.lessonNumber,
    required this.subject,
    required this.teacher,
    required this.classroom,
    required this.type,
    required this.weekType,
  });

  ScheduleItem copyWith({
    int? lessonNumber,
    String? subject,
    String? teacher,
    String? classroom,
    String? type,
    String? weekType,
  }) {
    return ScheduleItem(
      lessonNumber: lessonNumber ?? this.lessonNumber,
      subject: subject ?? this.subject,
      teacher: teacher ?? this.teacher,
      classroom: classroom ?? this.classroom,
      type: type ?? this.type,
      weekType: weekType ?? this.weekType,
    );
  }

  Map<String, dynamic> toJson() => {
    'lesson_number': lessonNumber,
    'subject': subject,
    'teacher': teacher,
    'classroom': classroom,
    'type': type,
  };

  static ScheduleItem fromJson(Map<String, dynamic> json) {
    return ScheduleItem(
      lessonNumber: json['lesson_number'] as int,
      subject: (json['subject'] ?? '') as String,
      teacher: (json['teacher'] ?? '') as String,
      classroom: (json['classroom'] ?? '') as String,
      type: (json['type'] ?? '') as String,
      weekType: '',
    );
  }
}
