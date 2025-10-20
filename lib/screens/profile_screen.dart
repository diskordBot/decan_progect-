import 'dart:convert';
import 'dart:ui' show lerpDouble, ImageFilter;

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';

import '../constants.dart';
import 'package:decanat_progect/ui/overlay_toast.dart';

// =================== Validators ===================

String? validateEmail(String s) {
  final v = s.trim();
  if (v.isEmpty) return null; // не обязательно
  final re = RegExp(r'^[^\s@]+@[^\s@]+\.[^\s@]+$');
  return re.hasMatch(v) ? null : 'Некорректный email';
}

String? validatePhone(String s) {
  final v = s.trim();
  if (v.isEmpty) return null;
  final allowed = RegExp(r'^[0-9()+\-\s]{5,20}$');
  final digits = RegExp(r'\d').allMatches(v).length;
  if (!allowed.hasMatch(v) || digits < 7) return 'Некорректный номер телефона';
  return null;
}

String? validateRecordBook(String s) {
  final v = s.trim();
  if (v.isEmpty) return null;
  final re = RegExp(r'^[0-9A-Za-z\-]{5}$'); // ровно 5
  return re.hasMatch(v) ? null : 'Зачётная книжка: ровно 5 символов';
}

// =================== Secure password storage ===================

class SecurePasswordStore {
  static const _storage = FlutterSecureStorage();
  static String _key(String userId) => 'pw_$userId';

  static Future<void> save(String userId, String password) async {
    await _storage.write(key: _key(userId), value: password);
  }

  static Future<String?> load(String userId) async {
    return _storage.read(key: _key(userId));
    // ВАЖНО: это локальное безопасное хранилище, сервер сюда не имеет доступа
  }

  static Future<void> delete(String userId) async {
    await _storage.delete(key: _key(userId));
  }
}

// =================== Декор шапки ===================

enum DecorKind { circles, squares, triangles, emojis }

extension DecorKindCodec on DecorKind {
  String get key {
    switch (this) {
      case DecorKind.circles:
        return 'circles';
      case DecorKind.squares:
        return 'squares';
      case DecorKind.triangles:
        return 'triangles';
      case DecorKind.emojis:
        return 'emojis';
    }
  }

  static DecorKind fromKey(String? k) {
    switch (k) {
      case 'squares':
        return DecorKind.squares;
      case 'triangles':
        return DecorKind.triangles;
      case 'emojis':
        return DecorKind.emojis;
      case 'circles':
      default:
        return DecorKind.circles;
    }
  }
}

class ApiValidationException implements Exception {
  final String message;
  ApiValidationException(this.message);
  @override
  String toString() => message;
}

class ProfileScreen extends StatefulWidget {
  final String? userIdOverride;
  final String? roleOverride;
  final bool readOnly; // ← режим только просмотра

  const ProfileScreen({
    super.key,
    this.userIdOverride,
    this.roleOverride,
    this.readOnly = false,
  });

  @override
  State<ProfileScreen> createState() => _ProfileScreenState();
}

class _ProfileScreenState extends State<ProfileScreen> {
  static const int kAppTzOffsetHoursFromUtc = 3;

  String? _userId;
  String _role = 'user';
  String _currentUserRole = 'user';

  bool _loading = true;
  String? _error;

  Map<String, dynamic>? _student;
  Map<String, dynamic>? _teacher;
  Map<String, dynamic>? _user;

  List<String> _allGroups = [];
  bool _groupsLoading = false;
  String? _groupsError;

  DecorKind _decorKind = DecorKind.circles;
  String _decorEmoji = '✨';

  final TextEditingController _recordBookController = TextEditingController();
  final TextEditingController _phoneController = TextEditingController();
  final TextEditingController _emailController = TextEditingController();

  static const _prefsDecorKind = 'headerDecorKind';
  static const _prefsDecorEmoji = 'headerDecorEmoji';

  bool _passwordVisible = false;
  String? _knownPassword;

  void _toastInfo(String msg) =>
      OverlayToast.instance.info(msg, position: ToastPosition.top);
  void _toastError(String msg) =>
      OverlayToast.instance.error(msg, position: ToastPosition.top);

  @override
  void initState() {
    super.initState();
    _bootstrap();
  }

  @override
  void dispose() {
    _recordBookController.dispose();
    _phoneController.dispose();
    _emailController.dispose();
    super.dispose();
  }

  Future<void> _bootstrap() async {
    final prefs = await SharedPreferences.getInstance();
    setState(() {
      _userId = widget.userIdOverride ?? prefs.getString('userId');
      _role = widget.roleOverride ?? (prefs.getString('userRole') ?? 'user');
      _currentUserRole = prefs.getString('userRole') ?? 'user';

      _decorKind = DecorKindCodec.fromKey(prefs.getString(_prefsDecorKind));
      _decorEmoji = prefs.getString(_prefsDecorEmoji) ?? '✨';
    });

    if (_userId != null && _userId!.isNotEmpty) {
      await _loadUIPrefsFor(_userId!);
      await _loadKnownPassword(_userId!);
      await _tryFetchPlainPasswordFromServer(_userId!); // если реализовано у тебя
    }

    await Future.wait([_loadAll(), _loadGroups()]);
  }

  Future<void> _loadKnownPassword(String userId) async {
    final local = await SecurePasswordStore.load(userId);
    if (!mounted) return;
    setState(() {
      _knownPassword = local;
    });
  }

  Future<void> _tryFetchPlainPasswordFromServer(String userId) async {
    // опционально, для твоей локальной разработки — можно не реализовывать на сервере
    try {
      final uri = Uri.parse('${AppConfig.serverUrl}/api/users/$userId/password/plain');
      final r = await http.get(uri).timeout(const Duration(seconds: 6));
      if (r.statusCode == 200) {
        final data = json.decode(r.body);
        if (data is Map && data['password'] is String) {
          await SecurePasswordStore.save(userId, data['password'] as String);
          if (!mounted) return;
          setState(() => _knownPassword = data['password'] as String);
        }
      }
    } catch (_) {/* ignore */}
  }

  // ===== UI prefs =====

  Future<void> _loadUIPrefsFor(String userId) async {
    try {
      final uri = Uri.parse('${AppConfig.serverUrl}/api/users/$userId/ui');
      final r = await http.get(uri).timeout(const Duration(seconds: 8));
      if (r.statusCode == 200) {
        final data = json.decode(r.body) as Map<String, dynamic>;
        if (!mounted) return;
        setState(() {
          _decorKind = DecorKindCodec.fromKey(data['header_decor_kind']?.toString());
          _decorEmoji = data['header_decor_emoji']?.toString() ?? '✨';
        });

        if (widget.userIdOverride == null) {
          final prefs = await SharedPreferences.getInstance();
          await prefs.setString(_prefsDecorKind, _decorKind.key);
          await prefs.setString(_prefsDecorEmoji, _decorEmoji);
        }
      }
    } catch (_) {/* ignore */}
  }

  Future<void> _saveDecorPrefs() async {
    if (widget.readOnly && _currentUserRole != 'developer') return;
    if (_userId == null || _userId!.isEmpty) return;

    try {
      final uri = Uri.parse('${AppConfig.serverUrl}/api/users/${_userId!}/ui');
      await http.put(
        uri,
        headers: {'Content-Type': 'application/json; charset=utf-8'},
        body: json.encode({
          'header_decor_kind': _decorKind.key,
          'header_decor_emoji': _decorEmoji,
        }),
      ).timeout(const Duration(seconds: 8));
    } catch (_) {}

    if (widget.userIdOverride == null) {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString(_prefsDecorKind, _decorKind.key);
      await prefs.setString(_prefsDecorEmoji, _decorEmoji);
    }
  }

  // ===== Data load =====

