// lib/notifications/notification_service.dart
import 'dart:typed_data';
import 'package:flutter/material.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:http/http.dart' as http;

/// Фоновый обработчик тапа по локальному уведомлению (если нужно — оставь)
@pragma('vm:entry-point')
void notificationTapBackground(NotificationResponse response) {
  // TODO: навигация/логика по response.payload / response.actionId
  // debugPrint('BG tap: payload=${response.payload}, action=${response.actionId}');
}

class NotificationService {
  NotificationService._();
  static final NotificationService instance = NotificationService._();

  final FlutterLocalNotificationsPlugin _fln = FlutterLocalNotificationsPlugin();

  bool _vibrationEnabled = true;

  /// Канал для новостей (Android)
  static const AndroidNotificationChannel _channel = AndroidNotificationChannel(
    'news_channel',                 // id
    'Новости',                      // name
    description: 'Уведомления о новых новостях',
    importance: Importance.high,
    playSound: true,
    enableVibration: true,
  );

  /// Ключ для группировки нескольких уведомлений в одну группу (Android)
  static const String _groupKey = 'news_group_key';

  /// Фиксированный ID для «сводного» уведомления группы
  static const int _groupSummaryId = 900000001;

  Future<void> init() async {
    // ANDROID init
    const AndroidInitializationSettings androidInit =
    AndroidInitializationSettings('@mipmap/ic_launcher');

    // iOS/macOS init (Darwin*)
    const DarwinInitializationSettings darwinInit = DarwinInitializationSettings(
      requestAlertPermission: false,
      requestBadgePermission: false,
      requestSoundPermission: false,
    );

    const InitializationSettings settings = InitializationSettings(
      android: androidInit,
      iOS: darwinInit,
      macOS: darwinInit,
    );

    await _fln.initialize(
      settings,
      onDidReceiveNotificationResponse: (NotificationResponse response) async {
        // Тап по локальному уведомлению/экшену в фореграунде/бэке
        // debugPrint('Tap: payload=${response.payload}, action=${response.actionId}');
      },
      onDidReceiveBackgroundNotificationResponse: notificationTapBackground,
    );

    // Создаём канал под Android (важно: id должен совпадать с AndroidNotificationDetails)
    await _fln
        .resolvePlatformSpecificImplementation<
        AndroidFlutterLocalNotificationsPlugin>()
        ?.createNotificationChannel(_channel);
  }

  Future<void> setVibrationEnabled(bool enabled) async {
    _vibrationEnabled = enabled;
  }

