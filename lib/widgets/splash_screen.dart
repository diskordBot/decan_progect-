import 'package:flutter/material.dart';
import 'package:video_player/video_player.dart';
import 'package:decanat_progect/screens/home_screen.dart';
import '../constants.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';

import '../main.dart';

class SplashScreen extends StatefulWidget {
  @override
  _SplashScreenState createState() => _SplashScreenState();
}

class _SplashScreenState extends State<SplashScreen> {
  VideoPlayerController? _controller;
  String? _userId;
  String _userRole = 'user';
  bool _userInitialized = false;
  bool _navigated = false;

  @override
  void initState() {
    super.initState();
    _boot();
  }

  Future<void> _boot() async {
    // Запускаем оба процесса параллельно, но навигацию не блокируем дольше 5 сек
    await Future.wait([
      _initializeUser().catchError((_) {}),
      _initVideo().catchError((_) {}),
      Future.delayed(const Duration(seconds: 5)),
    ]);
    _goHomeSafely();
  }

  Future<void> _initVideo() async {
    final ctrl = VideoPlayerController.asset(
      'assets/logotiti.mp4',
      // 🔊 Не перехватывать аудиофокус, смешивать с другими источниками
      videoPlayerOptions: VideoPlayerOptions(mixWithOthers: true),
    );
    _controller = ctrl;

    await ctrl.initialize();
    if (!mounted) return;

    // На всякий случай глушим именно нашу аудиодорожку
    await ctrl.setVolume(0.0);

    setState(() {});
    ctrl.play();
  }


  Future<void> _initializeUser() async {
    final prefs = await SharedPreferences.getInstance();
    _userId = prefs.getString('userId');

    if (_userId == null) {
      await _createNewUser();
    } else {
      await _loadUserRole();
    }
    if (!mounted) return;
    setState(() => _userInitialized = true);
  }

  Future<void> _createNewUser() async {
    try {
      final res = await http.post(
        Uri.parse('${AppConfig.serverUrl}/api/users'),
        headers: {'Content-Type': 'application/json'},
        body: json.encode({'device_info': 'Flutter App'}),
      ).timeout(const Duration(seconds: 6));

      if (res.statusCode == 200) {
        final data = json.decode(res.body);
        final prefs = await SharedPreferences.getInstance();
        _userId = data['user_id'] as String?;
        _userRole = (data['role'] as String?) ?? 'user';
        await prefs.setString('userId', _userId!);
        await prefs.setString('userRole', _userRole);
      } else {
        await _fallbackUser();
      }
    } catch (_) {
      await _fallbackUser();
    }
  }

  Future<void> _fallbackUser() async {
    final prefs = await SharedPreferences.getInstance();
    final id = DateTime.now().millisecondsSinceEpoch.toString().substring(7);
    _userId = id;
    _userRole = 'user';
    await prefs.setString('userId', id);
    await prefs.setString('userRole', 'user');
  }

  Future<void> _loadUserRole() async {
    if (_userId == null) return;
    try {
      final res = await http
          .get(Uri.parse('${AppConfig.serverUrl}/api/users/$_userId/role'))
          .timeout(const Duration(seconds: 5));
      if (res.statusCode == 200) {
        final data = json.decode(res.body);
        _userRole = (data['role'] as String?) ?? 'user';
        final prefs = await SharedPreferences.getInstance();
        await prefs.setString('userRole', _userRole);
      }
    } catch (_) {
      final prefs = await SharedPreferences.getInstance();
      _userRole = prefs.getString('userRole') ?? 'user';
    }
  }

  void _goHomeSafely() {
    if (_navigated || !mounted) return;
    _navigated = true;
    Navigator.of(context).pushReplacement(
      MaterialPageRoute(builder: (_) => const MyHomePage()),
    );
  }

  @override
  void dispose() {
    _controller?.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final initialized = _controller?.value.isInitialized ?? false;
    return Scaffold(
      backgroundColor: Colors.black,
      body: Center(
        child: (_userInitialized && initialized)
            ? AspectRatio(
          aspectRatio: _controller!.value.aspectRatio,
          child: VideoPlayer(_controller!),
        )
            : Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: const [
            CircularProgressIndicator(),
            SizedBox(height: 16),
            Text('Загрузка...', style: TextStyle(color: Colors.white)),
          ],
        ),
      ),
    );
  }
}
