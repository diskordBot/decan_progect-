import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:flutter/services.dart';
import 'package:decanat_progect/constants.dart';
import 'dart:async';
import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';

// ✅ Единый синий AppBar
import '../widgets/custom_app_bar.dart';

class DepartmentDetailScreen extends StatefulWidget {
  const DepartmentDetailScreen({super.key});

  @override
  State<DepartmentDetailScreen> createState() => _DepartmentDetailScreenState();
}

class _DepartmentDetailScreenState extends State<DepartmentDetailScreen>
    with SingleTickerProviderStateMixin {
  // ---- Scroll + targets
  final _scrollCtrl = ScrollController();

  // Ключи карточек подробностей (ниже)
  final _pmkKey = GlobalKey(); // 01.xx.04 Прикладная математика
  final _sauKey = GlobalKey(); // 27.xx.03 Системный анализ и управление
  final _infKey = GlobalKey(); // 09.xx.03 Прикладная информатика
  final _piKey  = GlobalKey(); // 09.xx.04 Программная инженерия

  // ---------- Helpers: launch/copy ----------
  Future<void> _launchUrl(String urlString) async {
    final Uri url = Uri.parse(urlString);
    if (!await launchUrl(url)) {
      throw Exception('Could not launch $url');
    }
  }

  Future<void> _launchMap(String address) async {
    final Uri url = Uri.parse('https://yandex.ru/maps/?text=${Uri.encodeComponent(address)}');
    if (!await launchUrl(url)) {
      throw Exception('Could not launch map');
    }
  }

  Future<void> _copyToClipboard(String text, BuildContext context) async {
    await Clipboard.setData(ClipboardData(text: text));
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text('Скопировано: $text'), duration: const Duration(seconds: 2)),
    );
  }

  // ---------- Scroll-to-section + FLASH (через Overlay, плавный и короткий) ----------
  Future<void> _scrollToSection(GlobalKey targetKey) async {
    final ctx = targetKey.currentContext;
    if (ctx == null) return;

    // 1) СНАЧАЛА плавно скроллим к карточке
    await Scrollable.ensureVisible(
      ctx,
      duration: const Duration(milliseconds: 650),
      curve: Curves.easeInOut,
      alignment: 0.06, // чуть ниже верха экрана
    );

    // 2) Даём интерфейсу «устаканиться»
    await Future.delayed(const Duration(milliseconds: 120));

    // 3) Только теперь — подсветка поверх карточки
    await _flashOverlayFor(targetKey);
  }

  Future<void> _flashOverlayFor(GlobalKey targetKey) async {
    final ctx = targetKey.currentContext;
    if (ctx == null) return;

    final render = ctx.findRenderObject() as RenderBox?;
    if (render == null) return;

    final overlay = Overlay.of(context);
    if (overlay == null) return;

    final offset = render.localToGlobal(Offset.zero);
    final size = render.size;

    const pad = 6.0;
    final rect = Rect.fromLTWH(
      offset.dx - pad,
      offset.dy - pad,
      size.width + pad * 2,
      size.height + pad * 2,
    );

    final scheme = Theme.of(context).colorScheme;

    // Контроллер анимации: ~620 мс общая длительность
    final controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 620),
    );

    // Последовательность: плавно 0→1 (вход) -> пауза -> плавно 1→0 (выход)
    final opacitySequence = TweenSequence<double>([
      // Вход (≈180 мс)
      TweenSequenceItem(
        tween: CurveTween(curve: Curves.easeOutQuad),
        weight: 180,
      ),
      // Пауза на пике (≈180 мс) — реализуем плоской кривой
      TweenSequenceItem(
        tween: ConstantTween<double>(1.0),
        weight: 180,
      ),
      // Выход (≈260 мс)
      TweenSequenceItem(
        tween: CurveTween(curve: Curves.easeInQuad).chain(Tween(begin: 1.0, end: 0.0)),
        weight: 260,
      ),
    ]).animate(controller);

    // Цвет/тень делаем мягче
    double opacity = 0.0;
    final entry = OverlayEntry(
      builder: (_) {
        return Positioned(
          left: rect.left,
          top: rect.top,
          width: rect.width,
          height: rect.height,
          child: IgnorePointer(
            ignoring: true,
            child: Opacity(
              opacity: opacity,
              child: DecoratedBox(
                decoration: BoxDecoration(
                  color: scheme.primary.withOpacity(0.12), // мягче, чем было
                  borderRadius: BorderRadius.circular(12),
                  boxShadow: [
                    BoxShadow(
                      color: scheme.primary.withOpacity(0.30),
                      blurRadius: 18,
                      spreadRadius: 2,
                    ),
                  ],
                ),
                child: const SizedBox.expand(),
              ),
            ),
          ),
        );
      },
    );

    overlay.insert(entry);
    HapticFeedback.selectionClick(); // мягкая тактильная отдача (можно убрать)

    // Слушатель для покадрового обновления overlay
    void tick() {
      opacity = opacitySequence.value;
      entry.markNeedsBuild();
    }

    controller.addListener(tick);

    // Запускаем и ждём завершения
    await controller.forward();

    // Чистим
    controller.removeListener(tick);
    controller.dispose();
    entry.remove();
  }

  // Удобная маршрутизация кодов → секции
  void _onProgramTap(String code) {
    // Сопоставим обе ступени (бак/маг) к одним разделам
    if (code.startsWith('01.03') || code.startsWith('01.04')) {
      _scrollToSection(_pmkKey);
    } else if (code.startsWith('27.03') || code.startsWith('27.04')) {
      _scrollToSection(_sauKey);
    } else if (code.startsWith('09.03.03') || code.startsWith('09.04.03')) {
      _scrollToSection(_infKey);
    } else if (code.startsWith('09.03.04') || code.startsWith('09.04.04')) {
      _scrollToSection(_piKey);
    }
  }

  @override
  void dispose() {
    _scrollCtrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;

    return Scaffold(
      backgroundColor: scheme.background,

      // ✅ Статичный синий AppBar, как на главном
      appBar: const CustomAppBar(
        title: 'Кафедра ПМИИ',
        showBackButton: true,
      ),

      body: SingleChildScrollView(
        controller: _scrollCtrl,
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Заголовок с иконкой
            _buildHeader(context),
            const SizedBox(height: 24),

            // Контактная информация
            _buildContactInfo(context),
            const SizedBox(height: 24),

            // Направления подготовки
            _buildProgramsSection(context),
            const SizedBox(height: 24),

            // Детальная информация о направлениях
            _buildProgramDetails(context),
          ],
        ),
      ),
    );
  }

  Widget _buildHeader(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        // фирменный синий градиент шапки
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [
            AppColors.primary,
            Colors.blue[800]!,
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
      child: Row(
        children: [
          const Icon(Icons.school, size: 40, color: Colors.white),
          const SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  'Кафедра прикладной математики и\nискусственного интеллекта',
                  style: TextStyle(
                    color: Colors.white,
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  'ДонНТУ • Факультет интеллектуальных систем и программирования',
                  style: TextStyle(
                    color: Colors.white.withOpacity(0.9),
                    fontSize: 12,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildContactInfo(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;

    return Card(
      elevation: 3,
      color: Theme.of(context).cardColor,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(Icons.contact_mail, color: scheme.primary),
                const SizedBox(width: 8),
                Text(
                  'Контактная информация',
                  style: TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                    color: scheme.onBackground,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 16),
            _buildContactItem(
              context,
              '📍',
              'Адрес',
              'ул.Артема 131, 11-й корпус, аудитории 11.516, 11.417, 11.419, 11.408, 11.409',
              onTap: () => _launchMap('ул.Артема 131, Донецк'),
            ),
            _buildContactItem(
              context,
              '📞',
              'Телефоны',
              '+7 (856) 301-09-51, +7 (856) 301-03-91, +7 (856) 337-72-36\n+7 (949) 0010304, +7(949) 0270303, +7(949) 0090303',
              copyText:
              '+7 (856) 301-09-51, +7 (856) 301-03-91, +7 (856) 337-72-36, +7 (949) 0010304, +7(949) 0270303, +7(949) 0090303',
            ),
            _buildContactItem(
              context,
              '📧',
              'E-mail',
              'pm_donntu@mail.ru',
              onTap: () => _launchUrl('mailto:pm_donntu@mail.ru'),
              copyText: 'pm_donntu@mail.ru',
            ),
            _buildContactItem(
              context,
              '🌐',
              'Сайт',
              'http://amai.fisp.donntu.ru/',
              onTap: () => _launchUrl('http://amai.fisp.donntu.ru/'),
              copyText: 'http://amai.fisp.donntu.ru/',
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildContactItem(
      BuildContext context,
      String emoji,
      String title,
      String value, {
        VoidCallback? onTap,
        String? copyText,
      }) {
    final scheme = Theme.of(context).colorScheme;

    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(emoji, style: const TextStyle(fontSize: 16)),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: TextStyle(
                    fontWeight: FontWeight.w600,
                    color: scheme.onBackground,
                  ),
                ),
                const SizedBox(height: 4),
                GestureDetector(
                  onTap: onTap,
                  child: Text(
                    value,
                    style: TextStyle(
                      color: onTap != null ? scheme.primary : scheme.onBackground,
                      fontSize: 14,
                      decoration: TextDecoration.none, // ← без подчёркивания
                    ),
                  ),
                ),
              ],
            ),
          ),
          if (copyText != null) ...[
            const SizedBox(width: 8),
            IconButton(
              icon: const Icon(Icons.content_copy, size: 18),
              onPressed: () => _copyToClipboard(copyText, context),
              color: scheme.primary,
              padding: EdgeInsets.zero,
              constraints: const BoxConstraints(),
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildProgramsSection(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;

    return Card(
      elevation: 3,
      color: Theme.of(context).cardColor,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(Icons.menu_book, color: scheme.primary),
                const SizedBox(width: 8),
                Text(
                  'Направления подготовки',
                  style: TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                    color: scheme.onBackground,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 16),

            // Привязываем onTap к скроллу
            _buildProgramItem(context, '01.03.04', 'Прикладная математика (ПМК)', 'Бакалавриат',
                onTap: () => _onProgramTap('01.03.04')),
            _buildProgramItem(context, '01.04.04', 'Прикладная математика (ПМК)', 'Магистратура',
                onTap: () => _onProgramTap('01.04.04')),
            _buildProgramItem(context, '27.03.03', 'Системный анализ и управление (САУ)', 'Бакалавриат',
                onTap: () => _onProgramTap('27.03.03')),
            _buildProgramItem(context, '27.04.03', 'Системный анализ и управление (САУ)', 'Магистратура',
                onTap: () => _onProgramTap('27.04.03')),
            _buildProgramItem(context, '09.03.03', 'Прикладная информатика (ИНФ)', 'Бакалавриат',
                onTap: () => _onProgramTap('09.03.03')),
            _buildProgramItem(context, '09.04.03', 'Прикладная информатика (ИНФ)', 'Магистратура',
                onTap: () => _onProgramTap('09.04.03')),
            _buildProgramItem(context, '09.03.04', 'Программная инженерия (ПИ)', 'Бакалавриат',
                onTap: () => _onProgramTap('09.03.04')),
            _buildProgramItem(context, '09.04.04', 'Программная инженерия (ПИ)', 'Магистратура',
                onTap: () => _onProgramTap('09.04.04')),
          ],
        ),
      ),
    );
  }

  Widget _buildProgramItem(
      BuildContext context,
      String code,
      String name,
      String degree, {
        VoidCallback? onTap,
      }) {
    final scheme = Theme.of(context).colorScheme;

    return InkWell(
      borderRadius: BorderRadius.circular(12),
      onTap: onTap,
      child: Container(
        margin: const EdgeInsets.only(bottom: 12),
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: scheme.primary.withOpacity(0.05),
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: scheme.primary.withOpacity(0.12)),
        ),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // 🔵 Синий бейдж с кодом
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
              decoration: BoxDecoration(
                color: AppColors.primary,
                borderRadius: BorderRadius.circular(8),
              ),
              child: Text(
                code,
                style: const TextStyle(
                  color: Colors.white,
                  fontSize: 12.5,
                  fontWeight: FontWeight.w800,
                  letterSpacing: .2,
                ),
              ),
            ),
            const SizedBox(width: 12),

            // Название и уровень
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    name,
                    style: TextStyle(
                      fontWeight: FontWeight.w600,
                      color: scheme.onBackground,
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    degree,
                    style: TextStyle(
                      color: scheme.onSurface,
                      fontSize: 12.5,
                    ),
                  ),
                ],
              ),
            ),
            const Icon(Icons.arrow_downward_rounded, size: 18),
          ],
        ),
      ),
    );
  }

  Widget _buildProgramDetails(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Подробная информация о направлениях',
          style: TextStyle(
            fontSize: 18,
            fontWeight: FontWeight.bold,
            color: scheme.onBackground,
          ),
        ),
        const SizedBox(height: 16),

        // Прикладная математика
        _buildProgramDetailCard(
          context,
          key: _pmkKey,
          title: '01.03.04 Прикладная математика',
          childBlocks: [
            _buildProfileDetail(
              context,
              'Прикладная математика и кибернетика',
              'Математик-программист – одна из самых популярных профессий. Специалист занимается программированием процессов, которые невозможно смоделировать без знания математики.\n\nОсновное достоинство выпускников – универсальность: они могут работать программистами, дизайнерами, специалистами сетевых технологий, заниматься моделированием систем и процессов, компьютерной рекламой, работать в сфере Интернет-аналитики или информационной безопасности.',
            ),
            _buildProfileDetail(
              context,
              'Бизнес-аналитика финансовых систем',
              'Бизнес-аналитик – это высококвалифицированный специалист, который занимается анализом финансового или хозяйственного направления деятельности организации. На кафедре осуществляется подготовка аналитиков, владеющих современными методами интеллектуальной обработки данных для принятия управленческих решений.',
            ),
          ],
        ),

        // Системный анализ
        _buildProgramDetailCard(
          context,
          key: _sauKey,
          title: '27.03.03 Системный анализ и управление',
          childBlocks: [
            _buildProfileDetail(
              context,
              'Системный анализ и управление',
              'Выпускники ориентированы на работу системными аналитиками, выполняют анализ деятельности предприятия и осуществляют совершенствование бизнес-процессов; работают менеджерами проектов; руководят IT-службами предприятий; возглавляют аналитические отделы банков и страховых компаний.',
            ),
          ],
        ),

        // Прикладная информатика
        _buildProgramDetailCard(
          context,
          key: _infKey,
          title: '09.03.03 Прикладная информатика',
          childBlocks: [
            _buildProfileDetail(
              context,
              'Информатика в интеллектуальных системах',
              'Профиль предусматривает подготовку в области программирования, математического и компьютерного моделирования, проектирования, разработки и использования новейших компьютерных технологий и информационных систем в различных отраслях.',
            ),
            _buildProfileDetail(
              context,
              'Информационные системы в промышленной инженерии',
              'Совместная подготовка с факультетом металлургии и теплоэнергетики. Специалисты приобрёт знания в области программирования широкого спектра информационных технологий для промышленного сегмента.',
            ),
            _buildProfileDetail(
              context,
              'Интеллектуальные технологии проектирования',
              'Совместная подготовка с кафедрой "Горные машины". Выпускники будут не просто программистами, но ещё и специалистами в области проектирования и конструирования мехатронных горных машин.',
            ),
          ],
        ),

        // Программная инженерия
        _buildProgramDetailCard(
          context,
          key: _piKey,
          title: '09.03.04 Программная инженерия',
          childBlocks: [
            _buildProfileDetail(
              context,
              'Искусственный интеллект',
              'Обучение предполагает освоение теоретических знаний и практических навыков, необходимых для работы программистом в области проектирования и разработки прикладного программного обеспечения и систем искусственного интеллекта. Выпускники могут создавать, сопровождать и тестировать ПО, разрабатывать интернет-приложения, использовать облачные вычисления, решать задачи защиты информации.',
            ),
          ],
        ),
      ],
    );
  }

  // Карточка подробностей (без внутренней анимации; подсветка идёт через Overlay)
  Widget _buildProgramDetailCard(
      BuildContext context, {
        required GlobalKey key,
        required String title,
        required List<Widget> childBlocks,
      }) {
    final scheme = Theme.of(context).colorScheme;

    return Card(
      key: key, // важный момент: key на самой карточке
      margin: const EdgeInsets.only(bottom: 16),
      elevation: 2,
      color: Theme.of(context).cardColor,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              title,
              style: TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.bold,
                color: scheme.primary,
              ),
            ),
            const SizedBox(height: 12),
            ...childBlocks,
          ],
        ),
      ),
    );
  }

  Widget _buildProfileDetail(BuildContext context, String title, String description) {
    final scheme = Theme.of(context).colorScheme;

    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: scheme.surfaceVariant,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: Theme.of(context).dividerColor),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            title,
            style: TextStyle(
              fontWeight: FontWeight.w600,
              color: scheme.onBackground,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            description,
            style: TextStyle(
              color: scheme.onBackground,
              fontSize: 14,
            ),
          ),
        ],
      ),
    );
  }
}
