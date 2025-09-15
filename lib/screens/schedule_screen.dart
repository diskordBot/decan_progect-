import 'package:flutter/material.dart';
import '../widgets/custom_app_bar.dart';
import '../constants.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';
import 'package:shared_preferences/shared_preferences.dart';

// Модели данных для расписания
class ScheduleWeek {
  final String weekName;
  final List<ScheduleDay> days;

  ScheduleWeek({required this.weekName, required this.days});
}

class ScheduleDay {
  final String dayName;
  final List<ScheduleItem> items;

  ScheduleDay({required this.dayName, required this.items});
}

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

  Map<String, dynamic> toJson() => {
    'lesson_number': lessonNumber,
    'subject': subject,
    'teacher': teacher,
    'classroom': classroom,
    'type': type,
    'week_type': weekType,
  };

  factory ScheduleItem.fromJson(Map<String, dynamic> json) => ScheduleItem(
    lessonNumber: json['lesson_number'],
    subject: json['subject'],
    teacher: json['teacher'],
    classroom: json['classroom'],
    type: json['type'],
    weekType: json['week_type'] ?? '',
  );
}

class ScheduleScreen extends StatefulWidget {
  const ScheduleScreen({super.key});

  @override
  State<ScheduleScreen> createState() => _ScheduleScreenState();
}