  Future<void> _loadAll() async {
    if (_userId == null || _userId!.isEmpty) {
      setState(() {
        _loading = false;
        _error = 'ID не задан';
      });
      return;
    }

    setState(() {
      _loading = true;
      _error = null;
    });

    try {
      Map<String, dynamic>? student;
      Map<String, dynamic>? teacher;
      Map<String, dynamic>? user;

      if (_role == 'student') {
        student = await _fetchStudent(_userId!);
      } else if (_role == 'teacher') {
        teacher = await _fetchTeacher(_userId!);
      } else if (_role == 'developer') {
        // Для разработчика тоже подтягиваем "студенческие" поля, если они есть
        student = await _fetchStudent(_userId!);
      }
      user = await _fetchUserAggregated(_userId!);

      setState(() {
        _student = student;
        _teacher = teacher;
        _user = user;
        _loading = false;
      });
    } catch (_) {
      setState(() {
        _loading = false;
        _error = 'Нет подключения к интернету';
      });
    }
  }

  Future<Map<String, dynamic>?> _fetchStudent(String id) async {
    final uri = Uri.parse('${AppConfig.serverUrl}/api/students/$id');
    final r = await http.get(uri).timeout(const Duration(seconds: 8));
    if (r.statusCode == 200) {
      final d = json.decode(r.body);
      if (d is Map<String, dynamic>) return d;
    }
    return null;
  }

  Future<Map<String, dynamic>?> _fetchTeacher(String id) async {
    final uri = Uri.parse('${AppConfig.serverUrl}/api/teachers/$id');
    final r = await http.get(uri).timeout(const Duration(seconds: 8));
    if (r.statusCode == 200) {
      final d = json.decode(r.body);
      if (d is Map<String, dynamic>) return d;
    }
    return null;
  }

  Future<Map<String, dynamic>?> _fetchUserAggregated(String id) async {
    final all = Uri.parse('${AppConfig.serverUrl}/api/users');
    final r = await http.get(all).timeout(const Duration(seconds: 10));
    if (r.statusCode == 200) {
      final data = json.decode(r.body);
      if (data is List) {
        final list = List<Map<String, dynamic>>.from(data);
        final match = list.firstWhere(
              (u) => (u['user_id']?.toString() ?? '') == id,
          orElse: () => <String, dynamic>{},
        );
        if (match.isNotEmpty) return match;
      }
    }
    return null;
  }

  Future<void> _loadGroups() async {
    setState(() {
      _groupsLoading = true;
      _groupsError = null;
    });
    try {
      final uri = Uri.parse('${AppConfig.serverUrl}/api/groups');
      final r = await http.get(uri).timeout(const Duration(seconds: 8));
      if (r.statusCode == 200) {
        final data = json.decode(r.body);
        List<String> groups = [];
        if (data is List) {
          groups = data.map((e) => e.toString()).toList();
        } else if (data is Map && data['groups'] is List) {
          groups = (data['groups'] as List).map((e) => e.toString()).toList();
        }
        setState(() {
          _allGroups = groups;
          _groupsLoading = false;
          _groupsError = null;
        });
      } else {
        throw Exception('status ${r.statusCode}');
      }
    } catch (_) {
      setState(() {
        _groupsLoading = false;
        _groupsError = 'Не удалось загрузить список групп';
      });
    }
  }

  // ===== PATCH helper =====

  Future<Map<String, dynamic>> _patchJson(Uri uri, Map<String, dynamic> body) async {
    final r = await http
        .patch(
      uri,
      headers: {'Content-Type': 'application/json; charset=utf-8'},
      body: json.encode(body),
    )
        .timeout(const Duration(seconds: 12));

    if (r.statusCode >= 200 && r.statusCode < 300) {
      final d = json.decode(r.body);
      return (d is Map<String, dynamic>) ? d : <String, dynamic>{};
    }

    if (r.statusCode == 422) {
      try {
        final resp = json.decode(r.body);
        if (resp is Map && resp['detail'] is List) {
          final msgs = (resp['detail'] as List)
              .map((e) => (e is Map && e['msg'] is String) ? e['msg'] as String : null)
              .whereType<String>()
              .toList();
          if (msgs.isNotEmpty) {
            throw ApiValidationException('Проверьте поля: ${msgs.join(', ')}');
          }
        }
      } catch (_) {}
      throw ApiValidationException('Данные не прошли проверку (422). Проверьте поля.');
    }

    throw Exception('Ошибка сохранения (${r.statusCode})');
  }

  Future<void> _updateStudent({
    String? fullName,
    String? login,
    String? groupName,
    String? recordBookNumber,
    String? phone,
    String? email,
  }) async {
    final uri = Uri.parse('${AppConfig.serverUrl}/api/students/${_userId!}');
    final body = <String, dynamic>{};
    if (fullName != null) body['full_name'] = fullName.trim();
    if (login != null) body['login'] = login.trim();
    if (groupName != null) body['group_name'] = groupName.trim();
    if (recordBookNumber != null) body['record_book_number'] = recordBookNumber.trim();
    if (phone != null) body['phone'] = phone.trim();
    if (email != null) body['email'] = email.trim();

    final updated = await _patchJson(uri, body);
    setState(() => _student = {...?_student, ...updated});
    _user = await _fetchUserAggregated(_userId!);
    if (mounted) {
      _toastInfo('Данные успешно обновлены');
      setState(() {});
    }
  }

  Future<void> _updateTeacher({
    String? fullName,
    String? login,
    String? department,
    String? position,
    String? phone,
    String? email,
  }) async {
    final uri = Uri.parse('${AppConfig.serverUrl}/api/teachers/${_userId!}');
    final body = <String, dynamic>{};
    if (fullName != null) body['full_name'] = fullName.trim();
    if (login != null) body['login'] = login.trim();
    if (department != null) body['department'] = department.trim();
    if (position != null) body['position'] = position.trim();
    if (phone != null) body['phone'] = phone.trim();
    if (email != null) body['email'] = email.trim();

    final updated = await _patchJson(uri, body);
    setState(() => _teacher = {...?_teacher, ...updated});
    _user = await _fetchUserAggregated(_userId!);
    if (mounted) {
      _toastInfo('Профиль преподавателя обновлён');
      setState(() {});
    }
  }

  // ===== Password change (для владельца профиля/доступных ролей) =====

  Future<void> _changePassword({
    required String currentPassword,
    required String newPassword,
  }) async {
    if (_userId == null || _userId!.isEmpty) {
      throw Exception('ID не задан');
    }

    final uri = Uri.parse('${AppConfig.serverUrl}/api/users/${_userId!}/password');
    final r = await http
        .post(
      uri,
      headers: {'Content-Type': 'application/json; charset=utf-8'},
      body: json.encode({
        'old_password': currentPassword,
        'new_password': newPassword,
      }),
    )
        .timeout(const Duration(seconds: 12));

    if (r.statusCode == 204) {
      await SecurePasswordStore.save(_userId!, newPassword);
      if (mounted) {
        setState(() {
          _knownPassword = newPassword;
        });
      }
      return;
    }

    if (r.statusCode == 401) {
      throw ApiValidationException('Неверный текущий пароль');
    }
    if (r.statusCode == 422) {
      throw ApiValidationException('Новый пароль слишком короткий (мин. 8 символов)');
    }

    String msg = 'Ошибка смены пароля (${r.statusCode})';
    try {
      final data = json.decode(r.body);
      if (data is Map && data['detail'] is String) msg = data['detail'];
    } catch (_) {}
    throw Exception(msg);
  }

  // ===== Time & formatting =====

  bool _hasTz(String s) => s.endsWith('Z') || RegExp(r'[+\-]\d{2}:\d{2}$').hasMatch(s);

  DateTime? _parseToUtc(String? iso) {
    if (iso == null || iso.trim().isEmpty) return null;
    try {
      final s = iso.trim();
      final dt = DateTime.parse(s);
      if (_hasTz(s)) {
        return dt.isUtc ? dt : dt.toUtc();
      } else {
        return DateTime.utc(dt.year, dt.month, dt.day, dt.hour, dt.minute, dt.second, dt.millisecond, dt.microsecond);
      }
    } catch (_) {
      return null;
    }
  }

  DateTime? _toAppTz(DateTime? utc) => utc == null ? null : utc.add(const Duration(hours: kAppTzOffsetHoursFromUtc));

