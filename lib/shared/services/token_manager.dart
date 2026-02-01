import 'package:shared_preferences/shared_preferences.dart';
import 'dart:math' as Math;

class TokenManager {
  // In-memory token cache that persists across the app lifetime
  static String? _cachedToken;

  // Set token using multiple approaches
  static Future<bool> setToken(String token) async {
    // Always update the in-memory cache first
    _cachedToken = token;
    print(
        'Token stored in memory cache: ${token.substring(0, Math.min(10, token.length))}...');

    // Then try to store in SharedPreferences as a backup
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString('auth_token', token);
      print('Token also stored in SharedPreferences');
      return true;
    } catch (e) {
      print('Failed to store token in SharedPreferences: $e');
      // Even if SharedPreferences fails, we still have the in-memory token
      return true;
    }
  }

  // Get token from any available source
  static Future<String?> getToken() async {
    // First check in-memory cache as it's fastest
    if (_cachedToken != null && _cachedToken!.isNotEmpty) {
      print(
          'Using in-memory cached token: ${_cachedToken!.substring(0, Math.min(10, _cachedToken!.length))}...');
      return _cachedToken;
    }

    // If not in memory, try SharedPreferences
    try {
      final prefs = await SharedPreferences.getInstance();
      final token = prefs.getString('auth_token');

      if (token != null && token.isNotEmpty) {
        // Update our memory cache for next time
        _cachedToken = token;
        print(
            'Retrieved token from SharedPreferences: ${token.substring(0, Math.min(10, token.length))}...');
        return token;
      }
    } catch (e) {
      print('Failed to get token from SharedPreferences: $e');
      // Continue to next approach
    }

    // If we get here, we have no token
    print('No auth token found in any storage');
    return null;
  }

  // Clear token from all storage
  static Future<void> clearToken() async {
    _cachedToken = null;

    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.remove('auth_token');
      print('Token cleared from all storage');
    } catch (e) {
      print('Failed to clear token from SharedPreferences: $e');
    }
  }

  // For debug use - set a test token
  static void setDebugToken(String token) {
    _cachedToken = token;
    print(
        'DEBUG: Test token set in memory: ${token.substring(0, Math.min(10, token.length))}...');
  }
}
