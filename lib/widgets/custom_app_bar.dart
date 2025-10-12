import 'package:flutter/material.dart';
import '../constants.dart';

class CustomAppBar extends StatelessWidget implements PreferredSizeWidget {
  final String title;
  final List<Widget>? actions;
  final bool showBackButton;

  const CustomAppBar({
    super.key,
    required this.title,
    this.actions,
    this.showBackButton = true,
  });

  @override
  Size get preferredSize => const Size.fromHeight(kToolbarHeight + 10);

  // Небольшое ручное затемнение синего для градиента
  Color _darken(Color c, [double amount = .16]) {
    final hsl = HSLColor.fromColor(c);
    final h = hsl.hue;
    final s = hsl.saturation;
    final l = (hsl.lightness - amount).clamp(0.0, 1.0);
    return HSLColor.fromAHSL(hsl.alpha, h, s, l).toColor();
  }

  @override
  Widget build(BuildContext context) {
    // Текст/иконки всегда белые (мы это же зафиксировали в AppBarTheme)
    // Фон — всегда насыщенно-синий, как на главном
    final Color base = AppColors.primary;
    final Color baseDark = _darken(base, .18);

    return AppBar(
      title: AnimatedSwitcher(
        duration: const Duration(milliseconds: 200),
        child: Text(
          title,
          key: ValueKey<String>(title),
          style: const TextStyle(
            color: Colors.white,
            fontWeight: FontWeight.bold,
            fontSize: 20,
          ),
        ),
      ),
      centerTitle: true,
      elevation: 4,
      iconTheme: const IconThemeData(color: Colors.white),
      actions: actions,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(bottom: Radius.circular(16)),
      ),
      leading: showBackButton
          ? IconButton(
        icon: const Icon(Icons.arrow_back, size: 24, color: Colors.white),
        onPressed: () => Navigator.of(context).maybePop(),
      )
          : null,

      // ВСЕГДА рисуем красивый синий градиент, без оглядки на тему
      flexibleSpace: Container(
        decoration: BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: [base, baseDark],
          ),
          borderRadius: const BorderRadius.vertical(
            bottom: Radius.circular(16),
          ),
        ),
      ),
      backgroundColor: AppColors.primary, // дублируем для надёжности
      foregroundColor: Colors.white,
    );
  }
}
