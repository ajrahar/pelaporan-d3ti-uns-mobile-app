import 'package:flutter/material.dart';
import '../../domain/entities/user.dart';
import '../../domain/usecases/login_user.dart';

class AuthProvider extends ChangeNotifier {
  final LoginUser loginUser;

  AuthProvider({required this.loginUser});

  User? _user;
  User? get user => _user;

  bool _isLoading = false;
  bool get isLoading => _isLoading;

  String? _errorMessage;
  String? get errorMessage => _errorMessage;

  Future<bool> login(String email, String password) async {
    _isLoading = true;
    _errorMessage = null;
    notifyListeners();

    final result = await loginUser(LoginUserParams(email: email, password: password));

    bool success = false;
    result.fold(
      (failure) {
        _errorMessage = failure.message;
        success = false;
      },
      (user) {
        _user = user;
        success = true;
      },
    );

    _isLoading = false;
    notifyListeners();
    return success;
  }
}
