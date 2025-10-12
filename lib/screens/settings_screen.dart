import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:decanat_progect/constants.dart';
import 'package:decanat_progect/widgets/custom_app_bar.dart';
import 'package:decanat_progect/theme_controller.dart';
import 'package:decanat_progect/notifications/notification_service.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:package_info_plus/package_info_plus.dart';
import 'dart:async';
import 'dart:convert';
import 'package:http/http.dart' as http;

class SettingsScreen extends StatefulWidget {
  const SettingsScreen({super.key});
  @override
  State<SettingsScreen> createState() => _SettingsScreenState();
}

class _SettingsScreenState extends State<SettingsScreen> {
  bool _notificationsEnabled = true;
  bool _vibrationEnabled = true;
  bool _isLoading = true;

  String _themeOption = 'Системная';
  String? _userId;
  String _appVersion = ''; // 🔹 версия приложения

  @override
  void initState() {
    super.initState();
    _loadSettings();
    _loadAppVersion(); // загрузка версии
  }

  // ----------------- Data -----------------
  Future<void> _ensureUserId() async {
    final prefs = await SharedPreferences.getInstance();
    _userId = prefs.getString('userId');
    if (_userId == null) {
      _userId = DateTime.now().millisecondsSinceEpoch.toString().substring(7);
      await prefs.setString('userId', _userId!);
    }
  }

  Future<void> _loadSettings() async {
    final prefs = await SharedPreferences.getInstance();
    await _ensureUserId();

    setState(() {
      _notificationsEnabled = prefs.getBool('notifications') ?? true;
      _vibrationEnabled = prefs.getBool('vibration') ?? true;
      _themeOption = _themeModeToText(ThemeController.instance.themeMode);
      _isLoading = false;
    });

    await _syncFcmSubscription(_notificationsEnabled);
  }

  // 🔹 Получаем версию из build.gradle.kts
  Future<void> _loadAppVersion() async {
    final info = await PackageInfo.fromPlatform();
    setState(() {
      _appVersion = info.version; // только версия, без build number
    });
  }

  Future<void> _saveSetting(String key, dynamic value) async {
    final prefs = await SharedPreferences.getInstance();
    if (value is bool) await prefs.setBool(key, value);
  }

  // ----------------- Theme helpers -----------------
  String _themeModeToText(ThemeMode m) =>
      m == ThemeMode.light ? 'Светлая' : m == ThemeMode.dark ? 'Тёмная' : 'Системная';

  ThemeMode _textToThemeMode(String t) =>
      t == 'Светлая' ? ThemeMode.light : t == 'Тёмная' ? ThemeMode.dark : ThemeMode.system;

  int _themeToIndex(String t) => t == 'Светлая' ? 0 : t == 'Тёмная' ? 2 : 1;
  String _indexToTheme(int i) => i == 0 ? 'Светлая' : i == 2 ? 'Тёмная' : 'Системная';

  Future<void> _applyTheme(String option) async {
    await ThemeController.instance.setThemeMode(_textToThemeMode(option));
    setState(() => _themeOption = option);
  }

  // ----------------- FCM helpers -----------------
  Future<void> _syncFcmSubscription(bool enabled) async {
    try {
      if (enabled) {
        await FirebaseMessaging.instance.requestPermission(
          alert: true, badge: true, sound: true,
        );
        await FirebaseMessaging.instance.subscribeToTopic('news');
      } else {
        await FirebaseMessaging.instance.unsubscribeFromTopic('news');
      }
    } catch (_) {}
  }

