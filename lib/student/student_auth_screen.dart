import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:http/http.dart' as http;
import 'package:flutter_secure_storage/flutter_secure_storage.dart';

import 'package:decanat_progect/constants.dart';
// ⬇️ Поменяй путь на свой (ui/overlay_toast.dart / widgets/overlay_toast.dart и т.п.)
import 'package:decanat_progect/ui/overlay_toast.dart';

/// ===== Локальное безопасное хранение пароля (тот же ключ, что читает профиль)
class SecurePasswordStore {
  static const _storage = FlutterSecureStorage();
  static String _key(String userId) => 'pw_$userId';
  static Future<void> save(String userId, String password) =>
      _storage.write(key: _key(userId), value: password);
}

class StudentAuthScreen extends StatefulWidget {
  final bool isLogin;
  const StudentAuthScreen({super.key, this.isLogin = false});

  @override
  _StudentAuthScreenState createState() => _StudentAuthScreenState();
}

class _StudentAuthScreenState extends State<StudentAuthScreen> {
  final _formKey = GlobalKey<FormState>();
  final _serverUrl = AppConfig.serverUrl;

  // Поля формы
  String _fullName = '';
  String _login = '';
  String _password = '';
  String _selectedGroup = '';
  List<String> _groups = [];
  bool _groupsLoading = true;
  String _groupsError = '';
  bool _serverDown = false; // ⬅️ флаг для «сервер недоступен»

  bool _isLoading = false;
  bool _obscure = true;

  @override
  void initState() {
    super.initState();
    _loadGroups();
  }

  // ======= TOAST helpers (кастомные уведомления) =======
  void _toastInfo(String m)    => OverlayToast.instance.info(m);
  void _toastSuccess(String m) => OverlayToast.instance.success(m);
  void _toastWarn(String m)    => OverlayToast.instance.warning(m);
  void _toastError(String m)   => OverlayToast.instance.error(m);

  Future<void> _loadGroups() async {
    setState(() {
      _groupsLoading = true;
      _groupsError = '';
      _serverDown = false;
    });

    try {
      final response = await http.get(
        Uri.parse('$_serverUrl/api/groups'),
        headers: {'Accept': 'application/json'},
      ).timeout(const Duration(seconds: 8));

      if (response.statusCode == 200) {
        final List<dynamic> groupsData = json.decode(response.body);
        setState(() {
          _groups = groupsData.map((group) => group.toString()).toList();
          _groupsLoading = false;
          _groupsError = '';
        });
      } else {
        // сервер отвечает, но с ошибкой
        setState(() {
          _groupsLoading = false;
          _groupsError = 'Не удалось загрузить список групп';
        });
        _toastError('Ошибка сервера (${response.statusCode}). Группы не загружены.');
      }
    } on SocketException catch (_) {
      _onGroupsNetworkFail();
    } on HttpException catch (_) {
      _onGroupsNetworkFail();
    } on FormatException catch (_) {
      _onGroupsNetworkFail();
    } on TimeoutException catch (_) {
      _onGroupsNetworkFail();
    } catch (_) {
      _onGroupsNetworkFail();
    }
  }

  void _onGroupsNetworkFail() {
    setState(() {
      _groupsLoading = false;
      _groupsError = 'Сервер недоступен';
      _serverDown = true;
      // оставляем пустой список групп — чтобы не вводить пользователя в заблуждение
      _groups = [];
    });
    _toastWarn('Сервер недоступен. Проверьте интернет или попробуйте позже.');
  }

