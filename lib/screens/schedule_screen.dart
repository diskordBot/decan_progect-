import 'package:flutter/material.dart';
import '../widgets/custom_app_bar.dart';
import '../constants.dart';
import '../models/schedule_model.dart';
import '../database/schedule_data.dart';

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
  late Animation<double> _fadeAnimation;
  late Animation<Offset> _slideAnimation;
  late AnimationController _dropdownController;
  late Animation<double> _dropdownAnimation;
  final GlobalKey _dropdownKey = GlobalKey();

  @override
  void initState() {
    super.initState();

    // Основная анимация для контента
    _animationController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 800),
    );

    _fadeAnimation = Tween<double>(begin: 0.0, end: 1.0).animate(
      CurvedAnimation(
        parent: _animationController,
        curve: Curves.easeInOut,
      ),
    );

    _slideAnimation = Tween<Offset>(begin: const Offset(0, 0.3), end: Offset.zero)
        .animate(
      CurvedAnimation(
        parent: _animationController,
        curve: Curves.easeOutBack,
      ),
    );

    // Анимация для dropdown
    _dropdownController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 400),
    );

    _dropdownAnimation = Tween<double>(begin: 0.0, end: 1.0).animate(
      CurvedAnimation(
        parent: _dropdownController,
        curve: Curves.easeInOut,
      ),
    );

    _animationController.forward();
  }

  @override
  void dispose() {
    _animationController.dispose();
    _dropdownController.dispose();
    super.dispose();
  }

  void _onDropdownTap() {
    if (_dropdownController.status == AnimationStatus.completed) {
      _dropdownController.reverse();
    } else {
      _dropdownController.forward();
    }
  }

  Future<void> _refreshPage() async {
    // Логика для обновления страницы.
    // В данном случае просто перезагружаем расписание
    setState(() {
      _currentSchedule = null; // Убираем старое расписание
    });
    await Future.delayed(const Duration(seconds: 2)); // Симуляция ожидания
    setState(() {
      _updateSchedule();
    });
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
          onRefresh: _refreshPage, // Обработчик жеста обновления
          child: SingleChildScrollView(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Выбор недели с анимацией
                SlideTransition(
                  position: _slideAnimation,
                  child: FadeTransition(
                    opacity: _fadeAnimation,
                    child: _buildWeekSelector(),
                  ),
                ),
                const SizedBox(height: 20),

                // Выбор группы с анимацией
                SlideTransition(
                  position: _slideAnimation,
                  child: FadeTransition(
                    opacity: _fadeAnimation,
                    child: _buildGroupSelector(),
                  ),
                ),
                const SizedBox(height: 20),

                // Отображение расписания с анимацией
                if (_currentSchedule != null && _selectedGroup != null)
                  SlideTransition(
                    position: Tween<Offset>(
                      begin: const Offset(0, 0.2),
                      end: Offset.zero,
                    ).animate(
                      CurvedAnimation(
                        parent: _animationController,
                        curve: Curves.easeOut,
                      ),
                    ),
                    child: FadeTransition(
                      opacity: _fadeAnimation,
                      child: _buildScheduleDisplay(),
                    ),
                  )
                else if (_selectedGroup == null)
                  const Center(
                    child: Text(
                      'Выберите группу для отображения расписания',
                      style: TextStyle(
                        color: AppColors.textLight,
                        fontSize: 16,
                      ),
                    ),
                  ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildWeekSelector() {
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
              AppColors.primary.withOpacity(0.1),
              AppColors.accent.withOpacity(0.05),
            ],
          ),
          borderRadius: BorderRadius.circular(16),
        ),
        child: Padding(
          padding: const EdgeInsets.all(20),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text(
                'Текущая неделя:',
                style: TextStyle(
                  fontWeight: FontWeight.bold,
                  fontSize: 16,
                  color: AppColors.textDark,
                ),
              ),
              const SizedBox(height: 16),
              Row(
                children: [
                  Expanded(
                    child: _buildWeekButton(
                      'НИЖНЯЯ НЕДЕЛЯ',
                      'lower',
                      Icons.arrow_downward,
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: _buildWeekButton(
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

  Widget _buildWeekButton(String text, String weekType, IconData icon) {
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
          colors: [Colors.grey[100]!, Colors.grey[50]!],
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
              _updateSchedule();
            });
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
                  color: isSelected ? Colors.white : AppColors.textLight,
                ),
                const SizedBox(height: 8),
                Text(
                  text,
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    fontWeight: FontWeight.w600,
                    fontSize: 12,
                    color: isSelected ? Colors.white : AppColors.textDark,
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildGroupSelector() {
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
              AppColors.primary.withOpacity(0.1),
              AppColors.accent.withOpacity(0.05),
            ],
          ),
          borderRadius: BorderRadius.circular(16),
        ),
        child: Padding(
          padding: const EdgeInsets.all(20),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text(
                'Выберите свою группу:',
                style: TextStyle(
                  fontWeight: FontWeight.bold,
                  fontSize: 16,
                  color: AppColors.textDark,
                ),
              ),
              const SizedBox(height: 16),

              // Анимированный контейнер для dropdown
              AnimatedContainer(
                duration: const Duration(milliseconds: 300),
                curve: Curves.easeInOut,
                decoration: BoxDecoration(
                  color: Colors.white,
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
                            color: AppColors.primary,
                            size: 20,
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: Text(
                              _selectedGroup ?? 'Выберите группу',
                              style: TextStyle(
                                color: _selectedGroup != null
                                    ? AppColors.textDark
                                    : AppColors.textLight,
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
                              color: AppColors.primary,
                              size: 24,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
              ),

              // Анимированный список групп
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
                          color: Colors.white,
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
                              children: ScheduleDatabase.getGroups().map((group) {
                                return Material(
                                  color: Colors.transparent,
                                  child: InkWell(
                                    onTap: () {
                                      setState(() {
                                        _selectedGroup = group;
                                        _updateSchedule();
                                        _dropdownController.reverse();
                                        _animationController.reset();
                                        _animationController.forward();
                                      });
                                    },
                                    child: Container(
                                      padding: const EdgeInsets.symmetric(
                                        horizontal: 20,
                                        vertical: 16,
                                      ),
                                      decoration: BoxDecoration(
                                        border: Border(
                                          bottom: BorderSide(
                                            color: Colors.grey[200]!,

                                            width: 1,
                                          ),
                                        ),
                                      ),
                                      child: Row(
                                        children: [
                                          Icon(
                                            Icons.school,
                                            color: _selectedGroup == group
                                                ? AppColors.primary
                                                : AppColors.textLight,
                                            size: 18,
                                          ),
                                          const SizedBox(width: 12),
                                          Expanded(
                                            child: Text(
                                              group,
                                              style: TextStyle(
                                                color: _selectedGroup == group
                                                    ? AppColors.primary
                                                    : AppColors.textDark,
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
                                              color: AppColors.primary,
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

  void _updateSchedule() {
    if (_selectedGroup != null) {
      _currentSchedule = ScheduleDatabase.getSchedule(_selectedGroup!, _selectedWeek);
    }
  }

  Widget _buildScheduleDisplay() {
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
                AppColors.primary.withOpacity(0.1),
                AppColors.accent.withOpacity(0.05),
              ],
            ),
            borderRadius: BorderRadius.circular(16),
          ),
          child: Row(
            children: [
              Icon(Icons.calendar_today, color: AppColors.primary, size: 24),
              const SizedBox(width: 12),
              Expanded(
                child: Text(
                  '$_selectedGroup • ${_selectedWeek == 'upper' ? 'Верхняя неделя' : 'Нижняя неделя'}',
                  style: const TextStyle(
                    fontWeight: FontWeight.bold,
                    fontSize: 16, // уменьшенный размер шрифта
                    color: AppColors.textDark,
                  ),
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 20),
        ..._currentSchedule!.days.asMap().entries.map((entry) {
          final index = entry.key;
          final day = entry.value;
          return AnimatedOpacity(
            opacity: 1.0,
            duration: Duration(milliseconds: 300 + (index * 100)),
            child: Transform.translate(
              offset: Offset(0, index * 10.0),
              child: _buildDaySchedule(day),
            ),
          );
        }),
      ],
    );
  }

  Widget _buildDaySchedule(ScheduleDay day) {
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
              Colors.white,
              Colors.grey[50]!,
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
                      color: AppColors.primary.withOpacity(0.1),
                      borderRadius: BorderRadius.circular(20),
                    ),
                    child: Text(
                      day.dayName,
                      style: const TextStyle(
                        fontWeight: FontWeight.bold,
                        fontSize: 16,
                        color: AppColors.primary,
                      ),
                    ),
                  ),
                  const Spacer(),
                  Text(
                    '${day.items.length} пар',
                    style: TextStyle(
                      color: AppColors.textLight,
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
                      color: AppColors.textLight,
                      fontSize: 16,
                      fontStyle: FontStyle.italic,
                    ),
                  ),
                )
              else
                ...day.items.asMap().entries.map((entry) {
                  final index = entry.key;
                  final item = entry.value;
                  return AnimatedContainer(
                    duration: Duration(milliseconds: 200 + (index * 50)),
                    curve: Curves.easeInOut,
                    margin: const EdgeInsets.only(bottom: 12),
                    child: _buildScheduleItem(item),
                  );
                }),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildScheduleItem(ScheduleItem item) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
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
                      style: const TextStyle(
                        fontWeight: FontWeight.w600,
                        fontSize: 16,
                        color: AppColors.textDark,
                      ),
                    ),
                    const SizedBox(height: 6),
                    if (item.teacher.isNotEmpty)
                      Row(
                        children: [
                          Icon(
                            Icons.person,
                            size: 14,
                            color: AppColors.textLight,
                          ),
                          const SizedBox(width: 4),
                          Expanded(
                            child: Text(
                              item.teacher,
                              style: TextStyle(
                                color: AppColors.textLight,
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
                            color: AppColors.textLight,
                          ),
                          const SizedBox(width: 4),
                          Text(
                            item.classroom,
                            style: TextStyle(
                              color: AppColors.textLight,
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
                          color: AppColors.textLight,
                        ),
                        const SizedBox(width: 4),
                        Text(
                          _getLessonType(item.type),
                          style: TextStyle(
                            color: AppColors.textLight,
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