  // ----------------- Contact helpers -----------------
  Future<void> _openEmail() async {
    final uri = Uri(scheme: 'mailto', path: 'vlad14g@vk.com');
    if (!await launchUrl(uri, mode: LaunchMode.externalApplication)) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Не удалось открыть почтовое приложение')),
      );
    }
  }

  Future<void> _openTelegram() async {
    final uri = Uri.parse('https://t.me/HomeScreenPY');
    if (!await launchUrl(uri, mode: LaunchMode.externalApplication)) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Не удалось открыть Telegram')),
      );
    }
  }

  // ----------------- UI -----------------
  @override
  Widget build(BuildContext context) {
    if (_isLoading) {
      return Scaffold(
        backgroundColor: Theme.of(context).colorScheme.background,
        appBar: const CustomAppBar(title: 'Настройки', showBackButton: false),
        body: const Center(child: CircularProgressIndicator()),
      );
    }

    return Scaffold(
      backgroundColor: Theme.of(context).colorScheme.background,
      appBar: const CustomAppBar(title: 'Настройки', showBackButton: false),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          _sectionHeader('ВНЕШНИЙ ВИД'),
          const SizedBox(height: 8),
          _ThemeSimpleToggle(
            index: _themeToIndex(_themeOption),
            onChanged: (i) async => _applyTheme(_indexToTheme(i)),
          ),

          const SizedBox(height: 16),
          _sectionHeader('УВЕДОМЛЕНИЯ'),
          const SizedBox(height: 8),
          _switchTile('Уведомления', _notificationsEnabled,
                  (v) => _updateSetting('notifications', v), Icons.notifications),
          _switchTile('Вибрация', _vibrationEnabled,
                  (v) => _updateSetting('vibration', v), Icons.vibration),

          const SizedBox(height: 16),
          _sectionHeader('О ПРИЛОЖЕНИИ'),
          const SizedBox(height: 8),

          // 🔹 Автоматически подтягиваемая версия
          _infoTile(
            'Версия приложения',
            _appVersion.isEmpty ? 'Загрузка...' : _appVersion,
            Icons.info,
          ),

          _infoTile(
            'Разработчики',
            "Группа ИНФ-24\n"
                '• Галушка Владислав Романович\n'
                '• Бушлаков Олег Михайлович\n'
                'Факультет интеллектуальных систем и программирования, ДонНТУ',
            Icons.code,
          ),

          const SizedBox(height: 20),
          _sectionHeader('СВЯЗЬ'),
          const SizedBox(height: 8),
          Card(
            elevation: 1,
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
            child: Padding(
              padding: const EdgeInsets.fromLTRB(16, 14, 16, 14),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Есть идея, вопрос или нашли баг?',
                    style: TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.w700,
                      color: Theme.of(context).colorScheme.onSurface,
                    ),
                  ),
                  const SizedBox(height: 10),
                  Text(
                    'Свяжитесь с разработчиком:',
                    style: TextStyle(
                      fontSize: 13.5,
                      color: Theme.of(context).colorScheme.onSurfaceVariant,
                    ),
                  ),
                  const SizedBox(height: 14),
                  Row(
                    children: [
                      Expanded(
                        child: OutlinedButton.icon(
                          onPressed: _openEmail,
                          icon: Icon(Icons.email_outlined,
                              size: 18,
                              color: AppColors.secondary.withOpacity(.85)),
                          label: Text(
                            'Написать на почту',
                            style: TextStyle(
                              fontSize: 14.5,
                              fontWeight: FontWeight.w700,
                              color: AppColors.secondary.withOpacity(.85),
                            ),
                          ),
                          style: OutlinedButton.styleFrom(
                            padding: const EdgeInsets.symmetric(vertical: 14),
                            side: BorderSide(
                              color: AppColors.secondary.withOpacity(.35),
                              width: 1.2,
                            ),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(10),
                            ),
                          ),
                        ),
                      ),
                      const SizedBox(width: 10),
                      Expanded(
                        child: OutlinedButton.icon(
                          onPressed: _openTelegram,
                          icon: Icon(Icons.send_rounded,
                              size: 18,
                              color: AppColors.secondary.withOpacity(.85)),
                          label: Text(
                            'Telegram',
                            style: TextStyle(
                              fontSize: 14.5,
                              fontWeight: FontWeight.w700,
                              color: AppColors.secondary.withOpacity(.85),
                            ),
                          ),
                          style: OutlinedButton.styleFrom(
                            padding: const EdgeInsets.symmetric(vertical: 14),
                            side: BorderSide(
                              color: AppColors.secondary.withOpacity(.35),
                              width: 1.2,
                            ),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(10),
                            ),
                          ),
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ),

          const SizedBox(height: 24),
          _actionBtn('Сброс настроек', Icons.restart_alt, _resetSettings),
        ],
      ),
    );
  }

  Widget _sectionHeader(String t) => Text(
    t,
    style: TextStyle(
      fontSize: 16,
      fontWeight: FontWeight.bold,
      color: Theme.of(context).colorScheme.primary,
      letterSpacing: 1.2,
    ),
  );

  Widget _switchTile(String title, bool value, Function(bool) onChanged, IconData icon) => Card(
    elevation: 1,
    margin: const EdgeInsets.only(bottom: 8),
    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
    child: ListTile(
      leading: Icon(icon, size: 22, color: Theme.of(context).colorScheme.primary),
      title: Text(title, style: const TextStyle(fontWeight: FontWeight.w500, fontSize: 16)),
      trailing: Switch(value: value, onChanged: onChanged, activeColor: AppColors.primary),
      contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
    ),
  );

  Widget _infoTile(String title, String value, IconData icon) => Card(
    elevation: 1,
    margin: const EdgeInsets.only(bottom: 8),
    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
    child: ListTile(
      leading: Icon(icon, size: 22, color: Theme.of(context).colorScheme.primary),
      title: Text(title, style: const TextStyle(fontWeight: FontWeight.w500, fontSize: 16)),
      subtitle: Text(value, style: TextStyle(fontSize: 13, color: Colors.grey[600])),
      contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
    ),
  );

  Widget _actionBtn(String text, IconData icon, VoidCallback onPressed) => ElevatedButton.icon(
    icon: Icon(icon, size: 20),
    label: Text(text, style: const TextStyle(fontSize: 15)),
    onPressed: onPressed,
    style: ElevatedButton.styleFrom(
      backgroundColor: AppColors.primary,
      foregroundColor: Colors.white,
      padding: const EdgeInsets.symmetric(vertical: 16),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
      elevation: 1,
    ),
  );

  Future<void> _updateSetting(String key, bool value) async {
    setState(() {
      if (key == 'notifications') _notificationsEnabled = value;
      if (key == 'vibration') _vibrationEnabled = value;
    });

    await _saveSetting(key, value);

    if (key == 'notifications') {
      await _syncFcmSubscription(value);
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(value ? 'Уведомления включены' : 'Уведомления выключены')),
      );
    }

    if (key == 'vibration') {
      try {
        await NotificationService.instance.setVibrationEnabled(value);
      } catch (_) {}
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(value ? 'Вибрация включена' : 'Вибрация выключена')),
      );
    }
  }

  void _resetSettings() {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Сброс настроек'),
        content: const Text('Вы уверены, что хотите сбросить все настройки к значениям по умолчанию?'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Отмена')),
          TextButton(
            onPressed: () async {
              setState(() {
                _notificationsEnabled = true;
                _vibrationEnabled = true;
                _themeOption = 'Системная';
              });
              final prefs = await SharedPreferences.getInstance();
              await prefs.remove('notifications');
              await prefs.remove('vibration');

              await ThemeController.instance.setThemeMode(ThemeMode.system);
              await _syncFcmSubscription(true);
              if (mounted) Navigator.pop(ctx);
              if (!mounted) return;
              ScaffoldMessenger.of(context)
                  .showSnackBar(const SnackBar(content: Text('Настройки сброшены')));
            },
            child: const Text('Сбросить', style: TextStyle(color: Colors.red)),
          ),
        ],
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      ),
    );
  }
}

