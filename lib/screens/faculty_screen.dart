// lib/screens/faculty_screen.dart
import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:flutter/services.dart';

import '../widgets/custom_app_bar.dart';
import '../constants.dart';

// 🔔 Кастомные уведомления
import 'package:decanat_progect/ui/overlay_toast.dart';

class FacultyScreen extends StatefulWidget {
  const FacultyScreen({super.key});

  @override
  State<FacultyScreen> createState() => _FacultyScreenState();
}

class _FacultyScreenState extends State<FacultyScreen> {
  // ====== ДАННЫЕ ============================================================

  final List<Department> _departments = [
    Department(
      name: 'Кафедра компьютерной инженерии',
      code: 'КИ',
      head: 'Заведующий кафедрой компьютерной инженерии',
      description:
      'Кафедра осуществляет подготовку бакалавров и магистров в области информатики и вычислительной техники. Специализация включает разработку вычислительных систем, программного обеспечения, сетевых технологий и встроенных систем.',
      website: 'http://ki.fknt.donntu.ru',
      email: 'info_ki@cs.donntu.ru',
      phone: '+7 (856) 301-08-90',
      address: 'ДНР, г. Донецк, ул. Артема, 58, 4-й корпус, аудитория 39',
      programs: [
        Program(
          code: '09.03.01',
          name: 'Информатика и вычислительная техника (ИВТ)',
          degree: 'Бакалавриат',
          duration: '4 года',
          form: 'Очная',
          profiles: [
            ProgramProfile(
              name:
              'Вычислительные машины, комплексы, системы и сети (КС)',
              description:
              'Подготовка в области вычислительных машин, комплексов, систем и сетей предусматривает получение глубоких теоретических и практических знаний в разработке многопоточных распределённых приложений, Web-программировании, сетях, администрировании, базах данных, ОС, встраиваемых системах, FPGA, мобильной разработке и защите информации.',
            ),
            ProgramProfile(
              name:
              'Программное обеспечение средств вычислительной техники (ПОВТ)',
              description:
              'Современные технологии и языки программирования (C++, C#, Java), системное и прикладное ПО, веб-сайты и web-приложения, БД, ОС, ИИ и вычисления высокого уровня, параллельные и распределённые вычисления.',
            ),
          ],
        ),
        Program(
          code: '09.04.01',
          name: 'Информатика и вычислительная техника',
          degree: 'Магистратура',
          duration: '2 года',
          form: 'Очная',
          profiles: [
            ProgramProfile(
              name: 'Магистерские программы по компьютерной инженерии',
              description:
              'Углублённая подготовка по advanced programming, distributed systems, AI и современным аппаратным технологиям.',
            ),
          ],
        ),
      ],
    ),
    Department(
      name:
      'Кафедра прикладной математики и искусственного интеллекта',
      code: 'ПМИИ',
      head:
      'Заведующий кафедрой прикладной математики и искусственного интеллекта',
      description:
      'Подготовка бакалавров и магистров в области прикладной математики, системного анализа, прикладной информатики и программной инженерии с акцентом на ИИ и аналитические системы.',
      website: 'http://amai.fisp.donntu.ru/',
      email: 'pm_donntu@mail.ru',
      phone:
      '+7 (856) 301-09-51',
      address:
      'ДНР, г. Донецк, ул. Артема, 131, 11-й корпус, ауд. 11.516, 11.417, 11.419, 11.408, 11.409',
      programs: [
        Program(
          code: '01.03.04',
          name: 'Прикладная математика (ПМК)',
          degree: 'Бакалавриат',
          duration: '4 года',
          form: 'Очная',
          profiles: [
            ProgramProfile(
              name: 'Прикладная математика и кибернетика',
              description:
              'Математик-программист — универсальный специалист: программирование процессов, моделирование систем, аналитика данных, безопасность и др.',
            ),
            ProgramProfile(
              name: 'Бизнес-аналитика финансовых систем',
              description:
              'Подготовка аналитиков, владеющих методами интеллектуальной обработки данных и стратегического анализа, навыками работы с Big Data.',
            ),
          ],
        ),
        Program(
          code: '01.04.04',
          name: 'Прикладная математика (ПМК)',
          degree: 'Магистратура',
          duration: '2 года',
          form: 'Очная',
          profiles: [
            ProgramProfile(
              name: 'Прикладная математика',
              description:
              'Современные математические методы и их применение в науке и промышленности.',
            ),
          ],
        ),
        Program(
          code: '27.03.03',
          name: 'Системный анализ и управление (САУ)',
          degree: 'Бакалавриат',
          duration: '4 года',
          form: 'Очная',
          profiles: [
            ProgramProfile(
              name: 'Системный анализ и управление',
              description:
              'Системные аналитики, менеджеры проектов, руководители IT-служб, аналитические отделы банков и страховых компаний.',
            ),
          ],
        ),
        Program(
          code: '27.04.03',
          name: 'Системный анализ и управление (САУ)',
          degree: 'Магистратура',
          duration: '2 года',
          form: 'Очная',
          profiles: [
            ProgramProfile(
              name: 'Системный анализ и управление',
              description:
              'Управление сложными техническими, экономическими и социальными системами.',
            ),
          ],
        ),
        Program(
          code: '09.03.03',
          name: 'Прикладная информатика (ИНФ)',
          degree: 'Бакалавриат',
          duration: '4 года',
          form: 'Очная',
          profiles: [
            ProgramProfile(
              name: 'Информатика в интеллектуальных системах',
              description:
              'Программирование, моделирование, проектирование, разработка и использование современных ИС в разных отраслях.',
            ),
            ProgramProfile(
              name:
              'Информационные системы и программирование в промышленной инженерии',
              description:
              'Совместно с ФМиТЭ: промышленная разработка ПО, анализ задач, Agile-проектирование.',
            ),
            ProgramProfile(
              name:
              'Интеллектуальные технологии проектирования мехатронных машин',
              description:
              'Совместно с кафедрой «Горные машины»: программирование и проектирование мехатронных машин.',
            ),
          ],
        ),
        Program(
          code: '09.04.03',
          name: 'Прикладная информатика (ИНФ)',
          degree: 'Магистратура',
          duration: '2 года',
          form: 'Очная',
          profiles: [
            ProgramProfile(
              name: 'Информатика в интеллектуальных системах',
              description:
              'Интеллектуальные системы и технологии ИИ, разработка и применение.',
            ),
          ],
        ),
        Program(
          code: '09.03.04',
          name: 'Программная инженерия (ПИ)',
          degree: 'Бакалавриат',
          duration: '4 года',
          form: 'Очная',
          profiles: [
            ProgramProfile(
              name: 'Искусственный интеллект',
              description:
              'Проектирование и разработка ПО и систем ИИ, веб, облака, базы знаний, безопасность, промышленная и мобильная разработка.',
            ),
          ],
        ),
        Program(
          code: '09.04.04',
          name: 'Программная инженерия (ПИ)',
          degree: 'Магистратура',
          duration: '2 года',
          form: 'Очная',
          profiles: [
            ProgramProfile(
              name:
              'Технологии программного обеспечения интеллектуальных систем',
              description:
              'Методы и технологии разработки ПО для интеллектуальных систем и применение ИИ.',
            ),
          ],
        ),
      ],
    ),
    Department(
      name: 'Кафедра программной инженерии им. Л. П. Фельдмана',
      code: 'ПИ',
      head:
      'Заведующий кафедрой программной инженерии им. Л. П. Фельдмана',
      description:
      'Кафедра основана в 1974 г. Сферы: теория программирования, методы проектирования и технологии построения больших программных систем, индустриальная разработка ПО.',
      website: 'https://kpi.fisp.donntu.ru',
      email: 'pi@donntu.ru',
      phone: '+7 (856) 301-08-56',
      address:
      'ДНР, г. Донецк, ул. Кобозева 15, 5-й корпус, 4 этаж, ауд. 425',
      programs: [
        Program(
          code: '09.03.04',
          name: 'Программная инженерия (ПИ)',
          degree: 'Бакалавриат',
          duration: '4 года',
          form: 'Очная',
          profiles: [
            ProgramProfile(
              name: 'Инженерия программного обеспечения (ИПО)',
              description:
              'Методология программирования, ООП/АОП, сети, распределённые вычисления, веб, БД, VR, защита программ и данных, мобильная разработка, ИИ.',
            ),
          ],
        ),
        Program(
          code: '09.04.04',
          name: 'Программная инженерия (ПИ)',
          degree: 'Магистратура',
          duration: '2 года',
          form: 'Очная',
          profiles: [
            ProgramProfile(
              name:
              'Методы и средства разработки программного обеспечения',
              description:
              'Agile, UML/Gaia, генерация кода, БД и СУБД, Data Mining/Big Data/GRID, сетевые технологии, мультимедиа/гипермедиа, игры, ИИ (нечёткие системы, CV, распознавание, НС).',
            ),
          ],
        ),
      ],
    ),
    Department(
      name: 'Кафедра философии',
      code: 'ФИЛ',
      head: 'Заведующий кафедрой философии',
      description:
      'Кафедра создана в 1958 году. Научная работа — гуманизация науки, техники, образования. Проводит международные конференции, издаёт журнал «Культура и цивилизация».',
      website: 'http://kf.sgi.donntu.ru',
      email: 'philosophy1958@mail.ru',
      phone: '+7 (856) 305-39-18',
      address: 'ДНР, г. Донецк, ул. Артема, 96, 3-й корпус, ауд. 3.238',
      programs: [
        Program(
          code: '09.00.01',
          name: 'Социальная философия',
          degree: 'Аспирантура',
          duration: '3-4 года',
          form: 'Очная',
          profiles: [
            ProgramProfile(
              name: 'Социальная философия',
              description:
              'Подготовка научных кадров. Конференции по гуманитарной проблематике, журнал «Культура и цивилизация».',
            ),
          ],
        ),
      ],
    ),
  ];