  String _fmtAppTz(String? iso) {
    final local = _toAppTz(_parseToUtc(iso));
    if (local == null) return '—';
    final m = local.month.toString().padLeft(2, '0');
    final d = local.day.toString().padLeft(2, '0');
    final hh = local.hour.toString().padLeft(2, '0');
    final mm = local.minute.toString().padLeft(2, '0');
    return '$d.$m.${local.year} $hh:$mm';
  }

  // ===== UI helpers =====

  Future<void> _onRefresh() async {
    await Future.wait([_loadAll(), _loadGroups()]);
    if (_userId != null) await _loadUIPrefsFor(_userId!);
  }

  String _displayName() {
    final sName = _student?['full_name']?.toString();
    final tName = _teacher?['full_name']?.toString();
    final uName = _user?['full_name']?.toString();

    if (sName != null && sName.trim().isNotEmpty) return sName.trim();
    if (tName != null && tName.trim().isNotEmpty) return tName.trim();
    if (uName != null && uName.trim().isNotEmpty) return uName.trim();
    return _roleTitle(_role);
  }

  String _subtitle() {
    if ((_role == 'student' || _role == 'developer') && _student != null) {
      final group = (_student!['group_name'] ?? '').toString().trim();
      if (group.isNotEmpty) return 'Группа: $group';
    }
    if (_role == 'teacher' && _teacher != null) {
      final dep = (_teacher!['department'] ?? '').toString().trim();
      final pos = (_teacher!['position'] ?? '').toString().trim();
      final parts = [if (dep.isNotEmpty) dep, if (pos.isNotEmpty) pos];
      if (parts.isNotEmpty) return parts.join(' • ');
    }
    return _roleTitle(_role);
  }

  String _initials(String name) {
    final parts = name.trim().split(RegExp(r'\s+'));
    if (parts.length == 1) {
      return parts.first.characters.take(2).toString().toUpperCase();
    }
    return (parts.first.characters.take(1).toString() + parts.last.characters.take(1).toString()).toUpperCase();
  }

  Color _roleAccent(String role) {
    switch (role) {
      case 'developer':
        return Colors.purple;
      case 'admin':
        return Colors.blue;
      case 'teacher':
        return Colors.green;
      case 'student':
        return Colors.orange;
      default:
        return Colors.grey;
    }
  }

  String _roleTitle(String role) {
    switch (role) {
      case 'developer':
        return 'Разработчик';
      case 'admin':
        return 'Администратор';
      case 'teacher':
        return 'Преподаватель';
      case 'student':
        return 'Студент';
      default:
        return 'Пользователь';
    }
  }

  String _sanitizeEmoji(String input) {
    final s = input.trim();
    if (s.isEmpty) return '✨';
    final runes = s.runes.toList();
    final take = runes.length > 4 ? 4 : runes.length;
    return String.fromCharCodes(runes.take(take));
  }

