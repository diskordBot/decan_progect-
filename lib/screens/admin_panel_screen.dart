// lib/admin/admin_panel_screen.dart
import 'package:flutter/material.dart';
import 'package:decanat_progect/admin/admin_schedule_editor.dart';
import 'package:decanat_progect/admin/admin_schedule_teacher_editor.dart';
import 'package:decanat_progect/constants.dart';

// 🔔 твои кастомные уведомления
import 'package:decanat_progect/ui/overlay_toast.dart';

class AdminPanelScreen extends StatelessWidget {
  const AdminPanelScreen({super.key});

  Future<void> _openStudentsEditor(BuildContext context) async {
    try {
      OverlayToast.instance.info(
        'Открываю редактор расписания…',
        position: ToastPosition.bottom,
      );
      await Navigator.push(
        context,
        MaterialPageRoute(builder: (_) => const AdminScheduleEditor()),
      );
      OverlayToast.instance.info(
        'Возврат из редактора расписания',
        position: ToastPosition.bottom,
        icon: Icons.check_circle_outline_rounded,
      );
    } catch (e) {
      OverlayToast.instance.error(
        'Не удалось открыть редактор: $e',
        position: ToastPosition.bottom,
      );
    }
  }

  Future<void> _openTeachersEditor(BuildContext context) async {
    try {
      OverlayToast.instance.info(
        'Открываю редактор преподавателей…',
        position: ToastPosition.bottom,
      );
      await Navigator.push(
        context,
        MaterialPageRoute(builder: (_) => const AdminScheduleTeacherEditor()),
      );
      OverlayToast.instance.info(
        'Возврат из редактора преподавателей',
        position: ToastPosition.bottom,
        icon: Icons.check_circle_outline_rounded,
      );
    } catch (e) {
      OverlayToast.instance.error(
        'Не удалось открыть экран: $e',
        position: ToastPosition.bottom,
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;

    return Scaffold(
      backgroundColor: scheme.background,
      appBar: AppBar(
        centerTitle: true,
        elevation: 0,
        title: Text(
          'Админ панель',
          style: TextStyle(
            color: scheme.onPrimary,
            fontWeight: FontWeight.bold,
          ),
        ),
        flexibleSpace: Container(
          decoration: BoxDecoration(
            gradient: LinearGradient(
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
              colors: [
                AppColors.primary,
                Color.lerp(AppColors.primary, scheme.secondary, .25)!,
              ],
            ),
          ),
        ),
        iconTheme: IconThemeData(color: scheme.onPrimary),
      ),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(20, 26, 20, 26),
        children: [
          // «герой»-карточка
          Container(
            padding: const EdgeInsets.all(18),
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(18),
              gradient: LinearGradient(
                colors: [
                  scheme.surface.withOpacity(.95),
                  scheme.surfaceVariant.withOpacity(.92),
                ],
              ),
              border: Border.all(color: scheme.outline.withOpacity(.12)),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withOpacity(.08),
                  blurRadius: 18,
                  offset: const Offset(0, 10),
                ),
              ],
            ),
            child: Row(
              children: [
                Container(
                  width: 54,
                  height: 54,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    gradient: LinearGradient(
                      colors: [
                        scheme.primary.withOpacity(.18),
                        scheme.primary.withOpacity(.06)
                      ],
                    ),
                  ),
                  child: Icon(Icons.admin_panel_settings,
                      color: scheme.primary, size: 28),
                ),
                const SizedBox(width: 14),
                Expanded(
                  child: Text(
                    'Быстрые действия администратора',
                    style: TextStyle(
                      fontSize: 16.5,
                      fontWeight: FontWeight.w800,
                      color: scheme.onSurface,
                    ),
                  ),
                ),
              ],
            ),
          ),

          const SizedBox(height: 18),

          // Кнопки-сетки
          _AdminBigButton(
            label: 'Управление расписанием',
            icon: Icons.schedule,
            colors: [
              AppColors.primary,
              Color.lerp(AppColors.primary, scheme.secondary, .2)!,
            ],
            onTap: () => _openStudentsEditor(context),
          ),
          _AdminBigButton(
            label: 'Расписание преподавателей',
            icon: Icons.person,
            colors: const [Color(0xFF7C4DFF), Color(0xFF536DFE)],
            onTap: () => _openTeachersEditor(context),
          ),
        ],
      ),
    );
  }
}

class _AdminBigButton extends StatelessWidget {
  final String label;
  final IconData icon;
  final List<Color> colors;
  final VoidCallback onTap;

  const _AdminBigButton({
    required this.label,
    required this.icon,
    required this.colors,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8),
      child: InkWell(
        borderRadius: BorderRadius.circular(16),
        onTap: onTap,
        child: Ink(
          height: 64,
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(16),
            gradient: LinearGradient(colors: colors),
            boxShadow: [
              BoxShadow(
                color: colors.last.withOpacity(.25),
                blurRadius: 18,
                offset: const Offset(0, 10),
              ),
            ],
          ),
          child: Row(
            children: [
              const SizedBox(width: 16),
              Container(
                width: 36,
                height: 36,
                decoration: BoxDecoration(
                  color: Colors.white.withOpacity(.18),
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: Colors.white.withOpacity(.25)),
                ),
                child: Icon(icon, color: Colors.white, size: 22),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Text(
                  label,
                  style: const TextStyle(
                    color: Colors.white,
                    fontWeight: FontWeight.w800,
                    letterSpacing: .2,
                  ),
                ),
              ),
              const Icon(Icons.chevron_right_rounded, color: Colors.white70),
              const SizedBox(width: 10),
            ],
          ),
        ),
      ),
    );
  }
}
