// lib/profile_drawer.dart
import 'dart:convert';
import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:flutter/services.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:decanat_progect/constants.dart';
import 'package:decanat_progect/utils/auth_hint_bus.dart';
import 'package:decanat_progect/student/student_auth_screen.dart';
import 'package:decanat_progect/teacher/teacher_auth_screen.dart';
import 'dart:async';



/// Красивая выдвижная панель профиля
class ProfileDrawer extends StatelessWidget {
  final String userRole;
  final String? userId;

  final String serverUrl;
  final Future<bool> Function() checkServerStatus;

  final VoidCallback? onOpenDeveloperTools;
  final VoidCallback? onOpenAdminPanel;
  final VoidCallback? onOpenStudentScheduleEditor;
  final VoidCallback? onOpenTeacherScheduleEditor;

  /// Колбэк, чтобы немедленно обновить HomeScreen (роль/ID)
  final void Function({required String role, required String? userId})? onUserDataChanged;

  final void Function(String message)? showSnackBar;

  const ProfileDrawer({
    super.key,
    required this.userRole,
    required this.userId,
    required this.serverUrl,
    required this.checkServerStatus,
    this.onOpenDeveloperTools,
    this.onOpenAdminPanel,
    this.onOpenStudentScheduleEditor,
    this.onOpenTeacherScheduleEditor,
    this.showSnackBar,
    this.onUserDataChanged,
  });

  // -------------------- helpers --------------------
  bool get _isAdminOrDeveloper => userRole == 'admin' || userRole == 'developer';
  bool get _isRegistered => userRole == 'student' || userRole == 'teacher';
  bool get _isDeveloper => userRole == 'developer';

  // -------------------- API --------------------
  Future<Map<String, dynamic>?> _fetchStudent(String uid) async {
    final uri = Uri.parse('$serverUrl/api/students/$uid');
    try {
      final resp = await http.get(uri).timeout(const Duration(seconds: 6));
      if (resp.statusCode == 200) {
        final data = json.decode(resp.body) as Map<String, dynamic>;
        return {
          'full_name': data['full_name'],
          'group_name': data['group_name'],
          'login': data['login'],
        };
      }
    } catch (_) {}
    return null;
  }

  Future<Map<String, dynamic>?> _fetchTeacher(String uid) async {
    try {
      final direct = Uri.parse('$serverUrl/api/teachers/$uid');
      final r1 = await http.get(direct).timeout(const Duration(seconds: 6));
      if (r1.statusCode == 200) {
        final d = json.decode(r1.body) as Map<String, dynamic>;
        return {
          'full_name': d['full_name'],
          'department': d['department'],
          'position': d['position'],
          'login': d['login'],
        };
      }
    } catch (_) {}

    try {
      final all = Uri.parse('$serverUrl/api/users');
      final r2 = await http.get(all).timeout(const Duration(seconds: 8));
      if (r2.statusCode == 200) {
        final list = json.decode(r2.body) as List<dynamic>;
        final match = list.cast<Map<String, dynamic>>().firstWhere(
              (u) => (u['user_id']?.toString() ?? '') == uid,
          orElse: () => {},
        );
        if (match.isNotEmpty) {
          return {
            'full_name': match['full_name'],
            'department': match['department'],
            'position': match['position'],
            'login': match['login'],
          };
        }
      }
    } catch (_) {}

    return null;
  }

  Future<Map<String, dynamic>?> _loadProfile() async {
    final uid = userId;
    if (uid == null || uid.isEmpty) return null;
    if (userRole == 'student') return _fetchStudent(uid);
    if (userRole == 'teacher') return _fetchTeacher(uid);
    return null;
  }

  // -------------------- Role helpers --------------------
  Color _roleColor() {
    switch (userRole) {
      case 'admin':
        return Colors.blue;
      case 'developer':
        return Colors.purple;
      case 'student':
        return Colors.orange;
      case 'teacher':
        return Colors.green;
      default:
        return Colors.grey;
    }
  }

  IconData _roleIcon(String role) {
    switch (role) {
      case 'admin':
        return Icons.admin_panel_settings_rounded;
      case 'developer':
        return Icons.developer_mode_rounded;
      case 'teacher':
        return Icons.co_present_rounded;
      case 'student':
        return Icons.school_rounded;
      default:
        return Icons.person_rounded;
    }
  }

  String _roleTitle(String role) {
    switch (role) {
      case 'admin':
        return 'Администратор';
      case 'developer':
        return 'Разработчик';
      case 'teacher':
        return 'Преподаватель';
      case 'student':
        return 'Студент';
      default:
        return 'Пользователь';
    }
  }