  void _openDecorPicker() {
    final bool canEditDecor = !widget.readOnly || _currentUserRole == 'developer';
    if (!canEditDecor) return;

    final tempKind = ValueNotifier<DecorKind>(_decorKind);
    final emojiCtrl = TextEditingController(text: _decorEmoji);

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) {
        final inset = MediaQuery.of(ctx).viewInsets;
        return Padding(
          padding: EdgeInsets.only(bottom: inset.bottom),
          child: _GlassSheet(
            accent: _roleAccent(_role),
            title: widget.userIdOverride != null
                ? 'Оформление шапки (пользователь $_userId)'
                : 'Оформление шапки',
            avatarText: '🎨',
            childBuilder: (setLocal, saving) {
              Future<void> onSave() async {
                setState(() {
                  _decorKind = tempKind.value;
                  if (tempKind.value == DecorKind.emojis) {
                    _decorEmoji = _sanitizeEmoji(emojiCtrl.text);
                  }
                });
                await _saveDecorPrefs();
                if (mounted) Navigator.pop(ctx);
              }

              return SingleChildScrollView(
                padding: const EdgeInsets.only(bottom: 8),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    _DecorRadioTile(title: 'Круги', value: DecorKind.circles, group: tempKind),
                    _DecorRadioTile(title: 'Квадраты', value: DecorKind.squares, group: tempKind),
                    _DecorRadioTile(title: 'Треугольники', value: DecorKind.triangles, group: tempKind),
                    _DecorRadioTile(title: 'Эмодзи/Стикер', value: DecorKind.emojis, group: tempKind),
                    const SizedBox(height: 8),
                    ValueListenableBuilder<DecorKind>(
                      valueListenable: tempKind,
                      builder: (_, kind, __) {
                        if (kind != DecorKind.emojis) return const SizedBox.shrink();
                        return _FilledField(
                          controller: emojiCtrl,
                          label: 'Символ/эмодзи (например, ✨)',
                          icon: Icons.emoji_emotions_rounded,
                          textInputAction: TextInputAction.done,
                        );
                      },
                    ),
                    const SizedBox(height: 8),
                    _StickyActionsBar(
                      savingNotifier: ValueNotifier(false),
                      onCancel: () => Navigator.pop(ctx),
                      onSave: onSave,
                    ),
                  ],
                ),
              );
            },
          ),
        );
      },
    );
  }

  Future<void> _ensureGroupsLoaded() async {
    if (_allGroups.isEmpty && !_groupsLoading) {
      await _loadGroups();
    }
  }

  void _showTopHint(BuildContext context, String text) {
    _toastInfo(text);
  }

  void _openEditSheet(BuildContext context) async {
    final bool canEditData = !widget.readOnly || _currentUserRole == 'developer';
    if (!canEditData) return;

    // Разработчику даём такой же редактор, как студенту
    final isStudentLike = _role == 'student' || _role == 'developer';
    final isTeacher = _role == 'teacher';

    if (!isStudentLike && !isTeacher) {
      _toastError('Редактирование доступно для профилей студента/преподавателя/разработчика');
      return;
    }

    await _ensureGroupsLoaded();

    final nameCtrl = TextEditingController(
      text: isStudentLike ? (_student?['full_name'] ?? '') : (_teacher?['full_name'] ?? ''),
    );
    final loginCtrl = TextEditingController(
      text: isStudentLike ? (_student?['login'] ?? '') : (_teacher?['login'] ?? ''),
    );

    String selectedGroup = _student?['group_name']?.toString() ?? '';
    final depCtrl = TextEditingController(text: _teacher?['department'] ?? '');
    final posCtrl = TextEditingController(text: _teacher?['position'] ?? '');

    _recordBookController.text = _student?['record_book_number']?.toString() ?? '';
    _phoneController.text =
        _student?['phone']?.toString() ?? _teacher?['phone']?.toString() ?? '';
    _emailController.text =
        _student?['email']?.toString() ?? _teacher?['email']?.toString() ?? '';

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) {
        final inset = MediaQuery.of(ctx).viewInsets;
        return Padding(
          padding: EdgeInsets.only(bottom: inset.bottom),
          child: _GlassSheet(
            accent: _roleAccent(_role),
            title: 'Редактирование профиля',
            avatarText: _initials(_displayName()),
            childBuilder: (setLocal, saving) {
              String? errorText;
              String? phoneErr;
              String? emailErr;
              String? recordBookErr;

              Future<void> onSave() async {
                if (nameCtrl.text.trim().length < 3) {
                  setLocal(() {
                    errorText = 'ФИО слишком короткое';
                    phoneErr = emailErr = recordBookErr = null;
                  });
                  _showTopHint(ctx, 'Некорректный ввод — проверьте ФИО');
                  return;
                }
                if (loginCtrl.text.trim().length < 3) {
                  setLocal(() {
                    errorText = 'Логин слишком короткий';
                    phoneErr = emailErr = recordBookErr = null;
                  });
                  _showTopHint(ctx, 'Некорректный ввод — проверьте логин');
                  return;
                }
                if (isStudentLike && selectedGroup.trim().isEmpty) {
                  setLocal(() {
                    errorText = 'Выберите группу';
                    phoneErr = emailErr = recordBookErr = null;
                  });
                  _showTopHint(ctx, 'Некорректный ввод — выберите группу');
                  return;
                }

                final eErr = validateEmail(_emailController.text);
                final pErr = validatePhone(_phoneController.text);
                final rErr = isStudentLike ? validateRecordBook(_recordBookController.text) : null;

                if (eErr != null || pErr != null || rErr != null) {
                  setLocal(() {
                    errorText = null;
                    emailErr = eErr;
                    phoneErr = pErr;
                    recordBookErr = rErr;
                  });

                  final msg = eErr != null
                      ? 'Некорректная почта — пример: library@gmail.com'
                      : pErr != null
                      ? 'Некорректный телефон — пример: +7 999 123-45-67'
                      : 'Номер зачётной книжки должен быть ровно 5 символов';
                  _showTopHint(ctx, msg);
                  return;
                }

                final trimmedPhone = _phoneController.text.trim();
                final trimmedEmail = _emailController.text.trim();
                final trimmedRecord = _recordBookController.text.trim();

                setLocal(() {
                  errorText = null;
                  emailErr = phoneErr = recordBookErr = null;
                  saving.value = true;
                });

                try {
                  if (isStudentLike) {
                    await _updateStudent(
                      fullName: nameCtrl.text,
                      login: loginCtrl.text,
                      groupName: selectedGroup,
                      recordBookNumber: trimmedRecord.isEmpty ? null : trimmedRecord,
                      phone: trimmedPhone.isEmpty ? null : trimmedPhone,
                      email: trimmedEmail.isEmpty ? null : trimmedEmail,
                    );
                  } else if (isTeacher) {
                    await _updateTeacher(
                      fullName: nameCtrl.text,
                      login: loginCtrl.text,
                      phone: trimmedPhone.isEmpty ? null : trimmedPhone,
                      email: trimmedEmail.isEmpty ? null : trimmedEmail,
                      department: depCtrl.text.trim().isEmpty ? null : depCtrl.text,
                      position: posCtrl.text.trim().isEmpty ? null : posCtrl.text,
                    );
                  }
                  if (mounted) Navigator.pop(ctx);
                } catch (e) {
                  _toastError(e.toString());
                } finally {
                  if (mounted) setLocal(() => saving.value = false);
                }
              }

              return Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  _FilledField(
                    controller: nameCtrl,
                    label: 'ФИО',
                    icon: Icons.person_rounded,
                    textInputAction: TextInputAction.next,
                    hintText: 'Иванов Иван Иванович',
                  ),
                  const SizedBox(height: 8),
                  _FilledField(
                    controller: loginCtrl,
                    label: 'Логин',
                    icon: Icons.alternate_email_rounded,
                    textInputAction: TextInputAction.next,
                    hintText: 'username',
                  ),
                  const SizedBox(height: 8),
                  if (isStudentLike) ...[
                    if (_groupsLoading)
                      const Padding(
                        padding: EdgeInsets.symmetric(vertical: 8),
                        child: LinearProgressIndicator(),
                      )
                    else if (_groupsError != null)
                      Row(
                        children: [
                          Expanded(
                            child: Text(
                              _groupsError!,
                              style: TextStyle(color: Theme.of(context).colorScheme.error),
                            ),
                          ),
                          IconButton(
                            icon: const Icon(Icons.refresh_rounded),
                            onPressed: () async {
                              await _loadGroups();
                              setLocal(() {});
                            },
                          ),
                        ],
                      )
                    else
                      _FilledDropdown<String>(
                        value: _allGroups.contains(selectedGroup) ? selectedGroup : null,
                        label: 'Группа',
                        icon: Icons.school_rounded,
                        items: _allGroups.map((g) => DropdownMenuItem(value: g, child: Text(g))).toList(),
                        onChanged: (v) => setLocal(() => selectedGroup = v ?? ''),
                      ),
                    const SizedBox(height: 8),
                  ],
                  if (isTeacher) ...[
                    _FilledField(
                      controller: depCtrl,
                      label: 'Кафедра',
                      icon: Icons.business_rounded,
                      textInputAction: TextInputAction.next,
                      hintText: 'Кафедра ИТ',
                    ),
                    const SizedBox(height: 8),
                    _FilledField(
                      controller: posCtrl,
                      label: 'Должность',
                      icon: Icons.workspace_premium_rounded,
                      textInputAction: TextInputAction.next,
                      hintText: 'Доцент',
                    ),
                    const SizedBox(height: 8),
                  ],
                  _FilledField(
                    controller: _phoneController,
                    label: 'Телефон',
                    icon: Icons.phone_rounded,
                    textInputAction: TextInputAction.next,
                    keyboardType: TextInputType.phone,
                    inputFormatters: [FilteringTextInputFormatter.allow(RegExp(r'[0-9()+\-\s]'))],
                    hintText: '+7 999 123-45-67',
                    helperText: 'Разрешены цифры и + ( ) -',
                  ),
                  const SizedBox(height: 8),
                  _FilledField(
                    controller: _emailController,
                    label: 'Email',
                    icon: Icons.email_rounded,
                    textInputAction: TextInputAction.next,
                    keyboardType: TextInputType.emailAddress,
                    hintText: 'library@gmail.com',
                    helperText: 'Укажите действующий адрес',
                  ),
                  const SizedBox(height: 8),
                  if (isStudentLike)
                    _FilledField(
                      controller: _recordBookController,
                      label: 'Номер зачётной книжки',
                      icon: Icons.book_rounded,
                      textInputAction: TextInputAction.done,
                      keyboardType: TextInputType.text,
                      inputFormatters: [
                        FilteringTextInputFormatter.allow(RegExp(r'[0-9A-Za-z\-]')),
                        LengthLimitingTextInputFormatter(5),
                      ],
                      hintText: '5 символов (напр. A12B3)',
                      helperText: 'Только цифры/-',
                    ),
                  const SizedBox(height: 8),
                  _StickyActionsBar(
                    savingNotifier: ValueNotifier(false),
                    onCancel: () => Navigator.pop(ctx),
                    onSave: onSave,
                  ),
                ],
              );
            },
          ),
        );
      },
    );
  }

  void _copy(String label, String? value) async {
    final v = (value ?? '').trim();
    if (v.isEmpty) return;
    await Clipboard.setData(ClipboardData(text: v));
    if (mounted) {
      _toastInfo('$label скопирован');
    }
  }

  void _openChangePasswordSheet(BuildContext context) {
    final currentCtrl = TextEditingController();
    final newCtrl = TextEditingController();
    final confirmCtrl = TextEditingController();

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) {
        final inset = MediaQuery.of(ctx).viewInsets;
        return Padding(
          padding: EdgeInsets.only(bottom: inset.bottom),
          child: _GlassSheet(
            accent: _roleAccent(_role),
            title: 'Сменить пароль',
            avatarText: '🔒',
            childBuilder: (setLocal, saving) {
              String? errorText;
              String? curErr, newErr, confErr;

              Future<void> onSave() async {
                final cur = currentCtrl.text;
                final npw = newCtrl.text;
                final cfr = confirmCtrl.text;

                curErr = (cur.isEmpty) ? 'Введите текущий пароль' : null;
                if (npw.length < 8) {
                  newErr = 'Минимум 8 символов';
                } else {
                  newErr = null;
                }
                confErr = (cfr != npw) ? 'Пароли не совпадают' : null;

                if (curErr != null || newErr != null || confErr != null) {
                  setLocal(() {});
                  _showTopHint(ctx, 'Некорректный ввод — проверьте поля');
                  return;
                }

                saving.value = true;
                try {
                  await _changePassword(currentPassword: cur, newPassword: npw);
                  if (mounted) {
                    Navigator.pop(ctx);
                    _toastInfo('Пароль обновлён');
                  }
                } catch (e) {
                  setLocal(() => errorText = e.toString());
                  _showTopHint(ctx, errorText!.replaceAll('Exception: ', ''));
                } finally {
                  if (mounted) saving.value = false;
                }
              }

              return Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  _PasswordField(
                    controller: currentCtrl,
                    label: 'Текущий пароль',
                    errorText: curErr,
                  ),
                  const SizedBox(height: 8),
                  _PasswordField(
                    controller: newCtrl,
                    label: 'Новый пароль',
                    helperText: 'Не менее 8 символов',
                    errorText: newErr,
                  ),
                  const SizedBox(height: 8),
                  _PasswordField(
                    controller: confirmCtrl,
                    label: 'Подтверждение пароля',
                    errorText: confErr,
                  ),
                  if (errorText != null) ...[
                    const SizedBox(height: 6),
                    Align(
                      alignment: Alignment.centerLeft,
                      child: Text(
                        errorText!,
                        style: TextStyle(color: Theme.of(context).colorScheme.error),
                      ),
                    ),
                  ],
                  const SizedBox(height: 8),
                  _StickyActionsBar(
                    savingNotifier: ValueNotifier(false),
                    onCancel: () => Navigator.pop(ctx),
                    onSave: onSave,
                  ),
                ],
              );
            },
          ),
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    final idText = _userId ?? '—';
    final nameText = _displayName();
    final subtitleText = _subtitle();

    return Scaffold(
      appBar: AppBar(
        title: const Text('Профиль'),
        actions: [
          if (!widget.readOnly || _currentUserRole == 'developer')
            IconButton(
              tooltip: 'Оформление шапки',
              onPressed: _openDecorPicker,
              icon: const Icon(Icons.brush_rounded),
            ),
          if (!_loading && _error == null && (!widget.readOnly || _currentUserRole == 'developer'))
            IconButton(
              icon: const Icon(Icons.edit_rounded, color: Colors.orange),
              tooltip: 'Редактировать',
              onPressed: () => _openEditSheet(context),
            ),
        ],
      ),
      body: RefreshIndicator(
        onRefresh: _onRefresh,
        child: _loading
            ? CustomScrollView(
          physics: const AlwaysScrollableScrollPhysics(),
          slivers: const [
            SliverToBoxAdapter(child: _SkeletonHeaderCard()),
            SliverToBoxAdapter(child: SizedBox(height: 8)),
            SliverToBoxAdapter(child: _SkeletonSection()),
            SliverToBoxAdapter(child: _SkeletonSection()),
          ],
        )
            : (_error != null)
            ? CustomScrollView(
          physics: const AlwaysScrollableScrollPhysics(),
          slivers: [
            SliverToBoxAdapter(
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: _ErrorCard(text: _error!),
              ),
            ),
            SliverToBoxAdapter(
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 16),
                child: FilledButton.icon(
                  onPressed: _loadAll,
                  icon: const Icon(Icons.refresh_rounded),
                  label: const Text('Повторить попытку'),
                ),
              ),
            ),
          ],
        )
            : CustomScrollView(
          physics: const AlwaysScrollableScrollPhysics(),
          slivers: [
            SliverPersistentHeader(
              pinned: false,
              floating: false,
              delegate: _CollapsingProfileHeader(
                userId: idText,
                onCopyId: () async {
                  await Clipboard.setData(ClipboardData(text: idText));
                  if (mounted) {
                    _toastInfo('ID скопирован');
                  }
                },
                name: nameText,
                subtitle: subtitleText,
                initials: _initials(nameText),
                accent: _roleAccent(_role),
                decorKind: _decorKind,
                emoji: _decorEmoji,
              ),
            ),
            const SliverToBoxAdapter(child: SizedBox(height: 8)),
            SliverToBoxAdapter(
              child: Padding(
                padding: const EdgeInsets.fromLTRB(12, 0, 12, 24),
                child: Column(
                  children: [
                    // Основной блок с данными
                    InfoSectionCard(
                      children: [
                        InfoRow(
                          icon: Icons.fingerprint_rounded,
                          label: 'ID',
                          value: idText,
                          onTap: () => _copy('ID', idText),
                        ),
                        // Для студента ИЛИ разработчика (если есть "студенческие" поля)
                        if ((_role == 'student') ||
                            (_role == 'developer' && _student != null)) ...[
                          InfoRow(
                            icon: Icons.alternate_email_rounded,
                            label: 'Логин',
                            value: _student?['login'],
                            onTap: () => _copy('Логин', _student?['login']),
                          ),
                          if (((_student?['group_info']?['faculty']) ?? '')
                              .toString()
                              .trim()
                              .isNotEmpty)
                            InfoRow(
                              icon: Icons.account_tree_rounded,
                              label: 'Факультет',
                              value: _student!['group_info']['faculty'].toString(),
                            ),
                          if ((_student?['record_book_number'] ?? '')
                              .toString()
                              .trim()
                              .isNotEmpty)
                            InfoRow(
                              icon: Icons.book_rounded,
                              label: 'Зачётная книжка',
                              value: _student!['record_book_number'],
                              onTap: () => _copy('Номер зачётной книжки',
                                  _student!['record_book_number']),
                            ),
                          if ((_student?['phone'] ?? '').toString().trim().isNotEmpty)
                            InfoRow(
                              icon: Icons.phone_rounded,
                              label: 'Телефон',
                              value: _student!['phone'],
                              onTap: () =>
                                  _copy('Телефон', _student!['phone']),
                            ),
                          if ((_student?['email'] ?? '').toString().trim().isNotEmpty)
                            InfoRow(
                              icon: Icons.email_rounded,
                              label: 'Email',
                              value: _student!['email'],
                              onTap: () =>
                                  _copy('Email', _student!['email']),
                            ),
                          InfoRow(
                            icon: Icons.event_available_rounded,
                            label: 'Создан',
                            value: '${_fmtAppTz(_student?['created_at'])} (МСК)',
                          ),
                        ],
                        if (_role == 'teacher' && _teacher != null) ...[
                          InfoRow(
                            icon: Icons.alternate_email_rounded,
                            label: 'Логин',
                            value: _teacher!['login'],
                            onTap: () => _copy('Логин', _teacher!['login']),
                          ),
                          InfoRow(
                            icon: Icons.workspace_premium_rounded,
                            label: 'Должность',
                            value: _teacher!['position'],
                          ),
                          InfoRow(
                            icon: Icons.business_rounded,
                            label: 'Кафедра',
                            value: _teacher!['department'],
                          ),
                          if ((_teacher?['phone'] ?? '')
                              .toString()
                              .trim()
                              .isNotEmpty)
                            InfoRow(
                              icon: Icons.phone_rounded,
                              label: 'Телефон',
                              value: _teacher!['phone'],
                              onTap: () =>
                                  _copy('Телефон', _teacher!['phone']),
                            ),
                          if ((_teacher?['email'] ?? '')
                              .toString()
                              .trim()
                              .isNotEmpty)
                            InfoRow(
                              icon: Icons.email_rounded,
                              label: 'Email',
                              value: _teacher!['email'],
                              onTap: () =>
                                  _copy('Email', _teacher!['email']),
                            ),
                          InfoRow(
                            icon: Icons.event_available_rounded,
                            label: 'Создан',
                            value: '${_fmtAppTz(_teacher!['created_at'])} (МСК)',
                          ),
                        ],
                        // Блок «общего» пользователя остаётся — у разработчика роль не меняем
                        if (_role != 'student' && _role != 'teacher') ...[
                          InfoRow(
                            icon: Icons.verified_user_rounded,
                            label: 'Роль',
                            value: _roleTitle(_role),
                          ),
                          if ((_user?['full_name'] ?? '')
                              .toString()
                              .trim()
                              .isNotEmpty)
                            InfoRow(
                              icon: Icons.person_rounded,
                              label: 'ФИО',
                              value: _user!['full_name'],
                            ),
                          if ((_user?['login'] ?? '')
                              .toString()
                              .trim()
                              .isNotEmpty)
                            InfoRow(
                              icon: Icons.alternate_email_rounded,
                              label: 'Логин',
                              value: _user!['login'],
                              onTap: () => _copy('Логин', _user!['login']),
                            ),
                        ],
                      ],
                    ),

                    // === Конфиденциальность: показываем ТОЛЬКО если не readOnly ИЛИ если developer ===
                    if (!widget.readOnly || _currentUserRole == 'developer') ...[
                      const SizedBox(height: 12),
                      Align(
                        alignment: Alignment.centerLeft,
                        child: Padding(
                          padding: const EdgeInsets.only(left: 4, bottom: 6),
                          child: Text(
                            'КОНФИДЕНЦИАЛЬНОСТЬ',
                            style: Theme.of(context).textTheme.labelMedium?.copyWith(
                              fontWeight: FontWeight.w900,
                              letterSpacing: 1.0,
                              color: Theme.of(context)
                                  .colorScheme
                                  .onSurfaceVariant,
                            ),
                          ),
                        ),
                      ),
                      InfoSectionCard(
                        children: [
                          // визуализация локального пароля (если сохранён в secure storage)
                          Material(
                            color: Theme.of(context).colorScheme.surface,
                            borderRadius: BorderRadius.circular(16),
                            child: Container(
                              padding: const EdgeInsets.fromLTRB(12, 12, 12, 12),
                              decoration: BoxDecoration(
                                borderRadius: BorderRadius.circular(16),
                                border: Border.all(
                                  color: Theme.of(context)
                                      .colorScheme
                                      .outlineVariant
                                      .withOpacity(.35),
                                ),
                              ),
                              child: Row(
                                children: [
                                  Container(
                                    width: 36,
                                    height: 36,
                                    decoration: BoxDecoration(
                                      color: Theme.of(context)
                                          .colorScheme
                                          .primary
                                          .withOpacity(.10),
                                      borderRadius:
                                      BorderRadius.circular(10),
                                    ),
                                    child: Icon(Icons.lock_rounded,
                                        size: 20,
                                        color: Theme.of(context)
                                            .colorScheme
                                            .primary),
                                  ),
                                  const SizedBox(width: 12),
                                  Expanded(
                                    child: Column(
                                      crossAxisAlignment:
                                      CrossAxisAlignment.start,
                                      children: [
                                        Text('Пароль',
                                            style: TextStyle(
                                              color: Theme.of(context)
                                                  .colorScheme
                                                  .onSurfaceVariant,
                                              fontWeight:
                                              FontWeight.w600,
                                              fontSize: 12.5,
                                              letterSpacing: .2,
                                            )),
                                        const SizedBox(height: 4),
                                        GestureDetector(
                                          onLongPress: () {
                                            if ((_knownPassword ?? '')
                                                .isNotEmpty) {
                                              _copy('Пароль',
                                                  _knownPassword);
                                            }
                                          },
                                          child: Text(
                                            (_knownPassword == null ||
                                                _knownPassword!
                                                    .isEmpty)
                                                ? '— не сохранён локально —'
                                                : (_passwordVisible
                                                ? _knownPassword!
                                                : '••••••••'),
                                            style: TextStyle(
                                              color: Theme.of(context)
                                                  .colorScheme
                                                  .onSurface,
                                              fontWeight:
                                              FontWeight.w700,
                                              fontSize: 15.5,
                                            ),
                                          ),
                                        ),
                                      ],
                                    ),
                                  ),
                                  IconButton(
                                    tooltip:
                                    (_knownPassword ?? '').isEmpty
                                        ? 'Пароль не сохранён локально'
                                        : (_passwordVisible
                                        ? 'Скрыть'
                                        : 'Показать'),
                                    onPressed:
                                    (_knownPassword ?? '').isEmpty
                                        ? null
                                        : () => setState(() =>
                                    _passwordVisible =
                                    !_passwordVisible),
                                    icon: Icon(
                                      _passwordVisible
                                          ? Icons
                                          .visibility_off_rounded
                                          : Icons.visibility_rounded,
                                    ),
                                  ),
                                  const SizedBox(width: 4),
                                ],
                              ),
                            ),
                          ),
                          Align(
                            alignment: Alignment.centerRight,
                            child: TextButton.icon(
                              onPressed: () =>
                                  _openChangePasswordSheet(context),
                              icon:
                              const Icon(Icons.password_rounded),
                              label: const Text('Сменить пароль'),
                            ),
                          ),
                        ],
                      ),
                    ],
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// =================== Collapsing Header ===================

class _CollapsingProfileHeader extends SliverPersistentHeaderDelegate {
  final String userId;
  final VoidCallback onCopyId;
  final String name;
  final String subtitle;
  final String initials;
  final Color accent;
  final DecorKind decorKind;
  final String emoji;

  _CollapsingProfileHeader({
    required this.userId,
    required this.onCopyId,
    required this.name,
    required this.subtitle,
    required this.initials,
    required this.accent,
    required this.decorKind,
    required this.emoji,
  });

  @override
  double get maxExtent => 250;
  @override
  double get minExtent => 150;

  @override
  Widget build(BuildContext context, double shrinkOffset, bool overlapsContent) {
    final t = (shrinkOffset / (maxExtent - minExtent)).clamp(0.0, 1.0);
    final screenWidth = MediaQuery.of(context).size.width;

    final scale = lerpDouble(1.0, 0.82, t)!;
    final translateY = lerpDouble(0.0, -16.0, t)!;
    final contentOpacity = lerpDouble(1.0, 0.0, t * 0.85)!;

    return Stack(
      fit: StackFit.expand,
      children: [
        Align(
          alignment: Alignment.topCenter,
          child: Container(
            margin: const EdgeInsets.fromLTRB(12, 4, 12, 8),
            height: lerpDouble(maxExtent, minExtent, t),
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(26),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withOpacity(.18 * (1 - t)),
                  blurRadius: 22,
                  offset: const Offset(0, 12),
                ),
              ],
              gradient: LinearGradient(
                colors: [
                  accent.withOpacity(.95),
                  Color.lerp(accent, AppColors.accent, .55)!.withOpacity(.95),
                ],
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
              ),
            ),
            child: Stack(children: _buildDecorLayers()),
          ),
        ),

        IgnorePointer(
          child: Align(
            alignment: Alignment.center,
            child: Transform.translate(
              offset: Offset(0, translateY),
              child: Transform.scale(
                scale: scale,
                child: Opacity(
                  opacity: contentOpacity,
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      _IdChip(userId: userId, onCopyId: onCopyId),
                      const SizedBox(height: 8),
                      Container(
                        width: screenWidth * 0.28,
                        height: screenWidth * 0.28,
                        decoration: BoxDecoration(
                          shape: BoxShape.circle,
                          color: Colors.white.withOpacity(.12),
                          border:
                          Border.all(color: Colors.white.withOpacity(.60), width: 2),
                          boxShadow: [
                            BoxShadow(
                              color: Colors.black.withOpacity(.25),
                              blurRadius: 18,
                              offset: const Offset(0, 8),
                            ),
                          ],
                        ),
                        child: Center(
                          child: Text(
                            initials.isEmpty ? '👤' : initials,
                            style: const TextStyle(
                              fontSize: 32,
                              fontWeight: FontWeight.w900,
                              color: Colors.white,
                            ),
                          ),
                        ),
                      ),
                      const SizedBox(height: 12),
                      ConstrainedBox(
                        constraints: const BoxConstraints(maxWidth: 320),
                        child: FittedBox(
                          fit: BoxFit.scaleDown,
                          child: Text(
                            name,
                            textAlign: TextAlign.center,
                            style: const TextStyle(
                              fontWeight: FontWeight.w900,
                              fontSize: 20,
                              color: Colors.white,
                              letterSpacing: .3,
                            ),
                          ),
                        ),
                      ),
                      const SizedBox(height: 6),
                      ConstrainedBox(
                        constraints: const BoxConstraints(maxWidth: 320),
                        child: FittedBox(
                          fit: BoxFit.scaleDown,
                          child: Text(
                            subtitle,
                            textAlign: TextAlign.center,
                            style: TextStyle(
                              color: Colors.white.withOpacity(.92),
                              fontSize: 13,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ),
        ),
      ],
    );
  }

  List<Widget> _buildDecorLayers() {
    switch (decorKind) {
      case DecorKind.circles:
        return [
          Positioned(right: -40, top: -20, child: _circle(160, Colors.white.withOpacity(.10))),
          Positioned(left: -30, bottom: -35, child: _circle(120, Colors.white.withOpacity(.08))),
          Positioned(left: 24, top: 14, child: _circle(32, Colors.white.withOpacity(.12))),
        ];
      case DecorKind.squares:
        return [
          Positioned(right: -30, top: -18, child: _square(150, Colors.white.withOpacity(.10))),
          Positioned(left: -20, bottom: -30, child: _square(110, Colors.white.withOpacity(.08))),
          Positioned(left: 24, top: 14, child: _square(34, Colors.white.withOpacity(.12))),
        ];
      case DecorKind.triangles:
        return [
          Positioned(right: -50, top: -30, child: _triangle(180, Colors.white.withOpacity(.10))),
          Positioned(left: -30, bottom: -40, child: _triangle(130, Colors.white.withOpacity(.08))),
          Positioned(left: 24, top: 14, child: _triangle(36, Colors.white.withOpacity(.12))),
        ];
      case DecorKind.emojis:
        return [
          Positioned(right: -10, top: -6, child: _emojiSplash(emoji, 96, .10)),
          Positioned(left: -14, bottom: -10, child: _emojiSplash(emoji, 82, .10)),
          Positioned(left: 20, top: 10, child: _emojiSplash(emoji, 32, .18)),
        ];
    }
  }

  Widget _circle(double size, Color c) => Container(
    width: size,
    height: size,
    decoration: BoxDecoration(shape: BoxShape.circle, color: c),
  );

  Widget _square(double size, Color c) => Container(
    width: size,
    height: size,
    decoration: BoxDecoration(
      color: c,
      borderRadius: BorderRadius.circular(size * 0.12),
    ),
  );

  Widget _triangle(double size, Color c) =>
      CustomPaint(size: Size(size, size), painter: _TrianglePainter(c));

  Widget _emojiSplash(String e, double fontSize, double opacity) => Opacity(
    opacity: opacity,
    child: Text(e, style: TextStyle(fontSize: fontSize, color: Colors.white)),
  );

  @override
  bool shouldRebuild(covariant _CollapsingProfileHeader old) =>
      old.userId != userId ||
          old.name != name ||
          old.subtitle != subtitle ||
          old.initials != initials ||
          old.accent != accent ||
          old.decorKind != decorKind ||
          old.emoji != emoji;
}

class _IdChip extends StatelessWidget {
  final String userId;
  final VoidCallback onCopyId;

  const _IdChip({required this.userId, required this.onCopyId});

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.white.withOpacity(.22),
      shape: StadiumBorder(
        side: BorderSide(color: Colors.white.withOpacity(.6), width: 1),
      ),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              'ID: $userId',
              style: const TextStyle(
                color: Colors.white,
                fontWeight: FontWeight.w800,
                letterSpacing: .2,
              ),
            ),
            const SizedBox(width: 2),
            InkWell(
              onTap: onCopyId,
              customBorder: const CircleBorder(),
              child: const Padding(
                padding: EdgeInsets.all(0.1),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _TrianglePainter extends CustomPainter {
  final Color color;
  _TrianglePainter(this.color);

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()..color = color;
    final path = Path()
      ..moveTo(size.width / 2, 0)
      ..lineTo(size.width, size.height)
      ..lineTo(0, size.height)
      ..close();
    canvas.drawPath(path, paint);
  }

  @override
  bool shouldRepaint(covariant _TrianglePainter oldDelegate) =>
      oldDelegate.color != color;
}

// =================== Карточки и элементы ===================

class InfoSectionCard extends StatelessWidget {
  final List<Widget> children;
  const InfoSectionCard({super.key, required this.children});

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Container(
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(20),
        gradient: LinearGradient(
          colors: [
            scheme.surfaceVariant.withOpacity(.35),
            scheme.surface.withOpacity(.6),
          ],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        border: Border.all(color: scheme.outlineVariant.withOpacity(.35)),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(.06),
            blurRadius: 18,
            offset: const Offset(0, 10),
          ),
        ],
      ),
      padding: const EdgeInsets.fromLTRB(10, 10, 10, 10),
      child: Column(
        children: _separated(children, const SizedBox(height: 8)),
      ),
    );
  }

  List<Widget> _separated(List<Widget> items, Widget separator) {
    if (items.isEmpty) return items;
    final out = <Widget>[];
    for (var i = 0; i < items.length; i++) {
      out.add(items[i]);
      if (i != items.length - 1) out.add(separator);
    }
    return out;
  }
}

class InfoRow extends StatelessWidget {
  final IconData icon;
  final String label;
  final String? value;
  final VoidCallback? onTap;

  const InfoRow({
    super.key,
    required this.icon,
    required this.label,
    required this.value,
    this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final val = (value ?? '').toString().trim();

    return Material(
      color: scheme.surface,
      borderRadius: BorderRadius.circular(16),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(16),
        child: Container(
          padding: const EdgeInsets.fromLTRB(12, 12, 12, 12),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: scheme.outlineVariant.withOpacity(.35)),
          ),
          child: Row(
            children: [
              Container(
                width: 36,
                height: 36,
                decoration: BoxDecoration(
                  color: scheme.primary.withOpacity(.10),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Icon(icon, size: 20, color: scheme.primary),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(label,
                        style: TextStyle(
                          color: scheme.onSurfaceVariant,
                          fontWeight: FontWeight.w600,
                          fontSize: 12.5,
                          letterSpacing: .2,
                        )),
                    const SizedBox(height: 4),
                    Text(
                      val.isEmpty ? '—' : val,
                      style: TextStyle(
                        color: scheme.onSurface,
                        fontWeight: FontWeight.w700,
                        fontSize: 15.5,
                      ),
                    ),
                  ],
                ),
              ),
              if (onTap != null) Icon(Icons.copy_rounded, color: scheme.outline),
            ],
          ),
        ),
      ),
    );
  }
}

class _SkeletonHeaderCard extends StatelessWidget {
  const _SkeletonHeaderCard();

  @override
  Widget build(BuildContext context) {
    return Container(
      height: 210,
      margin: const EdgeInsets.fromLTRB(4, 0, 4, 10),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(22),
        gradient: LinearGradient(
          colors: [Colors.purple.withOpacity(.5), Colors.pink.withOpacity(.4)],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
      ),
      child: const Center(
        child: CircleAvatar(radius: 46, backgroundColor: Colors.white24),
      ),
    );
  }
}

class _SkeletonSection extends StatelessWidget {
  const _SkeletonSection();

  @override
  Widget build(BuildContext context) {
    final base = Theme.of(context).colorScheme.onSurface.withOpacity(.08);
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 0, vertical: 6),
      child: Column(
        children: List.generate(3, (i) => _line(base)).expand((w) sync* {
          yield w;
          if (i != 2) yield const SizedBox(height: 8);
        }).toList(),
      ),
    );
  }

  static int i = 0;
  Widget _line(Color c) {
    i++;
    return Container(
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(16),
        color: c.withOpacity(.18),
      ),
      padding: const EdgeInsets.all(16),
      child: Row(
        children: [
          Container(
              width: 36,
              height: 36,
              decoration:
              BoxDecoration(color: c, borderRadius: BorderRadius.circular(10))),
          const SizedBox(width: 12),
          Expanded(
            child: Container(
              height: 14,
              decoration:
              BoxDecoration(color: c, borderRadius: BorderRadius.circular(6)),
            ),
          ),
        ],
      ),
    );
  }
}

class _ErrorCard extends StatelessWidget {
  final String text;
  const _ErrorCard({required this.text});

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Card(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
      color: scheme.errorContainer,
      child: Padding(
        padding: const EdgeInsets.fromLTRB(16, 14, 16, 14),
        child: Row(
          children: [
            Icon(Icons.error_outline_rounded, color: scheme.onErrorContainer),
            const SizedBox(width: 10),
            Expanded(
              child: Text(text, style: TextStyle(color: scheme.onErrorContainer)),
            ),
          ],
        ),
      ),
    );
  }
}

// =================== Модалки ===================

class _GlassSheet extends StatelessWidget {
  final Widget Function(void Function(VoidCallback fn) setState, ValueNotifier<bool> saving) childBuilder;
  final String title;
  final String avatarText;
  final Color accent;

  const _GlassSheet({
    required this.childBuilder,
    required this.title,
    required this.avatarText,
    required this.accent,
  });

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final saving = ValueNotifier(false);

    return StatefulBuilder(
      builder: (ctx, setLocal) {
        return Stack(
          children: [
            BackdropFilter(
              filter: ImageFilter.blur(sigmaX: 14, sigmaY: 14),
              child: Container(color: Colors.black.withOpacity(.2)),
            ),
            Align(
              alignment: Alignment.bottomCenter,
              child: Container(
                decoration: BoxDecoration(
                  color: scheme.surface,
                  borderRadius: const BorderRadius.vertical(top: Radius.circular(22)),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withOpacity(.25),
                      blurRadius: 24,
                      offset: const Offset(0, -6),
                    ),
                  ],
                ),
                child: SafeArea(
                  top: false,
                  child: Padding(
                    padding: const EdgeInsets.fromLTRB(16, 12, 16, 12),
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Container(
                          height: 4,
                          width: 42,
                          decoration: BoxDecoration(
                            color: scheme.outline.withOpacity(.5),
                            borderRadius: BorderRadius.circular(999),
                          ),
                        ),
                        const SizedBox(height: 12),
                        Row(
                          children: [
                            Container(
                              width: 44,
                              height: 44,
                              decoration: BoxDecoration(
                                shape: BoxShape.circle,
                                gradient: LinearGradient(
                                  colors: [accent.withOpacity(.9), Color.lerp(accent, AppColors.accent, .4)!],
                                ),
                                boxShadow: [
                                  BoxShadow(
                                    color: accent.withOpacity(.35),
                                    blurRadius: 18,
                                    offset: const Offset(0, 8),
                                  ),
                                ],
                              ),
                              child: Center(
                                child: Text(
                                  avatarText.isEmpty ? '👤' : avatarText,
                                  style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w900),
                                ),
                              ),
                            ),
                            const SizedBox(width: 12),
                            Expanded(
                              child: Text(
                                title,
                                style: Theme.of(context).textTheme.titleMedium?.copyWith(
                                  fontWeight: FontWeight.w900,
                                  letterSpacing: .2,
                                ),
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 14),
                        childBuilder(setLocal, saving),
                      ],
                    ),
                  ),
                ),
              ),
            ),
          ],
        );
      },
    );
  }
}

