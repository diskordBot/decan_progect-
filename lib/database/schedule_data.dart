import '../models/schedule_model.dart';

class ScheduleDatabase {
  static final Map<String, Map<String, ScheduleWeek>> _scheduleData = {
    'КИ-25': {
      'upper': ScheduleWeek(
        weekName: 'Верхняя неделя',
        days: [
          ScheduleDay(
            dayName: 'Понедельник',
            items: [
              ScheduleItem(
                lessonNumber: 1,
                subject: '-',
                teacher: '',
                classroom: '',
                type: '',
                weekType: 'upper',
              ),
              ScheduleItem(
                lessonNumber: 2,
                subject: 'Физика',
                teacher: 'ст.препод. Савченко Е.В.',
                classroom: '9.411',
                type: 'лекц',
                weekType: 'upper',
              ),
              ScheduleItem(
                lessonNumber: 3,
                subject: 'Введение в специальность',
                teacher: 'доцент Аноприенко А.Я.',
                classroom: '1.001',
                type: 'лекц',
                weekType: 'upper',
              ),
              ScheduleItem(
                lessonNumber: 4,
                subject: '-',
                teacher: '',
                classroom: '',
                type: '',
                weekType: 'upper',
              ),
            ],
          ),
          ScheduleDay(
            dayName: 'Вторник',
            items: [
              ScheduleItem(
                lessonNumber: 1,
                subject: 'Программирование',
                teacher: 'доцент Дорожко Л.И., асс. Шубников В.С.',
                classroom: '4.003а',
                type: 'лб',
                weekType: 'upper',
              ),
              ScheduleItem(
                lessonNumber: 2,
                subject: 'Программирование',
                teacher: 'доцент Дорожко Л.И.',
                classroom: '5.427',
                type: 'лекц',
                weekType: 'upper',
              ),
              ScheduleItem(
                lessonNumber: 3,
                subject: 'Физическая культура и спорт',
                teacher: 'ст.препод. Соломенный Ф.Ф.',
                classroom: '',
                type: 'пр',
                weekType: 'upper',
              ),
              ScheduleItem(
                lessonNumber: 4,
                subject: 'Иностранный язык',
                teacher: 'ст.препод. Бойко В.Н., асс.Менжулина А.С.',
                classroom: '11.244, 11.236',
                type: 'пр',
                weekType: 'upper',
              ),
            ],
          ),
          // Добавьте остальные дни по аналогии
        ],
      ),
      'lower': ScheduleWeek(
        weekName: 'Нижняя неделя',
        days: [
          // Добавьте расписание для нижней недели
        ],
      ),
    },
    'СП-25а': {
      'upper': ScheduleWeek(weekName: 'Верхняя неделя', days: []),
      'lower': ScheduleWeek(weekName: 'Нижняя неделя', days: []),
    },
    'ИНФ-25': {
      'upper': ScheduleWeek(weekName: 'Верхняя неделя', days: []),
      'lower': ScheduleWeek(weekName: 'Нижняя неделя', days: []),
    },
    'ИНФ-24': {
      'upper': ScheduleWeek(weekName: 'Верхняя неделя', days: []),
      'lower': ScheduleWeek(weekName: 'Нижняя неделя', days: []),
    },
    'САУ-24': {
      'upper': ScheduleWeek(weekName: 'Верхняя неделя', days: []),
      'lower': ScheduleWeek(weekName: 'Нижняя неделя', days: []),
    },

    // Добавьте остальные группы по аналогии
  };

  static ScheduleWeek? getSchedule(String group, String weekType) {
    return _scheduleData[group]?[weekType];
  }

  static List<String> getGroups() {
    return _scheduleData.keys.toList();
  }
}