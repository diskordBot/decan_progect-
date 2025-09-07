import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:flutter/services.dart';
import 'package:decanat_progect/constants.dart';

class DepartmentDetailScreen extends StatelessWidget {
  const DepartmentDetailScreen({super.key});

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
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text('Скопировано: $text'),
        duration: const Duration(seconds: 2),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        title: const Text(
          'Кафедра ПМИИ',
          style: TextStyle(
            color: Colors.white,
            fontWeight: FontWeight.bold,
          ),
        ),
        backgroundColor: AppColors.primary,
        centerTitle: true,
        elevation: 0,
        iconTheme: const IconThemeData(color: Colors.white),
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Заголовок с иконкой
            _buildHeader(),
            const SizedBox(height: 24),

            // Контактная информация
            _buildContactInfo(context),
            const SizedBox(height: 24),

            // Направления подготовки
            _buildProgramsSection(),
            const SizedBox(height: 24),

            // Детальная информация о направлениях
            _buildProgramDetails(),
          ],
        ),
      ),
    );
  }

  Widget _buildHeader() {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
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
                  'Кафедра прикладной математики\nи искусственного интеллекта',
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
    return Card(
      elevation: 3,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Row(
              children: [
                Icon(Icons.contact_mail, color: AppColors.primary),
                SizedBox(width: 8),
                Text(
                  'Контактная информация',
                  style: TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                    color: AppColors.textDark,
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
              copyText: '+7 (856) 301-09-51, +7 (856) 301-03-91, +7 (856) 337-72-36, +7 (949) 0010304, +7(949) 0270303, +7(949) 0090303',
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
                  style: const TextStyle(
                    fontWeight: FontWeight.w600,
                    color: AppColors.textDark,
                  ),
                ),
                const SizedBox(height: 4),
                GestureDetector(
                  onTap: onTap,
                  child: Text(
                    value,
                    style: TextStyle(
                      color: onTap != null ? Colors.blue[700] : AppColors.textDark,
                      fontSize: 14,
                      decoration: onTap != null ? TextDecoration.underline : TextDecoration.none,
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
              color: AppColors.primary,
              padding: EdgeInsets.zero,
              constraints: const BoxConstraints(),
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildProgramsSection() {
    return Card(
      elevation: 3,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Row(
              children: [
                Icon(Icons.menu_book, color: AppColors.primary),
                SizedBox(width: 8),
                Text(
                  'Направления подготовки',
                  style: TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                    color: AppColors.textDark,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 16),
            _buildProgramItem('01.03.04', 'Прикладная математика (ПМК)', 'Бакалавриат'),
            _buildProgramItem('01.04.04', 'Прикладная математика (ПМК)', 'Магистратура'),
            _buildProgramItem('27.03.03', 'Системный анализ и управление (САУ)', 'Бакалавриат'),
            _buildProgramItem('27.04.03', 'Системный анализ и управление (САУ)', 'Магистратура'),
            _buildProgramItem('09.03.03', 'Прикладная информатика (ИНФ)', 'Бакалавриат'),
            _buildProgramItem('09.04.03', 'Прикладная информатика (ИНФ)', 'Магистратура'),
            _buildProgramItem('09.03.04', 'Программная инженерия (ПИ)', 'Бакалавриат'),
            _buildProgramItem('09.04.04', 'Программная инженерия (ПИ)', 'Магистратура'),
          ],
        ),
      ),
    );
  }

  Widget _buildProgramItem(String code, String name, String degree) {
    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: AppColors.primary.withOpacity(0.05),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: AppColors.primary.withOpacity(0.1)),
      ),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
            decoration: BoxDecoration(
              color: AppColors.primary,
              borderRadius: BorderRadius.circular(6),
            ),
            child: Text(
              code,
              style: const TextStyle(
                color: Colors.white,
                fontSize: 12,
                fontWeight: FontWeight.bold,
              ),
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  name,
                  style: const TextStyle(
                    fontWeight: FontWeight.w600,
                    color: AppColors.textDark,
                  ),
                ),
                Text(
                  degree,
                  style: TextStyle(
                    color: AppColors.textLight,
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

  Widget _buildProgramDetails() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text(
          'Подробная информация о направлениях',
          style: TextStyle(
            fontSize: 18,
            fontWeight: FontWeight.bold,
            color: AppColors.textDark,
          ),
        ),
        const SizedBox(height: 16),

        // Прикладная математика
        _buildProgramDetailCard(
          '01.03.04 Прикладная математика',
          [
            _buildProfileDetail(
                'Прикладная математика и кибернетика',
                'Математик-программист – одна из самых популярных профессий. Специалист занимается программированием процессов, которые невозможно смоделировать без знания математики.\n\nОсновное достоинство выпускников – универсальность: они могут работать программистами, дизайнерами, специалистами сетевых технологий, заниматься моделированием систем и процессов, компьютерной рекламой, работать в сфере Интернет-аналитики или информационной безопасности.'
            ),
            _buildProfileDetail(
                'Бизнес-аналитика финансовых систем',
                'Бизнес-аналитик – это высококвалифицированный специалист, который занимается анализом финансового или хозяйственного направления деятельности организации. На кафедре осуществляется подготовка аналитиков, владеющих современными методами интеллектуальной обработки данных для принятия управленческих решений.'
            ),
          ],
        ),

        // Системный анализ
        _buildProgramDetailCard(
          '27.03.03 Системный анализ и управление',
          [
            _buildProfileDetail(
                'Системный анализ и управление',
                'Выпускники ориентированы на работу системными аналитиками, выполняют анализ деятельности предприятия и осуществляют совершенствование бизнес-процессов; работают менеджерами проектов; руководят IT-службами предприятий; возглавляют аналитические отделы банков и страховых компаний.'
            ),
          ],
        ),

        // Прикладная информатика
        _buildProgramDetailCard(
          '09.03.03 Прикладная информатика',
          [
            _buildProfileDetail(
                'Информатика в интеллектуальных системах',
                'Профиль предусматривает подготовку в области программирования, математического и компьютерного моделирования, проектирования, разработки и использования новейших компьютерных технологий и информационных систем в различных отраслях.'
            ),
            _buildProfileDetail(
                'Информационные системы в промышленной инженерии',
                'Совместная подготовка с факультетом металлургии и теплоэнергетики. Специалисты приобретут знания в области программирования широкого спектра информационных технологий для промышленного сегмента.'
            ),
            _buildProfileDetail(
                'Интеллектуальные технологии проектирования',
                'Совместная подготовка с кафедрой "Горные машины". Выпускники будут не просто программистами, но ещё и специалистами в области проектирования и конструирования мехатронных горных машин.'
            ),
          ],
        ),

        // Программная инженерия
        _buildProgramDetailCard(
          '09.03.04 Программная инженерия',
          [
            _buildProfileDetail(
                'Искусственный интеллект',
                'Обучение предполагает освоение теоретических знаний и практических навыков, необходимых для работы программистом в области проектирования и разработки прикладного программного обеспечения и систем искусственного интеллекта. Выпускники могут создавать, сопровождать и тестировать ПО, разрабатывать интернет-приложения, использовать облачные вычисления, решать задачи защиты информации.'
            ),
          ],
        ),
      ],
    );
  }

  Widget _buildProgramDetailCard(String title, List<Widget> profiles) {
    return Card(
      margin: const EdgeInsets.only(bottom: 16),
      elevation: 2,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              title,
              style: const TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.bold,
                color: AppColors.primary,
              ),
            ),
            const SizedBox(height: 12),
            ...profiles,
          ],
        ),
      ),
    );
  }

  Widget _buildProfileDetail(String title, String description) {
    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Colors.grey[50],
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: Colors.grey[200]!),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            title,
            style: const TextStyle(
              fontWeight: FontWeight.w600,
              color: AppColors.textDark,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            description,
            style: const TextStyle(
              color: AppColors.textDark,
              fontSize: 14,
            ),
          ),
        ],
      ),
    );
  }
}