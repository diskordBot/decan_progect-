import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:decanat_progect/constants.dart';
import 'package:decanat_progect/widgets/custom_app_bar.dart';
import 'package:flutter/services.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';

class SettingsScreen extends StatefulWidget {
  const SettingsScreen({super.key});

  @override
  State<SettingsScreen> createState() => _SettingsScreenState();
}

class _SettingsScreenState extends State<SettingsScreen> {
  bool _notificationsEnabled = true;
  bool _vibrationEnabled = true;
  bool _soundEnabled = true;
  String _selectedLanguage = 'Русский';
  String _fontSize = 'Средний';
  String _userRole = 'user';
  String? _userId;
  bool _isLoading = true;

  final List<String> _languageOptions = ['Русский', 'English'];
  final List<String> _fontSizeOptions = ['Мелкий', 'Средний'];
  TextEditingController _userIdController = TextEditingController();
  bool _isEditingUserId = false;

  @override
  void initState() {
    super.initState();
    _loadSettings();
  }

  @override
  void dispose() {
    _userIdController.dispose();
    super.dispose();
  }

  // Загрузка данных - теперь ID создается на сервере
  Future<void> _loadSettings() async {
    final prefs = await SharedPreferences.getInstance();

    // Пытаемся получить сохраненный ID
    _userId = prefs.getString('userId');

    // Если ID нет, создаем нового пользователя на сервере
    if (_userId == null) {
      await _createNewUser();
    } else {
      // Загружаем настройки и роль существующего пользователя
      await _loadUserRole();
      await _loadSettingsFromServer();
    }

    // Загружаем локальные настройки
    setState(() {
      _notificationsEnabled = prefs.getBool('notifications') ?? true;
      _vibrationEnabled = prefs.getBool('vibration') ?? true;
      _soundEnabled = prefs.getBool('sound') ?? true;
      _selectedLanguage = prefs.getString('language') ?? 'Русский';
      _fontSize = prefs.getString('fontSize') ?? 'Средний';
      _isLoading = false;
    });
  }

