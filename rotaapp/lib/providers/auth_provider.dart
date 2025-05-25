// lib/providers/auth_provider.dart
import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart'; // Bu paketin pubspec.yaml'da olması ve 'flutter pub get' yapılmış olması GEREKLİ

class AuthProvider with ChangeNotifier {
  bool _isAuthenticated = false;
  String? _userId;
  String? _userEmail;
  String? _userName;

  bool get isAuthenticated => _isAuthenticated;
  String? get userId => _userId;
  String? get userEmail => _userEmail;
  String? get userName => _userName;

  Future<void> register(String name, String email, String password) async {
    try {
      // TODO: Firebase veya başka bir kimlik doğrulama servisi entegrasyonu
      await Future.delayed(const Duration(seconds: 1));

      _isAuthenticated = true;
      _userId = 'user_${DateTime.now().millisecondsSinceEpoch}';
      _userEmail = email;
      _userName = name;

      final prefs = await SharedPreferences.getInstance();
      await prefs.setBool('isAuthenticated', true);
      await prefs.setString('userId', _userId!);
      await prefs.setString('userEmail', email);
      await prefs.setString('userName', name);

      notifyListeners();
    } catch (e) {
      _isAuthenticated = false;
      _userId = null;
      _userEmail = null;
      _userName = null;
      throw Exception('Kayıt başarısız: $e');
    }
  }

  Future<void> signIn(String email, String password) async {
    try {
      // TODO: Firebase veya başka bir kimlik doğrulama servisi entegrasyonu
      await Future.delayed(const Duration(seconds: 1));

      _isAuthenticated = true;
      _userId = 'user_${DateTime.now().millisecondsSinceEpoch}';
      _userEmail = email;

      final prefs = await SharedPreferences.getInstance();
      await prefs.setBool('isAuthenticated', true);
      await prefs.setString('userId', _userId!);
      await prefs.setString('userEmail', email);

      notifyListeners();
    } catch (e) {
      _isAuthenticated = false;
      _userId = null;
      _userEmail = null;
      throw Exception('Giriş başarısız: $e');
    }
  }

  Future<void> signOut() async {
    _isAuthenticated = false;
    _userId = null;
    _userEmail = null;
    _userName = null;

    final prefs = await SharedPreferences.getInstance();
    await prefs.remove('isAuthenticated');
    await prefs.remove('userId');
    await prefs.remove('userEmail');
    await prefs.remove('userName');

    notifyListeners();
  }

  Future<void> checkAuthStatus() async {
    final prefs = await SharedPreferences.getInstance();
    _isAuthenticated = prefs.getBool('isAuthenticated') ?? false;
    _userId = prefs.getString('userId');
    _userEmail = prefs.getString('userEmail');
    _userName = prefs.getString('userName');
    notifyListeners();
  }
}