// =================== Универсальные поля ===================

class _FilledField extends StatelessWidget {
  final TextEditingController controller;
  final String label;
  final IconData icon;
  final TextInputAction textInputAction;
  final TextInputType? keyboardType;
  final List<TextInputFormatter>? inputFormatters;
  final String? errorText;
  final String? hintText;
  final String? helperText;

  const _FilledField({
    required this.controller,
    required this.label,
    required this.icon,
    required this.textInputAction,
    this.keyboardType,
    this.inputFormatters,
    this.errorText,
    this.hintText,
    this.helperText,
  });

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;

    return TextField(
      controller: controller,
      textInputAction: textInputAction,
      keyboardType: keyboardType,
      inputFormatters: inputFormatters,
      maxLines: 1,
      enableInteractiveSelection: true,
      decoration: InputDecoration(
        labelText: label,
        hintText: hintText,
        helperText: helperText,
        errorText: errorText,
        prefixIcon: Icon(icon, size: 18),
        isDense: true,
        contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
        filled: true,
        fillColor: scheme.surfaceVariant.withOpacity(.35),
        border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: BorderSide(color: scheme.outlineVariant.withOpacity(.35)),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: BorderSide(color: scheme.primary, width: 1.6),
        ),
      ),
      style: const TextStyle(fontSize: 14.5, fontWeight: FontWeight.w600),
    );
  }
}