  List<Color> _headerGradient(BuildContext context) {
    final base = AppColors.primary;
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return isDark
        ? [base.withOpacity(.98), Color.lerp(base, Colors.indigo, .25)!.withOpacity(.85)]
        : [base, Color.lerp(base, Colors.blueAccent, .20)!.withOpacity(.9)];
  }

  String _initials(String? fullName) {
    if (fullName == null || fullName.trim().isEmpty) return '';
    final parts = fullName.trim().split(RegExp(r'\s+'));
    if (parts.isEmpty) return '';
    if (parts.length == 1) {
      return parts.first.characters.take(2).toString().toUpperCase();
    }
    return (parts.first.characters.take(1).toString() +
        parts.last.characters.take(1).toString())
        .toUpperCase();
  }

  // -------------------- ID actions --------------------
  Future<void> _copyId(BuildContext context) async {
    if (userId == null || userId!.isEmpty) return;
    await Clipboard.setData(ClipboardData(text: userId!));
    (showSnackBar != null)
        ? showSnackBar!("ID скопирован")
        : ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('ID скопирован')),
    );
  }

  /// Изменять ID может только разработчик (доп. защита в рантайме)
  Future<void> _editId(BuildContext context) async {
    if (!_isDeveloper) {
      (showSnackBar != null)
          ? showSnackBar!("Только разработчик может изменять ID")
          : ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Только разработчик может изменять ID')),
      );
      return;
    }

    final controller = TextEditingController(text: userId ?? '');
    String? errorText;

    await showDialog(
      context: context,
      builder: (_) {
        return StatefulBuilder(builder: (ctx, setSt) {
          return AlertDialog(
            title: const Text('Изменить ID пользователя'),
            content: TextField(
              controller: controller,
              keyboardType: TextInputType.number,
              inputFormatters: [
                FilteringTextInputFormatter.digitsOnly,
                LengthLimitingTextInputFormatter(6),
              ],
              decoration: InputDecoration(
                labelText: 'Введите ID (ровно 6 цифр)',
                hintText: 'Например: 000123',
                border: const OutlineInputBorder(),
                counterText: '',
                errorText: errorText,
              ),
              maxLength: 6,
              onChanged: (v) {
                setSt(() {
                  errorText =
                  RegExp(r'^\d{6}$').hasMatch(v) ? null : 'Должно быть ровно 6 цифр';
                });
              },
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(ctx),
                child: const Text('Отмена'),
              ),
              TextButton(
                onPressed: () async {
                  final newId = controller.text.trim();
                  final isValid = RegExp(r'^\d{6}$').hasMatch(newId);
                  if (!isValid) {
                    setSt(() => errorText = 'Должно быть ровно 6 цифр');
                    return;
                  }

                  final prefs = await SharedPreferences.getInstance();
                  await prefs.setString('userId', newId);

                  final role = await _fetchRoleById(newId) ?? 'user';
                  await prefs.setString('userRole', role);

                  onUserDataChanged?.call(role: role, userId: newId);

                  (showSnackBar != null)
                      ? showSnackBar!("ID сохранён")
                      : ScaffoldMessenger.of(ctx).showSnackBar(
                    const SnackBar(content: Text('ID сохранён')),
                  );
                  Navigator.pop(ctx);
                },
                child: const Text('Сохранить'),
              ),
            ],
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
          );
        });
      },
    );
  }

  Future<String?> _fetchRoleById(String id) async {
    try {
      final url = Uri.parse('$serverUrl/api/users/$id/role');
      final resp = await http.get(url).timeout(const Duration(seconds: 6));
      if (resp.statusCode == 200) {
        final data = json.decode(resp.body);
        if (data is Map && data['role'] is String) {
          return data['role'] as String;
        }
      }
    } catch (_) {}
    return null;
  }

  Future<void> _reloadUserData(BuildContext context) async {
    final prefs = await SharedPreferences.getInstance();
    final id = prefs.getString('userId') ?? userId;
    if (id == null || id.isEmpty) {
      (showSnackBar != null)
          ? showSnackBar!("ID не задан")
          : ScaffoldMessenger.of(context)
          .showSnackBar(const SnackBar(content: Text('ID не задан')));
      return;
    }
    final role = await _fetchRoleById(id) ?? 'user';
    await prefs.setString('userRole', role);
    onUserDataChanged?.call(role: role, userId: id);

    (showSnackBar != null)
        ? showSnackBar!("Данные обновлены")
        : ScaffoldMessenger.of(context)
        .showSnackBar(const SnackBar(content: Text('Данные обновлены')));
  }

  // -------------------- Logout (ID НЕ ТРОГАЕМ) --------------------
  Future<void> _logout(BuildContext context) async {
    final prefs = await SharedPreferences.getInstance();

    final currentId = prefs.getString('userId') ?? userId;
    if (currentId != null) {
      await prefs.setString('userId', currentId);
    }

    await prefs.setString('userRole', 'user');
    onUserDataChanged?.call(role: 'user', userId: currentId);

    (showSnackBar != null)
        ? showSnackBar!("Вы вышли из аккаунта")
        : ScaffoldMessenger.of(context)
        .showSnackBar(const SnackBar(content: Text('Вы вышли из аккаунта')));

    Navigator.of(context).maybePop();
  }

  // -------------------- Auth helpers --------------------
  Future<void> _openAuth(BuildContext context, {required bool isLogin}) async {
    final rootNavigator = Navigator.of(context, rootNavigator: true);

    final role = await showModalBottomSheet<String>(
      context: context,
      useRootNavigator: true,
      backgroundColor: Theme.of(context).colorScheme.surface,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(16)),
      ),
      builder: (ctx) {
        return SafeArea(
          child: Padding(
            padding: const EdgeInsets.fromLTRB(12, 8, 12, 16),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Container(
                  width: 44,
                  height: 4,
                  decoration: BoxDecoration(
                    color: Theme.of(context).colorScheme.outline.withOpacity(.4),
                    borderRadius: BorderRadius.circular(999),
                  ),
                ),
                const SizedBox(height: 12),
                Text(
                  isLogin ? 'Войти как…' : 'Зарегистрироваться как…',
                  style: TextStyle(
                    fontWeight: FontWeight.w800,
                    fontSize: 16,
                    color: Theme.of(context).colorScheme.onSurface,
                  ),
                ),
                const SizedBox(height: 12),
                _RoleChoiceTile(
                  icon: Icons.school_rounded,
                  label: 'Студент',
                  color: Colors.orange,
                  onTap: () => Navigator.pop(ctx, 'student'),
                ),
                const SizedBox(height: 10),
                _RoleChoiceTile(
                  icon: Icons.co_present_rounded,
                  label: 'Преподаватель',
                  color: Colors.green,
                  onTap: () => Navigator.pop(ctx, 'teacher'),
                ),
              ],
            ),
          ),
        );
      },
    );

    if (role == null) return;

    final bool? ok = await rootNavigator.push<bool>(
      MaterialPageRoute(
        builder: (_) =>
        role == 'student' ? StudentAuthScreen(isLogin: isLogin) : TeacherAuthScreen(isLogin: isLogin),
      ),
    );

    if (ok == true) {
      await _reloadUserData(rootNavigator.context);
    }
  }

  // -------------------- UI: Header --------------------
  Widget _buildHeader(BuildContext context) {
    final colors = _headerGradient(context);
    final rc = _roleColor();

    return TweenAnimationBuilder<double>(
      duration: const Duration(milliseconds: 700),
      curve: Curves.easeOutCubic,
      tween: Tween(begin: 0, end: 1),
      builder: (_, t, __) {
        return Container(
          decoration: BoxDecoration(
            gradient: LinearGradient(
              colors: [colors[0], Color.lerp(colors[0], colors[1], t)!],
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
            ),
          ),
          padding: const EdgeInsets.fromLTRB(16, 22, 16, 18),
          child: ClipRRect(
            borderRadius: BorderRadius.circular(20),
            child: BackdropFilter(
              filter: ImageFilter.blur(sigmaX: 6, sigmaY: 6),
              child: Container(
                decoration: BoxDecoration(
                  color: Colors.white.withOpacity(.04),
                  borderRadius: BorderRadius.circular(20),
                  border: Border.all(color: Colors.white.withOpacity(.12)),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withOpacity(.18),
                      blurRadius: 18,
                      offset: const Offset(0, 10),
                    ),
                  ],
                ),
                padding: const EdgeInsets.fromLTRB(16, 14, 16, 14),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Row(
                      children: [
                        _Avatar(roleIcon: _roleIcon(userRole)),
                        const SizedBox(width: 12),
                        Expanded(
                          child: Align(
                            alignment: Alignment.centerLeft,
                            child: FittedBox(
                              fit: BoxFit.scaleDown,
                              alignment: Alignment.centerLeft,
                              child: _BadgeChip(
                                label: _roleTitle(userRole),
                                icon: _roleIcon(userRole),
                                background: rc.withOpacity(.22),
                                border: rc.withOpacity(.35),
                                textColor: Colors.white,
                                iconColor: Colors.white,
                              ),
                            ),
                          ),
                        ),
                        const SizedBox(width: 8),
                        _RoundIconButton(
                          tooltip: 'Обновить данные',
                          icon: Icons.refresh_rounded,
                          onTap: () => _reloadUserData(context),
                        ),
                      ],
                    ),
                    const SizedBox(height: 12),
                    const _ThinDivider(),
                    const SizedBox(height: 10),

                    _IdRow(
                      text: (userId != null && userId!.isNotEmpty) ? 'ID: $userId' : 'ID не задан',
                      dotColor: rc,
                      onCopy: () => _copyId(context),
                      onEdit: () => _editId(context),
                      canEdit: _isDeveloper, // ← только разработчик увидит кнопку
                    ),
                    const SizedBox(height: 12),

                    FutureBuilder<bool>(
                      future: checkServerStatus(),
                      builder: (context, snap) {
                        final online = snap.data ?? false;
                        return Row(
                          children: [
                            Icon(
                              online ? Icons.wifi_rounded : Icons.wifi_off_rounded,
                              size: 16,
                              color: Colors.white,
                            ),
                            const SizedBox(width: 8),
                            Expanded(
                              child: Text(
                                online ? 'Сервер онлайн' : 'Сервер офлайн',
                                style: const TextStyle(
                                  color: Colors.white,
                                  fontSize: 13,
                                  height: 1.2,
                                ),
                                overflow: TextOverflow.ellipsis,
                              ),
                            ),
                          ],
                        );
                      },
                    ),
                  ],
                ),
              ),
            ),
          ),
        );
      },
    );
  }

  // -------------------- UI: Profile card --------------------
  Widget _buildProfileCard(BuildContext context, Map<String, dynamic> p) {
    final isStudent = userRole == 'student';
    final title = (p['full_name'] as String?)?.trim();
    final subtitle = isStudent
        ? 'Группа: ${p['group_name'] ?? '—'}'
        : [
      if ((p['department'] ?? '').toString().trim().isNotEmpty) 'Кафедра: ${p['department']}',
      if ((p['position'] ?? '').toString().trim().isNotEmpty) 'Должность: ${p['position']}',
    ].where((s) => s.trim().isNotEmpty).join(' • ');

    final initials = _initials(title);

    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 14, 16, 10),
      child: Container(
        decoration: BoxDecoration(
          gradient: LinearGradient(
            colors: [
              Theme.of(context).colorScheme.surface,
              Theme.of(context).colorScheme.surface.withOpacity(.92),
            ],
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
          ),
          borderRadius: BorderRadius.circular(18),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(.06),
              blurRadius: 14,
              offset: const Offset(0, 8),
            ),
          ],
          border: Border.all(
            color: Theme.of(context).colorScheme.outline.withOpacity(.10),
          ),
        ),
        child: Padding(
          padding: const EdgeInsets.fromLTRB(16, 16, 16, 16),
          child: Row(
            children: [
              Container(
                width: 58,
                height: 58,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  gradient: LinearGradient(
                    colors: [
                      Theme.of(context).colorScheme.primary.withOpacity(.16),
                      Theme.of(context).colorScheme.primary.withOpacity(.06),
                    ],
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                  ),
                ),
                child: Center(
                  child: Text(
                    initials.isEmpty ? '👤' : initials,
                    style: TextStyle(
                      fontWeight: FontWeight.w800,
                      fontSize: initials.isEmpty ? 22 : 16,
                      color: Theme.of(context).colorScheme.primary,
                    ),
                  ),
                ),
              ),
              const SizedBox(width: 14),
              Expanded(
                child: AnimatedSwitcher(
                  duration: const Duration(milliseconds: 250),
                  child: Column(
                    key: ValueKey(title ?? ''),
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      if (title != null && title.isNotEmpty)
                        Text(
                          title,
                          style: TextStyle(
                            fontSize: 16.5,
                            color: Theme.of(context).colorScheme.onSurface,
                            fontWeight: FontWeight.w800,
                            letterSpacing: -.2,
                          ),
                        ),
                      if (subtitle.isNotEmpty) ...[
                        const SizedBox(height: 5),
                        Text(
                          subtitle,
                          style: TextStyle(
                            fontSize: 13.2,
                            color: Theme.of(context).colorScheme.onSurfaceVariant,
                          ),
                        ),
                      ],
                      if ((p['login'] ?? '').toString().isNotEmpty) ...[
                        const SizedBox(height: 8),
                        _InfoRow(
                          icon: Icons.alternate_email_rounded,
                          text: 'Логин: ${p['login']}',
                        ),
                      ],
                    ],
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildRoleProfileSection(BuildContext context) {
    if (userRole != 'student' && userRole != 'teacher') {
      return const SizedBox(height: 10);
    }
    return FutureBuilder<Map<String, dynamic>?>(
      future: _loadProfile(),
      builder: (context, snap) {
        if (snap.connectionState == ConnectionState.waiting) {
          return const Padding(
            padding: EdgeInsets.fromLTRB(16, 14, 16, 0),
            child: _SkeletonCard(),
          );
        }
        final data = snap.data;
        if (data == null) {
          return Padding(
            padding: const EdgeInsets.fromLTRB(16, 14, 16, 0),
            child: _EmptyState(
              text: 'Не удалось загрузить профиль',
              icon: Icons.error_outline_rounded,
            ),
          );
        }
        return _buildProfileCard(context, data);
      },
    );
  }

  // -------------------- Build --------------------
  @override
  Widget build(BuildContext context) {
    final divider = Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
      child: _GradientDivider(
        color: Theme.of(context).colorScheme.outline.withOpacity(.22),
      ),
    );

    final isGuest = userRole == 'user';

    return Drawer(
      backgroundColor: Theme.of(context).colorScheme.surface,
      child: SafeArea(
        child: Column(
          children: [
            _buildHeader(context),
            _buildRoleProfileSection(context),

            Expanded(
              child: ListTileTheme(
                iconColor: Theme.of(context).colorScheme.onSurfaceVariant,
                textColor: Theme.of(context).colorScheme.onSurface,
                child: ListView(
                  padding: const EdgeInsets.symmetric(vertical: 6),
                  children: [
                    if (isGuest) ...[
                      const _SectionLabel(text: 'Авторизация'),
                      ValueListenableBuilder<double>(
                        valueListenable: AuthHintBus.instance.intensity,
                        builder: (context, k, _) => _HintGlow(
                          intensity: k,
                          child: _ActionTile(
                            leadingIcon: Icons.app_registration_rounded,
                            title: 'Зарегистрироваться',
                            onTap: () async {
                              final rootCtx =
                                  Navigator.of(context, rootNavigator: true).context;
                              Navigator.of(context).pop();
                              await Future.microtask(() {});
                              await _openAuth(rootCtx, isLogin: false);
                            },
                          ),
                        ),
                      ),
                      const SizedBox(height: 6),
                      ValueListenableBuilder<double>(
                        valueListenable: AuthHintBus.instance.intensity,
                        builder: (context, k, _) => _HintGlow(
                          intensity: k,
                          child: _ActionTile(
                            leadingIcon: Icons.login_rounded,
                            title: 'Войти',
                            onTap: () async {
                              final rootCtx =
                                  Navigator.of(context, rootNavigator: true).context;
                              Navigator.of(context).pop();
                              await Future.microtask(() {});
                              await _openAuth(rootCtx, isLogin: true);
                            },
                          ),
                        ),
                      ),
                    ],

                    if (!isGuest) ...[
                      const _SectionLabel(text: 'Профиль'),
                      _ActionTile(
                        leadingIcon: Icons.person_outline_rounded,
                        title: 'Открыть профиль (бета)',
                        onTap: () => Navigator.pop(context),
                      ),
                    ],

                    if (_isAdminOrDeveloper) divider,
                    if (_isAdminOrDeveloper) const _SectionLabel(text: 'Расписание'),
                    if (_isAdminOrDeveloper)
                      _ActionTile(
                        leadingIcon: Icons.schedule_rounded,
                        title: 'Ред. расписание студентов',
                        onTap: () {
                          Navigator.pop(context);
                          onOpenStudentScheduleEditor?.call();
                        },
                      ),
                    if (_isAdminOrDeveloper)
                      _ActionTile(
                        leadingIcon: Icons.co_present_rounded,
                        title: 'Ред. расписание преподавателей',
                        onTap: () {
                          Navigator.pop(context);
                          onOpenTeacherScheduleEditor?.call();
                        },
                      ),

                    if (_isAdminOrDeveloper) divider,
                    if (_isAdminOrDeveloper)
                      _ActionTile(
                        leadingIcon: _isDeveloper
                            ? Icons.developer_mode_rounded
                            : Icons.admin_panel_settings_rounded,
                        title:
                        _isDeveloper ? 'Инструменты разработчика' : 'Панель администратора',
                        onTap: () {
                          Navigator.pop(context);
                          if (_isDeveloper) {
                            onOpenDeveloperTools?.call();
                          } else {
                            onOpenAdminPanel?.call();
                          }
                        },
                      ),
                  ],
                ),
              ),
            ),

            if (_isRegistered)
              InkWell(
                onTap: () => _logout(context),
                borderRadius: BorderRadius.circular(16),
                child: Container(
                  margin: const EdgeInsets.fromLTRB(16, 0, 16, 16),
                  padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      colors: [
                        Theme.of(context).colorScheme.surface,
                        Theme.of(context).colorScheme.surface.withOpacity(.96),
                      ],
                      begin: Alignment.topLeft,
                      end: Alignment.bottomRight,
                    ),
                    borderRadius: BorderRadius.circular(16),
                    border: Border.all(
                      color: Theme.of(context).colorScheme.outline.withOpacity(.10),
                    ),
                    boxShadow: [
                      BoxShadow(
                        color: Colors.black.withOpacity(.06),
                        blurRadius: 12,
                        offset: const Offset(0, 8),
                      ),
                    ],
                  ),
                  child: Row(
                    children: [
                      Icon(Icons.logout_rounded,
                          color: Theme.of(context).colorScheme.error),
                      const SizedBox(width: 10),
                      Text(
                        'Выйти',
                        style: TextStyle(
                          color: Theme.of(context).colorScheme.error,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                      const Spacer(),
                      Icon(Icons.arrow_forward_rounded,
                          color: Theme.of(context).colorScheme.error),
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

// -------------------- Header widgets --------------------
class _Avatar extends StatelessWidget {
  final IconData roleIcon;
  const _Avatar({required this.roleIcon});

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 56,
      height: 56,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        gradient: LinearGradient(
          colors: [Colors.white.withOpacity(.22), Colors.white.withOpacity(.10)],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        border: Border.all(color: Colors.white.withOpacity(.25)),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(.18),
            blurRadius: 14,
            offset: const Offset(0, 8),
          ),
        ],
      ),
      child: Icon(roleIcon, color: Colors.white, size: 30),
    );
  }
}

class _RoundIconButton extends StatelessWidget {
  final IconData icon;
  final String? tooltip;
  final VoidCallback onTap;

  const _RoundIconButton({
    required this.icon,
    required this.onTap,
    this.tooltip,
  });

  @override
  Widget build(BuildContext context) {
    return Tooltip(
      message: tooltip ?? '',
      child: Material(
        color: Colors.white.withOpacity(.12),
        shape: const CircleBorder(),
        child: InkWell(
          customBorder: const CircleBorder(),
          onTap: onTap,
          child: SizedBox(
            width: 38,
            height: 38,
            child: Icon(icon, color: Colors.white, size: 20),
          ),
        ),
      ),
    );
  }
}

class _IdRow extends StatelessWidget {
  final String text;
  final Color dotColor;
  final VoidCallback onCopy;
  final VoidCallback onEdit;
  final bool canEdit;

  const _IdRow({
    required this.text,
    required this.dotColor,
    required this.onCopy,
    required this.onEdit,
    this.canEdit = false,
  });

  @override
  Widget build(BuildContext context) {
    const double fontSize = 13.0;

    return Row(
      crossAxisAlignment: CrossAxisAlignment.center,
      children: [
        Text.rich(
          TextSpan(
            children: [
              WidgetSpan(
                baseline: TextBaseline.alphabetic,
                alignment: PlaceholderAlignment.baseline,
                child: Container(
                  width: 8,
                  height: 8,
                  decoration: BoxDecoration(color: dotColor, shape: BoxShape.circle),
                ),
              ),
              const WidgetSpan(
                baseline: TextBaseline.alphabetic,
                alignment: PlaceholderAlignment.baseline,
                child: SizedBox(width: 8),
              ),
              const WidgetSpan(
                baseline: TextBaseline.alphabetic,
                alignment: PlaceholderAlignment.baseline,
                child: Icon(Icons.badge_rounded, size: 14, color: Colors.white70),
              ),
              const WidgetSpan(
                baseline: TextBaseline.alphabetic,
                alignment: PlaceholderAlignment.baseline,
                child: SizedBox(width: 6),
              ),
              TextSpan(
                text: text,
                style: const TextStyle(
                  color: Colors.white70,
                  fontSize: fontSize,
                  height: 1.2,
                ),
              ),
            ],
          ),
        ),
        const Spacer(),
        _CircleIconSmall(
          icon: Icons.copy_rounded,
          tooltip: 'Копировать ID',
          onTap: onCopy,
        ),
        const SizedBox(width: 8),
        if (canEdit)
          _CircleIconSmall(
            icon: Icons.edit_rounded,
            tooltip: 'Изменить ID',
            onTap: onEdit,
          ),
      ],
    );
  }
}

class _CircleIconSmall extends StatelessWidget {
  final IconData icon;
  final String? tooltip;
  final VoidCallback onTap;

  const _CircleIconSmall({
    required this.icon,
    required this.onTap,
    this.tooltip,
  });

  @override
  Widget build(BuildContext context) {
    return Tooltip(
      message: tooltip ?? '',
      child: Material(
        color: Colors.white.withOpacity(.12),
        shape: const CircleBorder(),
        child: InkWell(
          customBorder: const CircleBorder(),
          onTap: onTap,
          child: SizedBox(
            width: 34,
            height: 34,
            child: Icon(icon, size: 18, color: Colors.white),
          ),
        ),
      ),
    );
  }
}

class _ThinDivider extends StatelessWidget {
  const _ThinDivider();

  @override
  Widget build(BuildContext context) {
    return Container(
      height: 1,
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [
            Colors.white.withOpacity(0.00),
            Colors.white.withOpacity(0.20),
            Colors.white.withOpacity(0.00),
          ],
          begin: Alignment.centerLeft,
          end: Alignment.centerRight,
        ),
      ),
    );
  }
}

// -------------------- Bottom sheet role tile --------------------
class _RoleChoiceTile extends StatelessWidget {
  final IconData icon;
  final String label;
  final Color color;
  final VoidCallback onTap;

  const _RoleChoiceTile({
    required this.icon,
    required this.label,
    required this.color,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final bg = color.withOpacity(.12);
    final border = color;
    return Material(
      color: Colors.transparent,
      borderRadius: BorderRadius.circular(12),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(12),
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
          decoration: BoxDecoration(
            color: bg,
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: border, width: 1),
          ),
          child: Row(
            children: [
              Icon(icon, size: 22, color: color),
              const SizedBox(width: 10),
              Expanded(
                child: Text(
                  label,
                  style: TextStyle(
                    fontWeight: FontWeight.w700,
                    fontSize: 14.5,
                    color: Theme.of(context).colorScheme.onSurface,
                  ),
                ),
              ),
              Icon(Icons.chevron_right_rounded, color: color),
            ],
          ),
        ),
      ),
    );
  }
}

// -------------------- Small UI widgets --------------------
class _InfoRow extends StatelessWidget {
  final IconData icon;
  final String text;
  const _InfoRow({required this.icon, required this.text});

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Icon(icon, size: 16, color: Theme.of(context).colorScheme.onSurfaceVariant),
        const SizedBox(width: 8),
        Expanded(
          child: Text(
            text,
            style: TextStyle(
              fontSize: 12.5,
              color: Theme.of(context).colorScheme.onSurfaceVariant,
            ),
          ),
        ),
      ],
    );
  }
}

class _SectionLabel extends StatelessWidget {
  final String text;
  const _SectionLabel({required this.text});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(18, 8, 16, 6),
      child: Text(
        text,
        style: TextStyle(
          fontSize: 12.5,
          letterSpacing: .2,
          color: Theme.of(context).colorScheme.onSurfaceVariant,
          fontWeight: FontWeight.w700,
        ),
      ),
    );
  }
}

