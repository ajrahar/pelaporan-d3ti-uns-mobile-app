import 'dart:convert';
import 'package:http/http.dart' as http;
import 'dart:math' as Math;
import '../models/laporan.dart';
import 'token_manager.dart';

class ApiService {
  final String baseUrl = 'http://10.0.2.2:8000/api';

  // This will now use our TokenManager
  Future<String?> getAuthToken() async {
    return await TokenManager.getToken();
  }

  // Get headers with auth if token is available
  Future<Map<String, String>> getHeaders() async {
    final token = await getAuthToken();
    final headers = {
      'Content-Type': 'application/json',
      'Accept': 'application/json',
    };

    if (token != null && token.isNotEmpty) {
      headers['Authorization'] = 'Bearer $token';
      print(
          'Using authorization token: Bearer ${token.substring(0, Math.min(10, token.length))}...');
    } else {
      print('WARNING: No authorization token available for API request');
    }

    return headers;
  }

  // Get all categories - should work even without auth
  Future<Map<int, String>> getCategories() async {
    try {
      final headers = {
        'Content-Type': 'application/json',
        'Accept': 'application/json',
      };

      print("API URL: $baseUrl/category");

      final response = await http
          .get(
            Uri.parse('$baseUrl/category'),
            headers: headers,
          )
          .timeout(Duration(seconds: 15));

      print("Categories API Response Status: ${response.statusCode}");

      if (response.statusCode == 200) {
        final List<dynamic> data = json.decode(response.body);
        final Map<int, String> categories = {};

        for (var category in data) {
          categories[category['category_id']] = category['nama'];
        }

        return categories;
      } else {
        print(
            'Server error in getCategories: ${response.statusCode} - ${response.body}');
        throw Exception('Failed to load categories: ${response.statusCode}');
      }
    } catch (e) {
      print('Network error in getCategories: $e');
      throw Exception('Failed to connect to server: $e');
    }
  }

  // Get all laporan - requires auth
  Future<List<Laporan>> getLaporan() async {
    try {
      final token = await getAuthToken();
      if (token == null || token.isEmpty) {
        throw Exception(
            'No authentication token available. Please log in again.');
      }

      final headers = {
        'Content-Type': 'application/json',
        'Accept': 'application/json',
        'Authorization': 'Bearer $token'
      };

      print("API URL: $baseUrl/laporan");
      print(
          "Using auth token: Bearer ${token.substring(0, Math.min(10, token.length))}...");

      // Add a timeout to prevent long waits
      final response = await http
          .get(
            Uri.parse('$baseUrl/laporan'),
            headers: headers,
          )
          .timeout(Duration(seconds: 15));

      print("API Response Status Code: ${response.statusCode}");

      if (response.statusCode == 200) {
        final List<dynamic> data = json.decode(response.body);
        print("Decoded JSON data count: ${data.length}");
        return data.map((json) => Laporan.fromJson(json)).toList();
      } else if (response.statusCode == 401) {
        print('Authentication failed: ${response.body}');
        throw Exception('Authentication failed. Please log in again.');
      } else {
        print('Server error: ${response.statusCode} - ${response.body}');
        throw Exception('Failed to load laporan: ${response.statusCode}');
      }
    } catch (e) {
      print('Error in getLaporan: $e');
      throw Exception('Failed to load reports: $e');
    }
  }
}
