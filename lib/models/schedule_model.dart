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
  final String weekType; // 'upper' или 'lower'

  ScheduleItem({
    required this.lessonNumber,
    required this.subject,
    required this.teacher,
    required this.classroom,
    required this.type,
    required this.weekType,
  });
}

// Группы из Excel файла
final List<String> groups = [
  'КИ-25', 'СП-25а', 'СП-25б', 'КСЦ-25', 'ПИ-25а', 'ПИ-25б', 'ПИ-25в',
  'ИИ-25а', 'ИИ-25б', 'ИНФ-25', 'САУ-25', 'ПМКИ-25', 'КИ-24', 'СП-24',
  'КСЦ-24', 'ПИ-24а', 'ПИ-24б', 'ИИ-24', 'ИНФ-24', 'САУ-24'
];