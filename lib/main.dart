// lib/main.dart
import 'dart:async';
import 'dart:convert';
import 'dart:math' as math;
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:curved_navigation_bar/curved_navigation_bar.dart';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_messaging/firebase_messaging.dart';

import 'widgets/splash_screen.dart';
import 'screens/home_screen.dart';
import 'screens/about_screen.dart';
import 'screens/news_screen.dart';
import 'screens/settings_screen.dart';
import 'screens/faculty_screen.dart';
import 'screens/schedule_screen.dart';
import 'teacher/teacher_schedule_screen.dart';
import 'constants.dart';
import 'theme_controller.dart';
import 'notifications/notification_service.dart';

// ⬇️ добавили
import 'ui/overlay_toast.dart';

// Глобальный ключ навигации, чтобы уметь навигировать из FCM-хэндлеров
final GlobalKey<NavigatorState> navigatorKey = GlobalKey<NavigatorState>();

// ========================= PresenceService =========================
class PresenceService {
  PresenceService._();
  static final PresenceService instance = PresenceService._();

  Timer? _timer;

  Future<void> pingOnce() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final userId = prefs.getString('userId');
      if (userId == null) return;

      await http.post(
        Uri.parse('${AppConfig.serverUrl}/api/presence/ping'),
        headers: {'Content-Type': 'application/json'},
        body: json.encode({'user_id': userId}),
      );
    } catch (_) {}
  }

  void start() {
    stop();
    pingOnce();
    _timer = Timer.periodic(const Duration(seconds: 60), (_) => pingOnce());
  }

  void stop() {
    _timer?.cancel();
    _timer = null;
  }
}

// ====================== AppLifecycleWatcher =======================
class AppLifecycleWatcher extends StatefulWidget {
  final Widget child;
  const AppLifecycleWatcher({super.key, required this.child});

  @override
  State<AppLifecycleWatcher> createState() => _AppLifecycleWatcherState();
}

class _AppLifecycleWatcherState extends State<AppLifecycleWatcher>
    with WidgetsBindingObserver {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    PresenceService.instance.start();
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    PresenceService.instance.stop();
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) {
      PresenceService.instance.start();
      PresenceService.instance.pingOnce();
    }
    if (state == AppLifecycleState.paused ||
        state == AppLifecycleState.inactive ||
        state == AppLifecycleState.detached) {
      PresenceService.instance.stop();
    }
  }

  @override
  Widget build(BuildContext context) => widget.child;
}

// Фоновый хэндлер FCM
Future<void> _firebaseMessagingBackgroundHandler(RemoteMessage message) async {
  await Firebase.initializeApp();
  await NotificationService.instance.init();
  await NotificationService.instance.showFromRemoteMessage(message);
}

void _handleNotificationNavigation(RemoteMessage message) {
  final nav = navigatorKey.currentState;
  if (nav == null) return;
  nav.pushNamedAndRemoveUntil('/news', (route) => true);
}

