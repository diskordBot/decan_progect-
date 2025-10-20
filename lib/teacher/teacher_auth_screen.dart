// lib/teacher/teacher_auth_screen.dart
import 'dart:async'; // TimeoutException
import 'dart:io';    // SocketException
import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:http/http.dart' as http;
import 'package:flutter_secure_storage/flutter_secure_storage.dart';

import 'package:decanat_progect/constants.dart';
import 'package:decanat_progect/ui/overlay_toast.dart';

/// ===== Локальное безопасное хранение пароля
class SecurePasswordStore {
  static const _storage = FlutterSecureStorage();
  static String _key(String userId) => 'pw_$userId';
  static Future<void> save(String userId, String password) =>
      _storage.write(key: _key(userId), value: password);
}

class TeacherAuthScreen extends StatefulWidget {
  final bool isLogin;
  const TeacherAuthScreen({super.key, required this.isLogin});

  @override
  State<TeacherAuthScreen> createState() => _TeacherAuthScreenState();
}

class _TeacherAuthScreenState extends State<TeacherAuthScreen> {
  final _formKey = GlobalKey<FormState>();

  final _loginController = TextEditingController();
  final _passwordController = TextEditingController();
  final _fullNameController = TextEditingController();
  final _departmentController = TextEditingController();
  final _positionController = TextEditingController();

  bool _isLoading = false;
  String _errorMessage = '';
  bool _obscure = true;

  @override
  void dispose() {
    _loginController.dispose();
    _passwordController.dispose();
    _fullNameController.dispose();
    _departmentController.dispose();
    _positionController.dispose();
    super.dispose();
  }

