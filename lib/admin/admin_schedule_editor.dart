import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';
import 'package:decanat_progect/constants.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:flutter/animation.dart';

class AdminScheduleEditor extends StatefulWidget {
  @override
  _AdminScheduleEditorState createState() => _AdminScheduleEditorState();
}

class _AdminScheduleEditorState extends State<AdminScheduleEditor> {
  List<String> groups = [];
  String? selectedGroup;
  String selectedWeek = 'upper';
  bool isLoading = true;
  bool isAddingNewGroup = false;
  bool isEditingExisting = false;
  bool isLoadingSchedule = false;
  bool _isDropdownOpen = false; // Добавьте эту переменную
  TextEditingController newGroupController = TextEditingController();
  String _userRole = 'user';

  // Данные для расписания - раздельные для верхней и нижней недель
  Map<String, List<ScheduleItem>> upperWeekSchedule = {};
  Map<String, List<ScheduleItem>> lowerWeekSchedule = {};

  final List<String> daysOfWeek = [
    'Понедельник',
    'Вторник',
    'Среда',
    'Четверг',
    'Пятница',
    'Суббота'
  ];

  final List<String> lessonTypes = ['лекц', 'пр', 'лб'];

  // Создаем контроллеры для всех полей текста
  Map<String, TextEditingController> subjectControllers = {};
  Map<String, TextEditingController> classroomControllers = {};
  Map<String, TextEditingController> teacherControllers = {};

  @override
  void initState() {
    super.initState();
    _loadUserRole();
    _loadGroups();
  }

  Future<void> _loadUserRole() async {
    final prefs = await SharedPreferences.getInstance();
    setState(() {
      _userRole = prefs.getString('userRole') ?? 'user';
    });
  }

  @override
  void dispose() {
    // Не забываем очистить контроллеры после завершения работы
    subjectControllers.forEach((key, controller) => controller.dispose());
    classroomControllers.forEach((key, controller) => controller.dispose());
    teacherControllers.forEach((key, controller) => controller.dispose());
    newGroupController.dispose();
    super.dispose();
  }

  Future<void> _loadGroups() async {
    try {
      final response = await http.get(Uri.parse('${AppConfig.serverUrl}/api/groups'));

      if (response.statusCode == 200) {
        setState(() {
          groups = List<String>.from(json.decode(response.body));
          isLoading = false;
        });
      } else {
        _loadLocalGroups();
      }
    } catch (e) {
      _loadLocalGroups();
    }
  }

  void _loadLocalGroups() {
    setState(() {
      groups = [
        'КИ-25', 'СП-25а', 'СП-25б', 'КСЦ-25', 'ПИ-25а', 'ПИ-25б', 'ПИ-25в',
        'ИИ-25а', 'ИИ-25б', 'ИНФ-25', 'САУ-25', 'ПМКИ-25', 'КИ-24', 'СП-24',
        'КСЦ-24', 'ПИ-24а', 'ПИ-24б', 'ИИ-24', 'ИНФ-24', 'САУ-24'
      ];
      isLoading = false;
    });
  }