class _FilledDropdown<T> extends StatelessWidget {
  final T? value;
  final String label;
  final IconData icon;
  final List<DropdownMenuItem<T>> items;
  final ValueChanged<T?> onChanged;

  const _FilledDropdown({
    required this.value,
    required this.label,
    required this.icon,
    required this.items,
    required this.onChanged,
  });

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;

    return DropdownButtonFormField<T>(
      value: value,
      items: items,
      onChanged: onChanged,
      decoration: InputDecoration(
        labelText: label,
        prefixIcon: Icon(icon, size: 18),
        isDense: true,
        filled: true,
        fillColor: scheme.surfaceVariant.withOpacity(.35),
        border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: BorderSide(color: scheme.outlineVariant.withOpacity(.4)),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: BorderSide(color: scheme.primary, width: 1.6),
        ),
      ),
    );
  }
}

class _StickyActionsBar extends StatelessWidget {
  final ValueNotifier<bool> savingNotifier;
  final VoidCallback onCancel;
  final Future<void> Function() onSave;

  const _StickyActionsBar({
    required this.savingNotifier,
    required this.onCancel,
    required this.onSave,
  });

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Container(
      padding: const EdgeInsets.fromLTRB(0, 8, 0, 0),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(14),
        color: scheme.surface,
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(.06),
            blurRadius: 16,
            offset: const Offset(0, -2),
          ),
        ],
      ),
      child: Row(
        children: [
          Expanded(
            child: OutlinedButton(
              onPressed: savingNotifier.value ? null : onCancel,
              style: OutlinedButton.styleFrom(
                padding: const EdgeInsets.symmetric(vertical: 12),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
              ),
              child: const Text('Отмена'),
            ),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: ValueListenableBuilder<bool>(
              valueListenable: savingNotifier,
              builder: (_, saving, __) {
                return FilledButton.icon(
                  onPressed: saving ? null : onSave,
                  style: FilledButton.styleFrom(
                    padding: const EdgeInsets.symmetric(vertical: 12),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                  ),
                  icon: saving
                      ? const SizedBox(width: 16, height: 16, child: CircularProgressIndicator(strokeWidth: 2))
                      : const Icon(Icons.save_rounded),
                  label: const Text('Сохранить'),
                );
              },
            ),
          ),
        ],
      ),
    );
  }
}

