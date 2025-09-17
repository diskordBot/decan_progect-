// lib/providers/auth_provider.dart
import 'package:flutter/foundation.dart';
import 'package:decanat_progect/providers/user_model.dart';
import 'package:decanat_progect/providers/auth_service.dart';

class AuthProvider with ChangeNotifier {
  User? _currentUser;
  bool _isLoading = false;

  User? get currentUser => _currentUser;
  bool get isLoading => _isLoading;
  bool get isAuthenticated => _currentUser != null;
  bool get isTeacher => _currentUser?.role == 'teacher';

  Future<bool> registerTeacher({
    required String fullName,
    required String login,
    required String password,
  }) async {
    _isLoading = true;
    notifyListeners();

    try {
      final user = await AuthService.registerTeacher(
        fullName: fullName,
        login: login,
        password: password,
      );

      if (user != null) {
        _currentUser = user;
        _isLoading = false;
        notifyListeners();
        return true;
      }
      return false;
    } catch (e) {
      _isLoading = false;
      notifyListeners();
      rethrow;
    }
  }

  Future<bool> loginTeacher({
    required String login,
    required String password,
  }) async {
    _isLoading = true;
    notifyListeners();

    try {
      final user = await AuthService.loginTeacher(
        login: login,
        password: password,
      );

      if (user != null) {
        _currentUser = user;
        _isLoading = false;
        notifyListeners();
        return true;
      }
      return false;
    } catch (e) {
      _isLoading = false;
      notifyListeners();
      rethrow;
    }
  }

  void logout() {
    _currentUser = null;
    notifyListeners();
  }
}