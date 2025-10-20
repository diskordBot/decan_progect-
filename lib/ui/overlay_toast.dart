// lib/ui/overlay_toast.dart
import 'dart:async';
import 'dart:ui' as ui;
import 'package:flutter/material.dart';
import 'package:flutter/scheduler.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:decanat_progect/constants.dart';

/// 3 стиля уведомлений
enum ToastStyle { redFrame, glass, minimal }

/// Где показывать тост
enum ToastPosition { top, bottom }

/// Глобальный сервис верхних уведомлений
class OverlayToast {
  OverlayToast._();
  static final OverlayToast instance = OverlayToast._();

  /// navigatorKey вашего MaterialApp (передаётся в init)
  late GlobalKey<NavigatorState> _navKey;

  /// Текущий стиль (подтягивается/сохраняется в SharedPreferences)
  ToastStyle _style = ToastStyle.redFrame;

  /// Активный оверлей и таймер
  OverlayEntry? _entry;
  Timer? _timer;

  /// Контроллер анимации
  late AnimationController _controller;

  bool _initialized = false;

  /// Инициализация — вызовите один раз при старте (например, в main)
  Future<void> init({
    required GlobalKey<NavigatorState> navigatorKey,
    TickerProvider? tickerProviderForPreview, // опционально: ускоряет первый показ
  }) async {
    if (_initialized) return;
    _navKey = navigatorKey;

    // Подтянуть сохранённый стиль
    final prefs = await SharedPreferences.getInstance();
    final savedIndex = prefs.getInt('toast_style');
    if (savedIndex != null &&
        savedIndex >= 0 &&
        savedIndex < ToastStyle.values.length) {
      _style = ToastStyle.values[savedIndex];
    }

    _controller = AnimationController(
      vsync: tickerProviderForPreview ?? _DummyTickerProvider(),
      duration: const Duration(milliseconds: 240),
      reverseDuration: const Duration(milliseconds: 180),
    );

    _initialized = true;
  }

  /// Программно сменить стиль и сохранить в SharedPreferences
  Future<void> setStyle(ToastStyle style) async {
    _style = style;
    final prefs = await SharedPreferences.getInstance();
    await prefs.setInt('toast_style', style.index);
  }

  ToastStyle get style => _style;

