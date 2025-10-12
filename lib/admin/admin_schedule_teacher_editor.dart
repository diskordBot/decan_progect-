import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';
import 'package:decanat_progect/constants.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:flutter/animation.dart';
import 'dart:async';


class AdminScheduleTeacherEditor extends StatefulWidget {
  @override
  _AdminScheduleTeacherEditorState createState() => _AdminScheduleTeacherEditorState();
}

class _AdminScheduleTeacherEditorState extends State<AdminScheduleTeacherEditor> {
  List<String> teachers = [];
  String? selectedTeacher;
  String selectedWeek = 'upper';
  bool isLoading = true;
  bool isLoadingSchedule = false;
  bool isEditingExisting = false;
  bool _isDropdownOpen = false;

  // Данные для расписания - раздельные для верхней и нижней недель
  Map<String, List<TeacherScheduleItem>> upperWeekSchedule = {};
  Map<String, List<TeacherScheduleItem>> lowerWeekSchedule = {};

  final List<String> daysOfWeek = [
    'Понедельник',
    'Вторник',
    'Среда',
    'Четверг',
    'Пятница',
    'Суббота'
  ];

  final List<String> lessonTypes = ['лекц', 'пр', 'лб'];

  // Контроллеры для полей
  Map<String, TextEditingController> subjectControllers = {};
  Map<String, TextEditingController> classroomControllers = {};
  Map<String, TextEditingController> groupControllers = {};

  @override
  void initState() {
    super.initState();
    _loadTeachers();
  }

  @override
  void dispose() {
    subjectControllers.forEach((key, controller) => controller.dispose());
    classroomControllers.forEach((key, controller) => controller.dispose());
    groupControllers.forEach((key, controller) => controller.dispose());
    super.dispose();
  }

  Future<void> _loadTeachers() async {
    try {
      final response = await http.get(Uri.parse('${AppConfig.serverUrl}/api/teachers'));

      if (response.statusCode == 200) {
        final List<dynamic> teachersData = json.decode(response.body);
        setState(() {
          teachers = teachersData.map((teacher) => teacher['full_name'] as String).toList();
          isLoading = false;
        });

        // Сохраняем преподавателей в кеш
        final prefs = await SharedPreferences.getInstance();
        await prefs.setStringList('teachersList', teachers);
      } else {
        _loadLocalTeachers();
      }
    } catch (e) {
      _loadLocalTeachers();
    }
  }

  void _loadLocalTeachers() async {
    final prefs = await SharedPreferences.getInstance();
    final cachedTeachers = prefs.getStringList('teachersList');

    setState(() {
      teachers = cachedTeachers ?? [
        'Иванов И.И.',
        'Петров П.П.',
        'Сидоров С.С.',
        'Кузнецова А.В.',
        'Смирнов Д.О.',
        'Васильева Е.П.',
        'Николаев М.С.',
        'Орлова Т.К.'
      ];
      isLoading = false;
    });
  }