class _ScheduleScreenState extends State<ScheduleScreen>
    with TickerProviderStateMixin {
  String _selectedWeek = 'upper';
  String? _selectedGroup;
  ScheduleWeek? _currentSchedule;
  late AnimationController _animationController;
  late AnimationController _dropdownController;
  late Animation<double> _dropdownAnimation;
  List<String> _groups = [];
  bool _isLoadingGroups = true;
  bool _isLoadingSchedule = false;

  bool _isOfflineData = false;

  @override
  void initState() {
    super.initState();
    _animationController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 800),
    );

    _dropdownController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 400),
    );
    _dropdownAnimation = Tween<double>(begin: 0.0, end: 1.0).animate(
      CurvedAnimation(parent: _dropdownController, curve: Curves.easeInOut),
    );

    _loadSavedWeek();   // 👈 загружаем сохранённую неделю
    _loadSavedGroup();  // 👈 загружаем сохранённую группу
    _loadGroups();
    _animationController.forward();
  }

  @override
  void dispose() {
    _animationController.dispose();
    _dropdownController.dispose();
    super.dispose();
  }

  // ===== Сохранение и загрузка недели =====
  Future<void> _saveSelectedWeek(String week) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString('selectedWeek', week);
  }

  Future<void> _loadSavedWeek() async {
    final prefs = await SharedPreferences.getInstance();
    final savedWeek = prefs.getString('selectedWeek');
    if (savedWeek != null) {
      setState(() {
        _selectedWeek = savedWeek;
      });
    }
  }

  Future<void> _loadSavedGroup() async {
    final prefs = await SharedPreferences.getInstance();
    final savedGroup = prefs.getString('selectedGroup');
    if (savedGroup != null) {
      setState(() {
        _selectedGroup = savedGroup;
      });
      await _loadSchedule(); // сразу грузим расписание для сохранённой группы
    }
  }

  Future<void> _saveSelectedGroup(String group) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString('selectedGroup', group);
  }

  Future<void> _loadGroups() async {
    try {
      final response = await http.get(
        Uri.parse('${AppConfig.serverUrl}/api/groups'),
      );

      if (response.statusCode == 200) {
        final List<dynamic> groupsData = json.decode(response.body);
        setState(() {
          _groups = groupsData.cast<String>();
          _isLoadingGroups = false;
        });
      } else {
        _loadFallbackGroups();
      }
    } catch (e) {
      _loadFallbackGroups();
    }
  }

  void _loadFallbackGroups() {
    setState(() {
      _groups = [
        'КИ-25', 'СП-25а', 'СП-25б', 'КСЦ-25',
        'ПИ-25а', 'ПИ-25б', 'ПИ-25в', 'ИИ-25а',
        'ИИ-25б', 'ИНФ-25', 'САУ-25', 'ПМКИ-25',
        'КИ-24', 'СП-24', 'КСЦ-24', 'ПИ-24а',
        'ПИ-24б', 'ИИ-24', 'ИНФ-24', 'САУ-24'
      ];
      _isLoadingGroups = false;
    });
  }

  Future<void> _loadSchedule() async {
    if (_selectedGroup == null) return;

    setState(() {
      _isLoadingSchedule = true;
      _isOfflineData = false;
    });

    try {
      final response = await http.get(
        Uri.parse(
            '${AppConfig.serverUrl}/api/schedule/$_selectedGroup/$_selectedWeek'),
      );

      if (response.statusCode == 200) {
        final Map<String, dynamic> scheduleData = json.decode(response.body);
        final parsed = _parseScheduleFromJson(scheduleData);

        final prefs = await SharedPreferences.getInstance();
        await prefs.setString(
            'schedule_${_selectedGroup}_$_selectedWeek', json.encode(scheduleData));

        setState(() {
          _currentSchedule = parsed;
          _isLoadingSchedule = false;
          _isOfflineData = false;
        });
      } else {
        await _loadCachedSchedule();
      }
    } catch (e) {
      await _loadCachedSchedule();
    }
  }

  Future<void> _loadCachedSchedule() async {
    final prefs = await SharedPreferences.getInstance();
    final cached =
    prefs.getString('schedule_${_selectedGroup}_$_selectedWeek');

    if (cached != null) {
      final scheduleData = json.decode(cached);
      setState(() {
        _currentSchedule = _parseScheduleFromJson(scheduleData);
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

  ScheduleWeek _parseScheduleFromJson(Map<String, dynamic> jsonData) {
    final days = <ScheduleDay>[];
    const dayOrder = [
      'Понедельник',
      'Вторник',
      'Среда',
      'Четверг',
      'Пятница',
      'Суббота'
    ];

    for (final dayName in dayOrder) {
      if (jsonData.containsKey(dayName)) {
        final lessons = jsonData[dayName] as List<dynamic>;
        final scheduleItems = lessons
            .map((lesson) => ScheduleItem.fromJson(lesson))
            .toList();
        days.add(ScheduleDay(dayName: dayName, items: scheduleItems));
      } else {
        days.add(ScheduleDay(dayName: dayName, items: []));
      }
    }

    return ScheduleWeek(
      weekName: _selectedWeek == 'upper' ? 'Верхняя неделя' : 'Нижняя неделя',
      days: days,
    );
  }

  void _onDropdownTap() {
    if (_dropdownController.status == AnimationStatus.completed) {
      _dropdownController.reverse();
    } else {
      _dropdownController.forward();
    }
  }

  // 👇 при выборе группы теперь сохраняем её
  void _onSelectGroup(String group) {
    setState(() {
      _selectedGroup = group;
    });
    _saveSelectedGroup(group);
    _loadSchedule();
    _dropdownController.reverse();
    _animationController.reset();
    _animationController.forward();
  }

  Future<void> _refreshPage() async {
    if (_selectedGroup != null) {
      await _loadSchedule();
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: const CustomAppBar(title: 'Расписание занятий'),
      body: GestureDetector(
        onTap: () {
          if (_dropdownController.status == AnimationStatus.completed) {
            _dropdownController.reverse();
          }
        },
        child: RefreshIndicator(
          onRefresh: _refreshPage,
          child: SingleChildScrollView(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                _buildWeekSelector(context),
                const SizedBox(height: 20),
                _buildGroupSelector(context),
                const SizedBox(height: 20),

                if (_isLoadingSchedule)
                  const Center(child: CircularProgressIndicator())
                else if (_currentSchedule != null && _selectedGroup != null)
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      if (_isOfflineData)
                        Padding(
                          padding: const EdgeInsets.only(bottom: 12),
                          child: Text(
                            "⚠ Показано оффлайн-расписание",
                            style: TextStyle(
                              color: Colors.orange[700],
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ),
                      _buildScheduleDisplay(context),
                    ],
                  )
                else if (_selectedGroup == null)
                    const Center(
                      child: Text('Выберите группу для отображения расписания'),
                    )
                  else
                    const Center(
                      child: Text('Расписание для выбранной группы не найдено'),
                    ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildWeekSelector(BuildContext context) {
    return Card(
      elevation: 4,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(16),
      ),
      child: Container(
        decoration: BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: [
              Theme.of(context).colorScheme.primary.withOpacity(0.1),
              Theme.of(context).colorScheme.secondary.withOpacity(0.05),
            ],
          ),
          borderRadius: BorderRadius.circular(16),
        ),
        child: Padding(
          padding: const EdgeInsets.all(20),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'Текущая неделя:',
                style: TextStyle(
                  fontWeight: FontWeight.bold,
                  fontSize: 16,
                  color: Theme.of(context).colorScheme.onBackground,
                ),
              ),
              const SizedBox(height: 16),
              Row(
                children: [
                  Expanded(
                    child: _buildWeekButton(
                      context,
                      'НИЖНЯЯ НЕДЕЛЯ',
                      'lower',
                      Icons.arrow_downward,
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: _buildWeekButton(
                      context,
                      'ВЕРХНЯЯ НЕДЕЛЯ',
                      'upper',
                      Icons.arrow_upward,
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildWeekButton(BuildContext context, String text, String weekType,
      IconData icon) {
    final isSelected = _selectedWeek == weekType;
    return AnimatedContainer(
      duration: const Duration(milliseconds: 300),
      curve: Curves.easeInOut,
      decoration: BoxDecoration(
        gradient: isSelected
            ? LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [
            AppColors.primary,
            AppColors.primary.withOpacity(0.8),
          ],
        )
            : LinearGradient(
          colors: [
            Theme.of(context).colorScheme.surface.withOpacity(0.8),
            Theme.of(context).colorScheme.surface.withOpacity(0.6),
          ],
        ),
        borderRadius: BorderRadius.circular(12),
        boxShadow: isSelected
            ? [
          BoxShadow(
            color: AppColors.primary.withOpacity(0.3),
            blurRadius: 10,
            offset: const Offset(0, 4),
          ),
        ]
            : [
          BoxShadow(
            color: Colors.grey.withOpacity(0.2),
            blurRadius: 4,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: () {
            setState(() {
              _selectedWeek = weekType;
            });
            _saveSelectedWeek(weekType); // 👈 сохраняем выбранную неделю
            _loadSchedule();
          },
          borderRadius: BorderRadius.circular(12),
          child: Padding(
            padding: const EdgeInsets.symmetric(vertical: 16, horizontal: 8),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(
                  icon,
                  size: 24,
                  color: isSelected ? Colors.white : Theme.of(context).colorScheme.onSurface,
                ),
                const SizedBox(height: 8),
                Text(
                  text,
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    fontWeight: FontWeight.w600,
                    fontSize: 12,
                    color: isSelected ? Colors.white : Theme.of(context).colorScheme.onBackground,
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildGroupSelector(BuildContext context) {
    return Card(
      elevation: 4,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(16),
      ),
      child: Container(
        decoration: BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: [
              Theme.of(context).colorScheme.primary.withOpacity(0.1),
              Theme.of(context).colorScheme.secondary.withOpacity(0.05),
            ],
          ),
          borderRadius: BorderRadius.circular(16),
        ),
        child: Padding(
          padding: const EdgeInsets.all(20),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'Выберите свою группу:',
                style: TextStyle(
                  fontWeight: FontWeight.bold,
                  fontSize: 16,
                  color: Theme.of(context).colorScheme.onBackground,
                ),
              ),
              const SizedBox(height: 16),

              if (_isLoadingGroups)
                Center(
                  child: CircularProgressIndicator(
                    valueColor: AlwaysStoppedAnimation<Color>(
                      Theme.of(context).colorScheme.primary,
                    ),
                  ),
                )
              else
                AnimatedContainer(
                  duration: const Duration(milliseconds: 300),
                  curve: Curves.easeInOut,
                  decoration: BoxDecoration(
                    color: Theme.of(context).cardColor,
                    borderRadius: BorderRadius.circular(12),
                    boxShadow: [
                      BoxShadow(
                        color: Colors.grey.withOpacity(0.2),
                        blurRadius: 8,
                        offset: const Offset(0, 4),
                      ),
                    ],
                  ),
                  child: Material(
                    color: Colors.transparent,
                    child: InkWell(
                      onTap: _onDropdownTap,
                      borderRadius: BorderRadius.circular(12),
                      child: Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 20,
                          vertical: 16,
                        ),
                        child: Row(
                          children: [
                            Icon(
                              Icons.group,
                              color: Theme.of(context).colorScheme.primary,
                              size: 20,
                            ),
                            const SizedBox(width: 12),
                            Expanded(
                              child: Text(
                                _selectedGroup ?? 'Выберите группу',
                                style: TextStyle(
                                  color: _selectedGroup != null
                                      ? Theme.of(context).colorScheme.onBackground
                                      : Theme.of(context).colorScheme.onSurface,
                                  fontWeight: FontWeight.w500,
                                  fontSize: 14,
                                ),
                              ),
                            ),
                            RotationTransition(
                              turns: Tween(begin: 0.0, end: 0.5).animate(
                                CurvedAnimation(
                                  parent: _dropdownController,
                                  curve: Curves.easeInOut,
                                ),
                              ),
                              child: Icon(
                                Icons.arrow_drop_down,
                                color: Theme.of(context).colorScheme.primary,
                                size: 24,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),
                ),

              if (!_isLoadingGroups)
                SizeTransition(
                  sizeFactor: _dropdownAnimation,
                  axisAlignment: -1.0,
                  child: FadeTransition(
                    opacity: _dropdownAnimation,
                    child: Padding(
                      padding: const EdgeInsets.only(top: 8),
                      child: Material(
                        elevation: 4,
                        borderRadius: BorderRadius.circular(12),
                        child: Container(
                          decoration: BoxDecoration(
                            color: Theme.of(context).cardColor,
                            borderRadius: BorderRadius.circular(12),
                            boxShadow: [
                              BoxShadow(
                                color: Colors.grey.withOpacity(0.2),
                                blurRadius: 10,
                                offset: const Offset(0, 4),
                              ),
                            ],
                          ),
                          child: ConstrainedBox(
                            constraints: const BoxConstraints(
                              maxHeight: 200,
                            ),
                            child: SingleChildScrollView(
                              child: Column(
                                children: _groups.map((group) {
                                  return Material(
                                    color: Colors.transparent,
                                    child: InkWell(
                                      onTap: () {
                                        _onSelectGroup(group);
                                      },
                                      child: Container(
                                        padding: const EdgeInsets.symmetric(
                                          horizontal: 20,
                                          vertical: 16,
                                        ),
                                        decoration: BoxDecoration(
                                          border: Border(
                                            bottom: BorderSide(
                                              color: Theme.of(context).dividerColor,
                                              width: 1,
                                            ),
                                          ),
                                        ),
                                        child: Row(
                                          children: [
                                            Icon(
                                              Icons.school,
                                              color: _selectedGroup == group
                                                  ? Theme.of(context).colorScheme.primary
                                                  : Theme.of(context).colorScheme.onSurface,
                                              size: 18,
                                            ),
                                            const SizedBox(width: 12),
                                            Expanded(
                                              child: Text(
                                                group,
                                                style: TextStyle(
                                                  color: _selectedGroup == group
                                                      ? Theme.of(context).colorScheme.primary
                                                      : Theme.of(context).colorScheme.onBackground,
                                                  fontWeight: _selectedGroup == group
                                                      ? FontWeight.w600
                                                      : FontWeight.w500,
                                                  fontSize: 14,
                                                ),
                                              ),
                                            ),
                                            if (_selectedGroup == group)
                                              Icon(
                                                Icons.check,
                                                color: Theme.of(context).colorScheme.primary,
                                                size: 18,
                                              ),
                                          ],
                                        ),
                                      ),
                                    ),
                                  );
                                }).toList(),
                              ),
                            ),
                          ),
                        ),
                      ),
                    ),
                  ),
                ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildScheduleDisplay(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            gradient: LinearGradient(
              begin: Alignment.centerLeft,
              end: Alignment.centerRight,
              colors: [
                Theme.of(context).colorScheme.primary.withOpacity(0.1),
                Theme.of(context).colorScheme.secondary.withOpacity(0.05),
              ],
            ),
            borderRadius: BorderRadius.circular(16),
          ),
          child: Row(
            children: [
              Icon(Icons.calendar_today, color: Theme.of(context).colorScheme.primary, size: 24),
              const SizedBox(width: 12),
              Expanded(
                child: Text(
                  '$_selectedGroup • ${_selectedWeek == 'upper'
                      ? 'Верхняя неделя'
                      : 'Нижняя неделя'}',
                  style: TextStyle(
                    fontWeight: FontWeight.bold,
                    fontSize: 16,
                    color: Theme.of(context).colorScheme.onBackground,
                  ),
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 20),
        ..._currentSchedule!
            .days
            .asMap()
            .entries
            .map((entry) {
          final index = entry.key;
          final day = entry.value;
          return AnimatedOpacity(
            opacity: 1.0,
            duration: Duration(milliseconds: 300 + (index * 100)),
            child: Transform.translate(
              offset: Offset(0, index * 10.0),
              child: _buildDaySchedule(context, day),
            ),
          );
        }),
      ],
    );
  }

  Widget _buildDaySchedule(BuildContext context, ScheduleDay day) {
    return Card(
      elevation: 4,
      margin: const EdgeInsets.only(bottom: 20),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(16),
      ),
      child: Container(
        decoration: BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: [
              Theme.of(context).cardColor,
              Theme.of(context).colorScheme.surface.withOpacity(0.8),
            ],
          ),
          borderRadius: BorderRadius.circular(16),
        ),
        child: Padding(
          padding: const EdgeInsets.all(20),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 16,
                      vertical: 8,
                    ),
                    decoration: BoxDecoration(
                      color: Theme.of(context).colorScheme.primary.withOpacity(0.1),
                      borderRadius: BorderRadius.circular(20),
                    ),
                    child: Text(
                      day.dayName,
                      style: TextStyle(
                        fontWeight: FontWeight.bold,
                        fontSize: 16,
                        color: Theme.of(context).colorScheme.primary,
                      ),
                    ),
                  ),
                  const Spacer(),
                  Text(
                    '${day.items.length} пар',
                    style: TextStyle(
                      color: Theme.of(context).colorScheme.onSurface,
                      fontSize: 14,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 16),
              if (day.items.isEmpty)
                Center(
                  child: Text(
                    '🎉 Выходной! Нет занятий',
                    style: TextStyle(
                      color: Theme.of(context).colorScheme.onSurface,
                      fontSize: 16,
                      fontStyle: FontStyle.italic,
                    ),
                  ),
                )
              else
                ...day.items
                    .asMap()
                    .entries
                    .map((entry) {
                  final index = entry.key;
                  final item = entry.value;
                  return AnimatedContainer(
                    duration: Duration(milliseconds: 200 + (index * 50)),
                    curve: Curves.easeInOut,
                    margin: const EdgeInsets.only(bottom: 12),
                    child: _buildScheduleItem(context, item),
                  );
                }),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildScheduleItem(BuildContext context, ScheduleItem item) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Theme.of(context).cardColor,
        borderRadius: BorderRadius.circular(12),
        boxShadow: [
          BoxShadow(
            color: Colors.grey.withOpacity(0.1),
            blurRadius: 8,
            offset: const Offset(0, 2),
          ),
        ],
        border: Border.all(
          color: _getLessonColor(item.type).withOpacity(0.3),
          width: 1,
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Container(
                width: 32,
                height: 32,
                decoration: BoxDecoration(
                  color: _getLessonColor(item.type),
                  shape: BoxShape.circle,
                ),
                child: Center(
                  child: Text(
                    '${item.lessonNumber}',
                    style: const TextStyle(
                      color: Colors.white,
                      fontWeight: FontWeight.bold,
                      fontSize: 14,
                    ),
                  ),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      item.subject,
                      style: TextStyle(
                        fontWeight: FontWeight.w600,
                        fontSize: 16,
                        color: Theme.of(context).colorScheme.onBackground,
                      ),
                    ),
                    const SizedBox(height: 6),
                    if (item.teacher.isNotEmpty)
                      Row(
                        children: [
                          Icon(
                            Icons.person,
                            size: 14,
                            color: Theme.of(context).colorScheme.onSurface,
                          ),
                          const SizedBox(width: 4),
                          Expanded(
                            child: Text(
                              item.teacher,
                              style: TextStyle(
                                color: Theme.of(context).colorScheme.onSurface,
                                fontSize: 13,
                              ),
                            ),
                          ),
                        ],
                      ),
                    if (item.classroom.isNotEmpty)
                      Row(
                        children: [
                          Icon(
                            Icons.room,
                            size: 14,
                            color: Theme.of(context).colorScheme.onSurface,
                          ),
                          const SizedBox(width: 4),
                          Text(
                            item.classroom,
                            style: TextStyle(
                              color: Theme.of(context).colorScheme.onSurface,
                              fontSize: 13,
                            ),
                          ),
                        ],
                      ),
                    Row(
                      children: [
                        Icon(
                          _getLessonIcon(item.type),
                          size: 14,
                          color: Theme.of(context).colorScheme.onSurface,
                        ),
                        const SizedBox(width: 4),
                        Text(
                          _getLessonType(item.type),
                          style: TextStyle(
                            color: Theme.of(context).colorScheme.onSurface,
                            fontSize: 13,
                            fontWeight: FontWeight.w500,
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Color _getLessonColor(String type) {
    switch (type) {
      case 'лекц':
        return Colors.blue;
      case 'пр':
        return Colors.green;
      case 'лб':
        return Colors.orange;
      default:
        return AppColors.primary;
    }
  }

  IconData _getLessonIcon(String type) {
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

  String _getLessonType(String type) {
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