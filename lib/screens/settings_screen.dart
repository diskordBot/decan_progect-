import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:decanat_progect/constants.dart';
import 'package:decanat_progect/widgets/custom_app_bar.dart';
import 'package:flutter/services.dart';

class SettingsScreen extends StatefulWidget {
  final bool isDarkMode;
  final Function(bool) toggleTheme;

  const SettingsScreen({
    super.key,
    required this.isDarkMode,
    required this.toggleTheme,
  });

  @override
  State<SettingsScreen> createState() => _SettingsScreenState();
}

class _SettingsScreenState extends State<SettingsScreen> {
  // Настройки приложения
  bool _notificationsEnabled = true;
  bool _vibrationEnabled = true;
  bool _soundEnabled = true;
  String _selectedLanguage = 'Русский';
  String _selectedTheme = 'Системная';
  String _fontSize = 'Средний';

  // Списки опций
  final List<String> _themeOptions = ['Системная', 'Светлая', 'Тёмная'];
  final List<String> _languageOptions = ['Русский', 'English', 'Українська'];
  final List<String> _fontSizeOptions = ['Мелкий', 'Средний', 'Крупный'];

  @override
  void initState() {
    super.initState();
    _loadSettings();
  }

  Future<void> _loadSettings() async {
    final prefs = await SharedPreferences.getInstance();
    setState(() {
      _notificationsEnabled = prefs.getBool('notifications') ?? true;
      _vibrationEnabled = prefs.getBool('vibration') ?? true;
      _soundEnabled = prefs.getBool('sound') ?? true;
      _selectedLanguage = prefs.getString('language') ?? 'Русский';
      _selectedTheme = prefs.getString('theme') ?? 'Системная';
      _fontSize = prefs.getString('fontSize') ?? 'Средний';
    });
  }

  Future<void> _saveSetting(String key, dynamic value) async {
    final prefs = await SharedPreferences.getInstance();
    if (value is bool) {
      await prefs.setBool(key, value);
    } else if (value is String) {
      await prefs.setString(key, value);
    }
  }