  Future<void> _registerStudent() async {
    if (!_formKey.currentState!.validate()) return;

    setState(() => _isLoading = true);

    try {
      final prefs = await SharedPreferences.getInstance();
      final userId = prefs.getString('userId');

      if (userId == null || userId.isEmpty) {
        _toastError('Ошибка: пользователь не найден');
        return;
      }

      final response = await http
          .post(
        Uri.parse('$_serverUrl/api/students/register'),
        headers: {'Content-Type': 'application/json','Accept': 'application/json'},
        body: json.encode({
          'user_id': userId,
          'full_name': _fullName,
          'login': _login,
          'password': _password,
          'group_name': _selectedGroup,
        }),
      )
          .timeout(const Duration(seconds: 12));

      if (response.statusCode == 200) {
        // 1) роль и прочее
        await prefs.setString('userRole', 'student');
        await prefs.setString('studentGroup', _selectedGroup);

        // 2) локально пароль (для профиля)
        await SecurePasswordStore.save(userId, _password);

        _toastSuccess('Регистрация успешна!');
        if (mounted) Navigator.pop(context, true);
      } else {
        String msg = 'Ошибка регистрации';
        try {
          final errorData = json.decode(response.body);
          msg = (errorData['detail'] ?? msg).toString();
        } catch (_) {}
        _toastError(msg);
      }
    } on SocketException catch (_) {
      _toastError('Сервер недоступен. Проверьте подключение.');
    } on TimeoutException catch (_) {
      _toastError('Сервер недоступен (таймаут). Попробуйте позже.');
    } catch (e) {
      _toastError('Ошибка: $e');
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  Future<void> _loginStudent() async {
    if (!_formKey.currentState!.validate()) return;

    setState(() => _isLoading = true);

    try {
      final prefs = await SharedPreferences.getInstance();

      final response = await http
          .post(
        Uri.parse('$_serverUrl/api/students/login'),
        headers: {'Content-Type': 'application/json','Accept': 'application/json'},
        body: json.encode({'login': _login, 'password': _password}),
      )
          .timeout(const Duration(seconds: 12));

      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        await prefs.setString('userRole', 'student');
        if (data is Map && data['group_name'] != null) {
          await prefs.setString('studentGroup', data['group_name'].toString());
        }

        // user_id: из ответа или из prefs
        String? userIdFromResp =
        (data is Map && data['user_id'] != null) ? data['user_id'].toString() : null;
        String? userId = userIdFromResp ?? prefs.getString('userId');

        if (userIdFromResp != null && (prefs.getString('userId') ?? '').isEmpty) {
          await prefs.setString('userId', userIdFromResp);
        }

        if (userId != null && userId.isNotEmpty) {
          await SecurePasswordStore.save(userId, _password);
        }

        _toastSuccess('Вход выполнен успешно!');
        if (mounted) Navigator.pop(context, true);
      } else {
        String msg = 'Ошибка входа';
        try {
          final errorData = json.decode(response.body);
          msg = (errorData['detail'] ?? msg).toString();
        } catch (_) {}
        _toastError(msg);
      }
    } on SocketException catch (_) {
      _toastError('Сервер недоступен. Проверьте подключение.');
    } on TimeoutException catch (_) {
      _toastError('Сервер недоступен (таймаут). Попробуйте позже.');
    } catch (e) {
      _toastError('Ошибка: $e');
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  // ---- UI helpers
  InputDecoration _dec(String label, IconData icon, {Widget? suffix}) {
    final scheme = Theme.of(context).colorScheme;
    return InputDecoration(
      labelText: label,
      prefixIcon: Icon(icon, color: scheme.primary),
      suffixIcon: suffix,
      filled: true,
      fillColor: Theme.of(context).brightness == Brightness.dark
          ? const Color(0xFF1F2429)
          : const Color(0xFFF4F6F8),
      border: OutlineInputBorder(
        borderRadius: BorderRadius.circular(14),
        borderSide: BorderSide(color: scheme.outlineVariant),
      ),
      enabledBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(14),
        borderSide: BorderSide(color: scheme.outlineVariant),
      ),
      focusedBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(14),
        borderSide: BorderSide(color: scheme.primary, width: 1.6),
      ),
      contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 14),
    );
  }