  /// Универсальный показ уведомления
  void show(
      String message, {
        IconData icon = Icons.info_outline_rounded,
        Color? accent,
        Duration duration = const Duration(seconds: 2),
        ToastPosition position = ToastPosition.top,
      }) {
    if (!_initialized || _navKey.currentState == null) return;

    // Закрыть предыдущий
    _timer?.cancel();
    _timer = null;
    _entry?.remove();
    _entry = null;

    final overlay = _navKey.currentState!.overlay;
    if (overlay == null) return;

    final entry = OverlayEntry(
      builder: (context) {
        // Анимации
        final fadeIn = CurvedAnimation(parent: _controller, curve: Curves.easeOut);
        final slide = Tween<Offset>(
          begin: position == ToastPosition.top
              ? const Offset(0, -0.25)
              : const Offset(0, 0.25),
          end: Offset.zero,
        ).animate(
          CurvedAnimation(parent: _controller, curve: Curves.easeOutCubic),
        );
        final scale = Tween<double>(begin: 0.98, end: 1.0).animate(
          CurvedAnimation(parent: _controller, curve: Curves.easeOutBack),
        );

        // Тема/цвета
        final theme = Theme.of(context);
        final scheme = theme.colorScheme;
        final isDark = theme.brightness == Brightness.dark;
        final baseBg = isDark ? const Color(0xFF1E1F25) : Colors.white;
        final onSurface = scheme.onSurface;

        // Позиции
        final padding = MediaQuery.of(context).padding;
        final topPos = padding.top + 12;
        final bottomPos = padding.bottom + 16;

        // Общий стиль текста
        const textStyle = TextStyle(
          fontSize: 15.5,
          height: 1.28,
          fontWeight: FontWeight.w600,
          decoration: TextDecoration.none,
        );

        // Содержимое по стилям
        late final Widget content;

        switch (_style) {
          case ToastStyle.redFrame:
          // Рамка и акцент берутся из accent (по умолчанию AppColors.accent)
            final Color ac = accent ?? AppColors.accent;
            content = Container(
              constraints: const BoxConstraints(maxWidth: 360),
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(18),
                border: Border.all(color: ac, width: 2),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withOpacity(0.20),
                    blurRadius: 18,
                    offset: const Offset(0, 10),
                  ),
                ],
              ),
              child: Material(
                color: baseBg,
                borderRadius: BorderRadius.circular(16),
                child: Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Container(
                        width: 36,
                        height: 36,
                        decoration: BoxDecoration(
                          shape: BoxShape.circle,
                          color: ac.withOpacity(0.10),
                        ),
                        child: Icon(icon, color: ac),
                      ),
                      const SizedBox(width: 12),
                      Flexible(
                        child: Text(
                          message,
                          style: textStyle.copyWith(color: onSurface),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            );
            break;

          case ToastStyle.glass:
          // iOS-look: сильный blur, стеклянный фон с тонким штрихом и мягким glow
            final ac = accent ?? AppColors.accent;
            final overlayTint =
            isDark ? Colors.white.withOpacity(0.07) : Colors.white.withOpacity(0.55);

            content = ClipRRect(
              borderRadius: BorderRadius.circular(22),
              child: BackdropFilter(
                filter: ui.ImageFilter.blur(sigmaX: 24, sigmaY: 24),
                child: Container(
                  constraints: const BoxConstraints(maxWidth: 380),
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      begin: Alignment.topLeft,
                      end: Alignment.bottomRight,
                      colors: [
                        overlayTint,
                        overlayTint.withOpacity(isDark ? 0.06 : 0.35),
                      ],
                    ),
                    borderRadius: BorderRadius.circular(22),
                    border: Border.all(
                      color: Colors.white.withOpacity(isDark ? 0.15 : 0.35),
                      width: 1,
                    ),
                    boxShadow: [
                      BoxShadow(
                        color: ac.withOpacity(0.25),
                        blurRadius: 22,
                        spreadRadius: 1,
                        offset: const Offset(0, 10),
                      ),
                    ],
                  ),
                  padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      // Бейдж слева как на iOS
                      Container(
                        width: 34,
                        height: 34,
                        decoration: BoxDecoration(
                          shape: BoxShape.circle,
                          gradient: LinearGradient(
                            colors: [ac.withOpacity(0.95), ac.withOpacity(0.65)],
                            begin: Alignment.topLeft,
                            end: Alignment.bottomRight,
                          ),
                          boxShadow: [
                            BoxShadow(
                              color: ac.withOpacity(0.35),
                              blurRadius: 12,
                              offset: const Offset(0, 6),
                            ),
                          ],
                        ),
                        child: const Icon(Icons.notifications, color: Colors.white),
                      ),
                      const SizedBox(width: 12),
                      Flexible(
                        child: Text(
                          message,
                          style: textStyle.copyWith(color: onSurface),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            );
            break;

          case ToastStyle.minimal:
          // Чистый минимал: тонкая рамка, аккуратная тень, маленький капсуль-бейдж
            final Color ac = accent ?? AppColors.primary;
            content = Container(
              constraints: const BoxConstraints(maxWidth: 360),
              decoration: BoxDecoration(
                color: baseBg,
                borderRadius: BorderRadius.circular(14),
                border: Border.all(color: scheme.outlineVariant.withOpacity(0.5)),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withOpacity(0.12),
                    blurRadius: 14,
                    offset: const Offset(0, 8),
                  ),
                ],
              ),
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Container(
                    width: 26,
                    height: 26,
                    decoration: BoxDecoration(
                      borderRadius: BorderRadius.circular(7),
                      color: ac.withOpacity(0.12),
                    ),
                    child: Icon(icon, size: 18, color: ac),
                  ),
                  const SizedBox(width: 10),
                  Flexible(
                    child: Text(
                      message,
                      style: textStyle.copyWith(color: onSurface),
                    ),
                  ),
                ],
              ),
            );
            break;
        }

        return Positioned(
          top: position == ToastPosition.top ? topPos : null,
          bottom: position == ToastPosition.bottom ? bottomPos : null,
          left: 16,
          right: 16,
          child: Center(
            child: FadeTransition(
              opacity: fadeIn,
              child: SlideTransition(
                position: slide,
                child: ScaleTransition(scale: scale, child: content),
              ),
            ),
          ),
        );
      },
    );

    _entry = entry;
    overlay.insert(entry);
    _controller.forward(from: 0);

    _timer = Timer(duration, () async {
      await _controller.reverse();
      _entry?.remove();
      _entry = null;
    });
  }

  // -------- Удобные шорткаты --------

  /// Информационное уведомление (акцент берётся из AppColors.accent)
  void info(
      String message, {
        IconData icon = Icons.info_outline_rounded,
        ToastPosition position = ToastPosition.top,
        Duration duration = const Duration(seconds: 2),
      }) {
    show(
      message,
      icon: icon,
      accent: AppColors.accent,
      duration: duration,
      position: position,
    );
  }

  /// Уведомление об ошибке (акцент — красный)
  void error(
      String message, {
        IconData icon = Icons.error_outline_rounded,
        ToastPosition position = ToastPosition.top,
        Duration duration = const Duration(seconds: 2),
      }) {
    show(
      message,
      icon: icon,
      accent: Colors.redAccent,
      duration: duration,
      position: position,
    );
  }

  /// Успех (зелёный акцент)
  void success(
      String message, {
        IconData icon = Icons.check_circle_rounded,
        ToastPosition position = ToastPosition.top,
        Duration duration = const Duration(seconds: 2),
      }) {
    show(
      message,
      icon: icon,
      accent: Colors.greenAccent,
      duration: duration,
      position: position,
    );
  }

  /// Предупреждение (жёлтый акцент)
  void warning(
      String message, {
        IconData icon = Icons.warning_amber_rounded,
        ToastPosition position = ToastPosition.top,
        Duration duration = const Duration(seconds: 2),
      }) {
    show(
      message,
      icon: icon,
      accent: Colors.amber,
      duration: duration,
      position: position,
    );
  }

  /// Принудительно закрыть текущий тост (если висит)
  Future<void> close() async {
    _timer?.cancel();
    _timer = null;
    if (_entry != null) {
      await _controller.reverse();
      _entry?.remove();
      _entry = null;
    }
  }
}

/// Небольшой vsync-провайдер на случай, если init вызвали без контекста экрана
class _DummyTickerProvider implements TickerProvider {
  @override
  Ticker createTicker(TickerCallback onTick) => Ticker(onTick);
}
