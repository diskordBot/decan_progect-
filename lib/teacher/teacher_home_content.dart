import 'dart:async';

import 'package:decanat_progect/teacher/teacher_schedule_screen.dart';
import 'package:flutter/material.dart';
import 'package:decanat_progect/widgets/bubble_button.dart';
import 'package:decanat_progect/screens/department_detail_screen.dart';
import 'package:flutter/services.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../screens/attendance_journal_screen.dart';
import '../ui/overlay_toast.dart';
import 'package:decanat_progect/teacher/student_info_screen.dart';


class TeacherHomeContent extends StatefulWidget {
  final String userRole;
  final String? userId;
  final VoidCallback onRoleChanged;

  const TeacherHomeContent({
    super.key,
    required this.userRole,
    this.userId,
    required this.onRoleChanged,
  });

  @override
  State<TeacherHomeContent> createState() => _TeacherHomeContentState();
}

class _TeacherHomeContentState extends State<TeacherHomeContent>
    with SingleTickerProviderStateMixin {
  String _currentUserRole = 'user';

  // --- Для красивого верхнего тоста
  OverlayEntry? _topToast;
  Timer? _toastTimer;
  late final AnimationController _toastController;

  @override
  void initState() {
    super.initState();
    _loadUserRole();
    _toastController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 240),
      reverseDuration: const Duration(milliseconds: 180),
    );
  }

  @override
  void dispose() {
    _toastTimer?.cancel();
    _removeTopToast(immediate: true);
    _toastController.dispose();
    super.dispose();
  }

  Future<void> _loadUserRole() async {
    final prefs = await SharedPreferences.getInstance();
    if (!mounted) return;
    setState(() {
      _currentUserRole = prefs.getString('userRole') ?? 'user';
    });
  }

  // =================== ТОП-ТОСТ (компактный, не на всю ширину) ===================

  void _removeTopToast({bool immediate = false}) {
    _toastTimer?.cancel();
    _toastTimer = null;

    if (_topToast == null) return;

    if (!immediate && _toastController.status != AnimationStatus.dismissed) {
      _toastController.reverse();
      Future.delayed(
        _toastController.reverseDuration ?? const Duration(milliseconds: 180),
            () {
          _topToast?.remove();
          _topToast = null;
        },
      );
    } else {
      _topToast?.remove();
      _topToast = null;
    }
  }

  void _showTopToast(String message) {
    // Закрываем предыдущий, если был
    _removeTopToast(immediate: true);

    final overlay = Overlay.of(context);
    if (overlay == null) return;

    final entry = OverlayEntry(
      builder: (context) {
        // Анимации
        final fadeIn = CurvedAnimation(
          parent: _toastController,
          curve: Curves.easeOut,
        );
        final slide = Tween<Offset>(
          begin: const Offset(0, -0.25),
          end: Offset.zero,
        ).animate(
          CurvedAnimation(parent: _toastController, curve: Curves.easeOutCubic),
        );
        final scale = Tween<double>(begin: 0.98, end: 1.0).animate(
          CurvedAnimation(parent: _toastController, curve: Curves.easeOutBack),
        );

        final isDark = Theme.of(context).brightness == Brightness.dark;
        final baseBg = isDark ? const Color(0xFF1E1F25) : Colors.white;
        final onSurface = Theme.of(context).colorScheme.onSurface;

        // Размеры и позиционирование
        final topInset = MediaQuery.of(context).padding.top + 12;
        const double maxWidth = 360;

        // Градиентная рамка
        final gradient = LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [
            Theme.of(context).colorScheme.secondary,
            Theme.of(context).colorScheme.secondary.withOpacity(0.55),
          ],
        );

        return Positioned(
          top: topInset,
          left: 16,
          right: 16,
          child: Center(
            child: FadeTransition(
              opacity: fadeIn,
              child: SlideTransition(
                position: slide,
                child: ScaleTransition(
                  scale: scale,
                  child: Container(
                    constraints: const BoxConstraints(maxWidth: maxWidth),
                    decoration: BoxDecoration(
                      borderRadius: BorderRadius.circular(18),
                      gradient: gradient, // внешняя "подсветка" рамки
                      boxShadow: [
                        BoxShadow(
                          color: Colors.black.withOpacity(0.25),
                          blurRadius: 24,
                          offset: const Offset(0, 12),
                        ),
                        BoxShadow(
                          color: Colors.black.withOpacity(0.12),
                          blurRadius: 8,
                          offset: const Offset(0, 2),
                        ),
                      ],
                    ),
                    padding: const EdgeInsets.all(2), // толщина рамки
                    child: Material(
                      color: baseBg,
                      elevation: 0,
                      borderRadius: BorderRadius.circular(16),
                      child: Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 14,
                          vertical: 12,
                        ),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            // Небольшой “медальон”
                            Container(
                              width: 36,
                              height: 36,
                              decoration: BoxDecoration(
                                shape: BoxShape.circle,
                                color: Theme.of(context)
                                    .colorScheme
                                    .primary
                                    .withOpacity(0.12),
                              ),
                              child: Icon(
                                Icons.info_outline_rounded,
                                color: Theme.of(context).colorScheme.primary,
                              ),
                            ),
                            const SizedBox(width: 12),
                            // Текст
                            Flexible(
                              child: Text(
                                message,
                                textAlign: TextAlign.left,
                                style: TextStyle(
                                  fontSize: 15,
                                  height: 1.25,
                                  fontWeight: FontWeight.w600,
                                  color: onSurface,
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
            ),
          ),
        );
      },
    );

    _topToast = entry;
    overlay.insert(entry);
    _toastController.forward(from: 0);

    _toastTimer = Timer(const Duration(seconds: 2), () async {
      await _toastController.reverse();
      _topToast?.remove();
      _topToast = null;
    });
  }

  // =================== КОНТЕНТ ===================

  Widget _buildTeacherContent() {
    return GridView.count(
      crossAxisCount: 2,
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      crossAxisSpacing: 16,
      mainAxisSpacing: 16,
      childAspectRatio: 1.0,
      children: [
        BubbleButton(
          title: 'Расписание',
          icon: Icons.backup_table,
          primaryColor: Colors.blue[700]!,
          onTap: () => Navigator.push(
            context,
            MaterialPageRoute(
              builder: (context) => const TeacherScheduleScreen(),
            ),
          ),
        ),
        BubbleButton(
          title: 'Факультет',
          icon: Icons.account_balance,
          primaryColor: Colors.green[700]!,
          onTap: () => Navigator.pushNamed(context, '/faculty'),
        ),
        BubbleButton(
          title: 'Кафедра',
          icon: Icons.people,
          primaryColor: Colors.orange[700]!,
          onTap: () => Navigator.push(
            context,
            MaterialPageRoute(
              builder: (context) => const DepartmentDetailScreen(),
            ),
          ),
        ),
        // Новая кнопка — Информация о студентах
        BubbleButton(
          title: 'Информация\nо студентах',
          icon: Icons.info_outline_rounded,
          primaryColor: Colors.purple[700]!,
          onTap: () {
            Navigator.push(
              context,
              MaterialPageRoute(
                builder: (context) => const StudentInfoScreen(), // новый экран ниже
              ),
            );
          },

        ),
        // в TeacherHomeContent, в BubbleButton "Журнал":
        BubbleButton(
          title: 'Журнал',
          icon: Icons.book_outlined,
          primaryColor: Colors.deepOrangeAccent,
          onTap: () async {
            // при нажатии показываем кастомный тост с пользовательским стилем
            final prefs = await SharedPreferences.getInstance();
            final emoji = prefs.getString('header_decor_emoji') ?? '🚧';
            final msg = '$emoji  Раздел в разработке';

            // можно немного "живости"
            HapticFeedback.mediumImpact();

            // используем активный стиль тостов — OverlayToast сам знает, какой сейчас выбран
            OverlayToast.instance.info(
              msg,
              icon: Icons.construction_rounded,
              position: ToastPosition.top,
            );
          },
        ),


      ],
    );
  }

  @override
  Widget build(BuildContext context) {
    if (_currentUserRole == 'teacher' ||
        _currentUserRole == 'admin' ||
        _currentUserRole == 'developer') {
      return _buildTeacherContent();
    }
    // дефолт:
    return const SizedBox.shrink(); // или _buildStudentContent() / _buildAuthButtons()
  }
}