  int? _expandedDepartmentIndex;
  int? _expandedProgramIndex;
  int? _expandedProfileIndex;

  // ====== ЛАУНЧЕРЫ + ТОСТЫ ==================================================

  Future<bool> _tryLaunch(String url) async {
    try {
      final ok = await launchUrl(Uri.parse(url), mode: LaunchMode.externalApplication);
      return ok;
    } catch (_) {
      return false;
    }
  }

  Future<void> _openAddress(String address) async {
    OverlayToast.instance.show(
      'Открываю Яндекс.Карты…',
      icon: Icons.map_rounded,
      accent: AppColors.primary,
    );
    final ok = await _tryLaunch('https://yandex.ru/maps/?text=${Uri.encodeComponent(address)}');
    if (!ok) {
      OverlayToast.instance.show(
        'Не удалось открыть Яндекс.Карты',
        icon: Icons.error_outline_rounded,
        accent: Colors.red,
      );
    }
  }

  Future<void> _openPhone(String digits) async {
    OverlayToast.instance.show(
      'Открываю звонилку…',
      icon: Icons.phone_rounded,
      accent: Colors.green,
    );
    final ok = await _tryLaunch('tel:$digits');
    if (!ok) {
      OverlayToast.instance.show(
        'Не удалось открыть звонилку',
        icon: Icons.error_outline_rounded,
        accent: Colors.red,
      );
    }
  }

