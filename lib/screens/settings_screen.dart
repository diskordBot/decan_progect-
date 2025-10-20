// lib/screens/settings_screen.dart
import 'dart:async';
import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:package_info_plus/package_info_plus.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:firebase_messaging/firebase_messaging.dart';

import 'package:decanat_progect/constants.dart';
import 'package:decanat_progect/widgets/custom_app_bar.dart';
import 'package:decanat_progect/theme_controller.dart';
import 'package:decanat_progect/notifications/notification_service.dart';
import 'package:decanat_progect/ui/overlay_toast.dart'; // ToastStyle + OverlayToast

class SettingsScreen extends StatefulWidget {
  const SettingsScreen({super.key});
  @override
  State<SettingsScreen> createState() => _SettingsScreenState();
}

class _SettingsScreenState extends State<SettingsScreen> {
  bool _isLoading = true;

  // уведомления
  bool _notificationsEnabled = true;
  bool _vibrationEnabled = true;

  // тема
  String _themeOption = 'Системная';

  // версия
  String _appVersion = '';

  // стиль тостов
  ToastStyle _toastStyle = ToastStyle.redFrame;

  @override
  void initState() {
    super.initState();
    _initSafe();
  }

  Future<void> _initSafe() async {
    try {
      await Future.wait([
        _loadSettings(),
        _loadAppVersion(),
      ]);
      // стиль тостов — читаем из OverlayToast (он поднимается в main)
      _toastStyle = OverlayToast.instance.style;
    } finally {
      if (mounted) setState(() => _isLoading = false);

      // Синхронизацию FCM запускаем уже после снятия спиннера и не ждём
      _syncFcmSubscription(_notificationsEnabled)
          .timeout(const Duration(seconds: 2))
          .catchError((_) {});
    }
  }

  Future<void> _loadSettings() async {
    final prefs = await SharedPreferences.getInstance();
    setState(() {
      _notificationsEnabled = prefs.getBool('notifications') ?? true;
      _vibrationEnabled = prefs.getBool('vibration') ?? true;
      _themeOption = _themeModeToText(ThemeController.instance.themeMode);
    });
  }

  Future<void> _loadAppVersion() async {
    final info = await PackageInfo.fromPlatform();
    if (!mounted) return;
    setState(() => _appVersion = info.version);
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
    if (!mounted) return;
    setState(() => _themeOption = option);

    OverlayToast.instance.show(
      'Тема: $option',
      icon: Icons.brightness_6_rounded,
      accent: AppColors.accent,
    );
  }

  // ----------------- FCM helpers -----------------
  Future<void> _syncFcmSubscription(bool enabled) async {
    try {
      if (enabled) {
        await FirebaseMessaging.instance
            .requestPermission(alert: true, badge: true, sound: true)
            .timeout(const Duration(seconds: 2));
        await FirebaseMessaging.instance
            .subscribeToTopic('news')
            .timeout(const Duration(seconds: 2));
      } else {
        await FirebaseMessaging.instance
            .unsubscribeFromTopic('news')
            .timeout(const Duration(seconds: 2));
      }
    } catch (_) {
      // тихо игнорируем
    }
  }