  void _showSnackBar(String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        duration: const Duration(seconds: 2),
      ),
    );
  }

  // Реальное применение настроек темы
  void _applyThemeSettings() {
    if (_selectedTheme == 'Тёмная') {
      widget.toggleTheme(true);
    } else if (_selectedTheme == 'Светлая') {
      widget.toggleTheme(false);
    } else {
      // Системная тема
      final brightness = MediaQuery.of(context).platformBrightness;
      widget.toggleTheme(brightness == Brightness.dark);
    }
    _showSnackBar('Тема применена');
  }

  void _applyFontSizeSettings() {
    // Здесь можно добавить логику для изменения размера текста
    _showSnackBar('Размер текста изменен');
  }

  void _toggleVibration() {
    if (_vibrationEnabled) {
      HapticFeedback.lightImpact();
    }
  }

  void _toggleSound() {
    if (_soundEnabled) {
      SystemSound.play(SystemSoundType.click);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Theme.of(context).colorScheme.background,
      appBar: const CustomAppBar(
        title: 'Настройки',
        showBackButton: false,
      ),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          // Внешний вид
          _buildSectionHeader('ВНЕШНИЙ ВИД'),
          const SizedBox(height: 8),
          _buildListTile(
            'Тема приложения',
            _selectedTheme,
            Icons.color_lens,
                () => _showOptionsDialog('Выберите тему', _themeOptions, _selectedTheme, 'theme', _applyThemeSettings),
          ),
          _buildListTile(
            'Размер текста',
            _fontSize,
            Icons.text_fields,
                () => _showOptionsDialog('Размер текста', _fontSizeOptions, _fontSize, 'fontSize', _applyFontSizeSettings),
          ),

          const SizedBox(height: 16),

          // Уведомления
          _buildSectionHeader('УВЕДОМЛЕНИЯ'),
          const SizedBox(height: 8),
          _buildSwitchTile(
            'Уведомления',
            _notificationsEnabled,
                (value) => _updateSetting('notifications', value),
            Icons.notifications,
          ),
          _buildSwitchTile(
            'Вибрация',
            _vibrationEnabled,
                (value) {
              _updateSetting('vibration', value);
              _toggleVibration();
            },
            Icons.vibration,
          ),
          _buildSwitchTile(
            'Звук',
            _soundEnabled,
                (value) {
              _updateSetting('sound', value);
              _toggleSound();
            },
            Icons.volume_up,
          ),

          const SizedBox(height: 16),

          // Язык
          _buildSectionHeader('ЯЗЫК'),
          const SizedBox(height: 8),
          _buildListTile(
            'Язык приложения',
            _selectedLanguage,
            Icons.language,
                () => _showOptionsDialog('Выберите язык', _languageOptions, _selectedLanguage, 'language', () {}),
          ),

          const SizedBox(height: 16),

          // О приложении
          _buildSectionHeader('О ПРИЛОЖЕНИИ'),
          const SizedBox(height: 8),
          _buildInfoTile(
            'Версия приложения',
            '1.2.0',
            Icons.info,
          ),
          _buildInfoTile(
            'Разработчик',
            'Галушка Владислав Романович, ФИСП, ИНФ-24',
            Icons.code,
          ),

          const SizedBox(height: 24),

          // Кнопки действий
          _buildActionButton(
            'Сброс настроек',
            Icons.restart_alt,
                () => _resetSettings(),
          ),
        ],
      ),
    );
  }

  Widget _buildSectionHeader(String title) {
    return Text(
      title,
      style: TextStyle(
        fontSize: 16,
        fontWeight: FontWeight.bold,
        color: Theme.of(context).colorScheme.primary,
        letterSpacing: 1.2,
      ),
    );
  }

  Widget _buildSwitchTile(String title, bool value, Function(bool) onChanged, IconData icon) {
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
        trailing: Switch(
          value: value,
          onChanged: onChanged,
          activeColor: AppColors.primary,
        ),
        contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
      ),
    );
  }

  Widget _buildListTile(String title, String value, IconData icon, VoidCallback onTap) {
    return Card(
      elevation: 1,
      margin: const EdgeInsets.only(bottom: 8),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
      child: ListTile(
        leading: Icon(icon, size: 22, color: Theme.of(context).colorScheme.primary),
        title: Text(title, style: const TextStyle(fontWeight: FontWeight.w500, fontSize: 16)),
        subtitle: Text(value, style: TextStyle(fontSize: 13, color: Colors.grey[600])),
        trailing: Icon(Icons.chevron_right, color: Colors.grey[400]),
        onTap: onTap,
        contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
      ),
    );
  }

  Widget _buildInfoTile(String title, String value, IconData icon) {
    return Card(
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
  }

  Widget _buildActionButton(String text, IconData icon, VoidCallback onPressed) {
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

  void _updateSetting(String key, bool value) {
    setState(() {
      switch (key) {
        case 'notifications':
          _notificationsEnabled = value;
          break;
        case 'vibration':
          _vibrationEnabled = value;
          break;
        case 'sound':
          _soundEnabled = value;
          break;
      }
    });
    _saveSetting(key, value);
    _showSnackBar('Настройка сохранена');
  }

  void _showOptionsDialog(String title, List<String> options, String currentValue, String settingKey, VoidCallback onApplied) {
    showDialog(
      context: context,
      builder: (BuildContext context) {
        return AlertDialog(
          title: Text(title, style: const TextStyle(fontWeight: FontWeight.bold)),
          content: SizedBox(
            width: double.maxFinite,
            child: ListView.builder(
              shrinkWrap: true,
              itemCount: options.length,
              itemBuilder: (context, index) {
                final option = options[index];
                return ListTile(
                  title: Text(option),
                  trailing: currentValue == option
                      ? Icon(Icons.check, color: Theme.of(context).colorScheme.primary)
                      : null,
                  onTap: () {
                    setState(() {
                      switch (settingKey) {
                        case 'theme':
                          _selectedTheme = option;
                          break;
                        case 'language':
                          _selectedLanguage = option;
                          break;
                        case 'fontSize':
                          _fontSize = option;
                          break;
                      }
                    });
                    _saveSetting(settingKey, option);
                    Navigator.pop(context);
                    onApplied();
                  },
                );
              },
            ),
          ),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        );
      },
    );
  }

  void _resetSettings() {
    showDialog(
      context: context,
      builder: (BuildContext context) {
        return AlertDialog(
          title: const Text('Сброс настроек'),
          content: const Text('Вы уверены, что хотите сбросить все настройки к значениям по умолчанию?'),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('Отмена'),
            ),
            TextButton(
              onPressed: () {
                // Сброс настроек
                setState(() {
                  _notificationsEnabled = true;
                  _vibrationEnabled = true;
                  _soundEnabled = true;
                  _selectedLanguage = 'Русский';
                  _selectedTheme = 'Системная';
                  _fontSize = 'Средний';
                });

                // Очистка SharedPreferences
                _clearPreferences();

                // Сброс темы
                widget.toggleTheme(false);

                Navigator.pop(context);
                _showSnackBar('Настройки сброшены');
              },
              child: const Text('Сбросить', style: TextStyle(color: Colors.red)),
            ),
          ],
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        );
      },
    );
  }

  Future<void> _clearPreferences() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove('notifications');
    await prefs.remove('vibration');
    await prefs.remove('sound');
    await prefs.remove('language');
    await prefs.remove('theme');
    await prefs.remove('fontSize');
  }
}