  Widget _header() {
    final title = widget.isLogin ? 'Вход для студентов' : 'Регистрация студента';
    final subtitle = widget.isLogin
        ? 'Введите логин и пароль, чтобы продолжить'
        : 'Заполните данные для регистрации';
    final scheme = Theme.of(context).colorScheme;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            CircleAvatar(
              radius: 18,
              backgroundColor: scheme.primary.withOpacity(.12),
              child: Icon(Icons.school, color: scheme.primary),
            ),
            const SizedBox(width: 10),
            Text(
              title,
              style: TextStyle(
                fontSize: 20,
                fontWeight: FontWeight.w800,
                color: Theme.of(context).brightness == Brightness.dark
                    ? Colors.white
                    : const Color(0xFF0F172A),
              ),
            ),
          ],
        ),
        const SizedBox(height: 6),
        Text(
          subtitle,
          style: TextStyle(
            color: Theme.of(context).brightness == Brightness.dark
                ? Colors.white70
                : const Color(0xFF475569),
          ),
        ),
        const SizedBox(height: 10),
        // ⬇️ Предупреждение: регистрация 1 аккаунта
        Container(
          width: double.infinity,
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
          decoration: BoxDecoration(
            color: Colors.amber.withOpacity(.12),
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: Colors.amber.withOpacity(.45)),
          ),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Icon(Icons.warning_amber_rounded, color: Colors.amber, size: 18),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  'Регистрация доступна только для ОДНОГО аккаунта на пользователя. '
                      'Повторные регистрации запрещены.',
                  style: TextStyle(
                    color: Theme.of(context).colorScheme.onSurface,
                    fontWeight: FontWeight.w700,
                    fontSize: 12.5,
                  ),
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildServerDownBanner() {
    if (!_serverDown && _groupsError.isEmpty) return const SizedBox.shrink();
    final isDown = _serverDown || _groupsError.contains('Сервер недоступен');

    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
      decoration: BoxDecoration(
        color: (isDown ? Colors.red : Colors.orange).withOpacity(.12),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: (isDown ? Colors.red : Colors.orange).withOpacity(.45)),
      ),
      child: Row(
        children: [
          Icon(
            isDown ? Icons.cloud_off_rounded : Icons.info_rounded,
            color: isDown ? Colors.red : Colors.orange,
            size: 18,
          ),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              isDown ? 'Сервер недоступен. Попробуйте позже.' : _groupsError,
              style: TextStyle(
                fontWeight: FontWeight.w700,
                fontSize: 12.5,
                color: Theme.of(context).colorScheme.onSurface,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildGroupDropdown() {
    if (widget.isLogin) return const SizedBox.shrink();

    if (_groupsLoading) {
      return Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          LinearProgressIndicator(color: Theme.of(context).colorScheme.primary),
          const SizedBox(height: 8),
          const Text('Загрузка списка групп...', style: TextStyle(fontSize: 12)),
        ],
      );
    }

    // баннер сверху (сервер недоступен/ошибка загрузки)
    final banner = _buildServerDownBanner();

    if (_groupsError.isNotEmpty) {
      return Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          banner,
          // Кнопка «повторить»
          Align(
            alignment: Alignment.centerLeft,
            child: TextButton.icon(
              onPressed: _loadGroups,
              icon: const Icon(Icons.refresh_rounded),
              label: const Text('Повторить'),
            ),
          ),
        ],
      );
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        banner,
        DropdownButtonFormField<String>(
          decoration: _dec('Группа', Icons.group),
          value: _selectedGroup.isNotEmpty ? _selectedGroup : null,
          items: _groups.map((g) => DropdownMenuItem(value: g, child: Text(g))).toList(),
          validator: (v) => (v == null || v.isEmpty) ? 'Выберите группу' : null,
          onChanged: (v) => setState(() => _selectedGroup = v ?? ''),
        ),
      ],
    );
  }

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;

    return Scaffold(
      backgroundColor: Theme.of(context).colorScheme.background,
      appBar: AppBar(
        title: Text(widget.isLogin ? 'Вход' : 'Регистрация'),
        centerTitle: true,
        elevation: 0,
        backgroundColor: scheme.primary,
        foregroundColor: scheme.onPrimary,
      ),
      body: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 560),
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Card(
              elevation: 3,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(18)),
              child: Padding(
                padding: const EdgeInsets.fromLTRB(18, 18, 18, 20),
                child: Form(
                  key: _formKey,
                  child: ListView(
                    shrinkWrap: true,
                    children: [
                      _header(),
                      const SizedBox(height: 16),

                      if (!widget.isLogin) ...[
                        TextFormField(
                          decoration: _dec('ФИО', Icons.person),
                          onChanged: (v) => _fullName = v,
                          validator: (v) {
                            if (v == null || v.isEmpty) return 'Введите ФИО';
                            if (v.length < 3) return 'Минимум 3 символа';
                            return null;
                          },
                        ),
                        const SizedBox(height: 14),
                      ],

                      TextFormField(
                        decoration: _dec('Логин', Icons.alternate_email),
                        onChanged: (v) => _login = v,
                        validator: (v) {
                          if (v == null || v.isEmpty) return 'Введите логин';
                          if (v.length < 3) return 'Минимум 3 символа';
                          return null;
                        },
                      ),
                      const SizedBox(height: 14),

                      TextFormField(
                        decoration: _dec(
                          'Пароль',
                          Icons.lock,
                          suffix: IconButton(
                            onPressed: () => setState(() => _obscure = !_obscure),
                            icon: Icon(_obscure ? Icons.visibility : Icons.visibility_off),
                          ),
                        ),
                        obscureText: _obscure,
                        onChanged: (v) => _password = v,
                        validator: (v) {
                          if (v == null || v.isEmpty) return 'Введите пароль';
                          if (v.length < 8) return 'Минимум 8 символов';
                          return null;
                        },
                      ),
                      const SizedBox(height: 14),

                      _buildGroupDropdown(),
                      if (!widget.isLogin) const SizedBox(height: 10),

                      const SizedBox(height: 8),
                      SizedBox(
                        height: 52,
                        child: ElevatedButton(
                          onPressed: _isLoading
                              ? null
                              : () => widget.isLogin ? _loginStudent() : _registerStudent(),
                          style: ElevatedButton.styleFrom(
                            backgroundColor: AppColors.primary,
                            foregroundColor: Colors.white,
                            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                          ),
                          child: _isLoading
                              ? const SizedBox(
                            height: 22,
                            width: 22,
                            child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
                          )
                              : Text(
                            widget.isLogin ? 'Войти' : 'Зарегистрироваться',
                            style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w700),
                          ),
                        ),
                      ),

                      const SizedBox(height: 14),
                      TextButton(
                        onPressed: _isLoading
                            ? null
                            : () {
                          Navigator.pushReplacement(
                            context,
                            MaterialPageRoute(
                              builder: (_) => StudentAuthScreen(isLogin: !widget.isLogin),
                            ),
                          );
                        },
                        child: Text(
                          widget.isLogin
                              ? 'Нет аккаунта? Зарегистрируйтесь'
                              : 'Уже есть аккаунт? Войдите',
                          style: TextStyle(color: scheme.primary),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}
