import 'package:flutter/material.dart';
import '../constants.dart';

class VictoryBanner extends StatelessWidget {
  const VictoryBanner({super.key});

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(vertical: 5, horizontal: 5),
      decoration: BoxDecoration(
        color: AppColors.primary,
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.2),
            blurRadius: 8,
            offset: const Offset(0, 4),
          ),
        ],
        borderRadius: BorderRadius.vertical(bottom: Radius.circular(15)), // Скругление снизу
      ),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          // Изображение с закругленными углами
          ClipRRect(
            borderRadius: BorderRadius.circular(12), // Скругление углов изображения
            child: Image.asset(
              'assets/images/donnty.png',
              height: 240,
              fit: BoxFit.contain,
            ),
          ),

          const SizedBox(height: 8),

          // Текст под изображением
          const Text(
            'Мы встретили первокурсников!\nДобро пожаловать в ДонНТУ!',
            textAlign: TextAlign.center,
            style: TextStyle(
              fontSize: 14,
              fontWeight: FontWeight.w600,
              color: Colors.white,
              height: 1.3,
            ),
          ),
        ],
      ),
    );
  }
}
