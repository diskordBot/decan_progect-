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
  bool _isLoading = false;
  bool _groupsLoading = true;
  String _groupsError = '';

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
      print('Ошибка загрузки групп: $e');
      setState(() {
        _groupsLoading = false;
        _groupsError = 'Не удалось загрузить список групп';

        // Дефолтные группы на случай ошибки (можно убрать, если не нужно)
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

    setState(() {
      _isLoading = true;
    });

    try {
      final prefs = await SharedPreferences.getInstance();
      final userId = prefs.getString('userId');

      if (userId == null) {
        _showError('Ошибка: пользователь не найден');
        return;
      }

      final response = await http.post(
        Uri.parse('$_serverUrl/api/students/register'),
        headers: {
          'Content-Type': 'application/json',
          'Accept': 'application/json',
        },
        body: json.encode({
          'user_id': userId,
          'full_name': _fullName,
          'login': _login,
          'password': _password,
          'group_name': _selectedGroup,
        }),
      );

      if (response.statusCode == 200) {
        final data = json.decode(response.body);

        // Сохраняем роль студента
        await prefs.setString('userRole', 'student');
        await prefs.setString('studentGroup', _selectedGroup);

        _showSuccess('Регистрация успешна!');
        Navigator.pop(context, true);
      } else {
        final errorData = json.decode(response.body);
        final error = errorData['detail'] ?? 'Неизвестная ошибка';
        _showError(error);
      }
    } catch (e) {
      _showError('Ошибка сети: $e');
    } finally {
      setState(() {
        _isLoading = false;
      });
    }
  }

  Future<void> _loginStudent() async {
    if (!_formKey.currentState!.validate()) return;

    setState(() {
      _isLoading = true;
    });

    try {
      final prefs = await SharedPreferences.getInstance();
      final userId = prefs.getString('userId');

      if (userId == null) {
        _showError('Ошибка: пользователь не найден');
        return;
      }

      final response = await http.post(
        Uri.parse('$_serverUrl/api/students/login'),
        headers: {
          'Content-Type': 'application/json',
          'Accept': 'application/json',
        },
        body: json.encode({
          'login': _login,
          'password': _password,
        }),
      );

      if (response.statusCode == 200) {
        final data = json.decode(response.body);

        // Сохраняем роль студента и группу
        await prefs.setString('userRole', 'student');
        await prefs.setString('studentGroup', data['group_name']);

        _showSuccess('Вход выполнен успешно!');
        Navigator.pop(context, true);
      } else {
        final errorData = json.decode(response.body);
        final error = errorData['detail'] ?? 'Неизвестная ошибка';
        _showError(error);
      }
    } catch (e) {
      _showError('Ошибка сети: $e');
    } finally {
      setState(() {
        _isLoading = false;
      });
    }
  }

  void _showError(String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        backgroundColor: Colors.red,
        duration: const Duration(seconds: 3),
      ),
    );
  }

  void _showSuccess(String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        backgroundColor: Colors.green,
        duration: const Duration(seconds: 2),
      ),
    );
  }

  Widget _buildGroupDropdown() {
    if (_groupsLoading) {
      return const Column(
        children: [
          LinearProgressIndicator(),
          SizedBox(height: 8),
          Text('Загрузка списка групп...', style: TextStyle(fontSize: 12)),
        ],
      );
    }

    if (_groupsError.isNotEmpty) {
      return Column(
        children: [
          Text(
            _groupsError,
            style: TextStyle(color: Colors.red, fontSize: 12),
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 8),
        ],
      );
    }

    return DropdownButtonFormField<String>(
      decoration: const InputDecoration(
        labelText: 'Группа',
        border: OutlineInputBorder(),
        prefixIcon: Icon(Icons.group),
      ),
      value: _selectedGroup.isNotEmpty ? _selectedGroup : null,
      items: _groups.map((String group) {
        return DropdownMenuItem<String>(
          value: group,
          child: Text(group),
        );
      }).toList(),
      validator: (value) {
        if (value == null || value.isEmpty) {
          return 'Выберите группу';
        }
        return null;
      },
      onChanged: (value) {
        setState(() {
          _selectedGroup = value!;
        });
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(widget.isLogin ? 'Вход для студентов' : 'Регистрация студента'),
        backgroundColor: AppColors.primary,
      ),
      body: Padding(
        padding: const EdgeInsets.all(20.0),
        child: Form(
          key: _formKey,
          child: ListView(
            children: [
              if (!widget.isLogin) ...[
                TextFormField(
                  decoration: const InputDecoration(
                    labelText: 'ФИО',
                    border: OutlineInputBorder(),
                    prefixIcon: Icon(Icons.person),
                  ),
                  validator: (value) {
                    if (value == null || value.isEmpty) {
                      return 'Введите ФИО';
                    }
                    if (value.length < 3) {
                      return 'ФИО должно содержать минимум 3 символа';
                    }
                    return null;
                  },
                  onChanged: (value) => _fullName = value,
                ),
                const SizedBox(height: 16),
              ],

              TextFormField(
                decoration: const InputDecoration(
                  labelText: 'Логин',
                  border: OutlineInputBorder(),
                  prefixIcon: Icon(Icons.alternate_email),
                ),
                validator: (value) {
                  if (value == null || value.isEmpty) {
                    return 'Введите логин';
                  }
                  if (value.length < 3) {
                    return 'Логин должен содержать минимум 3 символа';
                  }
                  return null;
                },
                onChanged: (value) => _login = value,
              ),
              const SizedBox(height: 16),

              TextFormField(
                decoration: const InputDecoration(
                  labelText: 'Пароль',
                  border: OutlineInputBorder(),
                  prefixIcon: Icon(Icons.lock),
                ),
                obscureText: true,
                validator: (value) {
                  if (value == null || value.isEmpty) {
                    return 'Введите пароль';
                  }
                  if (value.length < 6) {
                    return 'Пароль должен содержать минимум 6 символов';
                  }
                  return null;
                },
                onChanged: (value) => _password = value,
              ),
              const SizedBox(height: 16),

              if (!widget.isLogin) ...[
                _buildGroupDropdown(),
                const SizedBox(height: 24),
              ],

              ElevatedButton(
                onPressed: _isLoading ? null : () {
                  if (widget.isLogin) {
                    _loginStudent();
                  } else {
                    _registerStudent();
                  }
                },
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppColors.primary,
                  foregroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(vertical: 16),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                ),
                child: _isLoading
                    ? const CircularProgressIndicator(color: Colors.white)
                    : Text(
                  widget.isLogin ? 'Войти' : 'Зарегистрироваться',
                  style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                ),
              ),

              if (widget.isLogin) ...[
                const SizedBox(height: 16),
                TextButton(
                  onPressed: () {
                    Navigator.pushReplacement(
                      context,
                      MaterialPageRoute(
                        builder: (context) => const StudentAuthScreen(isLogin: false),
                      ),
                    );
                  },
                  child: const Text('Нет аккаунта? Зарегистрируйтесь'),
                ),
              ] else ...[
                const SizedBox(height: 16),
                TextButton(
                  onPressed: () {
                    Navigator.pushReplacement(
                      context,
                      MaterialPageRoute(
                        builder: (context) => const StudentAuthScreen(isLogin: true),
                      ),
                    );
                  },
                  child: const Text('Уже есть аккаунт? Войдите'),
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }
}