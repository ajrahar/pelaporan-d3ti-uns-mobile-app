import 'dart:convert';
import 'dart:io';
import 'package:http/http.dart' as http;
import 'package:http_parser/http_parser.dart';
import 'package:pelaporan_d3ti/models/laporan_kekerasan.dart';
import 'dart:math' as Math;
import '../models/laporan.dart';
import 'token_manager.dart';

class ApiService {
  // Changed the default baseUrl to the new URL
  String baseUrl = 'http://pelaporan-d3ti.my.id/api';

  // Method to update the base URL at runtime
  void updateBaseUrl(String newUrl) {
    baseUrl = newUrl;
    print("ApiService baseUrl updated to: $baseUrl");
  }

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
        final responseJson = json.decode(response.body);
        List<dynamic> data;

        // Handle both direct array and { status, data } structures
        if (responseJson is List) {
          data = responseJson;
        } else if (responseJson is Map && responseJson.containsKey('data')) {
          data = responseJson['data'];
        } else {
          throw Exception('Unexpected API response format');
        }

        final Map<int, String> categories = {};

        for (var category in data) {
          // Support both 'category_id' and 'id' fields
          int id = category['category_id'] ?? category['id'];
          // Support both 'nama' and 'nama_kategori' fields
          String name = category['nama'] ?? category['nama_kategori'];
          categories[id] = name;
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

            // CRITICAL FIX: Check for laporan_id first, which is the primary key in the API response
            if (fixedData.containsKey('laporan_id')) {
              // Use laporan_id as id if it exists
              fixedData['id'] = fixedData['laporan_id'];
            } else if (fixedData['id'] == null &&
                fixedData.containsKey('nomor_laporan')) {
              // Use hash code of nomor_laporan as a temporary ID if needed
              fixedData['id'] = fixedData['nomor_laporan'].hashCode;
            }

            // Process image_path if it's a JSON string
            if (fixedData.containsKey('image_path') &&
                fixedData['image_path'] is String &&
                fixedData['image_path'].startsWith('[') &&
                fixedData['image_path'].endsWith(']')) {
              try {
                List<dynamic> images = json.decode(fixedData['image_path']);
                fixedData['image_path'] =
                    images.isNotEmpty ? images.join(',') : null;
              } catch (e) {
                print("Error parsing image_path JSON: $e");
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

        // Check if we need to handle laporan_id vs id
        Map<String, dynamic> fixedData = Map.from(data);
        if (fixedData.containsKey('laporan_id')) {
          fixedData['id'] = fixedData['laporan_id'];
        }

        // Process image_path if it's a JSON string
        if (fixedData.containsKey('image_path') &&
            fixedData['image_path'] is String &&
            fixedData['image_path'].startsWith('[') &&
            fixedData['image_path'].endsWith(']')) {
          try {
            List<dynamic> images = json.decode(fixedData['image_path']);
            fixedData['image_path'] =
                images.isNotEmpty ? images.join(',') : null;
          } catch (e) {
            print("Error parsing image_path JSON in detail: $e");
          }
        }

        return Laporan.fromJson(fixedData);
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
  Future<void> updateLaporanTanggapan(int laporanId, dynamic tanggapan,
      {String status = 'verified'}) async {
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

      // Tambahkan headers (kecuali Content-Type yang akan diatur secara otomatis oleh MultipartRequest)
      headers.forEach((key, value) {
        if (key != 'Content-Type') {
          request.headers[key] = value;
        }
      });

      // Tambahkan field form
      request.fields['_method'] = 'PUT';
      request.fields['tanggapan'] = tanggapanStr;
      request.fields['status'] =
          status; // Use the status parameter with default value

      // Kirim request
      var streamedResponse = await request.send();
      var response = await http.Response.fromStream(streamedResponse);

      print(
          "Update tanggapan response: ${response.statusCode} - ${response.body}");

      if (response.statusCode != 200) {
        throw Exception(
            'Failed to update laporan: ${response.statusCode} - ${response.body}');
      }
    } catch (e) {
      print('Error in updateLaporanTanggapan: $e');
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

      // Tambahkan headers (kecuali Content-Type yang akan diatur secara otomatis oleh MultipartRequest)
      headers.forEach((key, value) {
        if (key != 'Content-Type') {
          request.headers[key] = value;
        }
      });

      // Tambahkan field form
      request.fields['_method'] = 'PUT';
      request.fields['status'] = status;

      // Kirim request
      var streamedResponse = await request.send();
      var response = await http.Response.fromStream(streamedResponse);

      print(
          "Update status response: ${response.statusCode} - ${response.body}");

      if (response.statusCode != 200) {
        throw Exception(
            'Failed to update status: ${response.statusCode} - ${response.body}');
      }
    } catch (e) {
      print('Error in updateLaporanStatus: $e');
      throw Exception('Failed to update status: $e');
    }
  }

  // Get laporan kekerasan
  Future<List<LaporanKekerasan>> getLaporanKekerasan() async {
    try {
      final token = await getAuthToken();
      final response = await http.get(
        Uri.parse('$baseUrl/laporan_kekerasan'),
        headers: {
          'Content-Type': 'application/json',
          'Authorization': 'Bearer $token',
        },
      );

      if (response.statusCode == 200) {
        final List<dynamic> data = json.decode(response.body);
        return data.map((json) => LaporanKekerasan.fromJson(json)).toList();
      } else {
        throw Exception('Failed to load laporan kekerasan');
      }
    } catch (e) {
      throw Exception('Error getting laporan kekerasan: $e');
    }
  }

  // Get detail of laporan kekerasan by id
  Future<LaporanKekerasan> getLaporanKekerasanById(int id) async {
    try {
      final token = await getAuthToken();
      final response = await http.get(
        Uri.parse('$baseUrl/laporan_kekerasan/$id'),
        headers: {
          'Content-Type': 'application/json',
          'Authorization': 'Bearer $token',
        },
      );

      if (response.statusCode == 200) {
        final dynamic data = json.decode(response.body);
        return LaporanKekerasan.fromJson(data);
      } else {
        throw Exception('Failed to load laporan kekerasan detail');
      }
    } catch (e) {
      throw Exception('Error getting laporan kekerasan detail: $e');
    }
  }

  // Submit the report
  Future<Map<String, dynamic>> submitLaporanKekerasan({
    required String title,
    required int categoryId,
    required String description,
    required String tanggalKejadian,
    required String namaPelapor,
    required String nimPelapor,
    required String nomorTelepon,
    String? lampiranLink,
    required List<String> buktiPelanggaran,
    required List<Map<String, dynamic>> terlapor,
    required List<Map<String, dynamic>> saksi,
    required List<File> imageFiles,
    required bool agreement,
  }) async {
    try {
      var request = http.MultipartRequest(
        'POST',
        Uri.parse('$baseUrl/laporan_kekerasan/add_laporan'),
      );

      // Add text fields
      request.fields['judul'] = title;
      request.fields['category_id'] = categoryId.toString();
      request.fields['deskripsi'] = description;
      request.fields['tanggal_kejadian'] = tanggalKejadian;
      request.fields['nama_pelapor'] = namaPelapor;
      request.fields['nim_pelapor'] = nimPelapor;
      request.fields['nomor_telepon'] = nomorTelepon;
      request.fields['current_datetime'] = DateTime.now().toUtc().toString();
      request.fields['username'] = nimPelapor;

      if (lampiranLink != null && lampiranLink.isNotEmpty) {
        request.fields['lampiran_link'] = lampiranLink;
      }

      // Add bukti_pelanggaran as array
      for (var i = 0; i < buktiPelanggaran.length; i++) {
        request.fields['bukti_pelanggaran[$i]'] = buktiPelanggaran[i];
      }

      // Add terlapor with proper array format for Laravel
      for (var i = 0; i < terlapor.length; i++) {
        terlapor[i].forEach((key, value) {
          if (value != null && value.toString().isNotEmpty) {
            request.fields['terlapor[$i][$key]'] = value.toString();
          }
        });
      }

      // Add saksi with proper array format for Laravel
      for (var i = 0; i < saksi.length; i++) {
        saksi[i].forEach((key, value) {
          if (value != null && value.toString().isNotEmpty) {
            request.fields['saksi[$i][$key]'] = value.toString();
          }
        });
      }

      // Add agreement field
      request.fields['agreement'] = agreement.toString();

      // Add image files
      for (var i = 0; i < imageFiles.length; i++) {
        final file = imageFiles[i];
        final fileName = file.path.split('/').last;
        final fileExtension = fileName.split('.').last.toLowerCase();

        var contentType = MediaType('image', fileExtension);

        request.files.add(
          http.MultipartFile(
            'image_path[]',
            file.readAsBytes().asStream(),
            file.lengthSync(),
            filename: fileName,
            contentType: contentType,
          ),
        );
      }

      // Send the request
      var response = await request.send();
      var responseData = await response.stream.bytesToString();

      if (response.statusCode == 200 || response.statusCode == 201) {
        return json.decode(responseData);
      } else {
        throw Exception(
            'Failed to submit report: ${response.statusCode}\n$responseData');
      }
    } catch (e) {
      throw Exception('Error submitting report: $e');
    }
  }
}