Future<void> _initFcmListeners() async {
  await FirebaseMessaging.instance.setForegroundNotificationPresentationOptions(
    alert: true, badge: true, sound: true,
  );

  FirebaseMessaging.onMessage.listen((RemoteMessage message) async {
    await NotificationService.instance.showFromRemoteMessage(message);
  });

  FirebaseMessaging.onMessageOpenedApp.listen(_handleNotificationNavigation);

  final initialMessage = await FirebaseMessaging.instance.getInitialMessage();
  if (initialMessage != null) {
    _handleNotificationNavigation(initialMessage);
  }
}

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();

  // ⬇️ инициализация красивых верхних уведомлений (до runApp)
  await OverlayToast.instance.init(navigatorKey: navigatorKey);

  await Firebase.initializeApp();
  await ThemeController.instance.load();
  await NotificationService.instance.init();

  FirebaseMessaging.onBackgroundMessage(_firebaseMessagingBackgroundHandler);
  await _initFcmListeners();

  SystemChrome.setSystemUIOverlayStyle(const SystemUiOverlayStyle(
    statusBarColor: AppColors.primary,
    statusBarIconBrightness: Brightness.light,
    statusBarBrightness: Brightness.dark,
  ));

  runApp(const MyApp());
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: ThemeController.instance,
      builder: (context, _) {
        return AppLifecycleWatcher(
          child: MaterialApp(
            debugShowCheckedModeBanner: false,
            title: 'Кафедра ПМИИ',
            navigatorKey: navigatorKey, // ⬅️ важно для OverlayToast
            themeMode: ThemeController.instance.themeMode,
            theme: _buildLightTheme(),
            darkTheme: _buildDarkTheme(),
            home: SplashScreen(),
            routes: {
              '/home': (context) => const MyHomePage(),
              '/about': (context) => const AboutScreen(),
              '/news': (context) => const NewsScreen(),
              '/settings': (context) => const SettingsScreen(),
              '/schedule': (context) => const ScheduleScreen(),
              '/faculty': (context) => const FacultyScreen(),
              '/teacher-schedule': (context) => const TeacherScheduleScreen(),
            },
          ),
        );
      },
    );
  }

  ThemeData _buildLightTheme() {
    final scheme = ColorScheme.fromSeed(
      seedColor: AppColors.primary,
      brightness: Brightness.light,
    ).copyWith(onPrimary: Colors.white, primary: AppColors.primary);

    return ThemeData(
      useMaterial3: true,
      colorScheme: scheme,
      scaffoldBackgroundColor: scheme.background,
      appBarTheme: AppBarTheme(
        backgroundColor: scheme.primary,
        foregroundColor: scheme.onPrimary,
        centerTitle: true,
        elevation: 0,
        titleTextStyle: const TextStyle(
          fontSize: 16,
          fontWeight: FontWeight.w700,
        ),
        iconTheme: IconThemeData(color: scheme.onPrimary),
        systemOverlayStyle: const SystemUiOverlayStyle(
          statusBarColor: AppColors.primary,
          statusBarIconBrightness: Brightness.light,
          statusBarBrightness: Brightness.dark,
        ),
      ),
      cardTheme: CardThemeData(
        color: scheme.surface,
        elevation: 1,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      ),
      snackBarTheme: SnackBarThemeData(
        behavior: SnackBarBehavior.floating,
        backgroundColor: scheme.inverseSurface,
        contentTextStyle: TextStyle(color: scheme.onInverseSurface),
      ),
    );
  }

  ThemeData _buildDarkTheme() {
    final scheme = ColorScheme.fromSeed(
      seedColor: AppColors.primary,
      brightness: Brightness.dark,
    ).copyWith(onPrimary: Colors.white, primary: AppColors.primary);

    return ThemeData(
      useMaterial3: true,
      colorScheme: scheme,
      scaffoldBackgroundColor: scheme.background,
      appBarTheme: AppBarTheme(
        backgroundColor: scheme.primary,
        foregroundColor: scheme.onPrimary,
        centerTitle: true,
        elevation: 0,
        titleTextStyle: const TextStyle(
          fontSize: 16,
          fontWeight: FontWeight.w700,
        ),
        iconTheme: IconThemeData(color: scheme.onPrimary),
        systemOverlayStyle: const SystemUiOverlayStyle(
          statusBarColor: AppColors.primary,
          statusBarIconBrightness: Brightness.light,
          statusBarBrightness: Brightness.dark,
        ),
      ),
      cardTheme: CardThemeData(
        color: scheme.surface,
        elevation: 1,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      ),
      snackBarTheme: SnackBarThemeData(
        behavior: SnackBarBehavior.floating,
        backgroundColor: scheme.inverseSurface,
        contentTextStyle: TextStyle(color: scheme.onInverseSurface),
      ),
    );
  }
}

class MyHomePage extends StatefulWidget {
  const MyHomePage({super.key});
  @override
  State<MyHomePage> createState() => _MyHomePageState();
}

class _MyHomePageState extends State<MyHomePage> {
  int _selectedIndex = 0;

  static final List<Widget> _pages = [
    const HomeScreen(),
    const AboutScreen(),
    const NewsScreen(),
    const SettingsScreen(),
  ];

  void _onItemTapped(int index) => setState(() => _selectedIndex = index);

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final double sysBottom = MediaQuery.of(context).viewPadding.bottom;
    final double safeGap = math.max(8.0, sysBottom);

    return Scaffold(
      body: AnimatedSwitcher(
        duration: const Duration(milliseconds: 300),
        child: _pages[_selectedIndex],
      ),
      bottomNavigationBar: SafeArea(
        top: false,
        left: false,
        right: false,
        bottom: true,
        child: Padding(
          padding: EdgeInsets.only(bottom: safeGap),
          child: CurvedNavigationBar(
            index: _selectedIndex,
            onTap: _onItemTapped,
            height: 60,
            backgroundColor: Colors.transparent,
            color: scheme.primary,
            buttonBackgroundColor: scheme.primary.withOpacity(0.95),
            items: <Widget>[
              Icon(Icons.home, size: 28, color: scheme.onPrimary),
              Icon(Icons.info, size: 28, color: scheme.onPrimary),
              Icon(Icons.newspaper, size: 28, color: scheme.onPrimary),
              Icon(Icons.settings, size: 28, color: scheme.onPrimary),
            ],
            animationDuration: const Duration(milliseconds: 350),
            animationCurve: Curves.easeInOut,
          ),
        ),
      ),
    );
  }
}
