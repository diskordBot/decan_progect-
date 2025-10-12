import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';

import '../constants.dart';
import '../widgets/custom_app_bar.dart';

/// ---------- МОДЕЛИ ----------
class TeacherScheduleWeek {
  final String weekName;
  final List<TeacherScheduleDay> days;
  TeacherScheduleWeek({required this.weekName, required this.days});
}

class TeacherScheduleDay {
  final String dayName;
  final List<TeacherScheduleItem> items;
  TeacherScheduleDay({required this.dayName, required this.items});
}

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

  Map<String, dynamic> toJson() => {
    'lesson_number': lessonNumber,
    'subject': subject,
    'group_name': groupName,
    'classroom': classroom,
    'type': type,
    'week_type': weekType,
  };

  factory TeacherScheduleItem.fromJson(Map<String, dynamic> json) =>
      TeacherScheduleItem(
        lessonNumber: json['lesson_number'],
        subject: json['subject'],
        groupName: json['group_name'],
        classroom: json['classroom'],
        type: json['type'],
        weekType: json['week_type'] ?? '',
      );
}

/// ---------- ЭКРАН ----------
class TeacherScheduleScreen extends StatefulWidget {
  const TeacherScheduleScreen({super.key});

  @override
  State<TeacherScheduleScreen> createState() => _TeacherScheduleScreenState();
}