// ----------------- Виджет выбора темы -----------------
class _ThemeSimpleToggle extends StatelessWidget {
  final int index;
  final ValueChanged<int> onChanged;
  const _ThemeSimpleToggle({required this.index, required this.onChanged});

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;

    return Card(
      elevation: 1,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: Padding(
        padding: const EdgeInsets.fromLTRB(14, 12, 14, 12),
        child: Column(
          children: [
            Text(
              'Выбрать тему',
              style: TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.w700,
                color: scheme.onSurface,
              ),
            ),
            const SizedBox(height: 12),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                InkWell(
                  borderRadius: BorderRadius.circular(6),
                  onTap: () => onChanged(0),
                  child: Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 6),
                    child: Text(
                      'Светлая',
                      style: TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.w600,
                        color: scheme.onSurfaceVariant,
                      ),
                    ),
                  ),
                ),
                _MiniTriSwitch(
                  index: index,
                  onChanged: onChanged,
                  width: 54,
                  height: 24,
                  knobInset: 3,
                  trackColor: scheme.primary.withOpacity(.35),
                  knobColor: scheme.primary,
                  borderColor: scheme.outline.withOpacity(.35),
                ),
                InkWell(
                  borderRadius: BorderRadius.circular(6),
                  onTap: () => onChanged(2),
                  child: Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 6),
                    child: Text(
                      'Тёмная',
                      style: TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.w600,
                        color: scheme.onSurfaceVariant,
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

class _MiniTriSwitch extends StatelessWidget {
  final int index;
  final ValueChanged<int> onChanged;
  final double width;
  final double height;
  final double knobInset;
  final Color trackColor;
  final Color knobColor;
  final Color borderColor;

  const _MiniTriSwitch({
    required this.index,
    required this.onChanged,
    this.width = 54,
    this.height = 24,
    this.knobInset = 3,
    required this.trackColor,
    required this.knobColor,
    required this.borderColor,
  });

  @override
  Widget build(BuildContext context) {
    final w = width;
    final h = height;
    final knob = h - knobInset * 2;
    final seg = w / 3;

    double left = (seg - knob) / 2;
    if (index == 1) left = seg + (seg - knob) / 2;
    if (index == 2) left = 2 * seg + (seg - knob) / 2;

    return SizedBox(
      width: w,
      height: h,
      child: Stack(
        children: [
          Container(
            width: w,
            height: h,
            decoration: BoxDecoration(
              color: trackColor,
              border: Border.all(color: borderColor),
              borderRadius: BorderRadius.circular(999),
            ),
          ),
          Positioned.fill(
            child: Row(
              children: List.generate(3, (i) {
                return Expanded(
                  child: InkWell(
                    borderRadius: BorderRadius.circular(999),
                    onTap: () => onChanged(i),
                    child: const SizedBox.expand(),
                  ),
                );
              }),
            ),
          ),
          AnimatedPositioned(
            duration: const Duration(milliseconds: 140),
            curve: Curves.easeOut,
            left: left,
            top: knobInset,
            width: knob,
            height: knob,
            child: Container(
              decoration: BoxDecoration(
                color: knobColor,
                shape: BoxShape.circle,
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withOpacity(.12),
                    blurRadius: 4,
                    offset: const Offset(0, 2),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}