  Future<void> _authenticate() async {
    if (!_formKey.currentState!.validate()) return;

    setState(() {
      _isLoading = true;
      _errorMessage = '';
    });

    try {
      final prefs = await SharedPreferences.getInstance();
      String? userId = prefs.getString('userId');

      if (!widget.isLogin && (userId == null || userId.isEmpty)) {
        // При регистрации обязательно нужен userId
        OverlayToast.instance.warning(
          'ID пользователя не найден. Сначала задайте ID.',
          icon: Icons.badge_rounded,
        );
        throw Exception('Пользователь не найден');
      }

      final url = widget.isLogin
          ? '${AppConfig.serverUrl}/api/teachers/login'
          : '${AppConfig.serverUrl}/api/teachers/register';

      final body = widget.isLogin
          ? {
        'login': _loginController.text.trim(),
        'password': _passwordController.text,
      }
          : {
        'user_id': userId,
        'full_name': _fullNameController.text.trim(),
        'login': _loginController.text.trim(),
        'password': _passwordController.text,
        // передаём null если пусто — сервер не будет обновлять поле
        'department': _departmentController.text.trim().isNotEmpty
            ? _departmentController.text.trim()
            : null,
        'position': _positionController.text.trim().isNotEmpty
            ? _positionController.text.trim()
            : null,
      };

      final response = await http
          .post(
        Uri.parse(url),
        headers: {'Content-Type': 'application/json'},
        body: json.encode(body),
      )
          .timeout(const Duration(seconds: 12));

      if (response.statusCode == 200) {
        final dynamic data = json.decode(response.body);

        await prefs.setString('userRole', 'teacher');

        // Если логин — пытаемся взять user_id из ответа
        if (widget.isLogin) {
          final fromResp =
          (data is Map && data['user_id'] != null) ? data['user_id'].toString() : null;
          if (fromResp != null && fromResp.isNotEmpty) {
            userId = fromResp;
            if ((prefs.getString('userId') ?? '').isEmpty) {
              await prefs.setString('userId', fromResp);
            }
          }
        }

        // Сохраняем пароль в secure storage
        if (userId != null && userId.isNotEmpty) {
          await SecurePasswordStore.save(userId, _passwordController.text);
        }

        // Сообщение сервера или дефолт
        final msg = (data is Map && data['message'] is String)
            ? data['message'] as String
            : (widget.isLogin ? 'Вход выполнен!' : 'Регистрация успешна!');

        OverlayToast.instance.success(msg);

        if (mounted) Navigator.pop(context, true);
      } else {
        // попытка вытащить detail
        String serverMsg = 'Ошибка авторизации';
        try {
          final err = json.decode(response.body);
          if (err is Map && err['detail'] is String) {
            serverMsg = err['detail'] as String;
          }
        } catch (_) {}
        OverlayToast.instance.error(serverMsg);
        throw Exception(serverMsg);
      }
    } on TimeoutException {
      final msg = 'Сервер недоступен: превышено время ожидания';
      OverlayToast.instance.error(msg, icon: Icons.cloud_off_rounded);
      setState(() => _errorMessage = msg);
    } on SocketException {
      final msg = 'Нет подключения к интернету';
      OverlayToast.instance.error(msg, icon: Icons.wifi_off_rounded);
      setState(() => _errorMessage = msg);
    } catch (e) {
      final msg = e.toString().replaceAll('Exception: ', '');
      // Падаем сюда для прочих ошибок сервера / валидации
      OverlayToast.instance.error(msg);
      setState(() => _errorMessage = msg);
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
    final title = widget.isLogin ? 'Вход для преподавателей' : 'Регистрация преподавателя';
    final subtitle =
    widget.isLogin ? 'Укажите логин и пароль для входа' : 'Заполните данные для регистрации';
    final scheme = Theme.of(context).colorScheme;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            CircleAvatar(
              radius: 18,
              backgroundColor: scheme.primary.withOpacity(.12),
              child: Icon(Icons.badge, color: scheme.primary),
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

        // Предупреждение про 1 аккаунт
        if (!widget.isLogin)
          Container(
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(12),
              color: Colors.amber.withOpacity(.12),
              border: Border.all(color: Colors.amber.withOpacity(.45)),
            ),
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Icon(Icons.warning_amber_rounded, color: Colors.amber),
                const SizedBox(width: 10),
                Expanded(
                  child: Text(
                    'Важно: регистрировать можно только один аккаунт на один ID пользователя. '
                        'Если у вас уже есть учётная запись — выполните вход.',
                    style: TextStyle(
                      color: Theme.of(context).colorScheme.onSurface,
                      fontWeight: FontWeight.w600,
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
                  child: SingleChildScrollView(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        _header(),
                        const SizedBox(height: 16),

                        if (!widget.isLogin) ...[
                          TextFormField(
                            controller: _fullNameController,
                            decoration: _dec('Полное имя', Icons.person),
                            validator: (v) {
                              if (v == null || v.isEmpty) return 'Введите полное имя';
                              if (v.trim().length < 3) return 'Минимум 3 символа';
                              return null;
                            },
                          ),
                          const SizedBox(height: 14),
                        ],

                        TextFormField(
                          controller: _loginController,
                          decoration: _dec('Логин', Icons.alternate_email),
                          validator: (v) {
                            if (v == null || v.isEmpty) return 'Введите логин';
                            if (v.trim().length < 3) return 'Минимум 3 символа';
                            return null;
                          },
                        ),
                        const SizedBox(height: 14),

                        TextFormField(
                          controller: _passwordController,
                          decoration: _dec(
                            'Пароль',
                            Icons.lock,
                            suffix: IconButton(
                              onPressed: () => setState(() => _obscure = !_obscure),
                              icon: Icon(_obscure ? Icons.visibility : Icons.visibility_off),
                            ),
                          ),
                          obscureText: _obscure,
                          validator: (v) {
                            if (v == null || v.isEmpty) return 'Введите пароль';
                            if (v.length < 8) return 'Минимум 8 символов';
                            return null;
                          },
                        ),
                        const SizedBox(height: 14),

                        if (!widget.isLogin) ...[
                          TextFormField(
                            controller: _departmentController,
                            decoration: _dec('Кафедра (необязательно)', Icons.business),
                          ),
                          const SizedBox(height: 14),
                          TextFormField(
                            controller: _positionController,
                            decoration: _dec('Должность (необязательно)', Icons.work),
                          ),
                        ],

                        const SizedBox(height: 16),

                        if (_errorMessage.isNotEmpty)
                          Padding(
                            padding: const EdgeInsets.only(bottom: 8),
                            child: Text(
                              _errorMessage,
                              textAlign: TextAlign.center,
                              style: TextStyle(color: Theme.of(context).colorScheme.error),
                            ),
                          ),

                        SizedBox(
                          height: 52,
                          child: ElevatedButton(
                            onPressed: _isLoading ? null : _authenticate,
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
                                builder: (_) => TeacherAuthScreen(isLogin: !widget.isLogin),
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
      ),
    );
  }
}