class _DecorRadioTile extends StatelessWidget {
  final String title;
  final DecorKind value;
  final ValueNotifier<DecorKind> group;
  final Widget? trailing;

  const _DecorRadioTile({
    required this.title,
    required this.value,
    required this.group,
    this.trailing,
  });

  @override
  Widget build(BuildContext context) {
    return ValueListenableBuilder<DecorKind>(
      valueListenable: group,
      builder: (_, selected, __) {
        return ListTile(
          contentPadding: const EdgeInsets.symmetric(horizontal: 4),
          title: Text(title, style: const TextStyle(fontWeight: FontWeight.w700)),
          leading: Radio<DecorKind>(
            value: value,
            groupValue: selected,
            onChanged: (v) => group.value = v ?? selected,
          ),
          trailing: trailing,
          onTap: () => group.value = value,
        );
      },
    );
  }
}

// =================== Поле пароля ===================

class _PasswordField extends StatefulWidget {
  final TextEditingController controller;
  final String label;
  final String? errorText;
  final String? helperText;

  const _PasswordField({
    required this.controller,
    required this.label,
    this.errorText,
    this.helperText,
  });

  @override
  State<_PasswordField> createState() => _PasswordFieldState();
}

class _PasswordFieldState extends State<_PasswordField> {
  bool _obscure = true;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return TextField(
      controller: widget.controller,
      obscureText: _obscure,
      textInputAction: TextInputAction.done,
      decoration: InputDecoration(
        labelText: widget.label,
        helperText: widget.helperText,
        errorText: widget.errorText,
        isDense: true,
        filled: true,
        fillColor: scheme.surfaceVariant.withOpacity(.35),
        border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: BorderSide(color: scheme.outlineVariant.withOpacity(.35)),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: BorderSide(color: scheme.primary, width: 1.6),
        ),
        suffixIcon: IconButton(
          onPressed: () => setState(() => _obscure = !_obscure),
          icon: Icon(_obscure ? Icons.visibility_rounded : Icons.visibility_off_rounded),
        ),
      ),
      maxLines: 1,
    );
  }
}