  Future<void> _savePref(String key, bool value) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(key, value);
  }

  Future<void> _updateSetting(String key, bool value) async {
    setState(() {
      if (key == 'notifications') _notificationsEnabled = value;
      if (key == 'vibration') _vibrationEnabled = value;
    });
    await _savePref(key, value);

    if (key == 'notifications') {
      _syncFcmSubscription(value).timeout(const Duration(seconds: 2)).catchError((_) {});
      OverlayToast.instance.show(
        value ? 'Уведомления включены' : 'Уведомления выключены',
        icon: value ? Icons.notifications_active_rounded : Icons.notifications_off_rounded,
        accent: AppColors.accent,
      );
    }

    if (key == 'vibration') {
      try {
        await NotificationService.instance.setVibrationEnabled(value);
      } catch (_) {}
      OverlayToast.instance.show(
        value ? 'Вибрация включена' : 'Вибрация выключена',
        icon: Icons.vibration_rounded,
        accent: AppColors.accent,
      );
    }
  }

  // ----------------- Contact helpers -----------------
  Future<void> _openEmail() async {
    final uri = Uri(scheme: 'mailto', path: 'vlad14g@vk.com');
    final ok = await launchUrl(uri, mode: LaunchMode.externalApplication);
    if (!ok && mounted) {
      OverlayToast.instance.show(
        'Не удалось открыть почтовое приложение',
        icon: Icons.warning_amber_rounded,
        accent: AppColors.accent,
      );
    }
  }

  Future<void> _openTelegram() async {
    final uri = Uri.parse('https://t.me/HomeScreenPY');
    final ok = await launchUrl(uri, mode: LaunchMode.externalApplication);
    if (!ok && mounted) {
      OverlayToast.instance.show(
        'Не удалось открыть Telegram',
        icon: Icons.warning_amber_rounded,
        accent: AppColors.accent,
      );
    }
  }

  // ----------------- Toast style -----------------
  Future<void> _setToastStyle(ToastStyle style) async {
    await OverlayToast.instance.setStyle(style);
    if (!mounted) return;
    setState(() => _toastStyle = style);

    final previewIcon = switch (style) {
      ToastStyle.redFrame => Icons.emergency_rounded,
      ToastStyle.glass => Icons.blur_on_rounded,
      ToastStyle.minimal => Icons.radio_button_checked_rounded,
    };
    final name = switch (style) {
      ToastStyle.redFrame => 'Рамка',
      ToastStyle.glass => 'Стекло',
      ToastStyle.minimal => 'Минимальный',
    };

    OverlayToast.instance.show(
      'Стиль уведомлений: $name',
      icon: previewIcon,
      accent: AppColors.accent, // рамка у redFrame всегда красная, как просил
    );
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

    final scheme = Theme.of(context).colorScheme;

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
            onChanged: (i) => _applyTheme(_indexToTheme(i)),
          ),

          const SizedBox(height: 16),
          _sectionHeader('УВЕДОМЛЕНИЯ'),
          const SizedBox(height: 8),
          _switchTile(
            context,
            title: 'Уведомления',
            value: _notificationsEnabled,
            icon: Icons.notifications,
            onChanged: (v) => _updateSetting('notifications', v),
          ),
          _switchTile(
            context,
            title: 'Вибрация',
            value: _vibrationEnabled,
            icon: Icons.vibration,
            onChanged: (v) => _updateSetting('vibration', v),
          ),

          const SizedBox(height: 16),
          _sectionHeader('СТИЛЬ ВСПЛЫВАЮЩИХ УВЕДОМЛЕНИЙ'),
          const SizedBox(height: 8),
          _toastStyleChips(context),

          const SizedBox(height: 16),
          _sectionHeader('О ПРИЛОЖЕНИИ'),
          const SizedBox(height: 8),
          _infoTile(
            context,
            title: 'Версия приложения',
            value: _appVersion.isEmpty ? 'Загрузка...' : _appVersion,
            icon: Icons.info,
          ),
          _infoTile(
            context,
            title: 'Разработчики',
            value: "Группа ИНФ-24\n"
                "• Галушка Владислав Романович\n"
                "• Бушлаков Олег Михайлович\n"
                "Факультет интеллектуальных систем и программирования, ДонНТУ",
            icon: Icons.code,
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
                      color: scheme.onSurface,
                    ),
                  ),
                  const SizedBox(height: 10),
                  Text(
                    'Свяжитесь с разработчиком:',
                    style: TextStyle(fontSize: 13.5, color: scheme.onSurfaceVariant),
                  ),
                  const SizedBox(height: 14),
                  Row(
                    children: [
                      Expanded(
                        child: OutlinedButton.icon(
                          onPressed: _openEmail,
                          icon: Icon(Icons.email_outlined, size: 18, color: AppColors.secondary.withOpacity(.85)),
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
                            side: BorderSide(color: AppColors.secondary.withOpacity(.35), width: 1.2),
                            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                          ),
                        ),
                      ),
                      const SizedBox(width: 10),
                      Expanded(
                        child: OutlinedButton.icon(
                          onPressed: _openTelegram,
                          icon: Icon(Icons.send_rounded, size: 18, color: AppColors.secondary.withOpacity(.85)),
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
                            side: BorderSide(color: AppColors.secondary.withOpacity(.35), width: 1.2),
                            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
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
          _actionBtn(
            context,
            text: 'Сброс настроек',
            icon: Icons.restart_alt,
            onPressed: _resetSettings,
          ),
        ],
      ),
    );
  }

  // ----------------- UI helpers -----------------
  Widget _sectionHeader(String t) => Text(
    t,
    style: TextStyle(
      fontSize: 16,
      fontWeight: FontWeight.bold,
      color: Theme.of(context).colorScheme.primary,
      letterSpacing: 1.2,
    ),
  );

  Widget _switchTile(
      BuildContext context, {
        required String title,
        required bool value,
        required IconData icon,
        required ValueChanged<bool> onChanged,
      }) {
    return Card(
      elevation: 1,
      margin: const EdgeInsets.only(bottom: 8),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
      child: ListTile(
        leading: Icon(icon, size: 22, color: Theme.of(context).colorScheme.primary),
        title: Text(
          title,
          style: const TextStyle(fontWeight: FontWeight.w500, fontSize: 16),
        ),
        trailing: Switch(value: value, onChanged: onChanged, activeColor: AppColors.primary),
        contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
      ),
    );
  }

  Widget _infoTile(
      BuildContext context, {
        required String title,
        required String value,
        required IconData icon,
      }) {
    return Card(
      elevation: 1,
      margin: const EdgeInsets.only(bottom: 8),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
      child: ListTile(
        leading: Icon(icon, size: 22, color: Theme.of(context).colorScheme.primary),
        title: Text(
          title,
          style: const TextStyle(fontWeight: FontWeight.w500, fontSize: 16),
        ),
        subtitle: Text(value, style: TextStyle(fontSize: 13, color: Colors.grey[600])),
        contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
      ),
    );
  }

  Widget _actionBtn(BuildContext context,
      {required String text, required IconData icon, required VoidCallback onPressed}) {
    return ElevatedButton.icon(
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
  }

  // ----------------- Минималистичный выбор стиля тостов -----------------
  Widget _toastStyleChips(BuildContext context) {
    final entries = <({ToastStyle style, String label, IconData icon})>[
      (style: ToastStyle.redFrame, label: 'Рамка', icon: Icons.flip_rounded),
      (style: ToastStyle.glass, label: 'Стекло', icon: Icons.blur_on_rounded),
      (style: ToastStyle.minimal, label: 'Минимал', icon: Icons.radio_button_checked_rounded),
    ];

    return Wrap(
      spacing: 8,
      runSpacing: 8,
      children: entries.map((e) {
        final selected = _toastStyle == e.style;
        return ChoiceChip(
          selected: selected,
          onSelected: (_) => _setToastStyle(e.style),
          label: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(e.icon, size: 16, color: selected ? Colors.white : Theme.of(context).colorScheme.primary),
              const SizedBox(width: 6),
              Text(e.label),
            ],
          ),
          shape: StadiumBorder(
            side: BorderSide(
              color: selected
                  ? Theme.of(context).colorScheme.primary
                  : Theme.of(context).dividerColor,
              width: 1.1,
            ),
          ),
          labelStyle: TextStyle(
            fontWeight: FontWeight.w600,
            color: selected ? Colors.white : Theme.of(context).colorScheme.onSurface,
          ),
          backgroundColor: Theme.of(context).colorScheme.surface,
          selectedColor: Theme.of(context).colorScheme.primary,
          materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
          visualDensity: const VisualDensity(horizontal: -2, vertical: -2),
        );
      }).toList(),
    );
  }

  // ----------------- Reset -----------------
  void _resetSettings() {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Сброс настроек'),
        content: const Text('Сбросить все настройки к значениям по умолчанию?'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Отмена')),
          TextButton(
            onPressed: () async {
              // тема
              await ThemeController.instance.setThemeMode(ThemeMode.system);
              // prefs
              final prefs = await SharedPreferences.getInstance();
              await prefs.remove('notifications');
              await prefs.remove('vibration');
              // локально
              setState(() {
                _notificationsEnabled = true;
                _vibrationEnabled = true;
                _themeOption = 'Системная';
                _toastStyle = ToastStyle.redFrame;
              });
              // стиль тостов → дефолт
              await OverlayToast.instance.setStyle(ToastStyle.redFrame);
              // уведомления
              _syncFcmSubscription(true).timeout(const Duration(seconds: 2)).catchError((_) {});

              if (mounted) Navigator.pop(ctx);
              OverlayToast.instance.show(
                'Настройки сброшены',
                icon: Icons.check_circle_rounded,
                accent: AppColors.accent,
              );
            },
            child: const Text('Сбросить', style: TextStyle(color: Colors.red)),
          ),
        ],
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      ),
    );
  }
}

// ----------------- Виджет выбора темы (как было, аккуратно) -----------------
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
