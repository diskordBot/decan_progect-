//navigation_button.dart
import 'package:flutter/material.dart';
import '../constants.dart';

class NavigationButton extends StatelessWidget {
  final String title;
  final IconData icon;
  final VoidCallback onPressed;

  const NavigationButton({
    super.key,
    required this.title,
    required this.icon,
    required this.onPressed,
  });

  @override
  Widget build(BuildContext context) {
    return ElevatedButton(
      style: ElevatedButton.styleFrom(
        backgroundColor: AppColors.primary,
        foregroundColor: Colors.white,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(8),
        ),
        padding: const EdgeInsets.symmetric(vertical: 16, horizontal: 20),
        elevation: 2,
      ),
      onPressed: onPressed,
      child: Row(
        children: [
          Icon(icon, size: 24),
          const SizedBox(width: 16),
          Text(
            title,
            style: const TextStyle(fontSize: 16),
          ),
          const Spacer(),
          const Icon(Icons.chevron_right, size: 24),
        ],
      ),
    );
  }
}