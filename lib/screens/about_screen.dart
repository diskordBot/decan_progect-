// lib/screens/about_screen.dart
import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';

import 'package:decanat_progect/widgets/custom_app_bar.dart';
import 'package:decanat_progect/ui/overlay_toast.dart';
import 'package:decanat_progect/constants.dart';

class AboutScreen extends StatelessWidget {
  const AboutScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;

    return Scaffold(
      backgroundColor: scheme.background,
      appBar: const CustomAppBar(
        title: 'О факультете',
        showBackButton: false, // ← убрали стрелку «назад»
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.fromLTRB(16, 16, 16, 24),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _HeaderCard(
              title: 'Факультет интеллектуальных систем и программирования',
              subtitle:
              'Крупнейший центр региона по подготовке бакалавров и магистров в области компьютерных наук, ИИ и программирования.',
              icon: Icons.auto_awesome,
            ),

            const SizedBox(height: 16),

            _SectionTitle('О факультете'),
            _InfoCard.rich(
              children: const [
                TextSpan(
                  text:
                  'Факультет интеллектуальных систем и программирования является крупнейшим центром региона по подготовке бакалавров и магистров в области компьютерных наук, искусственного интеллекта и программирования.\n\n',
                ),
                TextSpan(
                  text:
                  'Наши выпускники работают на предприятиях, в организациях и фирмах Донецка и области, России, Германии, США, Канаде, Финляндии, Польше и других международных корпорациях.\n\n',
                ),
                TextSpan(
                  text:
                  'Подготовка выпускников полностью соответствует уровню требований и стандартов Российской Федерации, все направления подготовки прошли аккредитацию в РФ и после окончания обучения выпускники получают российские дипломы.\n\n',
                ),
                TextSpan(
                  text:
                  'Мы предлагаем Вам поступить на факультет интеллектуальных систем и программирования и получить качественное образование по самым передовым и востребованным на современном рынке труда специальностям в области IT-технологий.\n\n',
                ),
                TextSpan(
                  text:
                  'Получение самых востребованных сегодня и в будущем компьютерных профессий предоставляет широкие возможности для эффективной карьеры, интересной и творческой работы.',
                ),
              ],
            ),

            const SizedBox(height: 16),

            _SectionTitle('Почему выбирают нас'),
            const _BulletCard(items: [
              'Сильные образовательные программы по ИИ, Data Science, программной и компьютерной инженерии.',
              'Российская аккредитация: выпускники получают дипломы РФ.',
              'Выпускники работают в ведущих IT-компаниях и международных корпорациях.',
              'Учебные и научные проекты, хакатоны, исследовательские лаборатории.',
            ]),

            const SizedBox(height: 16),

            _SectionTitle('Перспективы и карьера'),
            const _InfoCard(
              'Факультет предлагает качественное образование по наиболее перспективным и востребованным IT-специальностям, '
                  'открывая широкие возможности для профессионального роста, выбора траекторий (разработка, аналитика данных, '
                  'ML/AI, DevOps/Cloud, системная архитектура) и участия в прикладных и исследовательских проектах.',
            ),

            const SizedBox(height: 16),

            _SectionTitle('История'),
            _InfoCard.rich(
              children: const [
                TextSpan(
                  text:
                  'Наши истоки уходят в 1959 год, когда в Донецком индустриальном институте был создан электротехнический факультет. '
                      'С 1960–1964 гг. формируются ключевые кафедры автоматики и телемеханики, затем вычислительной техники; '
                      'в 1970 г. состоялся первый выпуск инженеров-вычислителей. В 1970–1990-е годы активно развиваются направления '
                      '«Прикладная математика», «Системное программирование», создаются новые кафедры и реализуются крупные НИР.\n\n',
                ),
                TextSpan(
                  text:
                  'В 2000–2010-е годы факультет трансформируется в факультет компьютерных наук и технологий, '
                      'расширяет исследовательскую повестку (системный анализ, интеллектуальные системы, программная инженерия), '
                      'укрепляет международные связи и научные школы.\n\n',
                ),
                TextSpan(
                  text:
                  'С 2021 года в составе Института компьютерных наук и технологий развиваются два факультета: '
                      'факультет интеллектуальных систем и программирования (ИСП) и факультет информационных систем и технологий (ИСТ).',
                ),
              ],
              trailing: Align(
                alignment: Alignment.centerRight,
                child: TextButton.icon(
                  onPressed: () => _openSite('https://donntu.ru/fisp'),
                  icon: const Icon(Icons.open_in_new),
                  label: const Text('Подробнее на сайте'),
                ),
              ),
            ),

            const SizedBox(height: 16),

            _SectionTitle('Контакты'),
            _ContactCard(
              icon: Icons.location_on,
              iconColor: Colors.red,
              label: 'Адрес',
              value: 'Донецк, ул. Артёма, 58, 4-й корпус',
              onTap: () => _openAddress(
                context,
                'Донецк, ул. Артёма, 58, 4-й корпус',
              ),
            ),
            _ContactCard(
              icon: Icons.phone,
              iconColor: Colors.green,
              label: 'Телефон',
              value: '+7 (856) 301-08-04',
              onTap: () => _openPhone(context, '+78563010804'),
            ),
            _ContactCard(
              icon: Icons.email,
              iconColor: Colors.blue,
              label: 'E-mail',
              value: 'fisp@donntu.ru',
              onTap: () => _openEmail(context, 'fisp@donntu.ru'),
            ),
            _ContactCard(
              icon: Icons.public,
              iconColor: Colors.purple,
              label: 'Сайт',
              value: 'fisp.iknt.donntu.ru',
              onTap: () => _openSiteWithToast(context, 'https://donntu.ru/fisp'),
            ),

            const SizedBox(height: 8),
          ],
        ),
      ),
    );
  }

  // ===== Launch helpers + кастомные уведомления =====

  static Future<void> _openAddress(BuildContext context, String address) async {
    // Яндекс.Карты по тексту
    final url = 'https://yandex.ru/maps/?text=${Uri.encodeComponent(address)}';
    OverlayToast.instance.info('Открываю Яндекс.Карты…', position: ToastPosition.bottom);
    final ok = await _launchUrl(url);
    if (!ok) {
      OverlayToast.instance.error('Не удалось открыть Яндекс.Карты');
    }
  }

  static Future<void> _openPhone(BuildContext context, String digits) async {
    final url = 'tel:$digits';
    OverlayToast.instance.info('Открываю звонилку…', position: ToastPosition.bottom);
    final ok = await _launchUrl(url);
    if (!ok) {
      OverlayToast.instance.error('Не удалось открыть звонилку');
    }
  }

  static Future<void> _openEmail(BuildContext context, String email) async {
    final url = 'mailto:$email';
    OverlayToast.instance.info('Открываю почтовое приложение…', position: ToastPosition.bottom);
    final ok = await _launchUrl(url);
    if (!ok) {
      OverlayToast.instance.error('Не удалось открыть почту');
    }
  }

  static Future<void> _openSiteWithToast(BuildContext context, String url) async {
    OverlayToast.instance.info('Открываю сайт…', position: ToastPosition.bottom);
    final ok = await _launchUrl(url);
    if (!ok) {
      OverlayToast.instance.error('Не удалось открыть сайт');
    }
  }

  static Future<void> _openSite(String url) async {
    await _launchUrl(url);
  }

  static Future<bool> _launchUrl(String url) async {
    final uri = Uri.parse(url);
    return await launchUrl(uri, mode: LaunchMode.externalApplication);
  }
}