  /// Показ локальной нотификации, если FCM пришёл в фореграунде.
  /// - BigPicture, если в message.data есть image (URL)
  /// - иначе BigText
  /// - группировка по ключу [_groupKey]
  Future<void> showFromRemoteMessage(RemoteMessage message) async {
    final notif = message.notification;
    final title = notif?.title ?? message.data['title'] ?? 'Новости';
    final body = notif?.body ?? message.data['body'] ?? '';

    // попробуем взять картинку из data.image
    final String? imageUrl = (message.data['image'] is String)
        ? message.data['image'] as String
        : null;

    // Базовые Android-параметры (без styleInformation)
    AndroidNotificationDetails _baseAndroidDetails() => AndroidNotificationDetails(
      _channel.id,
      _channel.name,
      channelDescription: _channel.description,
      importance: Importance.high,
      priority: Priority.high,
      playSound: true,
      enableVibration: _vibrationEnabled,
      category: AndroidNotificationCategory.message,
      groupKey: _groupKey,
      actions: const [
        AndroidNotificationAction(
          'open',
          'Открыть',
          showsUserInterface: true,
        ),
      ],
    );

    AndroidNotificationDetails androidDetails;

    if (imageUrl != null && imageUrl.startsWith('http')) {
      // BigPicture
      final bytes = await _downloadBytes(imageUrl);
      if (bytes != null) {
        final bmp = ByteArrayAndroidBitmap(bytes);
        androidDetails = AndroidNotificationDetails(
          _channel.id,
          _channel.name,
          channelDescription: _channel.description,
          importance: Importance.high,
          priority: Priority.high,
          playSound: true,
          enableVibration: _vibrationEnabled,
          category: AndroidNotificationCategory.message,
          groupKey: _groupKey,
          actions: const [
            AndroidNotificationAction('open', 'Открыть', showsUserInterface: true),
          ],
          styleInformation: BigPictureStyleInformation(
            bmp,
            largeIcon: bmp,
            contentTitle: title,
            summaryText: body,
            hideExpandedLargeIcon: false,
          ),
        );
      } else {
        // fallback в BigText
        androidDetails = AndroidNotificationDetails(
          _channel.id,
          _channel.name,
          channelDescription: _channel.description,
          importance: Importance.high,
          priority: Priority.high,
          playSound: true,
          enableVibration: _vibrationEnabled,
          category: AndroidNotificationCategory.message,
          groupKey: _groupKey,
          actions: const [
            AndroidNotificationAction('open', 'Открыть', showsUserInterface: true),
          ],
          styleInformation: BigTextStyleInformation(
            body,
            contentTitle: title,
          ),
        );
      }
    } else {
      // BigText
      androidDetails = AndroidNotificationDetails(
        _channel.id,
        _channel.name,
        channelDescription: _channel.description,
        importance: Importance.high,
        priority: Priority.high,
        playSound: true,
        enableVibration: _vibrationEnabled,
        category: AndroidNotificationCategory.message,
        groupKey: _groupKey,
        actions: const [
          AndroidNotificationAction('open', 'Открыть', showsUserInterface: true),
        ],
        styleInformation: BigTextStyleInformation(
          body,
          contentTitle: title,
        ),
      );
    }

    // iOS/macOS
    const darwinDetails = DarwinNotificationDetails();

    final details = NotificationDetails(
      android: androidDetails,
      iOS: darwinDetails,
      macOS: darwinDetails,
    );

    await _fln.show(
      notif?.hashCode ?? DateTime.now().millisecondsSinceEpoch ~/ 1000,
      title,
      body,
      details,
      payload: message.data['type'] ?? 'news',
    );

    // Показать «сводку» для группы (необязательно, но красиво)
    await _showGroupSummary();
  }

  /// Простой (ручной) показ уведомления — если понадобится
  Future<void> showSimple({
    required String title,
    required String body,
    String? payload,
  }) async {
    final androidDetails = AndroidNotificationDetails(
      _channel.id,
      _channel.name,
      channelDescription: _channel.description,
      importance: Importance.high,
      priority: Priority.high,
      playSound: true,
      enableVibration: _vibrationEnabled,
      groupKey: _groupKey,
    );

    const darwinDetails = DarwinNotificationDetails();

    await _fln.show(
      DateTime.now().millisecondsSinceEpoch ~/ 1000,
      title,
      body,
      NotificationDetails(android: androidDetails, iOS: darwinDetails, macOS: darwinDetails),
      payload: payload,
    );

    await _showGroupSummary();
  }

  /// Скачиваем изображение как bytes (для BigPicture)
  Future<Uint8List?> _downloadBytes(String url) async {
    try {
      final resp =
      await http.get(Uri.parse(url)).timeout(const Duration(seconds: 8));
      if (resp.statusCode == 200) return resp.bodyBytes;
    } catch (_) {}
    return null;
  }

  /// Суммарное уведомление (Android) для группировки
  Future<void> _showGroupSummary() async {
    final androidSummary = AndroidNotificationDetails(
      _channel.id,
      _channel.name,
      channelDescription: _channel.description,
      styleInformation: const InboxStyleInformation([]),
      groupKey: _groupKey,
      setAsGroupSummary: true,
      importance: Importance.low,
      priority: Priority.low,
      playSound: false,
      enableVibration: false,
    );

    const darwin = DarwinNotificationDetails();

    await _fln.show(
      _groupSummaryId,
      'Новости',
      'Новые уведомления',
      NotificationDetails(android: androidSummary, iOS: darwin, macOS: darwin),
    );
  }
}