class _BadgeChip extends StatelessWidget {
  final String label;
  final IconData icon;
  final Color background;
  final Color border;
  final Color textColor;
  final Color iconColor;

  const _BadgeChip({
    required this.label,
    required this.icon,
    required this.background,
    required this.border,
    required this.textColor,
    required this.iconColor,
  });

  @override
  Widget build(BuildContext context) {
    return ClipRRect(
      borderRadius: BorderRadius.circular(999),
      child: BackdropFilter(
        filter: ImageFilter.blur(sigmaX: 6, sigmaY: 6),
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
          decoration: BoxDecoration(
            color: background,
            borderRadius: BorderRadius.circular(999),
            border: Border.all(color: border),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(icon, size: 14, color: iconColor),
              const SizedBox(width: 6),
              Text(
                label,
                maxLines: 1,
                softWrap: false,
                overflow: TextOverflow.visible,
                style: TextStyle(
                  color: textColor,
                  fontWeight: FontWeight.w800,
                  letterSpacing: .2,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _SkeletonCard extends StatelessWidget {
  const _SkeletonCard();

  @override
  Widget build(BuildContext context) {
    final base = Theme.of(context).colorScheme.onSurface.withOpacity(.08);
    return Container(
      height: 84,
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.surface,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(
          color: Theme.of(context).colorScheme.outline.withOpacity(.10),
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(.05),
            blurRadius: 12,
            offset: const Offset(0, 8),
          ),
        ],
      ),
      child: Row(
        children: [
          const SizedBox(width: 16),
          Container(
            width: 58,
            height: 58,
            decoration: BoxDecoration(
              color: base,
              shape: BoxShape.circle,
            ),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Padding(
              padding: const EdgeInsets.only(right: 14),
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  _skeletonLine(base, 150, 14),
                  const SizedBox(height: 10),
                  _skeletonLine(base, 200, 12),
                  const SizedBox(height: 8),
                  _skeletonLine(base, 120, 10),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _skeletonLine(Color base, double width, double height) {
    return ClipRRect(
      borderRadius: BorderRadius.circular(6),
      child: Container(
        width: width,
        height: height,
        decoration: BoxDecoration(
          gradient: LinearGradient(
            colors: [base, base.withOpacity(.6), base],
            begin: Alignment.centerLeft,
            end: Alignment.centerRight,
          ),
        ),
      ),
    );
  }
}

class _EmptyState extends StatelessWidget {
  final String text;
  final IconData icon;
  const _EmptyState({required this.text, required this.icon});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.fromLTRB(16, 16, 16, 16),
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.surface,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: Theme.of(context).colorScheme.outline.withOpacity(.10),
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(.05),
            blurRadius: 10,
            offset: const Offset(0, 8),
          ),
        ],
      ),
      child: Row(
        children: [
          Icon(icon, color: Theme.of(context).colorScheme.onSurfaceVariant, size: 20),
          const SizedBox(width: 12),
          Expanded(
            child: Text(
              text,
              style: TextStyle(
                color: Theme.of(context).colorScheme.onSurfaceVariant,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _GradientDivider extends StatelessWidget {
  final Color color;
  const _GradientDivider({required this.color});

  @override
  Widget build(BuildContext context) {
    return Container(
      height: .9,
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [Colors.transparent, color, Colors.transparent],
          begin: Alignment.centerLeft,
          end: Alignment.centerRight,
        ),
      ),
    );
  }
}

class _ActionTile extends StatelessWidget {
  final IconData leadingIcon;
  final String title;
  final VoidCallback onTap;

  const _ActionTile({
    required this.leadingIcon,
    required this.title,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final bg = Theme.of(context).colorScheme.surface;
    final outline = Theme.of(context).colorScheme.outline.withOpacity(.08);

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(14),
        child: Ink(
          decoration: BoxDecoration(
            color: bg,
            borderRadius: BorderRadius.circular(14),
            border: Border.all(color: outline),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withOpacity(.04),
                blurRadius: 10,
                offset: const Offset(0, 6),
              ),
            ],
          ),
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 10),
            child: Row(
              children: [
                Container(
                  width: 38,
                  height: 38,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    color: Theme.of(context).colorScheme.primary.withOpacity(.10),
                  ),
                  child: Icon(
                    leadingIcon,
                    size: 20,
                    color: Theme.of(context).colorScheme.primary,
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Text(
                    title,
                    style: TextStyle(
                      fontSize: 14.5,
                      fontWeight: FontWeight.w600,
                      color: Theme.of(context).colorScheme.onSurface,
                      letterSpacing: .1,
                    ),
                  ),
                ),
                Icon(Icons.chevron_right_rounded,
                    color: Theme.of(context).colorScheme.onSurfaceVariant),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

/// Плавная подсветка/мигание на основе интенсивности [0..1].
/// Добавляет мягкую тень и небольшое повышение непрозрачности.
class _HintGlow extends StatelessWidget {
  final double intensity; // 0..1
  final Widget child;
  const _HintGlow({required this.intensity, required this.child});

  @override
  Widget build(BuildContext context) {
    final blur = 8.0 + 18.0 * intensity;
    final spread = 1.0 + 2.0 * intensity;
    final shadowOpacity = 0.45 * intensity;

    return AnimatedOpacity(
      opacity: 0.85 + 0.15 * intensity,
      duration: const Duration(milliseconds: 80),
      child: Container(
        decoration: intensity > 0
            ? BoxDecoration(
          boxShadow: [
            BoxShadow(
              color: Theme.of(context)
                  .colorScheme
                  .primary
                  .withOpacity(shadowOpacity),
              blurRadius: blur,
              spreadRadius: spread,
            ),
          ],
        )
            : null,
        child: child,
      ),
    );
  }
}