  Future<void> _openEmail(String email) async {
    OverlayToast.instance.show(
      'Открываю почту…',
      icon: Icons.email_rounded,
      accent: Colors.blue,
    );
    final ok = await _tryLaunch('mailto:$email');
    if (!ok) {
      OverlayToast.instance.show(
        'Не удалось открыть почту',
        icon: Icons.error_outline_rounded,
        accent: Colors.red,
      );
    }
  }

  Future<void> _openSite(String url) async {
    OverlayToast.instance.show(
      'Открываю сайт…',
      icon: Icons.public_rounded,
      accent: Colors.purple,
    );
    final ok = await _tryLaunch(url);
    if (!ok) {
      OverlayToast.instance.show(
        'Не удалось открыть сайт',
        icon: Icons.error_outline_rounded,
        accent: Colors.red,
      );
    }
  }

  Future<void> _copy(String value) async {
    await Clipboard.setData(ClipboardData(text: value));
    HapticFeedback.selectionClick();
    OverlayToast.instance.show(
      'Скопировано: $value',
      icon: Icons.check_circle_rounded,
      accent: Colors.green,
    );
  }



  // ====== UI ================================================================

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: const CustomAppBar(title: '🎓 Информация о факультете'),
      body: Container(
        decoration: BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: [
              Theme.of(context).colorScheme.background,
              Theme.of(context).colorScheme.surface.withOpacity(0.5),
            ],
          ),
        ),
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Заголовок факультета
              Container(
                padding: const EdgeInsets.all(20),
                decoration: BoxDecoration(
                  gradient: const LinearGradient(
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                    colors: [AppColors.primary, Color(0xFF6A11CB)],
                  ),
                  borderRadius: BorderRadius.circular(20),
                  boxShadow: [
                    BoxShadow(
                      color: AppColors.primary.withOpacity(0.3),
                      blurRadius: 10,
                      offset: const Offset(0, 4),
                    ),
                  ],
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      '🏛️ Факультет интеллектуальных систем и программирования',
                      style: TextStyle(
                        fontSize: 22,
                        fontWeight: FontWeight.bold,
                        color: Colors.white,
                      ),
                    ),
                    const SizedBox(height: 8),
                    Text(
                      'Донецкий национальный технический университет',
                      style: TextStyle(
                        fontSize: 16,
                        color: Colors.white.withOpacity(0.9),
                      ),
                    ),
                  ],
                ),
              ),

              const SizedBox(height: 24),

              _buildSectionDivider(context, '📚 Кафедры факультета'),
              const SizedBox(height: 16),

              // Список кафедр
              ..._departments.asMap().entries.map((entry) {
                final index = entry.key;
                final department = entry.value;
                return _buildDepartmentCard(context, department, index);
              }),

              const SizedBox(height: 32),

              // Футер
              Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: Theme.of(context).colorScheme.primary.withOpacity(0.1),
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(
                    color: Theme.of(context)
                        .colorScheme
                        .primary
                        .withOpacity(0.2),
                  ),
                ),
                child: Column(
                  children: [
                    Text(
                      '🌟 Будущее начинается здесь',
                      style: TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.bold,
                        color: Theme.of(context).colorScheme.primary,
                      ),
                    ),
                    const SizedBox(height: 8),
                    Text(
                      'Присоединяйтесь к нашему факультету и станьте частью IT-будущего!',
                      textAlign: TextAlign.center,
                      style: TextStyle(
                        fontSize: 14,
                        color:
                        Theme.of(context).colorScheme.onBackground,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildSectionDivider(BuildContext context, String title) {
    return Row(
      children: [
        Expanded(
          child: Divider(
            color: Theme.of(context).colorScheme.primary.withOpacity(0.3),
            thickness: 1,
          ),
        ),
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 12),
          child: Text(
            title,
            style: TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.w600,
              color: Theme.of(context).colorScheme.primary,
            ),
          ),
        ),
        Expanded(
          child: Divider(
            color: Theme.of(context).colorScheme.primary.withOpacity(0.3),
            thickness: 1,
          ),
        ),
      ],
    );
  }

  Widget _buildDepartmentCard(
      BuildContext context, Department department, int departmentIndex) {
    final isDepartmentExpanded = _expandedDepartmentIndex == departmentIndex;

    return Container(
      margin: const EdgeInsets.only(bottom: 20),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(20),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.1),
            blurRadius: 10,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Card(
        elevation: 0,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(20),
          side: BorderSide(
            color: Theme.of(context).colorScheme.primary.withOpacity(.18),
          ),
        ),
        child: InkWell(
          onTap: () {
            setState(() {
              _expandedDepartmentIndex =
              isDepartmentExpanded ? null : departmentIndex;
              _expandedProgramIndex = null;
              _expandedProfileIndex = null;
            });
          },
          borderRadius: BorderRadius.circular(20),
          child: AnimatedContainer(
            duration: const Duration(milliseconds: 300),
            curve: Curves.easeInOut,
            padding: const EdgeInsets.all(20),
            decoration: BoxDecoration(
              gradient: isDepartmentExpanded
                  ? LinearGradient(
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
                colors: [
                  Theme.of(context)
                      .colorScheme
                      .primary
                      .withOpacity(0.15),
                  Theme.of(context)
                      .colorScheme
                      .secondary
                      .withOpacity(0.08),
                ],
              )
                  : null,
              borderRadius: BorderRadius.circular(20),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Заголовок
                Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 16,
                        vertical: 8,
                      ),
                      decoration: BoxDecoration(
                        gradient: const LinearGradient(
                          begin: Alignment.topLeft,
                          end: Alignment.bottomRight,
                          colors: [AppColors.primary, Color(0xFF6A11CB)],
                        ),
                        borderRadius: BorderRadius.circular(12),
                        boxShadow: [
                          BoxShadow(
                            color: AppColors.primary.withOpacity(0.3),
                            blurRadius: 6,
                            offset: const Offset(0, 2),
                          ),
                        ],
                      ),
                      child: Text(
                        department.code,
                        style: const TextStyle(
                          fontWeight: FontWeight.bold,
                          fontSize: 14,
                          color: Colors.white,
                        ),
                      ),
                    ),
                    const SizedBox(width: 16),
                    Expanded(
                      child: Text(
                        department.name,
                        style: TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.w600,
                          color: Theme.of(context)
                              .colorScheme
                              .onBackground,
                        ),
                      ),
                    ),
                    Icon(
                      isDepartmentExpanded
                          ? Icons.expand_less
                          : Icons.expand_more,
                      color: Theme.of(context).colorScheme.primary,
                      size: 28,
                    ),
                  ],
                ),

                // Контент
                AnimatedCrossFade(
                  duration: const Duration(milliseconds: 300),
                  crossFadeState: isDepartmentExpanded
                      ? CrossFadeState.showSecond
                      : CrossFadeState.showFirst,
                  firstChild: const SizedBox(),
                  secondChild: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const SizedBox(height: 20),

                      _buildMiniDivider(context),

                      // Адрес (кликабельный + long press для копирования)
                      _buildInfoClickable(
                        context,
                        emoji: '📍',
                        title: 'Адрес',
                        value: department.address,
                        onTap: () => _openAddress(department.address),
                        onLongPress: () => _copy(department.address),
                      ),

                      const SizedBox(height: 16),

                      // Руководитель
                      _buildInfoItem(
                        context,
                        '👨‍🏫',
                        'Руководитель',
                        department.head,
                      ),

                      const SizedBox(height: 16),

                      // Описание
                      Container(
                        padding: const EdgeInsets.all(16),
                        decoration: BoxDecoration(
                          color: Theme.of(context)
                              .colorScheme
                              .secondary
                              .withOpacity(0.1),
                          borderRadius: BorderRadius.circular(12),
                          border: Border.all(
                            color: Theme.of(context)
                                .colorScheme
                                .secondary
                                .withOpacity(0.2),
                          ),
                        ),
                        child: Text(
                          department.description,
                          style: TextStyle(
                            fontSize: 15,
                            color: Theme.of(context)
                                .colorScheme
                                .onBackground,
                            height: 1.5,
                          ),
                        ),
                      ),

                      const SizedBox(height: 20),

                      // Контакты (кликабельные + копирование)
                      _buildContactInfo(context, department),

                      const SizedBox(height: 24),

                      _buildMiniDivider(context),
                      const SizedBox(height: 16),

                      // Направления
                      Row(
                        children: [
                          Icon(Icons.school,
                              color: Theme.of(context).colorScheme.primary,
                              size: 20),
                          const SizedBox(width: 8),
                          Text(
                            '🎯 Направления подготовки:',
                            style: TextStyle(
                              fontSize: 18,
                              fontWeight: FontWeight.bold,
                              color: Theme.of(context)
                                  .colorScheme
                                  .onBackground,
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 16),

                      ...department.programs
                          .asMap()
                          .entries
                          .map((entry) => _buildProgramCard(
                          context,
                          entry.value,
                          departmentIndex,
                          entry.key)),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildMiniDivider(BuildContext context) {
    return Divider(
      color: Theme.of(context).colorScheme.primary.withOpacity(0.2),
      thickness: 1,
      height: 20,
    );
  }

  Widget _buildProgramCard(BuildContext context, Program program,
      int departmentIndex, int programIndex) {
    final isProgramExpanded =
        _expandedProgramIndex == programIndex &&
            _expandedDepartmentIndex == departmentIndex;

    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.05),
            blurRadius: 6,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Card(
        elevation: 0,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(16),
          side: BorderSide(
            color: Theme.of(context).colorScheme.primary.withOpacity(.14),
          ),
        ),
        child: InkWell(
          onTap: () {
            setState(() {
              _expandedProgramIndex =
              isProgramExpanded ? null : programIndex;
              _expandedProfileIndex = null;
            });
          },
          borderRadius: BorderRadius.circular(16),
          child: AnimatedContainer(
            duration: const Duration(milliseconds: 250),
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              gradient: isProgramExpanded
                  ? LinearGradient(
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
                colors: [
                  Theme.of(context)
                      .colorScheme
                      .secondary
                      .withOpacity(0.15),
                  Theme.of(context)
                      .colorScheme
                      .primary
                      .withOpacity(0.08),
                ],
              )
                  : null,
              borderRadius: BorderRadius.circular(16),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 12,
                        vertical: 6,
                      ),
                      decoration: BoxDecoration(
                        color: Theme.of(context)
                            .colorScheme
                            .primary
                            .withOpacity(0.1),
                        borderRadius: BorderRadius.circular(10),
                        border: Border.all(
                          color: Theme.of(context)
                              .colorScheme
                              .primary
                              .withOpacity(0.25),
                        ),
                      ),
                      child: Text(
                        program.code,
                        style: TextStyle(
                          fontWeight: FontWeight.bold,
                          fontSize: 12,
                          color:
                          Theme.of(context).colorScheme.primary,
                        ),
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Text(
                        program.name,
                        style: TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.w600,
                          color: Theme.of(context)
                              .colorScheme
                              .onBackground,
                        ),
                      ),
                    ),
                    Icon(
                      isProgramExpanded
                          ? Icons.expand_less
                          : Icons.expand_more,
                      color: Theme.of(context).colorScheme.primary,
                      size: 24,
                    ),
                  ],
                ),

                AnimatedCrossFade(
                  duration: const Duration(milliseconds: 250),
                  crossFadeState: isProgramExpanded
                      ? CrossFadeState.showSecond
                      : CrossFadeState.showFirst,
                  firstChild: const SizedBox(),
                  secondChild: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const SizedBox(height: 16),

                      // Информация
                      Container(
                        padding: const EdgeInsets.all(12),
                        decoration: BoxDecoration(
                          color: Theme.of(context)
                              .colorScheme
                              .primary
                              .withOpacity(0.05),
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: Column(
                          children: [
                            _buildInfoRow(context, '🎓 Степень:', program.degree),
                            _buildInfoRow(context, '📅 Форма обучения:', program.form),
                            _buildInfoRow(context, '⏱️ Продолжительность:', program.duration),
                          ],
                        ),
                      ),

                      const SizedBox(height: 16),

                      Row(
                        children: [
                          Icon(Icons.auto_awesome,
                              color: Theme.of(context).colorScheme.secondary,
                              size: 18),
                          const SizedBox(width: 8),
                          Text(
                            '📊 Профили подготовки:',
                            style: TextStyle(
                              fontSize: 16,
                              fontWeight: FontWeight.bold,
                              color: Theme.of(context)
                                  .colorScheme
                                  .onBackground,
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 12),

                      ...program.profiles
                          .asMap()
                          .entries
                          .map((entry) => _buildProfileCard(
                          context,
                          entry.value,
                          departmentIndex,
                          programIndex,
                          entry.key)),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildProfileCard(
      BuildContext context,
      ProgramProfile profile,
      int departmentIndex,
      int programIndex,
      int profileIndex) {
    final isProfileExpanded =
        _expandedProfileIndex == profileIndex &&
            _expandedProgramIndex == programIndex &&
            _expandedDepartmentIndex == departmentIndex;

    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      decoration: BoxDecoration(borderRadius: BorderRadius.circular(12)),
      child: Card(
        elevation: 0,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(12),
          side: BorderSide(
              color: Theme.of(context).colorScheme.primary.withOpacity(.12)),
        ),
        child: InkWell(
          onTap: () {
            setState(() {
              _expandedProfileIndex =
              isProfileExpanded ? null : profileIndex;
            });
          },
          borderRadius: BorderRadius.circular(12),
          child: AnimatedContainer(
            duration: const Duration(milliseconds: 200),
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              gradient: isProfileExpanded
                  ? LinearGradient(
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
                colors: [
                  Theme.of(context)
                      .colorScheme
                      .primary
                      .withOpacity(0.1),
                  Theme.of(context).colorScheme.surface,
                ],
              )
                  : null,
              borderRadius: BorderRadius.circular(12),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    const Icon(Icons.arrow_forward_ios,
                        size: 14, color: AppColors.primary),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        profile.name,
                        style: TextStyle(
                          fontSize: 15,
                          fontWeight: FontWeight.w600,
                          color: Theme.of(context)
                              .colorScheme
                              .onBackground,
                        ),
                      ),
                    ),
                    Icon(
                      isProfileExpanded
                          ? Icons.expand_less
                          : Icons.expand_more,
                      color: Theme.of(context).colorScheme.primary,
                      size: 20,
                    ),
                  ],
                ),

                AnimatedCrossFade(
                  duration: const Duration(milliseconds: 200),
                  crossFadeState: isProfileExpanded
                      ? CrossFadeState.showSecond
                      : CrossFadeState.showFirst,
                  firstChild: const SizedBox(),
                  secondChild: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const SizedBox(height: 12),
                      Container(
                        padding: const EdgeInsets.all(12),
                        decoration: BoxDecoration(
                          color: Theme.of(context).colorScheme.surfaceVariant,
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: Text(
                          profile.description,
                          style: TextStyle(
                            fontSize: 14,
                            color: Theme.of(context)
                                .colorScheme
                                .onBackground,
                            height: 1.4,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  // ——— Блоки информации ———

  Widget _buildInfoItem(
      BuildContext context, String emoji, String title, String value) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.secondary.withOpacity(0.1),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: Theme.of(context).colorScheme.secondary.withOpacity(0.2),
        ),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(emoji, style: const TextStyle(fontSize: 20)),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: TextStyle(
                    fontWeight: FontWeight.w600,
                    fontSize: 14,
                    color: Theme.of(context).colorScheme.onBackground,
                  ),
                ),
                const SizedBox(height: 6),
                Text(
                  value,
                  style: TextStyle(
                    fontSize: 14,
                    color: Theme.of(context).colorScheme.onBackground,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  // Кликабельная версия (адрес)
  Widget _buildInfoClickable(
      BuildContext context, {
        required String emoji,
        required String title,
        required String value,
        VoidCallback? onTap,
        VoidCallback? onLongPress,
      }) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        borderRadius: BorderRadius.circular(12),
        onTap: onTap,
        onLongPress: onLongPress,
        child: _buildInfoItem(context, emoji, title, value),
      ),
    );
  }

  Widget _buildContactInfo(BuildContext context, Department d) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.primary.withOpacity(0.1),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: Theme.of(context).colorScheme.primary.withOpacity(0.2),
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(Icons.contacts,
                  color: Theme.of(context).colorScheme.primary, size: 18),
              const SizedBox(width: 8),
              Text(
                '📞 Контакты:',
                style: TextStyle(
                  fontWeight: FontWeight.w600,
                  fontSize: 16,
                  color: Theme.of(context).colorScheme.onBackground,
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),

          // Телефон
          _buildContactRow(
            context,
            emoji: '📱',
            text: d.phone,
            onTap: () {
              // если несколько телефонов — копируем все, и предлагаем нажать на конкретный вручную
              _copy(d.phone);
            },
            onLongPress: () => _copy(d.phone),
          ),
          const SizedBox(height: 8),

          // E-mail
          _buildContactRow(
            context,
            emoji: '📧',
            text: d.email,
            onTap: () => _openEmail(d.email),
            onLongPress: () => _copy(d.email),
          ),
          const SizedBox(height: 8),

          // Сайт
          _buildContactRow(
            context,
            emoji: '🌐',
            text: d.website,
            onTap: () => _openSite(d.website),
            onLongPress: () => _copy(d.website),
          ),
        ],
      ),
    );
  }

  Widget _buildContactRow(
      BuildContext context, {
        required String emoji,
        required String text,
        VoidCallback? onTap,
        VoidCallback? onLongPress,
      }) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        borderRadius: BorderRadius.circular(10),
        onTap: onTap,
        onLongPress: onLongPress,
        child: Row(
          children: [
            Text(emoji, style: const TextStyle(fontSize: 16)),
            const SizedBox(width: 12),
            Expanded(
              child: Text(
                text,
                style: TextStyle(
                  fontSize: 14,
                  color: Theme.of(context).colorScheme.onBackground,
                  decoration: onTap != null
                      ? TextDecoration.none
                      : TextDecoration.none,
                ),
              ),
            ),
            if (onTap != null)
              Icon(Icons.open_in_new_rounded,
                  size: 18, color: Theme.of(context).colorScheme.primary),
          ],
        ),
      ),
    );
  }

  Widget _buildInfoRow(BuildContext context, String label, String value) {
    final scheme = Theme.of(context).colorScheme;
    final labelStyle = TextStyle(
      fontWeight: FontWeight.w600,
      color: scheme.onBackground,
      fontSize: 14,
    );
    final valueStyle = TextStyle(
      fontWeight: FontWeight.w400,
      color: scheme.onBackground,
      fontSize: 14,
    );

    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 6),
      child: Text.rich(
        TextSpan(
          children: [
            TextSpan(text: label.endsWith(':') ? label : '$label:', style: labelStyle),
            const TextSpan(text: '\u00A0'), // НЕпереносимый пробел
            TextSpan(text: value, style: valueStyle),
          ],
        ),
        softWrap: true,
      ),
    );
  }

}

// ====== МОДЕЛИ ===============================================================

class Department {
  final String name;
  final String code;
  final String head;
  final String description;
  final String website;
  final String email;
  final String phone;
  final String address;
  final List<Program> programs;

  Department({
    required this.name,
    required this.code,
    required this.head,
    required this.description,
    required this.website,
    required this.email,
    required this.phone,
    required this.address,
    required this.programs,
  });
}

class Program {
  final String code;
  final String name;
  final String degree;
  final String duration;
  final String form;
  final List<ProgramProfile> profiles;

  Program({
    required this.code,
    required this.name,
    required this.degree,
    required this.duration,
    required this.form,
    required this.profiles,
  });
}

class ProgramProfile {
  final String name;
  final String description;

  ProgramProfile({
    required this.name,
    required this.description,
  });
}
