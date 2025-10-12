// lib/utils/auth_hint_bus.dart
import 'dart:async';
import 'dart:math' as math;
import 'package:flutter/foundation.dart';

/// Шина подсказки авторизации с ПЛАВНОЙ интенсивностью [0..1].
/// Подписчики (ProfileDrawer) слушают [intensity] и рисуют подсветку.
/// triggerSequence() даёт 3 плавных цикла: появление → угасание.
class AuthHintBus {
  AuthHintBus._();
  static final AuthHintBus instance = AuthHintBus._();

  /// Интенсивность эффекта (0.0 = нет подсветки, 1.0 = пик).
  final ValueNotifier<double> intensity = ValueNotifier<double>(0.0);

  Completer<void>? _running;
  Timer? _ticker;

  /// Запускает последовательность плавных мерцаний.
  /// cycles — число циклов; up/down — длительность фазы появления/угасания;
  /// pause — пауза между циклами (при 0 — без паузы).
  Future<void> triggerSequence({
    int cycles = 3,
    Duration up = const Duration(milliseconds: 450),
    Duration down = const Duration(milliseconds: 550),
    Duration pause = const Duration(milliseconds: 120),
  }) async {
    // Остановить предыдущую анимацию
    _running?.complete();
    _running = Completer<void>();
    final local = _running!;

    // Убедимся, что начинаем с 0
    intensity.value = 0.0;
    _stopTicker();

    // Хелпер плавной анимации от A к B за duration
    Future<void> _animate(double from, double to, Duration duration) async {
      final start = DateTime.now();
      final totalMs = duration.inMilliseconds.clamp(1, 1000000);
      final tick = Duration(milliseconds: 16); // ~60 FPS

      final sign = (to - from) >= 0 ? 1.0 : -1.0;

      _stopTicker();
      _ticker = Timer.periodic(tick, (tm) {
        if (local.isCompleted) {
          _stopTicker();
          return;
        }
        final elapsed = DateTime.now().difference(start).inMilliseconds;
        double t = (elapsed / totalMs).clamp(0.0, 1.0);

        // Плавная кривая (S-образная): easeInOutCubic
        t = t < 0.5 ? 4 * t * t * t : 1 - math.pow(-2 * t + 2, 3) / 2;

        intensity.value = from + (to - from) * t;

        if (elapsed >= totalMs) {
          intensity.value = to;
          _stopTicker();
        }
      });

      // Ждём завершения
      while (_ticker != null && _ticker!.isActive && !local.isCompleted) {
        await Future.delayed(const Duration(milliseconds: 10));
      }
    }

    // Основной цикл: появление → угасание (x cycles)
    for (int i = 0; i < cycles; i++) {
      if (local.isCompleted) break;
      await _animate(intensity.value, 1.0, up);
      if (local.isCompleted) break;
      await _animate(intensity.value, 0.0, down);
      if (local.isCompleted) break;

      if (i < cycles - 1 && pause.inMilliseconds > 0) {
        // Небольшая пауза между циклами
        int waited = 0;
        while (waited < pause.inMilliseconds && !local.isCompleted) {
          await Future.delayed(const Duration(milliseconds: 20));
          waited += 20;
        }
      }
    }

    // Завершение: гарантируем что погасло
    intensity.value = 0.0;

    if (!local.isCompleted) local.complete();
    if (identical(_running, local)) _running = null;
  }

  /// Совместимо со старым вызовом: просто запускает 3 плавных мигания.
  void trigger([Duration _ = const Duration(seconds: 2)]) {
    // 3 цикла ≈ 2 секунды с текущими таймингами
    unawaited(triggerSequence());
  }

  void _stopTicker() {
    _ticker?.cancel();
    _ticker = null;
  }

  void dispose() {
    _running?.complete();
    _running = null;
    _stopTicker();
    intensity.dispose();
  }
}
