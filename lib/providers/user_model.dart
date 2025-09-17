// lib/models/user_model.dart
import 'dart:ui';

class User {
  final String id;
  final String fullName;
  final String login;
  final String role;
  final Color roleColor;

  User({
    required this.id,
    required this.fullName,
    required this.login,
    required this.role,
    required this.roleColor,
  });

  factory User.fromJson(Map<String, dynamic> json) {
    return User(
      id: json['id'],
      fullName: json['fullName'],
      login: json['login'],
      role: json['role'],
      roleColor: _parseColor(json['roleColor']),
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'fullName': fullName,
      'login': login,
      'role': role,
      'roleColor': roleColor.value.toString(),
    };
  }

  static Color _parseColor(String colorValue) {
    return Color(int.parse(colorValue));
  }
}