  // Создание нового пользователя на сервере
  Future<void> _createNewUser() async {
    try {
      final response = await http.post(
          Uri.parse('${AppConfig.serverUrl}/api/users'),
          headers: {'Content-Type': 'application/json'},
          body: json.encode({'device_info': 'Flutter App'})
      );

      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        final prefs = await SharedPreferences.getInstance();

        setState(() {
          _userId = data['user_id'];
        });

        await prefs.setString('userId', _userId!);

        // Загружаем роль и настройки
        await _loadUserRole();
        await _loadSettingsFromServer();

        _showSnackBar('Создан новый пользователь: $_userId');
      } else {
        _createFallbackUser();
      }
    } catch (e) {
      _createFallbackUser();
    }
  }

  // Fallback: создание пользователя локально если сервер недоступен
  void _createFallbackUser() async {
    final prefs = await SharedPreferences.getInstance();
    final fallbackId = _generateUniqueId();

    setState(() {
      _userId = fallbackId;
      _userRole = 'user';
    });

    await prefs.setString('userId', fallbackId);
    await prefs.setString('userRole', 'user');

    _showSnackBar('Сервер недоступен. Создан локальный пользователь: $fallbackId');
  }

  Future<void> _loadUserRole() async {
    if (_userId == null) return;

    try {
      final response = await http.get(
          Uri.parse('${AppConfig.serverUrl}/api/users/$_userId/role')
      );

      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        setState(() {
          _userRole = data['role'] ?? 'user';
        });

        final prefs = await SharedPreferences.getInstance();
        await prefs.setString('userRole', _userRole);
      }
    } catch (e) {
      // Используем локальную роль как fallback
      final prefs = await SharedPreferences.getInstance();
      _userRole = prefs.getString('userRole') ?? 'user';
      setState(() {});
    }
  }

  Future<void> _loadSettingsFromServer() async {
    if (_userId == null) return;

    try {
      final response = await http.get(
          Uri.parse('${AppConfig.serverUrl}/api/users/$_userId/settings')
      );

      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        final prefs = await SharedPreferences.getInstance();

        setState(() {
          _notificationsEnabled = data['notifications_enabled'] ?? true;
          _vibrationEnabled = data['vibration_enabled'] ?? true;
          _soundEnabled = data['sound_enabled'] ?? true;
          _selectedLanguage = data['language'] ?? 'Русский';
          _fontSize = data['font_size'] ?? 'Средний';
        });

        await prefs.setBool('notifications', _notificationsEnabled);
        await prefs.setBool('vibration', _vibrationEnabled);
        await prefs.setBool('sound', _soundEnabled);
        await prefs.setString('language', _selectedLanguage);
        await prefs.setString('fontSize', _fontSize);
      }
    } catch (e) {
      print('Ошибка загрузки настроек с сервера: $e');
    }
  }

  String _generateUniqueId() {
    return DateTime.now().millisecondsSinceEpoch.toString().substring(7);
  }

  Future<void> _saveSetting(String key, dynamic value) async {
    final prefs = await SharedPreferences.getInstance();

    if (value is bool) {
      await prefs.setBool(key, value);
    } else if (value is String) {
      await prefs.setString(key, value);
    }

    // Отправляем на сервер
    try {
      final updateData = {};
      switch (key) {
        case 'notifications': updateData['notifications_enabled'] = value; break;
        case 'vibration': updateData['vibration_enabled'] = value; break;
        case 'sound': updateData['sound_enabled'] = value; break;
        case 'language': updateData['language'] = value; break;
        case 'fontSize': updateData['font_size'] = value; break;
      }

      await http.put(
          Uri.parse('${AppConfig.serverUrl}/api/users/$_userId/settings'),
          headers: {'Content-Type': 'application/json'},
          body: json.encode(updateData)
      );
    } catch (e) {
      print('Ошибка синхронизации с сервером: $e');
    }
  }

  void _showSnackBar(String message) {
    ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(message), duration: const Duration(seconds: 2))
    );
  }

  // Методы для редактирования ID
  void _startEditingUserId() {
    setState(() {
      _isEditingUserId = true;
      _userIdController.text = _userId ?? '';
    });
  }

  void _cancelEditingUserId() {
    setState(() {
      _isEditingUserId = false;
      _userIdController.clear();
    });
  }

  Future<void> _saveUserId(String newUserId) async {
    if (newUserId.isEmpty) return;

    final prefs = await SharedPreferences.getInstance();
    await prefs.setString('userId', newUserId);

    setState(() {
      _userId = newUserId;
      _isEditingUserId = false;
    });

    await _loadUserRole();
    await _loadSettingsFromServer();

    _showSnackBar('ID пользователя изменен');
  }

  void _copyUserIdToClipboard() async {
    if (_userId != null) {
      await Clipboard.setData(ClipboardData(text: _userId!));
      _showSnackBar('ID скопирован в буфер обмена');
    }
  }

  IconData _getRoleIcon() {
    switch (_userRole) {
      case 'admin': return Icons.admin_panel_settings;
      case 'developer': return Icons.developer_mode;
      default: return Icons.person;
    }
  }

  Color _getRoleColor() {
    switch (_userRole) {
      case 'admin': return Colors.blue;
      case 'developer': return Colors.purple;
      default: return Colors.green;
    }
  }

  String _getRoleName() {
    switch (_userRole) {
      case 'admin': return 'Администратор';
      case 'developer': return 'Разработчик';
      default: return 'Пользователь';
    }
  }

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
          _buildUserHeader(),
          const SizedBox(height: 16),


          _buildSectionHeader('ВНЕШНИЙ ВИД'),
          const SizedBox(height: 8),
          _buildListTile(
              'Размер текста', _fontSize, Icons.text_fields,
                  () => _showOptionsDialog('Размер текста', _fontSizeOptions, _fontSize, 'fontSize', () {})
          ),
          const SizedBox(height: 16),
          _buildSectionHeader('УВЕДОМЛЕНИЯ'),
          const SizedBox(height: 8),
          _buildSwitchTile('Уведомления', _notificationsEnabled, (value) => _updateSetting('notifications', value), Icons.notifications),
          _buildSwitchTile('Вибрация', _vibrationEnabled, (value) => _updateSetting('vibration', value), Icons.vibration),
          _buildSwitchTile('Звук', _soundEnabled, (value) => _updateSetting('sound', value), Icons.volume_up),
          const SizedBox(height: 16),
          _buildSectionHeader('ЯЗЫК'),
          const SizedBox(height: 8),
          _buildListTile(
              'Язык приложения', _selectedLanguage, Icons.language,
                  () => _showOptionsDialog('Выберите язык', _languageOptions, _selectedLanguage, 'language', () {})
          ),
          const SizedBox(height: 16),
          _buildSectionHeader('О ПРИЛОЖЕНИИ'),
          const SizedBox(height: 8),
          _buildInfoTile('Версия приложения', '1.2.0', Icons.info),
          _buildInfoTile(
              'Разработчик',
              'ФИСП, Группа ИНФ-24, Галушка Владислав Романович\nФИСП, Группа ИНФ-24, Бушлаков Олег Михайлович',
              Icons.code
          ),

          const SizedBox(height: 24),
          _buildActionButton('Сброс настроек', Icons.restart_alt, _resetSettings),
        ],
      ),
    );
  }

  Widget _buildUserHeader() {
    return Card(
      elevation: 2,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          children: [
            Row(
              children: [
                Container(
                  width: 48, height: 48,
                  decoration: BoxDecoration(
                    color: _getRoleColor().withOpacity(0.1),
                    shape: BoxShape.circle,
                  ),
                  child: Icon(_getRoleIcon(), size: 28, color: _getRoleColor()),
                ),
                const SizedBox(width: 16),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(_getRoleName(), style: TextStyle(
                          fontSize: 14, fontWeight: FontWeight.bold, color: _getRoleColor()
                      )),
                      const SizedBox(height: 4),
                      if (!_isEditingUserId) Text('ID: ${_userId ?? 'Загрузка...'}', style: const TextStyle(
                          fontSize: 16, fontWeight: FontWeight.w600
                      )),
                    ],
                  ),
                ),
                if (!_isEditingUserId) ...[
                  IconButton(
                    icon: Icon(Icons.content_copy, color: Theme.of(context).colorScheme.primary),
                    onPressed: _copyUserIdToClipboard,
                    tooltip: 'Копировать ID',
                  ),
                  IconButton(
                    icon: Icon(Icons.save_rounded, color: Theme.of(context).colorScheme.primary),
                    onPressed: _startEditingUserId,
                    tooltip: 'Изменить ID',
                  ),
                ]
              ],
            ),
            if (_isEditingUserId) ...[
              const SizedBox(height: 16),
              TextField(
                controller: _userIdController,
                decoration: InputDecoration(
                  labelText: 'Введите ID пользователя',
                  border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                  suffixIcon: IconButton(
                    icon: const Icon(Icons.check),
                    onPressed: () => _saveUserId(_userIdController.text),
                  ),
                ),
                keyboardType: TextInputType.number,
                maxLength: 6,
              ),
              const SizedBox(height: 8),
              Row(
                mainAxisAlignment: MainAxisAlignment.end,
                children: [
                  TextButton(onPressed: _cancelEditingUserId, child: const Text('Отмена')),
                  ElevatedButton(
                    onPressed: () => _saveUserId(_userIdController.text),
                    child: const Text('Сохранить'),
                  ),
                ],
              ),
            ],
          ],
        ),
      ),
    );
  }



  Widget _buildSectionHeader(String title) {
    return Text(title, style: TextStyle(
        fontSize: 16, fontWeight: FontWeight.bold,
        color: Theme.of(context).colorScheme.primary, letterSpacing: 1.2
    ));
  }

  Widget _buildSwitchTile(String title, bool value, Function(bool) onChanged, IconData icon) {
    return Card(
      elevation: 1, margin: const EdgeInsets.only(bottom: 8),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
      child: ListTile(
        leading: Icon(icon, size: 22, color: Theme.of(context).colorScheme.primary),
        title: Text(title, style: const TextStyle(fontWeight: FontWeight.w500, fontSize: 16)),
        trailing: Switch(value: value, onChanged: onChanged, activeColor: AppColors.primary),
        contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
      ),
    );
  }

  Widget _buildListTile(String title, String value, IconData icon, VoidCallback onTap) {
    return Card(
      elevation: 1, margin: const EdgeInsets.only(bottom: 8),
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
      elevation: 1, margin: const EdgeInsets.only(bottom: 8),
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
          backgroundColor: AppColors.primary, foregroundColor: Colors.white,
          padding: const EdgeInsets.symmetric(vertical: 16),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)), elevation: 1
      ),
    );
  }

  void _updateSetting(String key, bool value) {
    setState(() {
      switch (key) {
        case 'notifications': _notificationsEnabled = value; break;
        case 'vibration': _vibrationEnabled = value; break;
        case 'sound': _soundEnabled = value; break;
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
                  trailing: currentValue == option ? Icon(Icons.check, color: Theme.of(context).colorScheme.primary) : null,
                  onTap: () {
                    setState(() {
                      switch (settingKey) {
                        case 'language': _selectedLanguage = option; break;
                        case 'fontSize': _fontSize = option; break;
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
            TextButton(onPressed: () => Navigator.pop(context), child: const Text('Отмена')),
            TextButton(
              onPressed: () async {
                setState(() {
                  _notificationsEnabled = true;
                  _vibrationEnabled = true;
                  _soundEnabled = true;
                  _selectedLanguage = 'Русский';
                  _fontSize = 'Средний';
                });

                final prefs = await SharedPreferences.getInstance();
                await prefs.remove('notifications');
                await prefs.remove('vibration');
                await prefs.remove('sound');
                await prefs.remove('language');
                await prefs.remove('fontSize');

                try {
                  await http.put(
                      Uri.parse('${AppConfig.serverUrl}/api/users/$_userId/settings'),
                      headers: {'Content-Type': 'application/json'},
                      body: json.encode({
                        'notifications_enabled': true,
                        'vibration_enabled': true,
                        'sound_enabled': true,
                        'language': 'Русский',
                        'font_size': 'Средний'
                      })
                  );
                } catch (e) {
                  print('Ошибка синхронизации сброса настроек: $e');
                }

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
}