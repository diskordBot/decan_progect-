import 'package:flutter/material.dart';
import '../constants.dart';

class BubbleButton extends StatelessWidget {
  final String title;
  final IconData icon;
  final Color primaryColor;
  final VoidCallback onTap;

  const BubbleButton({
    super.key,
    required this.title,
    required this.icon,
    required this.primaryColor,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        width: 100,
        height: 100,
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(16),
          boxShadow: [
            // Добавление тени для имитации размытия
            BoxShadow(
              color: primaryColor.withOpacity(0.2), // Цвет тени с размытием
              blurRadius: 10, // Степень размытия
              spreadRadius: 5, // Расстояние, на которое размытая область расширяется
              offset: const Offset(0, 0), // Тень вокруг контейнера
            ),
          ],
          border: Border.all(
            width: 2,
            style: BorderStyle.solid,
            color: primaryColor, // Основной цвет границы
          ),
        ),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            // Иконка в круге
            Container(
              width: 40,
              height: 40,
              decoration: BoxDecoration(
                color: primaryColor,
                shape: BoxShape.circle,
                boxShadow: [
                  BoxShadow(
                    color: primaryColor.withOpacity(0.5), // Тень для иконки
                    blurRadius: 6,
                    offset: const Offset(0, 4),
                  ),
                ],
              ),
              child: Icon(
                icon,
                size: 30,
                color: Colors.white,
              ),
            ),

            const SizedBox(height: 10),

            // Текст под иконкой
            Text(
              title,
              style: const TextStyle(
                fontSize: 13,
                fontWeight: FontWeight.w600,
                color: AppColors.textDark,
              ),
              textAlign: TextAlign.center,
            ),
          ],
        ),
      ),
    );
  }
}
