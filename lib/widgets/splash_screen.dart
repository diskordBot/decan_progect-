import 'package:flutter/material.dart';
import 'package:video_player/video_player.dart';
import 'package:decanat_progect/screens//home_screen.dart';
import '../main.dart';  // Путь к вашему главному экрану

class SplashScreen extends StatefulWidget {
  @override
  _SplashScreenState createState() => _SplashScreenState();
}

class _SplashScreenState extends State<SplashScreen> {
  late VideoPlayerController _controller;

  @override
  void initState() {
    super.initState();

    // Загружаем и инициализируем видео
    _controller = VideoPlayerController.asset('assets/logotiti.mp4')
      ..initialize().then((_) {
        setState(() {});
        _controller.play();  // Запуск видео
        _navigateToHomeScreen();  // Переход на главный экран после окончания видео
      });
  }

  // Переход на главный экран через некоторое время
  void _navigateToHomeScreen() {
    Future.delayed(Duration(seconds: 4), () {  // Убедитесь, что длительность видео соответствует
      Navigator.pushReplacement(
        context,
        MaterialPageRoute(builder: (context) => MyHomePage()),
      );
    });
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      body: Center(
        child: _controller.value.isInitialized
            ? AspectRatio(
          aspectRatio: _controller.value.aspectRatio,
          child: VideoPlayer(_controller),
        )
            : CircularProgressIndicator(),  // Пока видео загружается, показываем индикатор загрузки
      ),
    );
  }
}
