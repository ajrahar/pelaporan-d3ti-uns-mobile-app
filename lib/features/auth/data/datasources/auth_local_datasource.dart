import 'package:shared_preferences/shared_preferences.dart';
import '../../../../shared/services/token_manager.dart';
import '../models/user_model.dart';

abstract class AuthLocalDataSource {
  Future<void> cacheUser(UserModel user);
}

class AuthLocalDataSourceImpl implements AuthLocalDataSource {
  final SharedPreferences sharedPreferences;

  AuthLocalDataSourceImpl({required this.sharedPreferences});

  @override
  Future<void> cacheUser(UserModel user) async {
    // Use TokenManager to ensure compatibility with legacy code and in-memory cache
    await TokenManager.setToken(user.token);

    // Cache other user details directly to SharedPreferences
    await sharedPreferences.setInt('user_id', user.id);
    await sharedPreferences.setString('user_name', user.name);
    await sharedPreferences.setString('user_email', user.email);
    await sharedPreferences.setString('user_nim', user.nim);
    await sharedPreferences.setString('user_no_telp', user.noTelp);
    await sharedPreferences.setBool('is_logged_in', true);
  }
}