class _TeacherScheduleScreenState extends State<TeacherScheduleScreen>
    with TickerProviderStateMixin {
  // неделя
  String _selectedWeek = 'upper';

  // фиксированный преподаватель (для роли teacher)
  String? _teacherFullName; // определяем по userId
  String? _selectedTeacher; // фолбэк/используется для не-teacher ролей

  // данные
  TeacherScheduleWeek? _currentSchedule;
  List<String> _teachers = []; // только для не-teacher

  // состояния
  bool _isLoadingTeacherProfile = false;
  bool _isLoadingTeachers = true;
  bool _isLoadingSchedule = false;
  bool _isOfflineData = false;

  // анимации
  late AnimationController _animationController;
  late AnimationController _dropdownController;
  late Animation<double> _dropdownAnimation;

  // контекст пользователя
  String _userRole = 'user';
  String? _userId;
  bool get _isTeacher => _userRole == 'teacher';

  @override
  void initState() {
    super.initState();

    _animationController =
        AnimationController(vsync: this, duration: const Duration(milliseconds: 800));
    _dropdownController =
        AnimationController(vsync: this, duration: const Duration(milliseconds: 300));
    _dropdownAnimation =
        CurvedAnimation(parent: _dropdownController, curve: Curves.easeInOut);

    _initBaseWeekIfMissing();
    _initWeekAndUser(); // асинхронный старт

    _animationController.forward();
  }

  Future<void> _initWeekAndUser() async {
    // вычисляем текущую неделю
    final w = await _computeCurrentWeekType();
    if (!mounted) return;
    setState(() => _selectedWeek = w);

    // грузим контекст пользователя и остальное
    await _loadUserContext();
  }

  @override
  void dispose() {
    _animationController.dispose();
    _dropdownController.dispose();
    super.dispose();
  }

  /// ---------- НЕДЕЛИ ----------
  Future<void> _initBaseWeekIfMissing() async {
    final prefs = await SharedPreferences.getInstance();
    final baseDate = prefs.getString('baseWeekMonday');
    final baseType = prefs.getString('baseWeekType');
    if (baseDate == null || baseType == null) {
      // считаем текущую неделю базовой верхней (можно сменить в инструментах разработчика)
      final monday = _mondayOf(DateTime.now());
      await prefs.setString('baseWeekMonday', monday.toIso8601String().split('T').first);
      await prefs.setString('baseWeekType', 'upper');
    }
  }

  Future<String> _computeCurrentWeekType([DateTime? now]) async {
    now ??= DateTime.now();
    final monday = _mondayOf(now);
    return _weekTypeForDate(monday);
  }

  DateTime _mondayOf(DateTime d) {
    final wd = d.weekday; // 1..7
    return DateTime(d.year, d.month, d.day).subtract(Duration(days: wd - 1));
  }

  Future<String> _weekTypeForDate(DateTime monday) async {
    // читаем базу
    // baseWeekMonday — ISO (yyyy-MM-dd) понедельника
    // baseWeekType   — 'upper' | 'lower'
    final prefs = await SharedPreferences.getInstance();
    final baseMondayStr = prefs.getString('baseWeekMonday');
    final baseType = prefs.getString('baseWeekType') ?? 'upper';

    if (baseMondayStr == null) {
      await prefs.setString('baseWeekMonday', monday.toIso8601String().split('T').first);
      await prefs.setString('baseWeekType', baseType);
      return baseType;
    }

    final parts = baseMondayStr.split('-');
    final baseMonday = DateTime(
      int.parse(parts[0]),
      int.parse(parts[1]),
      int.parse(parts[2]),
    );

    final diffDays = monday.difference(baseMonday).inDays;
    final diffWeeks = diffDays ~/ 7; // целые недели
    final isEven = diffWeeks % 2 == 0;
    // если чётное количество недель от базы — база; иначе — противоположная
    return isEven ? baseType : (baseType == 'upper' ? 'lower' : 'upper');
  }

  /// ---------- КОНТЕКСТ ПОЛЬЗОВАТЕЛЯ ----------
  Future<void> _loadUserContext() async {
    final prefs = await SharedPreferences.getInstance();
    _userRole = prefs.getString('userRole') ?? 'user';
    _userId = prefs.getString('userId');

    if (_isTeacher) {
      // для преподавателя: узнаём ФИО и сразу тянем расписание
      await _loadTeacherProfileAndSchedule();
    } else {
      // для остальных: старое поведение (список преподов)
      _loadSavedTeacher();
      _loadTeachers();
    }
    if (mounted) setState(() {});
  }

  Future<void> _loadTeacherProfileAndSchedule() async {
    _isLoadingTeacherProfile = true;
    setState(() {});

    String? fullName;
    try {
      if (_userId != null && _userId!.isNotEmpty) {
        final url = Uri.parse('${AppConfig.serverUrl}/api/teachers/$_userId');
        final resp = await http.get(url).timeout(const Duration(seconds: 6));
        if (resp.statusCode == 200) {
          final data = json.decode(resp.body) as Map<String, dynamic>;
          fullName = (data['full_name'] as String?)?.trim();
        }
      }
    } catch (_) {}

    // фолбэк — вдруг раньше выбирали вручную
    final prefs = await SharedPreferences.getInstance();
    final cached = prefs.getString('selectedTeacher');

    _teacherFullName = (fullName != null && fullName.isNotEmpty)
        ? fullName
        : (cached != null && cached.isNotEmpty ? cached : null);

    if (_teacherFullName != null) {
      _selectedTeacher = _teacherFullName; // унифицируем поле
      await _loadSchedule();
    }

    _isLoadingTeacherProfile = false;
    if (mounted) setState(() {});
  }

  Future<void> _loadSavedTeacher() async {
    final prefs = await SharedPreferences.getInstance();
    final saved = prefs.getString('selectedTeacher');
    if (saved != null) {
      setState(() => _selectedTeacher = saved);
      await _loadSchedule();
    }
  }

  Future<void> _saveSelectedTeacher(String teacher) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString('selectedTeacher', teacher);
  }

  /// ---------- СПИСОК ПРЕПОДОВ (для не-teacher) ----------
  Future<void> _loadTeachers() async {
    if (_isTeacher) {
      setState(() => _isLoadingTeachers = false);
      return;
    }
    try {
      final r =
      await http.get(Uri.parse('${AppConfig.serverUrl}/api/teachers'));
      if (r.statusCode == 200) {
        final list = json.decode(r.body) as List<dynamic>;
        _teachers = list
            .map((t) => (t as Map<String, dynamic>)['full_name'] as String)
            .toList();
        await _saveTeachersToCache(_teachers);
        setState(() => _isLoadingTeachers = false);
      } else {
        await _loadTeachersFromCache();
      }
    } catch (_) {
      await _loadTeachersFromCache();
    }
  }

  Future<void> _loadTeachersFromCache() async {
    final prefs = await SharedPreferences.getInstance();
    final cached = prefs.getStringList('teachersList');
    if (cached != null && cached.isNotEmpty) {
      setState(() {
        _teachers = cached;
        _isLoadingTeachers = false;
      });
    } else {
      setState(() {
        _teachers = const [
          'Иванов И.И.',
          'Петров П.П.',
          'Сидоров С.С.',
          'Кузнецова А.В.',
          'Смирнов Д.О.',
          'Васильева Е.П.',
          'Николаев М.С.',
          'Орлова Т.К.',
        ];
        _isLoadingTeachers = false;
      });
    }
  }

  Future<void> _saveTeachersToCache(List<String> teachers) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setStringList('teachersList', teachers);
  }

  /// ---------- РАСПИСАНИЕ ----------
  Future<void> _loadSchedule() async {
    final teacher = _selectedTeacher;
    if (teacher == null || teacher.isEmpty) return;

    setState(() {
      _isLoadingSchedule = true;
      _isOfflineData = false;
    });

    try {
      final url = Uri.parse(
          '${AppConfig.serverUrl}/api/teacher-schedule/$teacher/${_selectedWeek}');
      final r = await http.get(url);

      if (r.statusCode == 200) {
        final data = json.decode(r.body) as Map<String, dynamic>;
        final parsed = _parseScheduleFromJson(data);

        final prefs = await SharedPreferences.getInstance();
        await prefs.setString(
            'teacher_schedule_${teacher}_$_selectedWeek', json.encode(data));

        setState(() {
          _currentSchedule = parsed;
          _isLoadingSchedule = false;
          _isOfflineData = false;
        });
      } else {
        await _loadCachedSchedule();
      }
    } catch (_) {
      await _loadCachedSchedule();
    }
  }

  Future<void> _loadCachedSchedule() async {
    final teacher = _selectedTeacher;
    if (teacher == null) return;
    final prefs = await SharedPreferences.getInstance();
    final cached = prefs.getString('teacher_schedule_${teacher}_$_selectedWeek');
    if (cached != null) {
      final data = json.decode(cached) as Map<String, dynamic>;
      setState(() {
        _currentSchedule = _parseScheduleFromJson(data);
        _isLoadingSchedule = false;
        _isOfflineData = true;
      });
    } else {
      setState(() {
        _currentSchedule = null;
        _isLoadingSchedule = false;
      });
    }
  }

  TeacherScheduleWeek _parseScheduleFromJson(Map<String, dynamic> jsonData) {
    final days = <TeacherScheduleDay>[];
    const order = ['Понедельник', 'Вторник', 'Среда', 'Четверг', 'Пятница'];
    for (final day in order) {
      if (jsonData.containsKey(day)) {
        final lessons = jsonData[day] as List<dynamic>;
        final items =
        lessons.map((l) => TeacherScheduleItem.fromJson(l)).toList();
        days.add(TeacherScheduleDay(dayName: day, items: items));
      } else {
        days.add(TeacherScheduleDay(dayName: day, items: const []));
      }
    }
    return TeacherScheduleWeek(
      weekName: _selectedWeek == 'upper' ? 'Верхняя неделя' : 'Нижняя неделя',
      days: days,
    );
  }

  /// ---------- UI ----------
  void _onDropdownTap() {
    if (_dropdownController.status == AnimationStatus.completed) {
      _dropdownController.reverse();
    } else {
      _dropdownController.forward();
    }
  }

  void _onSelectTeacher(String teacher) {
    setState(() => _selectedTeacher = teacher);
    _saveSelectedTeacher(teacher);
    _loadSchedule();
    _dropdownController.reverse();
    _animationController
      ..reset()
      ..forward();
  }

  Future<void> _refresh() async {
    // всегда пересчитаем актуальную неделю (вдруг поменяли базу)
    final w = await _computeCurrentWeekType();
    if (mounted) setState(() => _selectedWeek = w);

    if (_selectedTeacher != null) {
      await _loadSchedule();
    } else if (_isTeacher) {
      await _loadTeacherProfileAndSchedule();
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: const CustomAppBar(
        title: 'Расписание преподавателя',
        showBackButton: true,
      ),
      body: GestureDetector(
        onTap: () {
          if (_dropdownController.status == AnimationStatus.completed) {
            _dropdownController.reverse();
          }
        },
        child: RefreshIndicator(
          onRefresh: _refresh,
          child: SingleChildScrollView(
            padding: const EdgeInsets.all(16),
            physics: const AlwaysScrollableScrollPhysics(),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                _buildWeekSelector(context),
                const SizedBox(height: 16),
                _buildTeacherSelector(context), // сам решит, что показать
                const SizedBox(height: 16),

                if (_isLoadingSchedule)
                  const Center(child: CircularProgressIndicator())
                else if (_currentSchedule != null && _selectedTeacher != null)
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      if (_isOfflineData)
                        Padding(
                          padding: const EdgeInsets.only(bottom: 12),
                          child: Text(
                            '⚠ Показано оффлайн-расписание',
                            style: TextStyle(
                              color: Colors.orange[700],
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ),
                      _buildScheduleDisplay(context),
                    ],
                  )
                else if (_isTeacher && _teacherFullName == null)
                    const Center(child: Text('Не удалось определить ваш профиль'))
                  else if (_selectedTeacher == null)
                      const Center(child: Text('Выберите преподавателя'))
                    else
                      const Center(child: Text('Расписание не найдено')),
              ],
            ),
          ),
        ),
      ),
    );
  }

  /// компактный селектор недели (как у студента)
  Widget _buildWeekSelector(BuildContext context) {
    final isLower = _selectedWeek == 'lower';
    final bg = Theme.of(context).colorScheme.surface;
    return Container(
      decoration: BoxDecoration(
        color: bg,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Theme.of(context).dividerColor.withOpacity(.4)),
      ),
      padding: const EdgeInsets.all(10),
      child: Row(
        children: [
          _weekChip(
            context,
            label: 'НИЖНЯЯ',
            selected: isLower,
            onTap: () {
              setState(() => _selectedWeek = 'lower');
              _loadSchedule();
            },
          ),
          const SizedBox(width: 8),
          _weekChip(
            context,
            label: 'ВЕРХНЯЯ',
            selected: !isLower,
            onTap: () {
              setState(() => _selectedWeek = 'upper');
              _loadSchedule();
            },
          ),
          const Spacer(),
          Icon(Icons.cached, size: 18, color: Theme.of(context).hintColor),
          const SizedBox(width: 6),
          Text(
            _selectedWeek == 'upper' ? 'Верхняя' : 'Нижняя',
            style: TextStyle(
              fontWeight: FontWeight.w600,
              color: Theme.of(context).colorScheme.onSurface,
            ),
          ),
        ],
      ),
    );
  }

  Widget _weekChip(BuildContext context,
      {required String label, required bool selected, required VoidCallback onTap}) {
    return Expanded(
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        decoration: BoxDecoration(
          gradient: selected
              ? LinearGradient(colors: [
            Colors.blue[700]!,
            Colors.blue[700]!.withOpacity(.85),
          ])
              : null,
          color: selected ? null : Theme.of(context).colorScheme.surface,
          borderRadius: BorderRadius.circular(10),
          border: Border.all(
            color: selected
                ? Colors.blue[700]!.withOpacity(.5)
                : Theme.of(context).dividerColor,
          ),
          boxShadow: selected
              ? [
            BoxShadow(
              color: Colors.blue[700]!.withOpacity(.25),
              blurRadius: 10,
              offset: const Offset(0, 4),
            )
          ]
              : [],
        ),
        child: Material(
          color: Colors.transparent,
          child: InkWell(
            onTap: onTap,
            borderRadius: BorderRadius.circular(10),
            child: Padding(
              padding: const EdgeInsets.symmetric(vertical: 10, horizontal: 8),
              child: Center(
                child: Text(
                  label,
                  style: TextStyle(
                    color: selected ? Colors.white : Theme.of(context).colorScheme.onSurface,
                    fontWeight: FontWeight.w700,
                    fontSize: 12,
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildTeacherSelector(BuildContext context) {
    // 🔒 для роли teacher — селектор скрываем, показываем фиксированную плашку
    if (_isTeacher) {
      return Container(
        decoration: BoxDecoration(
          color: Theme.of(context).colorScheme.surface,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: Theme.of(context).dividerColor.withOpacity(.4)),
        ),
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 14),
        child: _isLoadingTeacherProfile
            ? Center(
          child: CircularProgressIndicator(
            valueColor: AlwaysStoppedAnimation<Color>(
                Theme.of(context).colorScheme.primary),
          ),
        )
            : Row(
          children: [
            Icon(Icons.person, color: Theme.of(context).colorScheme.primary),
            const SizedBox(width: 10),
            Expanded(
              child: Text(
                _teacherFullName ?? 'Профиль не найден',
                style: TextStyle(
                  fontWeight: FontWeight.w600,
                  color: Theme.of(context).colorScheme.onSurface,
                ),
              ),
            ),
          ],
        ),
      );
    }

    // ↓ Обычный селектор для не-teacher ролей
    return Column(
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
        const SizedBox(height: 8),
        Material(
          elevation: 1,
          borderRadius: BorderRadius.circular(12),
          child: InkWell(
            onTap: _onDropdownTap,
            borderRadius: BorderRadius.circular(12),
            child: Container(
              decoration: BoxDecoration(
                color: Theme.of(context).cardColor,
                borderRadius: BorderRadius.circular(12),
                border:
                Border.all(color: Theme.of(context).dividerColor.withOpacity(.5)),
              ),
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
              child: Row(
                children: [
                  Icon(Icons.person, color: Theme.of(context).colorScheme.primary),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Text(
                      _selectedTeacher ?? 'Выберите преподавателя',
                      style: TextStyle(
                        color: _selectedTeacher != null
                            ? Theme.of(context).colorScheme.onBackground
                            : Theme.of(context).hintColor,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                  ),
                  RotationTransition(
                    turns: Tween(begin: 0.0, end: 0.5).animate(_dropdownAnimation),
                    child: Icon(Icons.arrow_drop_down,
                        color: Theme.of(context).colorScheme.primary),
                  ),
                ],
              ),
            ),
          ),
        ),
        SizeTransition(
          sizeFactor: _dropdownAnimation,
          axisAlignment: -1.0,
          child: FadeTransition(
            opacity: _dropdownAnimation,
            child: Padding(
              padding: const EdgeInsets.only(top: 8),
              child: Material(
                elevation: 2,
                borderRadius: BorderRadius.circular(12),
                child: ConstrainedBox(
                  constraints: const BoxConstraints(maxHeight: 220),
                  child: ListView.separated(
                    shrinkWrap: true,
                    itemCount: _teachers.length,
                    separatorBuilder: (_, __) =>
                        Divider(height: 1, color: Theme.of(context).dividerColor),
                    itemBuilder: (ctx, i) {
                      final t = _teachers[i];
                      final sel = _selectedTeacher == t;
                      return InkWell(
                        onTap: () => _onSelectTeacher(t),
                        child: Padding(
                          padding: const EdgeInsets.symmetric(
                              horizontal: 16, vertical: 12),
                          child: Row(
                            children: [
                              Icon(
                                Icons.person_outline,
                                color: sel
                                    ? Theme.of(context).colorScheme.primary
                                    : Theme.of(context).colorScheme.onSurface,
                              ),
                              const SizedBox(width: 10),
                              Expanded(
                                child: Text(
                                  t,
                                  style: TextStyle(
                                    color: sel
                                        ? Theme.of(context).colorScheme.primary
                                        : Theme.of(context).colorScheme.onBackground,
                                    fontWeight: sel ? FontWeight.w700 : FontWeight.w500,
                                  ),
                                ),
                              ),
                              if (sel)
                                Icon(Icons.check,
                                    color: Theme.of(context).colorScheme.primary),
                            ],
                          ),
                        ),
                      );
                    },
                  ),
                ),
              ),
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildScheduleDisplay(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: _currentSchedule!.days.asMap().entries.map((e) {
        final idx = e.key;
        final day = e.value;
        return AnimatedOpacity(
          opacity: 1.0,
          duration: Duration(milliseconds: 250 + idx * 90),
          child: Transform.translate(
            offset: Offset(0, idx * 6.0),
            child: _buildDayCard(context, day),
          ),
        );
      }).toList(),
    );
  }

  Widget _buildDayCard(BuildContext context, TeacherScheduleDay day) {
    return Card(
      margin: const EdgeInsets.only(bottom: 16),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(Icons.calendar_today,
                    size: 18, color: Theme.of(context).colorScheme.primary),
                const SizedBox(width: 8),
                Text(
                  day.dayName,
                  style: TextStyle(
                    fontWeight: FontWeight.w800,
                    fontSize: 16,
                    color: Theme.of(context).colorScheme.onSurface,
                  ),
                ),
                const Spacer(),
                Text(
                  '${day.items.length} пар',
                  style: TextStyle(
                    color: Theme.of(context).colorScheme.onSurfaceVariant,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),
            if (day.items.isEmpty)
              Padding(
                padding: const EdgeInsets.symmetric(vertical: 8.0),
                child: Text('🎉 Выходной! Нет занятий',
                    style: TextStyle(
                        color: Theme.of(context).colorScheme.onSurfaceVariant)),
              )
            else
              ...day.items.asMap().entries.map((e) {
                final i = e.key;
                final it = e.value;
                return AnimatedContainer(
                  duration: Duration(milliseconds: 180 + i * 40),
                  curve: Curves.easeInOut,
                  margin: const EdgeInsets.only(bottom: 10),
                  child: _buildItem(context, it),
                );
              }),
          ],
        ),
      ),
    );
  }

  Widget _buildItem(BuildContext context, TeacherScheduleItem it) {
    return Container(
      decoration: BoxDecoration(
        color: Theme.of(context).cardColor,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: _lessonColor(it.type).withOpacity(.35), width: 1),
        boxShadow: [
          BoxShadow(
              color: Colors.black.withOpacity(.04),
              blurRadius: 8,
              offset: const Offset(0, 3))
        ],
      ),
      padding: const EdgeInsets.all(12),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _numberCircle(it.lessonNumber, _lessonColor(it.type)),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  it.subject,
                  style: TextStyle(
                    fontWeight: FontWeight.w600,
                    fontSize: 16,
                    color: Theme.of(context).colorScheme.onSurface,
                  ),
                ),
                const SizedBox(height: 6),
                _miniRow(context, Icons.group, it.groupName),
                _miniRow(context, Icons.room, it.classroom),
                _miniRow(context, _lessonIcon(it.type), _lessonType(it.type)),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _numberCircle(int n, Color c) {
    return Container(
      width: 32,
      height: 32,
      decoration: BoxDecoration(color: c, shape: BoxShape.circle),
      child: Center(
        child: Text(
          '$n',
          style: const TextStyle(
              color: Colors.white, fontWeight: FontWeight.bold, fontSize: 14),
        ),
      ),
    );
  }

  Widget _miniRow(BuildContext ctx, IconData ic, String text) {
    if (text.isEmpty) return const SizedBox.shrink();
    return Padding(
      padding: const EdgeInsets.only(bottom: 4),
      child: Row(
        children: [
          Icon(ic, size: 14, color: Theme.of(ctx).colorScheme.onSurfaceVariant),
          const SizedBox(width: 6),
          Flexible(
            child: Text(
              text,
              style: TextStyle(
                fontSize: 13,
                color: Theme.of(ctx).colorScheme.onSurfaceVariant,
              ),
            ),
          )
        ],
      ),
    );
  }

  Color _lessonColor(String type) {
    switch (type) {
      case 'лекц':
        return Colors.blue;
      case 'пр':
        return Colors.green;
      case 'лб':
        return Colors.orange;
      default:
        return Colors.blue[700]!;
    }
  }

  IconData _lessonIcon(String type) {
    switch (type) {
      case 'лекц':
        return Icons.school;
      case 'пр':
        return Icons.assignment;
      case 'лб':
        return Icons.science;
      default:
        return Icons.emoji_people;
    }
  }

  String _lessonType(String type) {
    switch (type) {
      case 'лекц':
        return 'Лекция';
      case 'пр':
        return 'Практика';
      case 'лб':
        return 'Лабораторная';
      default:
        return type;
    }
  }
}
