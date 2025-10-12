import 'package:flutter/material.dart';
import '../widgets/custom_app_bar.dart';
import '../constants.dart';
import 'dart:async';
import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';



class FacultyScreen extends StatefulWidget {
  const FacultyScreen({super.key});

  @override
  State<FacultyScreen> createState() => _FacultyScreenState();
}

class _FacultyScreenState extends State<FacultyScreen> {
  final List<Department> _departments = [
    Department(
      name: 'Кафедра компьютерной инженерии',
      code: 'КИ',
      head: 'Заведующий кафедрой компьютерной инженерии',
      description: 'Кафедра осуществляет подготовку бакалавров и магистров в области информатики и вычислительной техники. Специализация включает разработку вычислительных систем, программного обеспечения, сетевых технологий и встроенных систем.',
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
              name: 'Вычислительные машины, комплексы, системы и сети (КС)',
              description: 'Подготовка в области вычислительных машин, комплексов, систем и сетей предусматривает получение глубоких теоретических и практических знаний в области разработки многопоточных распределенных Интернет-приложений с применением языков программирования высокого уровня (С++, C#, Java), Web-программирование (PHP, JavaScript, HTML, XML, MySQL), платформ для разработки приложений (.NET и J2EE), компьютерных проводных и беспроводных локальных сетей, администрирования сетевого оборудования, сетевых протоколов и сервисов Internet, программирования в компьютерных сетях с использованием протоколов семейства TCP/IP, разработки и администрирования баз данных, администрирования и настройки серверных операционных систем и сервисов, разработки встроенных микропроцессорных систем и приложений на основе технологий программируемой логики и HDL-языков, программной и аппаратной реализации обработки информации на программируемых логических интегральных схемах (FPGA), программирования мобильных устройств, защиты информации в компьютерных системах, компьютерной графики.',
            ),
            ProgramProfile(
              name: 'Программное обеспечение средств вычислительной техники (ПОВТ)',
              description: 'Подготовка в области программного обеспечения средств вычислительной техники предусматривает освоение современных технологий и языков программирования (С++, C#, Java), инструментальных средств разработки программного обеспечения прикладного и системного характера, web-сайтов и Internet-приложений, технологии управления аппаратными ресурсами компьютера, средств разработки и администрирования баз данных, архитектуру и особенности реализации операционных систем различного назначения, технологий проектирования интеллектуальных систем и систем искусственного интеллекта, программного обеспечения для суперкомпьютеров, технологий параллельного программирования, распределенных вычислений и хранения данных.',
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
              description: 'Углубленная подготовка магистров в области современных компьютерных технологий, включая advanced programming, distributed systems, artificial intelligence, и cutting-edge hardware development.',
            ),
          ],
        ),
      ],
    ),
    Department(
      name: 'Кафедра прикладной математики и искусственного интеллекта',
      code: 'ПМИИ',
      head: 'Заведующий кафедрой прикладной математики и искусственного интеллекта',
      description: 'Кафедра осуществляет подготовку бакалавров и магистров в области прикладной математики, системного анализа, прикладной информатики и программной инженерии с акцентом на искусственный интеллект и аналитические системы.',
      website: 'http://amai.fisp.donntu.ru/',
      email: 'pm_donntu@mail.ru',
      phone: '+7 (856) 301-09-51, +7 (856) 301-03-91, +7 (856) 337-72-36',
      address: 'ДНР, г. Донецк, ул. Артема, 131, 11-й корпус, аудитории 11.516, 11.417, 11.419, 11.408, 11.409',
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
              description: 'Математик-программист – одна из самых популярных профессий. Специалист занимается программированием процессов, которые невозможно смоделировать без знания математики. Основное достоинство выпускников – универсальность: они могут работать и программистами, и дизайнерами, специалистами сетевых технологий, заниматься моделированием систем и процессов, компьютерной рекламой, работать в сфере Интернет – аналитики или информационной безопасности. Специалист в области прикладной математики – это компьютерщик – аналитик, способный решать задачи независимо от сферы применения.',
            ),
            ProgramProfile(
              name: 'Бизнес-аналитика финансовых систем',
              description: 'Бизнес-аналитик – это высококвалифицированный специалист, который занимается анализом финансового или хозяйственного направления деятельности организации, это универсал, который может быть одновременно и исследователем, и программистом, и аналитиком. На кафедре осуществляется подготовка высококвалифицированных аналитиков, владеющих современными методами интеллектуальной обработки данных для принятия управленческих решений с использованием методов стратегического бизнес-анализа, навыками работы с большими данными, построением моделей бизнес-процессов.',
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
              description: 'Углубленная подготовка магистров в области прикладной математики с фокусом на современные математические методы и их применение в различных областях науки и промышленности.',
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
              description: 'Выпускники ориентированы на работу системными аналитиками, выполняют анализ деятельности предприятия и осуществляют совершенствование бизнес-процессов; работают менеджерами проектов на предприятиях: специализируются на разработке и внедрении информационных систем; руководят IT-службами предприятий; возглавляют аналитические и плановые отделы банков, страховых компаний; консультируют по вопросам оптимизации и интеллектуализации управления производственной и финансовой деятельностью предприятий.',
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
              description: 'Углубленная подготовка магистров в области системного анализа и управления сложными техническими, экономическими и социальными системами.',
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
              description: 'Профиль предусматривает подготовку в области программирования, математического и компьютерного моделирования, проектирования, разработки и использования новейших компьютерных технологий и информационных систем в различных отраслях. Студенты получают знания по разработке алгоритмического и программного обеспечения информационных систем, использованию современных прикладных программных пакетов, баз данных и знаний, защите информации, методов системного анализа, управлению предприятием, внедрению передовых интеллектуальных технологий.',
            ),
            ProgramProfile(
              name: 'Информационные системы и программирование в промышленной инженерии',
              description: 'Профиль открыт совместно с выпускающими кафедрами факультета металлургии и теплоэнергетики. Кафедры совместно готовят высококвалифицированных специалистов промышленной инженерии. Специалисты приобретут знания в области программирования широкого спектра информационных технологий для промышленного сегмента. Будут уметь организовывать промышленную разработку программного обеспечения, осуществлять анализ промышленных задач, с последующим гибким Agile-проектированием функциональной модели будущей системы.',
            ),
            ProgramProfile(
              name: 'Интеллектуальные технологии проектирования мехатронных машин',
              description: 'Профиль открыт совместно с кафедрой «Горные машины». По этому профилю будут готовить высококвалифицированных специалистов, владеющих знаниями в области мехатронных машин. Выпускники будут не просто программистами, но ещё и специалистами в области проектирования и конструирования мехатронных горных машин.',
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
              description: 'Углубленная подготовка магистров в области прикладной информатики с фокусом на разработку и применение интеллектуальных систем и технологий искусственного интеллекта.',
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
              description: 'Обучение по данному профилю предполагает освоение теоретических знаний и практических навыков, необходимых для работы программистом в области проектирования и разработки прикладного программного обеспечения и систем искусственного интеллекта. Выпускники могут выполнять следующие функции: создание, сопровождение и тестирование программного обеспечения; разработка Интернет-приложений; использование облачных вычислений; разработка моделей и структур баз знаний; разработка корпоративных и интеллектуальных систем; решение задач защиты информации; разработка приложений для промышленных и мобильных устройств.',
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
              name: 'Технологии программного обеспечения интеллектуальных систем',
              description: 'Углубленная подготовка магистров в области программной инженерии с специализацией на разработке технологий программного обеспечения для интеллектуальных систем и применении методов искусственного интеллекта.',
            ),
          ],
        ),
      ],
    ),
    Department(
      name: 'Кафедра программной инженерии им. Л. П. Фельдмана',
      code: 'ПИ',
      head: 'Заведующий кафедрой программной инженерии им. Л. П. Фельдмана',
      description: 'Кафедра «Программная инженерия» им. Л. П. Фельдмана (до 2015 г. – кафедра прикладной математики, кафедра прикладной математики и информатики) была основана в январе 1974 г. выпускниками МГУ Е. И. Харламовой и Л. П. Фельдманом. В последние годы образовательная и научная деятельность кафедры сосредоточилась на теории программирования, методах проектирования и технологиях построения больших программных систем в соответствии с международными стандартами. Специалисты по программной инженерии ориентированы на индустриальную разработку программного обеспечения для информационно-вычислительных и интеллектуальных систем различного назначения.',
      website: 'https://kpi.fisp.donntu.ru',
      email: 'pi@donntu.ru',
      phone: '+7 (856) 301-08-56, +7 (856) 301-07-62',
      address: 'ДНР, г. Донецк, ул. Кобозева 15, 5-й корпус, 4 этаж, аудитория 425',
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
              description: 'Специалисты по программной инженерии ориентированы на индустриальную разработку программного обеспечения для информационно-вычислительных и интеллектуальных систем различного назначения. Кафедра формирует профессиональные компетенции в методологии программирования, программной инженерии, новых парадигмах программирования, языках программирования и компиляторах, операционных системах, компьютерных сетях, параллельных и распределенных вычислениях, технологиях создания веб-приложений, гибких технологиях ООП и АОП, технологиях создания БД и СУБД, компьютерной графике и виртуальной реальности, защите программ и данных, программировании мобильных устройств, программировании интеллектуальных систем и искусственном интеллекте.',
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
              name: 'Методы и средства разработки программного обеспечения',
              description: 'Магистранты углубленно изучают гибкие технологии разработки программ (Agile), принципы объектно-ориентированного и агентно-ориентированного программирования, основанные на построении визуальных моделей на языках UML и Gaia с последующей автоматической генерацией программного кода. Особое внимание уделяется разработке программного обеспечения баз данных, технологиям интеллектуального анализа больших объёмов данных (Data Mining, Big Data, GRID), сетевым технологиям, созданию современных мультимедиа и гипермедиа систем, компьютерных игр, а также технологиям искусственного интеллекта - программированию нечетких систем, методам обработки изображений и распознавания образов, нейросетевым технологиям.',
            ),
          ],
        ),
      ],
    ),
    Department(
      name: 'Кафедра философии',
      code: 'ФИЛ',
      head: 'Заведующий кафедрой философии',
      description: 'Кафедра философии была создана в Донецком национальном техническом университете (в то время – индустриальном институте) в сентябре 1958 года. Научно-исследовательская работа традиционно посвящена изучению проблем гуманизации науки, техники, образования. В конце 90-х – начале 2000-х годов на кафедре была открыта аспирантура по специальности 09.00.01 «Социальная философия». С ноября 2014 года кафедрой руководит Т. Э. Рагозина, к. филос. н., доцент. Кафедра проводит международные научные конференции и издает научный философский журнал «Культура и цивилизация».',
      website: 'http://kf.sgi.donntu.ru',
      email: 'philosophy1958@mail.ru',
      phone: '+7 (856) 305-39-18',
      address: 'ДНР, г. Донецк, ул. Артема, 96, 3-й корпус, аудитория 3.238',
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
              description: 'Подготовка научных кадров в области социальной философии. Научно-исследовательская работа посвящена изучению проблем гуманизации науки, техники, образования. Кафедра проводит международные научные конференции по темам: "Культура и духовное производство", "Формы и механизмы социально-исторической преемственности", "Субъективное и объективное в историческом процессе", "Марксизм и современность: альтернативы XXI века". Издается научный философский журнал "Культура и цивилизация", включенный в перечень рецензируемых научных изданий ВАК ДНР и наукометрическую базу РИНЦ.',
            ),
          ],
        ),
      ],
    ),
  ];


  int? _expandedDepartmentIndex;
  int? _expandedProgramIndex;
  int? _expandedProfileIndex;

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
                    colors: [
                      AppColors.primary,
                      Color(0xFF6A11CB),
                    ],
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

              // Разделитель
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
                    color: Theme.of(context).colorScheme.primary.withOpacity(0.2),
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
                        color: Theme.of(context).colorScheme.onBackground,
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

  Widget _buildDepartmentCard(BuildContext context, Department department, int departmentIndex) {
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
        ),
        child: InkWell(
          onTap: () {
            setState(() {
              _expandedDepartmentIndex = isDepartmentExpanded ? null : departmentIndex;
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
                  Theme.of(context).colorScheme.primary.withOpacity(0.15),
                  Theme.of(context).colorScheme.secondary.withOpacity(0.08),
                ],
              )
                  : null,
              borderRadius: BorderRadius.circular(20),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Заголовок кафедры
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
                          colors: [
                            AppColors.primary,
                            Color(0xFF6A11CB),
                          ],
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
                          color: Theme.of(context).colorScheme.onBackground,
                        ),
                      ),
                    ),
                    Icon(
                      isDepartmentExpanded ? Icons.expand_less : Icons.expand_more,
                      color: Theme.of(context).colorScheme.primary,
                      size: 28,
                    ),
                  ],
                ),

                // Анимированное содержимое кафедры
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

                      // Разделитель
                      _buildMiniDivider(context),

                      // Адрес
                      _buildInfoItem(
                        context,
                        '📍',
                        'Адрес',
                        department.address,
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

                      // Описание кафедры
                      Container(
                        padding: const EdgeInsets.all(16),
                        decoration: BoxDecoration(
                          color: Theme.of(context).colorScheme.secondary.withOpacity(0.1),
                          borderRadius: BorderRadius.circular(12),
                          border: Border.all(
                            color: Theme.of(context).colorScheme.secondary.withOpacity(0.2),
                          ),
                        ),
                        child: Text(
                          department.description,
                          style: TextStyle(
                            fontSize: 15,
                            color: Theme.of(context).colorScheme.onBackground,
                            height: 1.5,
                          ),
                        ),
                      ),

                      const SizedBox(height: 20),

                      // Контакты
                      _buildContactInfo(context, department),

                      const SizedBox(height: 24),

                      // Разделитель
                      _buildMiniDivider(context),

                      const SizedBox(height: 16),

                      // Направления подготовки
                      Row(
                        children: [
                          Icon(Icons.school, color: Theme.of(context).colorScheme.primary, size: 20),
                          const SizedBox(width: 8),
                          Text(
                            '🎯 Направления подготовки:',
                            style: TextStyle(
                              fontSize: 18,
                              fontWeight: FontWeight.bold,
                              color: Theme.of(context).colorScheme.onBackground,
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 16),

                      ...department.programs.asMap().entries.map((entry) {
                        final programIndex = entry.key;
                        final program = entry.value;
                        return _buildProgramCard(context, program, departmentIndex, programIndex);
                      }),
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

  Widget _buildProgramCard(BuildContext context, Program program, int departmentIndex, int programIndex) {
    final isProgramExpanded = _expandedProgramIndex == programIndex &&
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
        ),
        child: InkWell(
          onTap: () {
            setState(() {
              _expandedProgramIndex = isProgramExpanded ? null : programIndex;
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
                  Theme.of(context).colorScheme.secondary.withOpacity(0.15),
                  Theme.of(context).colorScheme.primary.withOpacity(0.08),
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
                        color: Theme.of(context).colorScheme.primary.withOpacity(0.15),
                        borderRadius: BorderRadius.circular(10),
                        border: Border.all(
                          color: Theme.of(context).colorScheme.primary.withOpacity(0.3),
                        ),
                      ),
                      child: Text(
                        program.code,
                        style: TextStyle(
                          fontWeight: FontWeight.bold,
                          fontSize: 12,
                          color: Theme.of(context).colorScheme.primary,
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
                          color: Theme.of(context).colorScheme.onBackground,
                        ),
                      ),
                    ),
                    Icon(
                      isProgramExpanded ? Icons.expand_less : Icons.expand_more,
                      color: Theme.of(context).colorScheme.primary,
                      size: 24,
                    ),
                  ],
                ),

                // Информация о программе
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

                      // Информация о программе в красивом контейнере
                      Container(
                        padding: const EdgeInsets.all(12),
                        decoration: BoxDecoration(
                          color: Theme.of(context).colorScheme.primary.withOpacity(0.05),
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

                      // Профили подготовки
                      Row(
                        children: [
                          Icon(Icons.auto_awesome, color: Theme.of(context).colorScheme.secondary, size: 18),
                          const SizedBox(width: 8),
                          Text(
                            '📊 Профили подготовки:',
                            style: TextStyle(
                              fontSize: 16,
                              fontWeight: FontWeight.bold,
                              color: Theme.of(context).colorScheme.onBackground,
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 12),

                      ...program.profiles.asMap().entries.map((entry) {
                        final profileIndex = entry.key;
                        final profile = entry.value;
                        return _buildProfileCard(context, profile, departmentIndex, programIndex, profileIndex);
                      }),
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

  Widget _buildProfileCard(BuildContext context, ProgramProfile profile, int departmentIndex, int programIndex, int profileIndex) {
    final isProfileExpanded = _expandedProfileIndex == profileIndex &&
        _expandedProgramIndex == programIndex &&
        _expandedDepartmentIndex == departmentIndex;

    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(12),
      ),
      child: Card(
        elevation: 0,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(12),
        ),
        child: InkWell(
          onTap: () {
            setState(() {
              _expandedProfileIndex = isProfileExpanded ? null : profileIndex;
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
                  Theme.of(context).colorScheme.primary.withOpacity(0.1),
                  Theme.of(context).colorScheme.surface,
                ],
              )
                  : null,
              borderRadius: BorderRadius.circular(12),
              border: Border.all(
                color: Theme.of(context).colorScheme.primary.withOpacity(0.1),
              ),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    const Icon(Icons.arrow_forward_ios, size: 14, color: AppColors.primary),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        profile.name,
                        style: TextStyle(
                          fontSize: 15,
                          fontWeight: FontWeight.w600,
                          color: Theme.of(context).colorScheme.onBackground,
                        ),
                      ),
                    ),
                    Icon(
                      isProfileExpanded ? Icons.expand_less : Icons.expand_more,
                      color: Theme.of(context).colorScheme.primary,
                      size: 20,
                    ),
                  ],
                ),

                // Описание профиля
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
                            color: Theme.of(context).colorScheme.onBackground,
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

  Widget _buildInfoItem(BuildContext context, String emoji, String title, String value) {
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
          Text(
            emoji,
            style: const TextStyle(fontSize: 20),
          ),
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

  Widget _buildContactInfo(BuildContext context, Department department) {
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
              Icon(Icons.contacts, color: Theme.of(context).colorScheme.primary, size: 18),
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
          _buildContactRow(context, '📱', department.phone),
          const SizedBox(height: 8),
          _buildContactRow(context, '📧', department.email),
          const SizedBox(height: 8),
          _buildContactRow(context, '🌐', department.website),
        ],
      ),
    );
  }

  Widget _buildContactRow(BuildContext context, String emoji, String text) {
    return Row(
      children: [
        Text(emoji, style: const TextStyle(fontSize: 16)),
        const SizedBox(width: 12),
        Expanded(
          child: Text(
            text,
            style: TextStyle(
              fontSize: 14,
              color: Theme.of(context).colorScheme.onBackground,
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildInfoRow(BuildContext context, String label, String value) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 6),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 140,
            child: Text(
              label,
              style: TextStyle(
                fontWeight: FontWeight.w500,
                color: Theme.of(context).colorScheme.onBackground,
                fontSize: 14,
              ),
            ),
          ),
          Expanded(
            child: Text(
              value,
              style: TextStyle(
                color: Theme.of(context).colorScheme.onBackground,
                fontSize: 14,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

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