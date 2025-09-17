// lib/services/auth_service.dart
import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:decanat_progect/providers/user_model.dart';

class AuthService {
  static const String baseUrl = 'https://your-api-url.com/api';

  static Future<User?> registerTeacher({
    required String fullName,
    required String login,
    required String password,
  }) async {
    try {
      final response = await http.post(
        Uri.parse('$baseUrl/teachers/register'),
        headers: {'Content-Type': 'application/json'},
        body: json.encode({
          'fullName': fullName,
          'login': login,
          'password': password,
          'role': 'teacher',
          'roleColor': Colors.orange.value.toString(),
        }),
      );

      if (response.statusCode == 201) {
        final userData = json.decode(response.body);
        return User.fromJson(userData);
      }
      return null;
    } catch (e) {
      throw Exception('Ошибка регистрации: $e');
    }
  }

  static Future<User?> loginTeacher({
    required String login,
    required String password,
  }) async {
    try {
      final response = await http.post(
        Uri.parse('$baseUrl/teachers/login'),
        headers: {'Content-Type': 'application/json'},
        body: json.encode({
          'login': login,
          'password': password,
        }),
      );

      if (response.statusCode == 200) {
        final userData = json.decode(response.body);
        return User.fromJson(userData);
      }
      return null;
    } catch (e) {
      throw Exception('Ошибка входа: $e');
    }
  }
}