  Future<void> _loadExistingSchedule() async {
    if (selectedGroup == null) return;

    setState(() {
      isLoadingSchedule = true;
    });

    try {
      final response = await http.get(
        Uri.parse('${AppConfig.serverUrl}/api/schedule/$selectedGroup'),
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
                ScheduleItem.fromJson(lesson)
            ).toList();
          });
        }

        // Загружаем нижнюю неделю
        if (scheduleData['lower_week'] != null) {
          final Map<String, dynamic> lowerWeek = scheduleData['lower_week'];
          lowerWeek.forEach((day, lessons) {
            lowerWeekSchedule[day] = (lessons as List).map((lesson) =>
                ScheduleItem.fromJson(lesson)
            ).toList();
          });
        }

        setState(() {
          isLoadingSchedule = false;
          isEditingExisting = true;
        });

        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Расписание загружено для редактирования'),
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

  Future<void> _addNewGroup() async {
    if (newGroupController.text.isNotEmpty) {
      try {
        final response = await http.post(
          Uri.parse('${AppConfig.serverUrl}/api/groups'),
          headers: {'Content-Type': 'application/json'},
          body: json.encode({'group_name': newGroupController.text}),
        );

        if (response.statusCode == 200) {
          setState(() {
            groups.add(newGroupController.text);
            selectedGroup = newGroupController.text;
            isAddingNewGroup = false;
            newGroupController.clear();
          });

          // Создаем пустые структуры для новой группы
          _initializeEmptySchedules();

          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('Группа добавлена успешно'),
              backgroundColor: Colors.green,
            ),
          );
        }
      } catch (e) {
        setState(() {
          groups.add(newGroupController.text);
          selectedGroup = newGroupController.text;
          isAddingNewGroup = false;
          newGroupController.clear();
        });

        // Создаем пустые структуры для новой группы
        _initializeEmptySchedules();
      }
    }
  }

  Future<void> _saveSchedule() async {
    if (selectedGroup == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Выберите группу'),
          backgroundColor: Colors.red,
        ),
      );
      return;
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
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Расписание сохранено успешно'),
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

  Map<String, dynamic> _convertScheduleToJson(Map<String, List<ScheduleItem>> schedule) {
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

      schedule[day]!.add(ScheduleItem(
        lessonNumber: schedule[day]!.length + 1,
        subject: '',
        teacher: '',
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

  void _updateLesson(String day, int index, ScheduleItem updatedItem) {
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
    // Проверяем, имеет ли пользователь права доступа
    if (_userRole != 'admin' && _userRole != 'developer') {
      return Scaffold(
        backgroundColor: Theme.of(context).colorScheme.background,
        appBar: AppBar(
          title: Text('Доступ запрещен'),
          backgroundColor: AppColors.primary,
        ),
        body: Center(
          child: Text(
            'У вас нет прав для доступа к этому разделу',
            style: TextStyle(fontSize: 18),
          ),
        ),
      );
    }

    return Scaffold(
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
        iconTheme: IconThemeData(color: Theme.of(context).colorScheme.onPrimary),
      ),
      body: isLoading
          ? Center(child: CircularProgressIndicator())
          : SingleChildScrollView(
        padding: EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Выбор группы
            _buildGroupSelector(),
            SizedBox(height: 20),

            if (selectedGroup != null) ...[
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
                    child: const Text('Сохранить расписание'),
                  ),
                ),
              ],
            ],
          ],
        ),
      ),
    );
  }

  Widget _buildGroupSelector() {
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
              'Выберите группу:',
              style: TextStyle(
                fontWeight: FontWeight.bold,
                fontSize: 16,
                color: Theme.of(context).colorScheme.onBackground,
              ),
            ),
            SizedBox(height: 10),

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
                    keyboardType: TextInputType.text,
                  ),
                  SizedBox(height: 10),
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
                        child: Text('Добавить'),
                      ),
                      SizedBox(width: 10),
                      TextButton(
                        onPressed: () {
                          setState(() {
                            isAddingNewGroup = false;
                          });
                        },
                        child: Text('Отмена'),
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
                    Icons.group,
                    color: Theme.of(context).colorScheme.primary,
                    size: 20,
                  ),
                  SizedBox(width: 12),
                  Expanded(
                    child: Text(
                      selectedGroup ?? 'Выберите группу',
                      style: TextStyle(
                        color: selectedGroup != null
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

        // Анимированный список групп
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
                // Опция добавления новой группы
                ListTile(
                  leading: Icon(Icons.add, size: 20),
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
                Divider(height: 1),

                // Список групп
                ...groups.map((group) {
                  return ListTile(
                    leading: Icon(
                      Icons.school,
                      size: 20,
                      color: selectedGroup == group
                          ? Theme.of(context).colorScheme.primary
                          : Theme.of(context).colorScheme.onSurface,
                    ),
                    title: Text(
                      group,
                      style: TextStyle(
                        color: selectedGroup == group
                            ? Theme.of(context).colorScheme.primary
                            : Theme.of(context).colorScheme.onBackground,
                        fontWeight: selectedGroup == group
                            ? FontWeight.bold
                            : FontWeight.normal,
                      ),
                    ),
                    trailing: selectedGroup == group
                        ? Icon(
                      Icons.check,
                      size: 20,
                      color: Theme.of(context).colorScheme.primary,
                    )
                        : null,
                    onTap: () {
                      setState(() {
                        selectedGroup = group;
                        _isDropdownOpen = false;
                        isLoadingSchedule = true;
                      });
                      // Автоматически загружаем расписание при выборе группы
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

  Widget _buildLessonEditor(String day, int index, ScheduleItem lesson) {
    // Проверяем, существует ли уже контроллер, если нет, создаем его
    subjectControllers.putIfAbsent('$day-$index-${lesson.weekType}', () => TextEditingController(text: lesson.subject));
    classroomControllers.putIfAbsent('$day-$index-${lesson.weekType}', () => TextEditingController(text: lesson.classroom));
    teacherControllers.putIfAbsent('$day-$index-${lesson.weekType}', () => TextEditingController(text: lesson.teacher));

    subjectControllers['$day-$index-${lesson.weekType}']!.addListener(() {
      _updateLesson(day, index, lesson.copyWith(subject: subjectControllers['$day-$index-${lesson.weekType}']!.text));
    });

    classroomControllers['$day-$index-${lesson.weekType}']!.addListener(() {
      _updateLesson(day, index, lesson.copyWith(classroom: classroomControllers['$day-$index-${lesson.weekType}']!.text));
    });

    teacherControllers['$day-$index-${lesson.weekType}']!.addListener(() {
      _updateLesson(day, index, lesson.copyWith(teacher: teacherControllers['$day-$index-${lesson.weekType}']!.text));
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
            controller: teacherControllers['$day-$index-${lesson.weekType}'],
            decoration: InputDecoration(
              labelText: 'ФИО преподавателя',
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(12),
              ),
            ),
            textInputAction: TextInputAction.done,
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

  Map<String, dynamic> toJson() {
  return {
  'lesson_number': lessonNumber,
  'subject': subject,
  'teacher': teacher,
  'classroom': classroom,
  'type': type,
  };
  }

  static ScheduleItem fromJson(Map<String, dynamic> json) {
  return ScheduleItem(
  lessonNumber: json['lesson_number'],
  subject: json['subject'],
  teacher: json['teacher'],
  classroom: json['classroom'],
  type: json['type'],
  weekType: '', // Это поле будет установлено позже
  );
  }
  }