// ===== UI Components =====

class _SectionTitle extends StatelessWidget {
  final String text;
  const _SectionTitle(this.text);

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Text(
        text,
        style: TextStyle(
          fontSize: 20,
          fontWeight: FontWeight.w800,
          letterSpacing: .2,
          color: scheme.onBackground,
        ),
      ),
    );
  }
}

class _HeaderCard extends StatelessWidget {
  final String title;
  final String subtitle;
  final IconData icon;
  const _HeaderCard({
    required this.title,
    required this.subtitle,
    required this.icon,
  });

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Container(
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [scheme.primary.withOpacity(.14), scheme.primary.withOpacity(.04)],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: scheme.primary.withOpacity(.18)),
      ),
      padding: const EdgeInsets.all(16),
      child: Row(
        children: [
          Container(
            width: 44,
            height: 44,
            decoration: BoxDecoration(
              color: scheme.primary.withOpacity(.15),
              shape: BoxShape.circle,
            ),
            child: Icon(icon, color: scheme.primary, size: 24),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(title,
                    style: TextStyle(
                      color: scheme.onBackground,
                      fontSize: 18,
                      fontWeight: FontWeight.w800,
                    )),
                const SizedBox(height: 6),
                Text(
                  subtitle,
                  style: TextStyle(
                    color: scheme.onBackground.withOpacity(.8),
                    height: 1.3,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _InfoCard extends StatelessWidget {
  final String? text;
  final List<TextSpan>? children;
  final Widget? trailing;

  const _InfoCard(this.text, {super.key})
      : children = null,
        trailing = null;

  const _InfoCard.rich({required this.children, this.trailing, super.key})
      : text = null;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Card(
      elevation: 2,
      color: Theme.of(context).cardColor,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
      child: Padding(
        padding: const EdgeInsets.fromLTRB(16, 14, 16, 12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            if (text != null)
              Text(
                text!,
                style: TextStyle(
                  fontSize: 16,
                  height: 1.45,
                  color: scheme.onBackground,
                ),
              ),
            if (children != null)
              RichText(
                text: TextSpan(
                  style: TextStyle(
                    fontSize: 16,
                    height: 1.45,
                    color: scheme.onBackground,
                  ),
                  children: children!,
                ),
              ),
            if (trailing != null) ...[
              const SizedBox(height: 8),
              trailing!,
            ],
          ],
        ),
      ),
    );
  }
}

class _BulletCard extends StatelessWidget {
  final List<String> items;
  const _BulletCard({required this.items});

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Card(
      elevation: 2,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
      child: Padding(
        padding: const EdgeInsets.fromLTRB(16, 14, 16, 14),
        child: Column(
          children: [
            for (final s in items)
              Padding(
                padding: const EdgeInsets.symmetric(vertical: 6),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text('•  ', style: TextStyle(fontSize: 18)),
                    Expanded(
                      child: Text(
                        s,
                        style: TextStyle(
                          fontSize: 16,
                          height: 1.4,
                          color: scheme.onBackground,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
          ],
        ),
      ),
    );
  }
}

class _ContactCard extends StatelessWidget {
  final IconData icon;
  final Color iconColor;
  final String label;
  final String value;
  final VoidCallback? onTap;

  const _ContactCard({
    required this.icon,
    required this.iconColor,
    required this.label,
    required this.value,
    this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Card(
      elevation: 2,
      margin: const EdgeInsets.symmetric(vertical: 6),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
      child: ListTile(
        onTap: onTap,
        leading: Container(
          width: 40,
          height: 40,
          decoration: BoxDecoration(
            color: iconColor.withOpacity(.12),
            shape: BoxShape.circle,
          ),
          child: Icon(icon, color: iconColor),
        ),
        title: Text(
          label,
          style: TextStyle(
            fontWeight: FontWeight.w700,
            color: scheme.onBackground,
          ),
        ),
        subtitle: Text(
          value,
          style: TextStyle(
            color: scheme.onBackground.withOpacity(.85),
          ),
        ),
        // стрелку у карточки оставляем, чтобы было видно, что это кликабельно
        trailing: onTap != null ? const Icon(Icons.chevron_right) : null,
      ),
    );
  }
}
