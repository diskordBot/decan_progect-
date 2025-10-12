import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';
import 'package:decanat_progect/constants.dart';

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

  bool _isLoading = false;
  bool _obscure = true;

  @override
  void initState() {
    super.initState();
    _loadGroups();
  }

  Future<void> _loadGroups() async {
    try {
      final response = await http.get(
        Uri.parse('$_serverUrl/api/groups'),
        headers: {'Accept': 'application/json'},
      );

      if (response.statusCode == 200) {
        final List<dynamic> groupsData = json.decode(response.body);
        setState(() {
          _groups = groupsData.map((group) => group.toString()).toList();
          _groupsLoading = false;
          _groupsError = '';
        });
      } else {
        throw Exception('Ошибка сервера: ${response.statusCode}');
      }
    } catch (e) {
      setState(() {
        _groupsLoading = false;
        _groupsError = 'Не удалось загрузить список групп';
        _groups = [
          'КИ-25', 'СП-25а', 'СП-25б', 'КСЦ-25', 'ПИ-25а', 'ПИ-25б', 'ПИ-25в',
          'ИИ-25а', 'ИИ-25б', 'ИНФ-25', 'САУ-25', 'ПМКИ-25', 'КИ-24', 'СП-24',
          'КСЦ-24', 'ПИ-24а', 'ПИ-24б', 'ИИ-24', 'ИНФ-24', 'САУ-24'
        ];
      });
    }
  }

  Future<void> _registerStudent() async {
    if (!_formKey.currentState!.validate()) return;

    setState(() => _isLoading = true);

    try {
      final prefs = await SharedPreferences.getInstance();
      final userId = prefs.getString('userId');

      if (userId == null) {
        _showError('Ошибка: пользователь не найден');
        return;
      }

      final response = await http.post(
        Uri.parse('$_serverUrl/api/students/register'),
        headers: {'Content-Type': 'application/json','Accept': 'application/json'},
        body: json.encode({
          'user_id': userId,
          'full_name': _fullName,
          'login': _login,
          'password': _password,
          'group_name': _selectedGroup,
        }),
      );

      if (response.statusCode == 200) {
        await prefs.setString('userRole', 'student');
        await prefs.setString('studentGroup', _selectedGroup);
        _showSuccess('Регистрация успешна!');
        Navigator.pop(context, true);
      } else {
        final errorData = json.decode(response.body);
        _showError(errorData['detail'] ?? 'Неизвестная ошибка');
      }
    } catch (e) {
      _showError('Ошибка сети: $e');
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  Future<void> _loginStudent() async {
    if (!_formKey.currentState!.validate()) return;

    setState(() => _isLoading = true);

    try {
      final prefs = await SharedPreferences.getInstance();

      final response = await http.post(
        Uri.parse('$_serverUrl/api/students/login'),
        headers: {'Content-Type': 'application/json','Accept': 'application/json'},
        body: json.encode({'login': _login, 'password': _password}),
      );

      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        await prefs.setString('userRole', 'student');
        await prefs.setString('studentGroup', data['group_name']);
        _showSuccess('Вход выполнен успешно!');
        Navigator.pop(context, true);
      } else {
        final errorData = json.decode(response.body);
        _showError(errorData['detail'] ?? 'Неизвестная ошибка');
      }
    } catch (e) {
      _showError('Ошибка сети: $e');
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  void _showError(String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(message), backgroundColor: Colors.red, duration: const Duration(seconds: 3)),
    );
  }

  void _showSuccess(String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(message), backgroundColor: Colors.green, duration: const Duration(seconds: 2)),
    );
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
            Text(title,
                style: TextStyle(
                  fontSize: 20, fontWeight: FontWeight.w800,
                  color: Theme.of(context).brightness == Brightness.dark
                      ? Colors.white
                      : const Color(0xFF0F172A),
                )),
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
      ],
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

    if (_groupsError.isNotEmpty) {
      return Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(_groupsError, style: const TextStyle(color: Colors.red, fontSize: 12)),
          const SizedBox(height: 8),
        ],
      );
    }

    return DropdownButtonFormField<String>(
      decoration: _dec('Группа', Icons.group),
      value: _selectedGroup.isNotEmpty ? _selectedGroup : null,
      items: _groups.map((g) => DropdownMenuItem(value: g, child: Text(g))).toList(),
      validator: (v) => (v == null || v.isEmpty) ? 'Выберите группу' : null,
      onChanged: (v) => setState(() => _selectedGroup = v ?? ''),
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
                          if (v.length < 6) return 'Минимум 6 символов';
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
                            height: 22, width: 22,
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
