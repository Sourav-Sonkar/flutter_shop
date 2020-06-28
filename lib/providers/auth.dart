import 'dart:convert';
import 'package:flutter/widgets.dart';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';
import 'dart:async';

import '../models/http_exception.dart';

class Auth with ChangeNotifier {
  String _token;
  DateTime _expiryDate;
  String _userId;
  Timer _authTimer;

  bool get isAuth {
    return token != null;
  }

  String get token {
    if (_expiryDate != null &&
        _expiryDate.isAfter(DateTime.now()) &&
        _token != null) {
      return _token;
    }
    return null;
  }

  String get userId {
    return _userId;
  }

  Future<void> _authenticate(
      String email, String password, String urlSegment) async {
    try {
      final response = await http.post(
        urlSegment,
        body: jsonEncode(
          {
            'email': email,
            'password': password,
            'returnSecureToken': true,
          },
        ),
      );
      final responseData = jsonDecode(response.body);
      if (responseData['error'] != null) {
        throw HttpException(responseData['error']['message']);
      }
      _token = responseData['idToken'];
      _userId = responseData['localId'];
      _expiryDate = DateTime.now().add(
        Duration(
          seconds: int.parse(
            responseData['expiresIn'],
          ),
        ),
      );
      _autologout();
      notifyListeners();
      final prefs = await SharedPreferences.getInstance();
      final userData = jsonEncode(
        {
          "token": _token,
          "userId": _userId,
          "expiryDate": _expiryDate.toIso8601String(),
        },
      );
      prefs.setString('userData', userData);
    } catch (error) {
      throw error;
    }
    //print(jsonDecode(response.body));
  }

  Future<void> signup(String email, String password) async {
    const url =
        "https://identitytoolkit.googleapis.com/v1/accounts:signUp?key=AIzaSyCTc8NbG-uO6NXKyzz-KJYbVz-NhganyCA";
    return _authenticate(email, password, url);
  }

  Future<void> Login(String email, String password) async {
    const url =
        "https://identitytoolkit.googleapis.com/v1/accounts:signInWithPassword?key=AIzaSyCTc8NbG-uO6NXKyzz-KJYbVz-NhganyCA";
    return _authenticate(email, password, url);
  }

  void logout() async {
    _token = null;
    _userId = null;
    _expiryDate = null;
    if (_authTimer != null) {
      _authTimer.cancel();
      _authTimer = null;
    }

    notifyListeners();
    final prefs = await SharedPreferences.getInstance();
    //prefs.remove('userData');
    prefs.clear();
  }

  Future<void> tryAutoLogin() async {
    Map<String, Object> extractedUserData;
    DateTime expiryDate;

    final prefs = await SharedPreferences.getInstance();

    if (prefs.containsKey('userData')) {
      extractedUserData =
          json.decode(prefs.getString('userData')) as Map<String, Object>;
      expiryDate = DateTime.parse(extractedUserData['expiryDate']);

      if (expiryDate.isAfter(DateTime.now())) {
        _token = extractedUserData['token'];
        _userId = extractedUserData['userId'];
        _expiryDate = expiryDate;
        notifyListeners();
        _autologout();
      }
    }
  }

  void _autologout() {
    if (_authTimer != null) {
      _authTimer.cancel();
    }
    final timeExpiry = _expiryDate.difference(DateTime.now()).inSeconds;
    _authTimer = Timer(Duration(seconds: timeExpiry), logout);
  }
}