  Future<void> _loadExistingSchedule() async {
    if (selectedTeacher == null) return;

    setState(() {
      isLoadingSchedule = true;
    });

    try {
      final response = await http.get(
        Uri.parse('${AppConfig.serverUrl}/api/teacher-schedule/$selectedTeacher'),
      );

      if (response.statusCode == 200) {
        final Map<String, dynamic> scheduleData = json.decode(response.body);

        // Очищаем текущие расписания
        upperWeekSchedule.clear();
        lowerWeekSchedule.clear();

        // Загружаем верхнюю неделю
        if (scheduleData['upper_week'] != null) {
          final Map<String, dynamic> upperWeek = scheduleData['upper_week'];
          upperWeek.forEach((day, lessons) {
            upperWeekSchedule[day] = (lessons as List).map((lesson) =>
                TeacherScheduleItem.fromJson(lesson)
            ).toList();
          });
        }

        // Загружаем нижнюю неделю
        if (scheduleData['lower_week'] != null) {
          final Map<String, dynamic> lowerWeek = scheduleData['lower_week'];
          lowerWeek.forEach((day, lessons) {
            lowerWeekSchedule[day] = (lessons as List).map((lesson) =>
                TeacherScheduleItem.fromJson(lesson)
            ).toList();
          });
        }

        setState(() {
          isLoadingSchedule = false;
          isEditingExisting = true;
        });

        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Расписание преподавателя загружено для редактирования'),
            backgroundColor: Colors.green,
          ),
        );
      } else {
        setState(() {
          isLoadingSchedule = false;
          isEditingExisting = false;
        });

        // Если расписания нет, создаем пустые структуры
        _initializeEmptySchedules();
      }
    } catch (e) {
      setState(() {
        isLoadingSchedule = false;
        isEditingExisting = false;
      });

      // Если ошибка, создаем пустые структуры
      _initializeEmptySchedules();

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Ошибка загрузки расписания: $e'),
          backgroundColor: Colors.red,
        ),
      );
    }
  }

  void _initializeEmptySchedules() {
    for (var day in daysOfWeek) {
      upperWeekSchedule[day] = [];
      lowerWeekSchedule[day] = [];
    }
  }

  Future<void> _saveSchedule() async {
    if (selectedTeacher == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Выберите преподавателя'),
          backgroundColor: Colors.red,
        ),
      );
      return;
    }

    try {
      final scheduleData = {
        'teacher_name': selectedTeacher,
        'upper_week': _convertScheduleToJson(upperWeekSchedule),
        'lower_week': _convertScheduleToJson(lowerWeekSchedule),
      };

      final response = await http.post(
        Uri.parse('${AppConfig.serverUrl}/api/teacher-schedule'),
        headers: {'Content-Type': 'application/json'},
        body: json.encode(scheduleData),
      );

      if (response.statusCode == 200) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Расписание преподавателя сохранено успешно'),
            backgroundColor: Colors.green,
          ),
        );

        setState(() {
          isEditingExisting = true;
        });
      }
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Ошибка сохранения: $e'),
          backgroundColor: Colors.red,
        ),
      );
    }
  }

  Map<String, dynamic> _convertScheduleToJson(Map<String, List<TeacherScheduleItem>> schedule) {
    Map<String, dynamic> result = {};

    schedule.forEach((day, items) {
      result[day] = items.map((item) => item.toJson()).toList();
    });

    return result;
  }

  void _addLesson(String day) {
    setState(() {
      final schedule = selectedWeek == 'upper' ? upperWeekSchedule : lowerWeekSchedule;
      if (!schedule.containsKey(day)) {
        schedule[day] = [];
      }

      schedule[day]!.add(TeacherScheduleItem(
        lessonNumber: schedule[day]!.length + 1,
        subject: '',
        groupName: '',
        classroom: '',
        type: 'лекц',
        weekType: selectedWeek,
      ));
    });
  }

  void _removeLesson(String day, int index) {
    setState(() {
      final schedule = selectedWeek == 'upper' ? upperWeekSchedule : lowerWeekSchedule;
      if (schedule.containsKey(day) && index < schedule[day]!.length) {
        schedule[day]!.removeAt(index);

        // Renumber lessons
        for (int i = 0; i < schedule[day]!.length; i++) {
          schedule[day]![i] = schedule[day]![i].copyWith(lessonNumber: i + 1);
        }
      }
    });
  }

  void _updateLesson(String day, int index, TeacherScheduleItem updatedItem) {
    setState(() {
      final schedule = selectedWeek == 'upper' ? upperWeekSchedule : lowerWeekSchedule;
      if (schedule.containsKey(day) && index < schedule[day]!.length) {
        schedule[day]![index] = updatedItem;
      }
    });
  }

  void _clearSchedule() {
    setState(() {
      _initializeEmptySchedules();
      isEditingExisting = false;
    });
  }

  void _copyUpperToLowerWeek() {
    setState(() {
      lowerWeekSchedule.clear();
      upperWeekSchedule.forEach((day, lessons) {
        lowerWeekSchedule[day] = lessons.map((lesson) => lesson.copyWith(weekType: 'lower')).toList();
      });

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Расписание скопировано с верхней недели на нижнюю'),
          backgroundColor: Colors.green,
        ),
      );
    });
  }

  void _copyLowerToUpperWeek() {
    setState(() {
      upperWeekSchedule.clear();
      lowerWeekSchedule.forEach((day, lessons) {
        upperWeekSchedule[day] = lessons.map((lesson) => lesson.copyWith(weekType: 'upper')).toList();
      });

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Расписание скопировано с нижней недели на верхнюю'),
          backgroundColor: Colors.green,
        ),
      );
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
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
        iconTheme: IconThemeData(color: Theme.of(context).colorScheme.onPrimary),
      ),
      body: isLoading
          ? Center(child: CircularProgressIndicator())
          : SingleChildScrollView(
        padding: EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Выбор преподавателя
            _buildTeacherSelector(),
            SizedBox(height: 20),

            if (selectedTeacher != null) ...[
              // Автоматическая загрузка расписания
              if (!isEditingExisting && !isLoadingSchedule)
                Card(
                  elevation: 3,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(16),
                  ),
                  child: Container(
                    padding: EdgeInsets.all(16),
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
                            color: Theme.of(context).colorScheme.onBackground,
                          ),
                        ),
                        SizedBox(height: 10),
                        TextButton(
                          onPressed: _clearSchedule,
                          child: Text('Начать создание нового расписания'),
                        ),
                      ],
                    ),
                  ),
                ),

              if (!isLoadingSchedule) ...[
                SizedBox(height: 20),

                // Выбор недели и кнопки копирования
                _buildWeekSelectorWithCopyButtons(),
                SizedBox(height: 20),

                // Редактор расписания
                ..._buildScheduleEditor(),

                SizedBox(height: 20),
                Center(
                  child: ElevatedButton(
                    onPressed: _saveSchedule,
                    style: ElevatedButton.styleFrom(
                      backgroundColor: AppColors.primary,
                      foregroundColor: Colors.white,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                      padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 16),
                    ),
                    child: const Text('Сохранить расписание преподавателя'),
                  ),
                ),
              ],
            ],
          ],
        ),
      ),
    );
  }

  Widget _buildTeacherSelector() {
    return Card(
      elevation: 3,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(16),
      ),
      color: Theme.of(context).cardColor,
      child: Container(
        padding: EdgeInsets.all(16),
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
            SizedBox(height: 10),
            _buildAnimatedDropdown(),
          ],
        ),
      ),
    );
  }

  Widget _buildAnimatedDropdown() {
    return Column(
      children: [
        // Кнопка для открытия/закрытия dropdown
        Material(
          color: Colors.transparent,
          child: InkWell(
            onTap: () {
              setState(() {
                _isDropdownOpen = !_isDropdownOpen;
              });
            },
            borderRadius: BorderRadius.circular(12),
            child: Container(
              padding: EdgeInsets.symmetric(horizontal: 16, vertical: 12),
              decoration: BoxDecoration(
                border: Border.all(
                  color: Theme.of(context).dividerColor,
                  width: 1,
                ),
                borderRadius: BorderRadius.circular(12),
              ),
              child: Row(
                children: [
                  Icon(
                    Icons.person,
                    color: Theme.of(context).colorScheme.primary,
                    size: 20,
                  ),
                  SizedBox(width: 12),
                  Expanded(
                    child: Text(
                      selectedTeacher ?? 'Выберите преподавателя',
                      style: TextStyle(
                        color: selectedTeacher != null
                            ? Theme.of(context).colorScheme.onBackground
                            : Theme.of(context).colorScheme.onSurface.withOpacity(0.6),
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                  ),
                  RotationTransition(
                    turns: _isDropdownOpen
                        ? AlwaysStoppedAnimation(0.5)
                        : AlwaysStoppedAnimation(0.0),
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
        SizedBox(height: 8),

        // Анимированный список преподавателей
        AnimatedContainer(
          duration: Duration(milliseconds: 300),
          curve: Curves.easeInOut,
          height: _isDropdownOpen ? 200 : 0,
          decoration: BoxDecoration(
            color: Theme.of(context).cardColor,
            borderRadius: BorderRadius.circular(12),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withOpacity(0.1),
                blurRadius: 8,
                offset: Offset(0, 4),
              ),
            ],
          ),
          child: _isDropdownOpen
              ? Material(
            color: Colors.transparent,
            child: ListView(
              padding: EdgeInsets.zero,
              children: [
                // Список преподавателей
                ...teachers.map((teacher) {
                  return ListTile(
                    leading: Icon(
                      Icons.person,
                      size: 20,
                      color: selectedTeacher == teacher
                          ? Theme.of(context).colorScheme.primary
                          : Theme.of(context).colorScheme.onSurface,
                    ),
                    title: Text(
                      teacher,
                      style: TextStyle(
                        color: selectedTeacher == teacher
                            ? Theme.of(context).colorScheme.primary
                            : Theme.of(context).colorScheme.onBackground,
                        fontWeight: selectedTeacher == teacher
                            ? FontWeight.bold
                            : FontWeight.normal,
                      ),
                    ),
                    trailing: selectedTeacher == teacher
                        ? Icon(
                      Icons.check,
                      size: 20,
                      color: Theme.of(context).colorScheme.primary,
                    )
                        : null,
                    onTap: () {
                      setState(() {
                        selectedTeacher = teacher;
                        _isDropdownOpen = false;
                        isLoadingSchedule = true;
                      });
                      // Автоматически загружаем расписание при выборе преподавателя
                      _loadExistingSchedule();
                    },
                  );
                }).toList(),
              ],
            ),
          )
              : SizedBox.shrink(),
        ),
      ],
    );
  }

  Widget _buildWeekSelectorWithCopyButtons() {
    return Card(
      elevation: 3,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(16),
      ),
      color: Theme.of(context).cardColor,
      child: Container(
        padding: EdgeInsets.all(16),
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
            SizedBox(height: 10),
            Row(
              children: [
                Expanded(
                  child: ElevatedButton(
                    style: ElevatedButton.styleFrom(
                      backgroundColor: selectedWeek == 'upper' ? AppColors.primary : Colors.grey,
                      foregroundColor: Colors.white,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                      padding: EdgeInsets.symmetric(vertical: 16),
                    ),
                    onPressed: () {
                      setState(() {
                        selectedWeek = 'upper';
                      });
                    },
                    child: Text('ВЕРХНЯЯ НЕДЕЛЯ'),
                  ),
                ),
                SizedBox(width: 10),
                Expanded(
                  child: ElevatedButton(
                    style: ElevatedButton.styleFrom(
                      backgroundColor: selectedWeek == 'lower' ? Colors.green[700] : Colors.grey,
                      foregroundColor: Colors.white,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                      padding: EdgeInsets.symmetric(vertical: 16),
                    ),
                    onPressed: () {
                      setState(() {
                        selectedWeek = 'lower';
                      });
                    },
                    child: Text('НИЖНЯЯ НЕДЕЛЯ'),
                  ),
                ),
              ],
            ),
            SizedBox(height: 16),
            Text(
              'Копирование расписания:',
              style: TextStyle(
                fontWeight: FontWeight.bold,
                fontSize: 14,
                color: Theme.of(context).colorScheme.onBackground,
              ),
            ),
            SizedBox(height: 10),
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
                    child: Text('Верхняя → Нижняя'),
                  ),
                ),
                SizedBox(width: 10),
                Expanded(
                  child: OutlinedButton(
                    style: OutlinedButton.styleFrom(
                      foregroundColor: Colors.green[700],
                      side: BorderSide(color: Colors.green[700]!),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(8),
                      ),
                    ),
                    onPressed: _copyLowerToUpperWeek,
                    child: Text('Нижняя → Верхняя'),
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
    final schedule = selectedWeek == 'upper' ? upperWeekSchedule : lowerWeekSchedule;

    return daysOfWeek.map((day) {
      final dayLessons = schedule[day] ?? [];

      return Card(
        elevation: 3,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(16),
        ),
        margin: EdgeInsets.only(bottom: 16),
        color: Theme.of(context).cardColor,
        child: Container(
          padding: EdgeInsets.all(16),
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
                  Spacer(),
                  IconButton(
                    icon: Icon(Icons.add, color: AppColors.primary),
                    onPressed: () => _addLesson(day),
                  ),
                ],
              ),
              Divider(color: Theme.of(context).dividerColor),
              if (dayLessons.isEmpty)
                Center(
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
                }).toList(),
            ],
          ),
        ),
      );
    }).toList();
  }

  Widget _buildLessonEditor(String day, int index, TeacherScheduleItem lesson) {
    // Проверяем, существует ли уже контроллер, если нет, создаем его
    subjectControllers.putIfAbsent('$day-$index-${lesson.weekType}', () => TextEditingController(text: lesson.subject));
    classroomControllers.putIfAbsent('$day-$index-${lesson.weekType}', () => TextEditingController(text: lesson.classroom));
    groupControllers.putIfAbsent('$day-$index-${lesson.weekType}', () => TextEditingController(text: lesson.groupName));

    subjectControllers['$day-$index-${lesson.weekType}']!.addListener(() {
      _updateLesson(day, index, lesson.copyWith(subject: subjectControllers['$day-$index-${lesson.weekType}']!.text));
    });

    classroomControllers['$day-$index-${lesson.weekType}']!.addListener(() {
      _updateLesson(day, index, lesson.copyWith(classroom: classroomControllers['$day-$index-${lesson.weekType}']!.text));
    });

    groupControllers['$day-$index-${lesson.weekType}']!.addListener(() {
      _updateLesson(day, index, lesson.copyWith(groupName: groupControllers['$day-$index-${lesson.weekType}']!.text));
    });

    return Container(
      margin: EdgeInsets.only(bottom: 12),
      padding: EdgeInsets.all(12),
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
              Spacer(),
              IconButton(
                icon: Icon(Icons.delete, color: Colors.red),
                onPressed: () => _removeLesson(day, index),
              ),
            ],
          ),
          SizedBox(height: 8),
          TextField(
            controller: subjectControllers['$day-$index-${lesson.weekType}'],
            decoration: InputDecoration(
              labelText: 'Название предмета',
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(12),
              ),
            ),
            textInputAction: TextInputAction.next,
            keyboardType: TextInputType.text,
          ),
          SizedBox(height: 8),
          TextField(
            controller: groupControllers['$day-$index-${lesson.weekType}'],
            decoration: InputDecoration(
              labelText: 'Группа студентов',
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(12),
              ),
            ),
            textInputAction: TextInputAction.next,
            keyboardType: TextInputType.text,
          ),
          SizedBox(height: 8),
          // Новая строка с кабинетом и типом занятия
          Row(
            children: [
              Expanded(
                flex: 1, // 1/3 ширины
                child: TextField(
                  controller: classroomControllers['$day-$index-${lesson.weekType}'],
                  decoration: InputDecoration(
                    labelText: 'Кабинет',
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                  ),
                  textInputAction: TextInputAction.next,
                  keyboardType: TextInputType.text,
                ),
              ),
              SizedBox(width: 8),
              Expanded(
                flex: 2, // 2/3 ширины
                child: DropdownButtonFormField<String>(
                  value: lesson.type,
                  decoration: InputDecoration(
                    labelText: 'Тип занятия',
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                  ),
                  items: lessonTypes.map((type) {
                    return DropdownMenuItem(
                      value: type,
                      child: Text(_getLessonTypeName(type)),
                    );
                  }).toList(),
                  onChanged: (value) {
                    if (value != null) {
                      _updateLesson(day, index, lesson.copyWith(type: value));
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

  String _getLessonTypeName(String type) {
    switch (type) {
      case 'лекц': return 'Лекция';
      case 'пр': return 'Практика';
      case 'лб': return 'Лабораторная';
      default: return type;
    }
  }
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

  Map<String, dynamic> toJson() {
    return {
      'lesson_number': lessonNumber,
      'subject': subject,
      'group_name': groupName,
      'classroom': classroom,
      'type': type,
    };
  }

  static TeacherScheduleItem fromJson(Map<String, dynamic> json) {
    return TeacherScheduleItem(
      lessonNumber: json['lesson_number'],
      subject: json['subject'],
      groupName: json['group_name'],
      classroom: json['classroom'],
      type: json['type'],
      weekType: '', // Это поле будет установлено позже
    );
  }
}