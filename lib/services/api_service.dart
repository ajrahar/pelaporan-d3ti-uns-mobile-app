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

        // Log field names from first item in response
        if (data.isNotEmpty) {
          print("Fields available in response: ${data[0].keys.join(', ')}");
        }

        List<Laporan> results = [];
        for (int i = 0; i < data.length; i++) {
          try {
            // Create a fixed version of the data if needed
            Map<String, dynamic> fixedData = Map.from(data[i]);

            // CRITICAL FIX: If ID is null but there's another identifier,
            // use that as a temporary ID for display purposes
            if (fixedData['id'] == null) {
              // Check if there's another field we can use as an ID substitute
              if (fixedData.containsKey('laporan_id')) {
                fixedData['id'] = fixedData['laporan_id'];
              } else if (fixedData.containsKey('nomor_laporan')) {
                // Use hash code of nomor_laporan as a temporary ID
                // (not ideal but usable for display purposes)
                fixedData['id'] = fixedData['nomor_laporan'].hashCode;
              }

              // If we updated the id, log it
              if (fixedData['id'] != null) {
                print(
                    "Fixed null ID for report at index $i: using ${fixedData['id']}");
              }
            }

            // Only add if we have a valid ID now
            if (fixedData['id'] != null) {
              results.add(Laporan.fromJson(fixedData));
            } else {
              print("Skipping report at index $i due to missing ID");
            }
          } catch (e) {
            print("Error parsing Laporan at index $i: $e");
            print("Problematic JSON: ${data[i]}");
          }
        }
        return results;
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

  // Get laporan by ID (with improved error handling)
  Future<Laporan> getLaporanById(int id) async {
    try {
      if (id <= 0) {
        throw Exception('ID laporan tidak valid: $id');
      }

      final headers = await getHeaders();
      print("Fetching detail for laporan ID: $id");
      print("API URL: $baseUrl/laporan/$id");

      final response = await http
          .get(
            Uri.parse('$baseUrl/laporan/$id'),
            headers: headers,
          )
          .timeout(Duration(seconds: 15));

      print("Detail API Response Status: ${response.statusCode}");

      if (response.statusCode == 200) {
        final data = json.decode(response.body);

        // Log the received data structure
        print("Detail response fields: ${data.keys.join(', ')}");

        return Laporan.fromJson(data);
      } else if (response.statusCode == 401) {
        throw Exception('Authentication failed. Please log in again.');
      } else if (response.statusCode == 404) {
        throw Exception('Laporan dengan ID $id tidak ditemukan.');
      } else {
        throw Exception('Gagal memuat laporan: ${response.statusCode}');
      }
    } catch (e) {
      print('Error in getLaporanById: $e');
      throw Exception('Gagal mengambil detail laporan: $e');
    }
  }

  // Update tanggapan laporan
  Future<void> updateLaporanTanggapan(int laporanId, dynamic tanggapan) async {
    try {
      final headers = await getHeaders();

      // Persiapkan data untuk dikirim
      final String tanggapanStr =
          tanggapan is List ? json.encode(tanggapan) : tanggapan.toString();

      // Buat multipart request untuk mendukung pengiriman data form
      var request = http.MultipartRequest(
        'POST',
        Uri.parse('$baseUrl/laporan/update_status/$laporanId'),
      );

      // Tambahkan headers
      headers.forEach((key, value) {
        request.headers[key] = value;
      });

      // Tambahkan field form
      request.fields['_method'] = 'PUT';
      request.fields['tanggapan'] = tanggapanStr;

      // Kirim request
      var streamedResponse = await request.send();
      var response = await http.Response.fromStream(streamedResponse);

      if (response.statusCode != 200) {
        throw Exception(
            'Failed to update laporan: ${response.statusCode} - ${response.body}');
      }
    } catch (e) {
      throw Exception('Failed to update tanggapan: $e');
    }
  }

  // Update status laporan
  Future<void> updateLaporanStatus(int laporanId, String status) async {
    try {
      final headers = await getHeaders();

      // Buat multipart request untuk mendukung pengiriman data form
      var request = http.MultipartRequest(
        'POST',
        Uri.parse('$baseUrl/laporan/update_status/$laporanId'),
      );

      // Tambahkan headers
      headers.forEach((key, value) {
        request.headers[key] = value;
      });

      // Tambahkan field form
      request.fields['_method'] = 'PUT';
      request.fields['status'] = status;

      // Kirim request
      var streamedResponse = await request.send();
      var response = await http.Response.fromStream(streamedResponse);

      if (response.statusCode != 200) {
        throw Exception(
            'Failed to update status: ${response.statusCode} - ${response.body}');
      }
    } catch (e) {
      throw Exception('Failed to update status: $e');
    }
  }
}
