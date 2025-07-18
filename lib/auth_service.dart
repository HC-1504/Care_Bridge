import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'user_model.dart';

class AuthService with ChangeNotifier {
  UserModel? _currentUser;
  final Future<SharedPreferences> _prefs = SharedPreferences.getInstance();
  String? _userID;

  UserModel? get currentUser => _currentUser;

  Future<void> loadUser() async {
    try {
      final prefs = await _prefs;
      final userJson = prefs.getString('currentUser');

      if (userJson != null) {
        final userData = json.decode(userJson);
        _currentUser = UserModel.fromJson(userData);
        notifyListeners();
      }
    } catch (e) {
      print('Error loading user: $e');
      await clearUser();
    }
  }

  Future<void> setUser(UserModel user) async {
    try {
      _currentUser = user;
      final prefs = await _prefs;
      await prefs.setString('currentUser', json.encode(user.toJson()));


      _userID = user.userID;
      await prefs.setString('userID', _userID!);

      notifyListeners();
    } catch (e) {
      print('Error saving user: $e');
    }
  }

  Future<void> clearUser() async {
    _currentUser = null;
    final prefs = await _prefs;
    await prefs.remove('currentUser');
    notifyListeners();
  }

  bool get isLoggedIn => _currentUser != null;
}