import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:http/http.dart' as http;
import 'package:image_picker/image_picker.dart';
import 'dart:typed_data';
import 'dart:ui' as ui;
import 'package:flutter/services.dart';
import 'package:pelaporan_d3ti/services/api_service.dart';
// Add the reCAPTCHA import
import 'package:flutter_recaptcha_v2_compat/flutter_recaptcha_v2_compat.dart';
// Conditional imports for web-only libraries
import 'package:webview_flutter/webview_flutter.dart';

// Define a function to safely import dart:html only on web
// ignore: uri_does_not_exist
import 'dart:html' if (dart.library.io) 'stub_html.dart' as html;
// ignore: uri_does_not_exist
import 'dart:ui_web' if (dart.library.io) 'stub_ui_web.dart' as ui_web;

// Create stub classes for non-web platforms
class HtmlElementPlaceholder {
  // Empty stub class
}

class AddLaporKsDosenPage extends StatefulWidget {
  const AddLaporKsDosenPage({Key? key}) : super(key: key);

  @override
  _AddLaporKsDosenPageState createState() => _AddLaporKsDosenPageState();
}

class _AddLaporKsDosenPageState extends State<AddLaporKsDosenPage> {
  final _formKey = GlobalKey<FormState>();
  bool isSubmitting = false;

  // For reCAPTCHA
  String createdViewId = 'recaptcha_element';
  String? recaptchaToken;
  String? recaptchaError;

  // Add reCAPTCHA controller
  RecaptchaV2Controller recaptchaV2Controller = RecaptchaV2Controller();
  bool recaptchaVerified = false;

  // Focus node for the reCAPTCHA section
  final FocusNode recaptchaFocusNode = FocusNode();

  // Form Data
  Map<String, dynamic> report = {
    'title': '',
    'category': '',
    'description': '',
    'reporterName': '',
    'nim': '',
    'phone': '',
    'incidentDate': DateTime.now(),
    'evidenceFiles': null,
    'lampiran_link': '',
    'bukti_pelanggaran': <String>[],
    'agreement': false,
    'terlapor': <Map<String, dynamic>>[],
    'saksi': <Map<String, dynamic>>[],
    'profesi': '',
    'jenis_kelamin': '',
    'umur_pelapor': '',
  };

  // UI state
  List<Map<String, dynamic>> categories = [];
  List<String> selectedBukti = [];
  List<String> buktiOptions = [
    'Bukti pemeriksaan medis',
    'Dokumen dan/atau rekaman',
    'Foto dan/atau video dokumentasi',
    'Surat atau kesaksian tertulis',
    'Identitas sumber informasi'
  ];
  bool showLainnyaInput = false;
  String buktiLainnya = '';
  bool showBuktiWarning = false;
  bool showAgreementWarning = false;
  List<XFile>? selectedFiles;
  List<Uint8List> imagePreviewBytes = [];
  late WebViewController webViewController;

  @override
  void dispose() {
    // Dispose focus node
    recaptchaFocusNode.dispose();
    super.dispose();
  }

  @override
  void initState() {
    super.initState();

    // Initialize an empty terlapor and saksi
    addTerduga();
    addSaksi();

    loadCategories();

    // Web-specific initialization
    if (kIsWeb) {
      _initializeWebViewForWeb();
    }
  }

  // Web-specific method
  void _initializeWebViewForWeb() {
    try {
      final ui_web = _importUiWeb();
      final html = _importHtml();

      if (ui_web != null && html != null) {
        ui_web.platformViewRegistry.registerViewFactory(
          createdViewId,
          (int viewId) {
            final iframeElement = html.IFrameElement()
              ..src = 'assets/recaptcha.html'
              ..style.border = 'none'
              ..style.height = '100%'
              ..style.width = '100%'
              ..style.overflow = 'hidden';

            // Listen for messages from the iframe
            html.window.addEventListener('message', (event) {
              final data = event.data;
              if (data is Map) {
                if (data['type'] == 'recaptcha-success') {
                  final token = data['token'].toString();
                  setState(() {
                    recaptchaToken = token;
                    recaptchaVerified = true;
                    recaptchaError = null;
                  });
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(
                        content: Text('reCAPTCHA verification successful')),
                  );
                } else if (data['type'] == 'recaptcha-expired') {
                  setState(() {
                    recaptchaVerified = false;
                    recaptchaError = 'Verifikasi telah kedaluwarsa';
                  });
                } else if (data['type'] == 'recaptcha-error') {
                  setState(() {
                    recaptchaVerified = false;
                    recaptchaError = 'Terjadi kesalahan saat verifikasi';
                  });
                }
              }
            });

            return iframeElement;
          },
        );
      }
    } catch (e) {
      print('Web initialization error: $e');
    }
  }

  // Dynamic imports for web libraries
  dynamic _importUiWeb() {
    if (kIsWeb) {
      // Use a JavaScript eval approach to conditionally import the library
      try {
        return _getDartLibrary('dart:ui_web');
      } catch (e) {
        print('Error importing ui_web: $e');
        return null;
      }
    }
    return null;
  }

  dynamic _importHtml() {
    if (kIsWeb) {
      try {
        return _getDartLibrary('dart:html');
      } catch (e) {
        print('Error importing html: $e');
        return null;
      }
    }
    return null;
  }

  // Helper method to dynamically import Dart libraries at runtime
  dynamic _getDartLibrary(String library) {
    // This function uses JavaScript interop which is only available on web
    // The actual implementation would need JavaScript interop
    // For now, return null to prevent compile errors
    return null;
  }

  Future<bool> verifyToken(String token) async {
    // For testing purposes, we'll use the test key verification endpoint
    Uri uri = Uri.parse('https://www.google.com/recaptcha/api/siteverify');
    final response = await http.post(
      uri,
      body: {
        'secret':
            '6LeIxAcTAAAAAGG-vFI1TnRWxMZNFuojJ4WifJWe', // Google's test secret key
        'response': token,
      },
    );

    final Map<String, dynamic> jsonResponse = json.decode(response.body);
    return jsonResponse['success'] == true;
  }

  // Override the resetRecaptcha method
  void resetRecaptcha() {
    // Use reload() to reset the reCAPTCHA
    recaptchaV2Controller.reload();
    setState(() {
      recaptchaVerified = false;
      recaptchaError = null;
    });
  }

  Future<void> fetchCategories() async {
    try {
      final response = await http.get(
        Uri.parse('https://v3422040.mhs.d3tiuns.com/api/category'),
        headers: {
          'Content-Type': 'application/json',
          'Accept': 'application/json',
        },
      );

      if (response.statusCode >= 200 && response.statusCode < 300) {
        final parsed = json.decode(response.body);

        setState(() {
          if (parsed is List) {
            categories = List<Map<String, dynamic>>.from(parsed);
          } else if (parsed is Map && parsed.containsKey('data')) {
            categories = List<Map<String, dynamic>>.from(parsed['data']);
          }
        });
      } else {
        _showErrorDialog('Error', 'Gagal memuat kategori laporan.');
      }
    } catch (e) {
      _showErrorDialog('Network Error',
          'Gagal memuat kategori laporan. Periksa koneksi internet Anda.');
    }
  }

  Future<void> loadCategories() async {
    try {
      final apiService = ApiService();
      final categoryData = await apiService.getCategories();
      setState(() {
        categories = categoryData.entries
            .map((entry) => {
                  'category_id': entry.key, // Change from 'id' to 'category_id'
                  'nama': entry.value
                })
            .toList();
        print("Categories loaded: ${categories.length}");
      });
    } catch (e) {
      print("Error loading categories: $e");
      // Show error to user
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Failed to load categories: $e')),
      );
    }
  }

  // Add this function to filter for categories starting with "Kekerasan"
  List<Map<String, dynamic>> getFilteredCategories() {
    if (categories.isEmpty) {
      print("Categories is empty or null");
      return [];
    }

    try {
      // Filter categories that start with 'Kekerasan'
      List<Map<String, dynamic>> filtered = categories
          .where(
              (category) => category['nama'].toString().startsWith('Kekerasan'))
          .toList();

      print("Filtered categories count: ${filtered.length}");
      return filtered;
    } catch (e) {
      print("Error in getFilteredCategories: $e");
      return [];
    }
  }

  void addTerduga() {
    setState(() {
      report['terlapor'].add({
        'nama_lengkap': '',
        'email': '',
        'nomor_telepon': '',
        'status_warga': '',
        'jenis_kelamin': ''
      });
    });
  }

  void removeTerduga(int index) {
    setState(() {
      report['terlapor'].removeAt(index);
      if (report['terlapor'].isEmpty) {
        addTerduga(); // Always keep at least one terduga field
      }
    });
  }

  void addSaksi() {
    setState(() {
      report['saksi']
          .add({'nama_lengkap': '', 'email': '', 'nomor_telepon': ''});
    });
  }

  void removeSaksi(int index) {
    setState(() {
      report['saksi'].removeAt(index);
      if (report['saksi'].isEmpty) {
        addSaksi(); // Always keep at least one saksi field
      }
    });
  }

  void updateBuktiPelanggaran() {
    List<String> buktiArray = [...selectedBukti];

    if (showLainnyaInput && buktiLainnya.trim().isNotEmpty) {
      buktiArray.add('Lainnya: ${buktiLainnya.trim()}');
    }

    setState(() {
      report['bukti_pelanggaran'] = buktiArray;
    });
  }

  Future<void> handleFileUpload() async {
    final ImagePicker picker = ImagePicker();
    final List<XFile> images = await picker.pickMultiImage();

    if (images.isNotEmpty) {
      // Check file sizes
      List<String> oversizedFiles = [];
      for (var image in images) {
        final bytes = await image.readAsBytes();
        if (bytes.length > 5 * 1024 * 1024) {
          oversizedFiles.add(image.name);
        }
      }

      if (oversizedFiles.isNotEmpty) {
        _showErrorDialog('File Terlalu Besar',
            'File berikut melebihi batas 5MB: ${oversizedFiles.join(", ")}');
        return;
      }

      // Update selected files and generate previews
      List<Uint8List> previews = [];
      for (var image in images) {
        final bytes = await image.readAsBytes();
        previews.add(bytes);
      }

      setState(() {
        selectedFiles = images;
        imagePreviewBytes = previews;
      });
    }
  }

  void removeImage(int index) {
    setState(() {
      imagePreviewBytes.removeAt(index);
      selectedFiles!.removeAt(index);
    });
  }

  void resetForm() {
    setState(() {
      report = {
        'title': '',
        'category': '',
        'description': '',
        'reporterName': '',
        'nim': '',
        'phone': '',
        'incidentDate': DateTime.now(),
        'evidenceFiles': null,
        'lampiran_link': '',
        'bukti_pelanggaran': <String>[],
        'agreement': false,
        'terlapor': [],
        'saksi': [],
        'profesi': '',
        'jenis_kelamin': '',
        'umur_pelapor': ''
      };
      selectedBukti = [];
      showLainnyaInput = false;
      buktiLainnya = '';
      showBuktiWarning = false;
      showAgreementWarning = false;
      imagePreviewBytes = [];
      selectedFiles = null;
      recaptchaError = null;
      recaptchaVerified = false;

      // Re-add empty terlapor and saksi
      addTerduga();
      addSaksi();
    });

    // Reset reCAPTCHA
    resetRecaptcha();
  }

  void submitForm() async {
    if (!_formKey.currentState!.validate()) {
      return;
    }

    // Validate agreement
    if (report['agreement'] != true) {
      setState(() {
        showAgreementWarning = true;
      });
      _showErrorDialog(
          'Error', 'Anda harus menyetujui pernyataan untuk melanjutkan');
      return;
    }

    // Validate reCAPTCHA
    if (!recaptchaVerified) {
      setState(() {
        recaptchaError =
            'Harap selesaikan verifikasi reCAPTCHA "Saya bukan robot"';
      });
      _showErrorDialog(
          'Error', 'Harap selesaikan verifikasi reCAPTCHA untuk melanjutkan');
      return;
    }

    // Update bukti_pelanggaran array before submission
    updateBuktiPelanggaran();

    // Validate bukti_pelanggaran
    if (report['bukti_pelanggaran'].isEmpty) {
      setState(() {
        showBuktiWarning = true;
      });
      return;
    }

    // Show loading state
    setState(() {
      isSubmitting = true;
    });

    try {
      // Prepare form data
      var formData = http.MultipartRequest(
          'POST',
          Uri.parse(
              'https://v3422040.mhs.d3tiuns.com/api/laporan_kekerasan/add_laporan'));

      // Add text fields
      formData.fields.addAll({
        'judul': report['title'],
        'category_id': report['category'],
        'deskripsi': report['description'],
        'nama_pelapor': report['reporterName'],
        'nim_pelapor': report['nim'],
        'nomor_telepon': report['phone'],
        'tanggal_kejadian': report['incidentDate'].toIso8601String(),
        'current_datetime': DateTime.now().toString(),
        'username': 'mobile_app_user',
        'profesi': report['profesi'],
        'jenis_kelamin': report['jenis_kelamin'],
        'umur_pelapor': report['umur_pelapor'],
      });

      // Add reCAPTCHA token if on web
      if (kIsWeb && recaptchaToken != null) {
        formData.fields['g-recaptcha-response'] = recaptchaToken!;
      }

      // Add lampiran_link if available
      if (report['lampiran_link'].isNotEmpty) {
        formData.fields['lampiran_link'] = report['lampiran_link'];
      }

      // Add bukti_pelanggaran as array
      if (report['bukti_pelanggaran'].isNotEmpty) {
        for (var bukti in report['bukti_pelanggaran']) {
          formData.fields['bukti_pelanggaran[]'] = bukti;
        }
      }

      // Add terlapor with proper array format for Laravel
      List<Map<String, dynamic>> terlaporFiltered =
          List<Map<String, dynamic>>.from(report['terlapor']
              .where((t) => t['nama_lengkap'].trim().isNotEmpty));

      if (terlaporFiltered.isNotEmpty) {
        terlaporFiltered.asMap().forEach((index, item) {
          item.forEach((key, value) {
            if (value != null && value.toString().isNotEmpty) {
              formData.fields['terlapor[$index][$key]'] = value.toString();
            }
          });
        });
      }

      // Add saksi with proper array format for Laravel
      List<Map<String, dynamic>> saksiFiltered =
          List<Map<String, dynamic>>.from(report['saksi']
              .where((s) => s['nama_lengkap'].trim().isNotEmpty));

      if (saksiFiltered.isNotEmpty) {
        saksiFiltered.asMap().forEach((index, item) {
          item.forEach((key, value) {
            if (value != null && value.toString().isNotEmpty) {
              formData.fields['saksi[$index][$key]'] = value.toString();
            }
          });
        });
      }

      // Add agreement field
      formData.fields['agreement'] = report['agreement'].toString();

      // Add image files if available
      if (selectedFiles != null) {
        for (int i = 0; i < selectedFiles!.length; i++) {
          final bytes = await selectedFiles![i].readAsBytes();
          formData.files.add(
            http.MultipartFile.fromBytes(
              'image_path[]',
              bytes,
              filename: selectedFiles![i].name,
            ),
          );
        }
      }

      // Send the request
      final response = await formData.send();
      final responseData = await http.Response.fromStream(response);

      // Handle response
      if (responseData.statusCode >= 200 && responseData.statusCode < 300) {
        // Success
        _showSuccessDialog();
        resetForm();
      } else {
        // Error
        String errorMessage = 'Terjadi kesalahan:';
        try {
          final errorResponse = json.decode(responseData.body);

          if (errorResponse.containsKey('message')) {
            errorMessage += '\n- ${errorResponse['message']}';
          }

          if (errorResponse.containsKey('errors')) {
            Map<String, dynamic> errors = errorResponse['errors'];
            errors.forEach((key, value) {
              if (value is List) {
                errorMessage += '\n- ${value.join(", ")}';
              } else {
                errorMessage += '\n- $value';
              }
            });
          }
        } catch (e) {
          errorMessage += '\n- ${responseData.reasonPhrase}';
        }

        _showErrorDialog('Form Submission Error', errorMessage);
      }
    } catch (e) {
      _showErrorDialog('Network Error',
          'Server tidak merespon. Periksa koneksi internet Anda.');
    } finally {
      setState(() {
        isSubmitting = false;
      });
    }
  }

  void _showSuccessDialog() {
    showDialog(
      context: context,
      builder: (BuildContext context) {
        return AlertDialog(
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(16),
          ),
          title: Row(
            children: [
              Container(
                padding: EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: Colors.green.shade50,
                  shape: BoxShape.circle,
                ),
                child: Icon(
                  Icons.check_circle_outline,
                  color: Colors.green,
                  size: 24,
                ),
              ),
              SizedBox(width: 12),
              Text('Sukses!'),
            ],
          ),
          content: Text(
            'Laporan berhasil dikirimkan. Tim kami akan segera memproses laporan Anda.',
            style: TextStyle(
              fontSize: 15,
              color: Colors.grey[800],
            ),
          ),
          actions: <Widget>[
            TextButton(
              onPressed: () {
                Navigator.of(context).pop();
              },
              child: Text('OK'),
              style: TextButton.styleFrom(
                foregroundColor: Colors.green,
                padding: EdgeInsets.symmetric(horizontal: 20, vertical: 10),
              ),
            ),
          ],
        );
      },
    );
  }

  void _showErrorDialog(String title, String message) {
    showDialog(
      context: context,
      builder: (BuildContext context) {
        return AlertDialog(
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(16),
          ),
          title: Row(
            children: [
              Container(
                padding: EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: Colors.red.shade50,
                  shape: BoxShape.circle,
                ),
                child: Icon(
                  Icons.error_outline,
                  color: Colors.red,
                  size: 24,
                ),
              ),
              SizedBox(width: 12),
              Text(title),
            ],
          ),
          content: Text(
            message,
            style: TextStyle(
              fontSize: 15,
              color: Colors.grey[800],
            ),
          ),
          actions: <Widget>[
            TextButton(
              onPressed: () {
                Navigator.of(context).pop();
              },
              child: Text('OK'),
              style: TextButton.styleFrom(
                foregroundColor: Colors.red,
                padding: EdgeInsets.symmetric(horizontal: 20, vertical: 10),
              ),
            ),
          ],
        );
      },
    );
  }

  // Add a method for building the reCAPTCHA verification section
  Widget buildRecaptchaVerificationSection() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _buildSectionTitle('Verifikasi reCAPTCHA'),
        SizedBox(height: 16),
        Container(
          padding: EdgeInsets.all(20),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(16),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withOpacity(0.04),
                blurRadius: 15,
                offset: Offset(0, 4),
              ),
            ],
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Container(
                    padding: EdgeInsets.all(8),
                    decoration: BoxDecoration(
                      color: Colors.blue.shade50,
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Icon(
                      Icons.security,
                      size: 18,
                      color: Colors.blue,
                    ),
                  ),
                  SizedBox(width: 12),
                  Expanded(
                    child: Text(
                      'Verifikasi bahwa Anda bukan robot sebelum mengirimkan laporan',
                      style: TextStyle(
                        fontSize: 15,
                        color: Colors.grey[700],
                      ),
                    ),
                  ),
                ],
              ),
              SizedBox(height: 20),

              // Directly display the reCAPTCHA widget in the form itself
              Container(
                width: double.infinity,
                height: 120, // Fixed height to contain the widget
                decoration: BoxDecoration(
                  border: Border.all(color: Colors.grey.shade200),
                  borderRadius: BorderRadius.circular(12),
                  color: Colors.grey.shade50,
                ),
                child: RecaptchaV2(
                  apiKey: "6LeIxAcTAAAAAJcZVRqyHh71UMIEGNQ_MXjiZKhI",
                  apiSecret: "6LeIxAcTAAAAAGG-vFI1TnRWxMZNFuojJ4WifJWe",
                  controller: recaptchaV2Controller,
                  padding: EdgeInsets.all(8),
                  onVerifiedSuccessfully: (success) {
                    setState(() {
                      recaptchaVerified = success;
                      recaptchaError = null;
                    });

                    if (success) {
                      ScaffoldMessenger.of(context).showSnackBar(
                        SnackBar(
                          content: Text('Verifikasi reCAPTCHA berhasil'),
                          behavior: SnackBarBehavior.floating,
                          backgroundColor: Colors.green,
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(10),
                          ),
                          margin: EdgeInsets.all(15),
                        ),
                      );
                    }
                  },
                  onVerifiedError: (err) {
                    print("reCAPTCHA error: $err");
                    setState(() {
                      recaptchaVerified = false;
                      recaptchaError = 'Verifikasi gagal: $err';
                    });
                  },
                ),
              ),

              SizedBox(height: 16),
              Center(
                child: recaptchaVerified
                    ? Container(
                        padding:
                            EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                        decoration: BoxDecoration(
                          color: Colors.green.shade50,
                          borderRadius: BorderRadius.circular(20),
                          border: Border.all(color: Colors.green.shade100),
                        ),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Icon(Icons.check_circle,
                                color: Colors.green, size: 16),
                            SizedBox(width: 8),
                            Text(
                              'Verifikasi berhasil',
                              style: TextStyle(
                                color: Colors.green[700],
                                fontWeight: FontWeight.w500,
                              ),
                            ),
                          ],
                        ),
                      )
                    : Container(
                        padding:
                            EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                        decoration: BoxDecoration(
                          color: Colors.orange.shade50,
                          borderRadius: BorderRadius.circular(20),
                          border: Border.all(color: Colors.orange.shade100),
                        ),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Icon(Icons.info_outline,
                                color: Colors.orange[700], size: 16),
                            SizedBox(width: 8),
                            Text(
                              'Harap selesaikan verifikasi reCAPTCHA',
                              style: TextStyle(
                                color: Colors.orange[700],
                                fontWeight: FontWeight.w500,
                              ),
                            ),
                          ],
                        ),
                      ),
              ),
              if (recaptchaError != null)
                Padding(
                  padding: const EdgeInsets.only(top: 12.0),
                  child: Container(
                    padding: EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: Colors.red.shade50,
                      borderRadius: BorderRadius.circular(8),
                      border: Border.all(color: Colors.red.shade100),
                    ),
                    child: Row(
                      children: [
                        Icon(Icons.error_outline, color: Colors.red, size: 16),
                        SizedBox(width: 8),
                        Expanded(
                          child: Text(
                            recaptchaError!,
                            style: TextStyle(
                              color: Colors.red,
                              fontSize: 13,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
            ],
          ),
        ),
      ],
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      appBar: AppBar(
        title: Text(
          'Laporan Kekerasan Seksual',
          style: TextStyle(
            color: Colors.grey[800],
            fontWeight: FontWeight.w600,
          ),
        ),
        backgroundColor: Colors.white,
        elevation: 0,
        iconTheme: IconThemeData(color: Colors.grey[800]),
        bottom: PreferredSize(
          preferredSize: Size.fromHeight(1),
          child: Container(
            height: 1,
            color: Colors.grey.shade200,
          ),
        ),
      ),
      body: Stack(
        children: [
          SingleChildScrollView(
            physics: ClampingScrollPhysics(),
            child: Padding(
              padding: const EdgeInsets.all(20.0),
              child: Column(
                children: [
                  // Form Card
                  Container(
                    width: double.infinity,
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(16),
                      boxShadow: [
                        BoxShadow(
                          color: Colors.black.withOpacity(0.04),
                          blurRadius: 15,
                          spreadRadius: 1,
                          offset: Offset(0, 5),
                        ),
                      ],
                    ),
                    child: Padding(
                      padding: const EdgeInsets.all(24.0),
                      child: Form(
                        key: _formKey,
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Center(
                              child: Container(
                                padding: EdgeInsets.all(16),
                                decoration: BoxDecoration(
                                  color: Colors.red.shade50,
                                  borderRadius: BorderRadius.circular(16),
                                ),
                                child: Icon(
                                  Icons.privacy_tip_outlined,
                                  color: Colors.red,
                                  size: 40,
                                ),
                              ),
                            ),
                            SizedBox(height: 16),
                            Text(
                              'Laporan Kekerasan Seksual',
                              style: TextStyle(
                                fontSize: 24,
                                fontWeight: FontWeight.bold,
                                color: Colors.grey[800],
                              ),
                              textAlign: TextAlign.center,
                            ),
                            SizedBox(height: 8),
                            Text(
                              'Silakan isi formulir dengan lengkap dan sesuai dengan kejadian yang dialami. Data pelapor akan terjaga kerahasiaannya.',
                              style: TextStyle(
                                fontSize: 14,
                                color: Colors.grey[600],
                              ),
                              textAlign: TextAlign.center,
                            ),
                            SizedBox(height: 32),

                            // Detail Laporan Section
                            _buildSectionTitle('Detail Laporan'),
                            SizedBox(height: 20),
                            _buildFormCard(
                              children: [
                                _buildLabel('Judul Laporan', isRequired: true),
                                SizedBox(height: 8),
                                _buildTextField(
                                  hintText: 'Masukkan judul laporan',
                                  errorText: report['title'].isEmpty
                                      ? 'Masukkan judul laporan'
                                      : null,
                                  onChanged: (value) =>
                                      setState(() => report['title'] = value),
                                  controller: TextEditingController(
                                      text: report['title']),
                                ),
                                SizedBox(height: 20),

                                // Kategori Dropdown
                                _buildLabel('Kategori', isRequired: true),
                                SizedBox(height: 8),
                                _buildDropdownField(
                                  value: report['category'].isEmpty
                                      ? null
                                      : report['category'],
                                  hint: 'Pilih Kategori',
                                  items:
                                      getFilteredCategories().map((category) {
                                    return DropdownMenuItem<String>(
                                      value: category['category_id'].toString(),
                                      child: Text(category['nama']),
                                    );
                                  }).toList(),
                                  errorText: report['category'].isEmpty
                                      ? 'Pilih kategori'
                                      : null,
                                  onChanged: (value) => setState(
                                      () => report['category'] = value!),
                                ),
                                SizedBox(height: 20),

                                // Bukti Pelanggaran Checkboxes
                                _buildLabel('Bukti Pelanggaran',
                                    isRequired: true),
                                SizedBox(height: 8),
                                _buildCheckboxesCard(
                                  children: [
                                    ...buktiOptions.map(
                                      (option) => _buildCheckboxTile(
                                        title: option,
                                        value: selectedBukti.contains(option),
                                        onChanged: (bool? value) {
                                          setState(() {
                                            if (value == true) {
                                              selectedBukti.add(option);
                                            } else {
                                              selectedBukti.remove(option);
                                            }
                                            updateBuktiPelanggaran();
                                            showBuktiWarning =
                                                report['bukti_pelanggaran']
                                                    .isEmpty;
                                          });
                                        },
                                      ),
                                    ),
                                    _buildCheckboxTile(
                                      title: 'Lainnya',
                                      value: showLainnyaInput,
                                      onChanged: (bool? value) {
                                        setState(() {
                                          showLainnyaInput = value ?? false;
                                          updateBuktiPelanggaran();
                                        });
                                      },
                                    ),
                                    if (showLainnyaInput)
                                      Padding(
                                        padding: const EdgeInsets.only(
                                            left: 34.0, top: 8.0, right: 8.0),
                                        child: _buildTextField(
                                          hintText: 'Sebutkan bukti lainnya',
                                          onChanged: (value) {
                                            setState(() {
                                              buktiLainnya = value;
                                              updateBuktiPelanggaran();
                                            });
                                          },
                                        ),
                                      ),
                                    if (showBuktiWarning)
                                      Padding(
                                        padding: const EdgeInsets.only(
                                            top: 8.0, left: 34.0),
                                        child: Text(
                                          'Pilih setidaknya satu bukti pelanggaran',
                                          style: TextStyle(
                                              color: Colors.red, fontSize: 12),
                                        ),
                                      ),
                                  ],
                                ),
                                SizedBox(height: 20),

                                // Link Lampiran
                                _buildLabel('Link Lampiran Tambahan'),
                                SizedBox(height: 4),
                                Text(
                                  'Masukkan URL Google Drive, Dropbox, atau layanan cloud lainnya',
                                  style: TextStyle(
                                    fontSize: 12,
                                    color: Colors.grey[600],
                                    fontStyle: FontStyle.italic,
                                  ),
                                ),
                                SizedBox(height: 8),
                                _buildTextField(
                                  hintText: 'https://',
                                  onChanged: (value) =>
                                      report['lampiran_link'] = value,
                                  prefixIcon: Icons.link,
                                ),
                                SizedBox(height: 20),

                                // Deskripsi Laporan
                                _buildLabel('Deskripsi', isRequired: true),
                                SizedBox(height: 8),
                                _buildTextField(
                                  hintText:
                                      'Berikan Deskripsi atau Kronologi Kejadian',
                                  errorText: report['description'].isEmpty
                                      ? 'Masukkan deskripsi laporan'
                                      : null,
                                  onChanged: (value) =>
                                      report['description'] = value,
                                  maxLines: 5,
                                ),
                                SizedBox(height: 20),

                                // Tanggal & Waktu Kejadian
                                _buildLabel('Tanggal & Waktu Kejadian',
                                    isRequired: true),
                                SizedBox(height: 8),
                                GestureDetector(
                                  onTap: () async {
                                    final DateTime? pickedDate =
                                        await showDatePicker(
                                      context: context,
                                      initialDate: report['incidentDate'] ??
                                          DateTime.now(),
                                      firstDate: DateTime(2000),
                                      lastDate: DateTime.now(),
                                      builder: (context, child) {
                                        return Theme(
                                          data: Theme.of(context).copyWith(
                                            colorScheme: ColorScheme.light(
                                              primary: Colors.red,
                                              onPrimary: Colors.white,
                                              surface: Colors.white,
                                              onSurface: Colors.grey[800]!,
                                            ),
                                            dialogBackgroundColor: Colors.white,
                                          ),
                                          child: child!,
                                        );
                                      },
                                    );

                                    if (pickedDate != null) {
                                      final TimeOfDay? pickedTime =
                                          await showTimePicker(
                                        context: context,
                                        initialTime: TimeOfDay.fromDateTime(
                                            report['incidentDate'] ??
                                                DateTime.now()),
                                        builder: (context, child) {
                                          return Theme(
                                            data: Theme.of(context).copyWith(
                                              colorScheme: ColorScheme.light(
                                                primary: Colors.red,
                                                onPrimary: Colors.white,
                                                surface: Colors.white,
                                                onSurface: Colors.grey[800]!,
                                              ),
                                              dialogBackgroundColor:
                                                  Colors.white,
                                            ),
                                            child: child!,
                                          );
                                        },
                                      );

                                      if (pickedTime != null) {
                                        setState(() {
                                          report['incidentDate'] = DateTime(
                                            pickedDate.year,
                                            pickedDate.month,
                                            pickedDate.day,
                                            pickedTime.hour,
                                            pickedTime.minute,
                                          );
                                        });
                                      }
                                    }
                                  },
                                  child: Container(
                                    width: double.infinity,
                                    padding: EdgeInsets.symmetric(
                                        vertical: 15, horizontal: 16),
                                    decoration: BoxDecoration(
                                      color: Colors.white,
                                      borderRadius: BorderRadius.circular(12),
                                      border: Border.all(
                                          color: Colors.grey.shade300),
                                    ),
                                    child: Row(
                                      mainAxisAlignment:
                                          MainAxisAlignment.spaceBetween,
                                      children: [
                                        Text(
                                          report['incidentDate'] != null
                                              ? "${report['incidentDate'].toLocal()}"
                                                  .split('.')[0]
                                              : "Pilih Tanggal & Waktu",
                                          style: TextStyle(
                                            color:
                                                report['incidentDate'] != null
                                                    ? Colors.grey[800]
                                                    : Colors.grey[500],
                                            fontSize: 15,
                                          ),
                                        ),
                                        Icon(
                                          Icons.calendar_today,
                                          size: 18,
                                          color: Colors.grey[500],
                                        ),
                                      ],
                                    ),
                                  ),
                                ),
                              ],
                            ),
                            SizedBox(height: 24),

                            // Multiple Image Upload
                            _buildSectionTitle('Lampiran Foto'),
                            SizedBox(height: 20),
                            _buildFormCard(
                              children: [
                                GestureDetector(
                                  onTap: handleFileUpload,
                                  child: Container(
                                    height: 160,
                                    width: double.infinity,
                                    decoration: BoxDecoration(
                                      borderRadius: BorderRadius.circular(12),
                                      color: Colors.grey.shade50,
                                      border: Border.all(
                                        color: Colors.grey.shade300,
                                        width: 1,
                                      ),
                                    ),
                                    child: Center(
                                      child: Column(
                                        mainAxisAlignment:
                                            MainAxisAlignment.center,
                                        children: [
                                          Container(
                                            padding: EdgeInsets.all(16),
                                            decoration: BoxDecoration(
                                              color: Colors.grey.shade100,
                                              shape: BoxShape.circle,
                                            ),
                                            child: Icon(
                                              Icons.cloud_upload_outlined,
                                              size: 40,
                                              color: Colors.grey.shade500,
                                            ),
                                          ),
                                          SizedBox(height: 16),
                                          Text(
                                            'Klik untuk memilih beberapa file foto',
                                            style: TextStyle(
                                              color: Colors.grey.shade700,
                                              fontWeight: FontWeight.w500,
                                              fontSize: 15,
                                            ),
                                          ),
                                          SizedBox(height: 6),
                                          Text(
                                            'Format: JPG, PNG, GIF (Maks 5MB)',
                                            style: TextStyle(
                                              fontSize: 13,
                                              color: Colors.grey.shade600,
                                            ),
                                          ),
                                        ],
                                      ),
                                    ),
                                  ),
                                ),

                                // Image Previews
                                if (imagePreviewBytes.isNotEmpty) ...[
                                  SizedBox(height: 20),
                                  Row(
                                    children: [
                                      Container(
                                        padding: EdgeInsets.all(6),
                                        decoration: BoxDecoration(
                                          color: Colors.blue.shade50,
                                          borderRadius:
                                              BorderRadius.circular(6),
                                        ),
                                        child: Icon(
                                          Icons.photo_library_outlined,
                                          size: 16,
                                          color: Colors.blue,
                                        ),
                                      ),
                                      SizedBox(width: 8),
                                      Text(
                                        'Preview Foto (${imagePreviewBytes.length} file)',
                                        style: TextStyle(
                                          fontSize: 15,
                                          fontWeight: FontWeight.w500,
                                          color: Colors.grey[700],
                                        ),
                                      ),
                                    ],
                                  ),
                                  SizedBox(height: 12),
                                  GridView.builder(
                                    shrinkWrap: true,
                                    physics: NeverScrollableScrollPhysics(),
                                    gridDelegate:
                                        SliverGridDelegateWithFixedCrossAxisCount(
                                      crossAxisCount: 3,
                                      crossAxisSpacing: 12,
                                      mainAxisSpacing: 12,
                                      childAspectRatio: 1,
                                    ),
                                    itemCount: imagePreviewBytes.length,
                                    itemBuilder: (context, index) {
                                      return Container(
                                        decoration: BoxDecoration(
                                          borderRadius:
                                              BorderRadius.circular(12),
                                          boxShadow: [
                                            BoxShadow(
                                              color: Colors.black
                                                  .withOpacity(0.05),
                                              blurRadius: 5,
                                              offset: Offset(0, 2),
                                            ),
                                          ],
                                        ),
                                        child: Stack(
                                          children: [
                                            ClipRRect(
                                              borderRadius:
                                                  BorderRadius.circular(12),
                                              child: Image.memory(
                                                imagePreviewBytes[index],
                                                fit: BoxFit.cover,
                                                width: double.infinity,
                                                height: double.infinity,
                                              ),
                                            ),
                                            Positioned(
                                              top: 6,
                                              right: 6,
                                              child: GestureDetector(
                                                onTap: () => removeImage(index),
                                                child: Container(
                                                  padding: EdgeInsets.all(4),
                                                  decoration: BoxDecoration(
                                                    color: Colors.black
                                                        .withOpacity(0.5),
                                                    shape: BoxShape.circle,
                                                  ),
                                                  child: Icon(
                                                    Icons.close,
                                                    size: 16,
                                                    color: Colors.white,
                                                  ),
                                                ),
                                              ),
                                            ),
                                          ],
                                        ),
                                      );
                                    },
                                  ),
                                ],
                              ],
                            ),
                            SizedBox(height: 24),

                            // Informasi Pelapor Section
                            _buildSectionTitle('Informasi Pelapor'),
                            SizedBox(height: 20),
                            _buildFormCard(
                              children: [
                                // Nama Pelapor
                                _buildLabel('Nama Pelapor', isRequired: true),
                                SizedBox(height: 8),
                                _buildTextField(
                                  controller: TextEditingController(
                                      text: report['reporterName']),
                                  hintText: 'Masukkan nama pelapor',
                                  errorText: report['reporterName'].isEmpty
                                      ? 'Masukkan nama pelapor'
                                      : null,
                                  onChanged: (value) =>
                                      report['reporterName'] = value,
                                ),
                                SizedBox(height: 20),

                                // NIM Pelapor
                                _buildLabel('NIM Pelapor', isRequired: true),
                                SizedBox(height: 8),
                                _buildTextField(
                                  controller: TextEditingController(
                                      text: report['nim']),
                                  hintText: 'Masukkan NIM pelapor',
                                  errorText: report['nim'].isEmpty
                                      ? 'Masukkan NIM pelapor'
                                      : null,
                                  onChanged: (value) => report['nim'] = value,
                                ),
                                SizedBox(height: 20),

                                // Nomor HP Pelapor
                                _buildLabel('Nomor HP Pelapor',
                                    isRequired: true),
                                SizedBox(height: 8),
                                _buildTextField(
                                  controller: TextEditingController(
                                      text: report['phone']),
                                  hintText: 'Masukkan nomor HP pelapor',
                                  keyboardType: TextInputType.phone,
                                  errorText: report['phone'].isEmpty
                                      ? 'Masukkan nomor HP pelapor'
                                      : null,
                                  onChanged: (value) => report['phone'] = value,
                                ),
                                SizedBox(height: 20),

                                // Profesi
                                _buildLabel('Profesi', isRequired: true),
                                SizedBox(height: 8),
                                _buildDropdownField(
                                  value: report['profesi'].isEmpty
                                      ? null
                                      : report['profesi'],
                                  hint: 'Pilih Profesi',
                                  items: [
                                    DropdownMenuItem(
                                        value: 'dosen', child: Text('Dosen')),
                                    DropdownMenuItem(
                                        value: 'mahasiswa',
                                        child: Text('Mahasiswa')),
                                    DropdownMenuItem(
                                        value: 'staff', child: Text('Staff')),
                                    DropdownMenuItem(
                                        value: 'lainnya',
                                        child: Text('Lainnya')),
                                  ],
                                  errorText: report['profesi'].isEmpty
                                      ? 'Pilih profesi'
                                      : null,
                                  onChanged: (value) => setState(
                                      () => report['profesi'] = value!),
                                ),
                                SizedBox(height: 20),

                                // Jenis Kelamin
                                _buildLabel('Jenis Kelamin', isRequired: true),
                                SizedBox(height: 8),
                                _buildRadioGroup(
                                  options: [
                                    {
                                      'value': 'laki-laki',
                                      'label': 'Laki-laki'
                                    },
                                    {
                                      'value': 'perempuan',
                                      'label': 'Perempuan'
                                    },
                                  ],
                                  groupValue: report['jenis_kelamin'],
                                  onChanged: (value) {
                                    setState(
                                        () => report['jenis_kelamin'] = value!);
                                  },
                                ),
                                SizedBox(height: 20),

                                // Umur Pelapor
                                _buildLabel('Rentang Umur', isRequired: true),
                                SizedBox(height: 8),
                                _buildRadioGroup(
                                  options: [
                                    {
                                      'value': '<20',
                                      'label': 'Kurang dari 20 tahun'
                                    },
                                    {
                                      'value': '20-40',
                                      'label': '20 - 40 tahun'
                                    },
                                    {
                                      'value': '40<',
                                      'label': 'Lebih dari 40 tahun'
                                    },
                                  ],
                                  groupValue: report['umur_pelapor'],
                                  onChanged: (value) {
                                    setState(
                                        () => report['umur_pelapor'] = value!);
                                  },
                                ),
                              ],
                            ),
                            SizedBox(height: 24),

                            // Informasi Terduga/Terlapor Section
                            _buildSectionTitle('Informasi Terduga/Terlapor'),
                            SizedBox(height: 16),
                            // Anonymous Instruction Info Box
                            Container(
                              padding: EdgeInsets.all(16),
                              decoration: BoxDecoration(
                                color: Colors.blue.shade50,
                                borderRadius: BorderRadius.circular(12),
                              ),
                              child: Row(
                                children: [
                                  Container(
                                    padding: EdgeInsets.all(8),
                                    decoration: BoxDecoration(
                                      color: Colors.blue.shade100,
                                      shape: BoxShape.circle,
                                    ),
                                    child: Icon(
                                      Icons.info_outline,
                                      color: Colors.blue.shade700,
                                      size: 20,
                                    ),
                                  ),
                                  SizedBox(width: 16),
                                  Expanded(
                                    child: Text(
                                      'Jika terduga adalah anonim, berikan inputan "anonim" untuk nama dan "anonim@gmail.com" untuk email.',
                                      style: TextStyle(
                                        color: Colors.blue.shade800,
                                        height: 1.4,
                                      ),
                                    ),
                                  ),
                                ],
                              ),
                            ),
                            SizedBox(height: 20),

                            // Terduga/Terlapor List
                            ...List.generate(report['terlapor'].length,
                                (index) {
                              return _buildTerdugaCard(index);
                            }),

                            // Add Terduga Button
                            SizedBox(height: 16),
                            Center(
                              child: _buildOutlinedButton(
                                icon: Icons.add,
                                text: 'Tambah Terduga/Terlapor',
                                onPressed: addTerduga,
                              ),
                            ),
                            SizedBox(height: 24),

                            // Informasi Saksi Section
                            _buildSectionTitle('Informasi Saksi'),
                            SizedBox(height: 20),
                            // Saksi List
                            ...List.generate(report['saksi'].length, (index) {
                              return _buildSaksiCard(index);
                            }),

                            // Add Saksi Button
                            SizedBox(height: 16),
                            Center(
                              child: _buildOutlinedButton(
                                icon: Icons.add,
                                text: 'Tambah Saksi',
                                onPressed: addSaksi,
                              ),
                            ),
                            SizedBox(height: 24),

                            buildRecaptchaVerificationSection(),
                            SizedBox(height: 24),

                            // Pernyataan Section
                            _buildSectionTitle('Pernyataan'),
                            SizedBox(height: 20),
                            _buildFormCard(
                              children: [
                                Text(
                                  'Dengan ini saya menyatakan bahwa:',
                                  style: TextStyle(
                                    fontSize: 16,
                                    fontWeight: FontWeight.w600,
                                    color: Colors.grey[800],
                                  ),
                                ),
                                SizedBox(height: 16),
                                _buildNumberedItem(1,
                                    'Segala informasi yang saya berikan dalam laporan ini adalah benar dan dapat dipertanggungjawabkan.'),
                                _buildNumberedItem(2,
                                    'Saya bersedia memberikan keterangan lebih lanjut apabila diperlukan untuk proses penanganan laporan.'),
                                _buildNumberedItem(3,
                                    'Saya memahami bahwa memberikan laporan palsu dapat dikenakan sanksi sesuai dengan peraturan yang berlaku.'),
                                SizedBox(height: 20),
                                Container(
                                  padding: EdgeInsets.symmetric(
                                      horizontal: 16, vertical: 12),
                                  decoration: BoxDecoration(
                                    color: report['agreement'] == true
                                        ? Colors.green.shade50
                                        : Colors.grey.shade50,
                                    borderRadius: BorderRadius.circular(12),
                                    border: Border.all(
                                      color: showAgreementWarning
                                          ? Colors.red
                                          : report['agreement'] == true
                                              ? Colors.green.shade200
                                              : Colors.grey.shade300,
                                    ),
                                  ),
                                  child: Row(
                                    children: [
                                      SizedBox(
                                        width: 24,
                                        height: 24,
                                        child: Checkbox(
                                          value: report['agreement'] == true,
                                          onChanged: (bool? value) {
                                            setState(() {
                                              report['agreement'] =
                                                  value ?? false;
                                              showAgreementWarning = false;
                                            });
                                          },
                                          activeColor: Colors.green,
                                          shape: RoundedRectangleBorder(
                                            borderRadius:
                                                BorderRadius.circular(4),
                                          ),
                                        ),
                                      ),
                                      SizedBox(width: 12),
                                      Expanded(
                                        child: Text(
                                          'Saya menyetujui pernyataan di atas',
                                          style: TextStyle(
                                            fontSize: 15,
                                            color: Colors.grey[800],
                                            fontWeight:
                                                report['agreement'] == true
                                                    ? FontWeight.w500
                                                    : FontWeight.normal,
                                          ),
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                                if (showAgreementWarning)
                                  Padding(
                                    padding:
                                        const EdgeInsets.only(top: 8, left: 12),
                                    child: Text(
                                      'Anda harus menyetujui pernyataan ini untuk melanjutkan',
                                      style: TextStyle(
                                          color: Colors.red, fontSize: 12),
                                    ),
                                  ),
                              ],
                            ),
                            SizedBox(height: 32),

                            // Form Actions
                            Row(
                              mainAxisAlignment: MainAxisAlignment.end,
                              children: [
                                TextButton(
                                  onPressed: () {
                                    Navigator.of(context).pop();
                                  },
                                  style: TextButton.styleFrom(
                                    foregroundColor: Colors.grey[700],
                                    padding: EdgeInsets.symmetric(
                                        horizontal: 20, vertical: 12),
                                  ),
                                  child: Text('Batal'),
                                ),
                                SizedBox(width: 16),
                                ElevatedButton(
                                  onPressed: (!report['agreement'] ||
                                          !recaptchaVerified ||
                                          isSubmitting)
                                      ? null
                                      : submitForm,
                                  style: ElevatedButton.styleFrom(
                                    backgroundColor: Colors.red[600],
                                    foregroundColor: Colors.white,
                                    elevation: 0,
                                    padding: EdgeInsets.symmetric(
                                        horizontal: 24, vertical: 12),
                                    shape: RoundedRectangleBorder(
                                      borderRadius: BorderRadius.circular(8),
                                    ),
                                    disabledBackgroundColor: Colors.grey[300],
                                    disabledForegroundColor: Colors.grey[500],
                                  ),
                                  child: isSubmitting
                                      ? Row(
                                          mainAxisSize: MainAxisSize.min,
                                          children: [
                                            SizedBox(
                                              height: 16,
                                              width: 16,
                                              child: CircularProgressIndicator(
                                                strokeWidth: 2,
                                                valueColor:
                                                    AlwaysStoppedAnimation<
                                                        Color>(Colors.white),
                                              ),
                                            ),
                                            SizedBox(width: 12),
                                            Text(
                                              'Mengirim...',
                                              style: TextStyle(
                                                fontWeight: FontWeight.w600,
                                              ),
                                            ),
                                          ],
                                        )
                                      : Text(
                                          'Simpan Laporan',
                                          style: TextStyle(
                                            fontWeight: FontWeight.w600,
                                          ),
                                        ),
                                ),
                              ],
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),
                  SizedBox(height: 40),
                ],
              ),
            ),
          ),
          // Loading overlay
          if (isSubmitting)
            Container(
              color: Colors.black.withOpacity(0.3),
              child: Center(
                child: Container(
                  padding: EdgeInsets.all(24),
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(16),
                    boxShadow: [
                      BoxShadow(
                        color: Colors.black.withOpacity(0.1),
                        blurRadius: 20,
                        offset: Offset(0, 10),
                      ),
                    ],
                  ),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      CircularProgressIndicator(
                        valueColor: AlwaysStoppedAnimation<Color>(Colors.red),
                      ),
                      SizedBox(height: 16),
                      Text(
                        'Mengirimkan laporan...',
                        style: TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.w500,
                          color: Colors.grey[800],
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
        ],
      ),
    );
  }

  Widget _buildSectionTitle(String title) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          title,
          style: TextStyle(
            fontSize: 20,
            fontWeight: FontWeight.bold,
            color: Colors.grey[800],
          ),
        ),
        SizedBox(height: 6),
        Container(
          width: 40,
          height: 3,
          decoration: BoxDecoration(
            color: Colors.red.shade600,
            borderRadius: BorderRadius.circular(10),
          ),
        ),
      ],
    );
  }

  Widget _buildFormCard({required List<Widget> children}) {
    return Container(
      width: double.infinity,
      padding: EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.03),
            blurRadius: 12,
            spreadRadius: 0,
            offset: Offset(0, 3),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: children,
      ),
    );
  }

  Widget _buildNumberedItem(int number, String text) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            padding: EdgeInsets.all(6),
            decoration: BoxDecoration(
              color: Colors.red.shade50,
              shape: BoxShape.circle,
            ),
            child: Text(
              '$number',
              style: TextStyle(
                color: Colors.red,
                fontWeight: FontWeight.bold,
                fontSize: 12,
              ),
            ),
          ),
          SizedBox(width: 12),
          Expanded(
            child: Text(
              text,
              style: TextStyle(
                color: Colors.grey[700],
                height: 1.5,
                fontSize: 14,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildLabel(String label, {bool isRequired = false}) {
    return Row(
      children: [
        Text(
          label,
          style: TextStyle(
            fontWeight: FontWeight.w500,
            fontSize: 15,
            color: Colors.grey[700],
          ),
        ),
        if (isRequired)
          Text(
            ' *',
            style: TextStyle(
              color: Colors.red,
              fontWeight: FontWeight.bold,
              fontSize: 16,
            ),
          ),
      ],
    );
  }

  Widget _buildTextField({
    TextEditingController? controller,
    required String hintText,
    String? errorText,
    Function(String)? onChanged,
    TextInputType? keyboardType,
    int? maxLines = 1,
    bool readOnly = false,
    IconData? prefixIcon,
  }) {
    return Container(
      decoration: BoxDecoration(
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.01),
            blurRadius: 4,
            offset: Offset(0, 2),
          ),
        ],
      ),
      child: TextFormField(
        controller: controller,
        maxLines: maxLines,
        keyboardType: keyboardType,
        readOnly: readOnly,
        onChanged: onChanged,
        decoration: InputDecoration(
          hintText: hintText,
          hintStyle: TextStyle(color: Colors.grey[400], fontSize: 14),
          errorText: errorText,
          errorStyle: TextStyle(color: Colors.red, fontSize: 12),
          contentPadding: EdgeInsets.symmetric(
            horizontal: 16,
            vertical: maxLines! > 1 ? 16 : 15,
          ),
          filled: true,
          fillColor: Colors.white,
          border: OutlineInputBorder(
            borderRadius: BorderRadius.circular(12),
            borderSide: BorderSide(color: Colors.grey.shade300),
          ),
          enabledBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(12),
            borderSide: BorderSide(
                color: errorText != null ? Colors.red : Colors.grey.shade300),
          ),
          focusedBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(12),
            borderSide: BorderSide(
              color: errorText != null ? Colors.red : Colors.red.shade400,
              width: 1.5,
            ),
          ),
          prefixIcon: prefixIcon != null
              ? Icon(prefixIcon, color: Colors.grey.shade500, size: 18)
              : null,
        ),
        style: TextStyle(
          fontSize: 15,
          color: Colors.grey[800],
        ),
      ),
    );
  }

  Widget _buildDropdownField({
    required String? value,
    required String hint,
    required List<DropdownMenuItem<String>> items,
    required Function(String?) onChanged,
    String? errorText,
  }) {
    return Container(
      decoration: BoxDecoration(
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.01),
            blurRadius: 4,
            offset: Offset(0, 2),
          ),
        ],
      ),
      child: DropdownButtonFormField<String>(
        value: value,
        hint: Text(
          hint,
          style: TextStyle(color: Colors.grey[400], fontSize: 14),
        ),
        items: items,
        onChanged: onChanged,
        decoration: InputDecoration(
          errorText: errorText,
          errorStyle: TextStyle(color: Colors.red, fontSize: 12),
          contentPadding: EdgeInsets.symmetric(
            horizontal: 16,
            vertical: 15,
          ),
          filled: true,
          fillColor: Colors.white,
          border: OutlineInputBorder(
            borderRadius: BorderRadius.circular(12),
            borderSide: BorderSide(color: Colors.grey.shade300),
          ),
          enabledBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(12),
            borderSide: BorderSide(
                color: errorText != null ? Colors.red : Colors.grey.shade300),
          ),
          focusedBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(12),
            borderSide: BorderSide(
              color: errorText != null ? Colors.red : Colors.red.shade400,
              width: 1.5,
            ),
          ),
        ),
        style: TextStyle(
          fontSize: 15,
          color: Colors.grey[800],
        ),
        icon: Icon(
          Icons.keyboard_arrow_down,
          color: Colors.grey.shade600,
        ),
        isExpanded: true,
        dropdownColor: Colors.white,
      ),
    );
  }

  Widget _buildCheckboxesCard({required List<Widget> children}) {
    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
            color: showBuktiWarning ? Colors.red : Colors.grey.shade300),
      ),
      child: Padding(
        padding: EdgeInsets.only(top: 8.0, bottom: 8.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: children,
        ),
      ),
    );
  }

  Widget _buildCheckboxTile({
    required String title,
    required bool value,
    required Function(bool?) onChanged,
  }) {
    return Theme(
      data: ThemeData(
        checkboxTheme: CheckboxThemeData(
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(4),
          ),
        ),
      ),
      child: CheckboxListTile(
        title: Text(
          title,
          style: TextStyle(
            fontSize: 14,
            color: Colors.grey[800],
            fontWeight: value ? FontWeight.w500 : FontWeight.normal,
          ),
        ),
        value: value,
        onChanged: onChanged,
        activeColor: Colors.red.shade600,
        controlAffinity: ListTileControlAffinity.leading,
        contentPadding: EdgeInsets.symmetric(horizontal: 12, vertical: 4),
        dense: true,
        tileColor: value ? Colors.red.shade50 : Colors.transparent,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(8),
        ),
      ),
    );
  }

  Widget _buildRadioGroup({
    required List<Map<String, String>> options,
    required String? groupValue,
    required Function(String?) onChanged,
  }) {
    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.grey.shade300),
      ),
      child: Column(
        children: options.map((option) {
          final bool isSelected = groupValue == option['value'];
          return Container(
            decoration: BoxDecoration(
              color: isSelected ? Colors.red.shade50 : Colors.white,
              borderRadius: options.indexOf(option) == 0
                  ? BorderRadius.only(
                      topLeft: Radius.circular(12),
                      topRight: Radius.circular(12),
                    )
                  : options.indexOf(option) == options.length - 1
                      ? BorderRadius.only(
                          bottomLeft: Radius.circular(12),
                          bottomRight: Radius.circular(12),
                        )
                      : null,
              border: Border(
                bottom: options.indexOf(option) != options.length - 1
                    ? BorderSide(color: Colors.grey.shade200)
                    : BorderSide.none,
              ),
            ),
            child: RadioListTile<String>(
              title: Text(
                option['label']!,
                style: TextStyle(
                  fontSize: 14,
                  fontWeight: isSelected ? FontWeight.w500 : FontWeight.normal,
                  color: Colors.grey[800],
                ),
              ),
              value: option['value']!,
              groupValue: groupValue,
              onChanged: onChanged,
              activeColor: Colors.red.shade600,
              contentPadding: EdgeInsets.symmetric(horizontal: 12, vertical: 8),
              dense: true,
              selected: isSelected,
              selectedTileColor: Colors.red.shade50,
            ),
          );
        }).toList(),
      ),
    );
  }

  Widget _buildOutlinedButton({
    required IconData icon,
    required String text,
    required VoidCallback onPressed,
  }) {
    return OutlinedButton.icon(
      onPressed: onPressed,
      icon: Icon(icon, size: 18),
      label: Text(text),
      style: OutlinedButton.styleFrom(
        foregroundColor: Colors.red.shade700,
        side: BorderSide(color: Colors.red.shade300),
        padding: EdgeInsets.symmetric(horizontal: 20, vertical: 12),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(12),
        ),
      ),
    );
  }

  Widget _buildTerdugaCard(int index) {
    final Map<String, dynamic> terduga = report['terlapor'][index];

    return Container(
      width: double.infinity,
      margin: EdgeInsets.only(bottom: 16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.03),
            blurRadius: 12,
            spreadRadius: 0,
            offset: Offset(0, 3),
          ),
        ],
      ),
      child: Padding(
        padding: const EdgeInsets.all(20.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Container(
                  padding: EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                  decoration: BoxDecoration(
                    color: Colors.amber.shade50,
                    borderRadius: BorderRadius.circular(20),
                    border: Border.all(color: Colors.amber.shade200),
                  ),
                  child: Text(
                    'Terlapor ${index + 1}',
                    style: TextStyle(
                      fontSize: 13,
                      fontWeight: FontWeight.w600,
                      color: Colors.amber.shade800,
                    ),
                  ),
                ),
                IconButton(
                  icon: Container(
                    padding: EdgeInsets.all(4),
                    decoration: BoxDecoration(
                      color: Colors.red.shade50,
                      shape: BoxShape.circle,
                    ),
                    child: Icon(
                      Icons.delete_outline,
                      color: Colors.red.shade700,
                      size: 16,
                    ),
                  ),
                  onPressed: () => removeTerduga(index),
                  tooltip: 'Hapus Terduga',
                  constraints: BoxConstraints(),
                  padding: EdgeInsets.all(4),
                ),
              ],
            ),
            SizedBox(height: 16),

            // Nama Terduga
            _buildLabel('Nama Lengkap', isRequired: true),
            SizedBox(height: 8),
            _buildTextField(
              controller: TextEditingController(text: terduga['nama_lengkap']),
              hintText: "Masukkan nama atau 'anonim'",
              onChanged: (value) =>
                  setState(() => terduga['nama_lengkap'] = value),
            ),
            SizedBox(height: 16),

            // Email Terduga
            _buildLabel('Email'),
            SizedBox(height: 8),
            _buildTextField(
              controller: TextEditingController(text: terduga['email']),
              hintText: "Masukkan email atau 'anonim@gmail.com'",
              keyboardType: TextInputType.emailAddress,
              onChanged: (value) => setState(() => terduga['email'] = value),
            ),
            SizedBox(height: 16),

            // Nomor Telepon Terduga
            _buildLabel('Nomor Telepon'),
            SizedBox(height: 8),
            _buildTextField(
              controller: TextEditingController(text: terduga['nomor_telepon']),
              hintText: "Masukkan nomor telepon",
              keyboardType: TextInputType.phone,
              onChanged: (value) =>
                  setState(() => terduga['nomor_telepon'] = value),
            ),
            SizedBox(height: 16),

            // Jenis Kelamin
            _buildLabel('Jenis Kelamin', isRequired: true),
            SizedBox(height: 8),
            _buildRadioGroup(
              options: [
                {'value': 'laki-laki', 'label': 'Laki-laki'},
                {'value': 'perempuan', 'label': 'Perempuan'},
              ],
              groupValue: terduga['jenis_kelamin'],
              onChanged: (value) {
                setState(() => terduga['jenis_kelamin'] = value);
              },
            ),
            SizedBox(height: 16),

            // Rentang Umur Terduga
            _buildLabel('Rentang Umur', isRequired: true),
            SizedBox(height: 8),
            _buildRadioGroup(
              options: [
                {'value': '<20', 'label': 'Kurang dari 20 tahun'},
                {'value': '20-40', 'label': '20 - 40 tahun'},
                {'value': '40<', 'label': 'Lebih dari 40 tahun'},
              ],
              groupValue: terduga['umur_terlapor'],
              onChanged: (value) {
                setState(() => terduga['umur_terlapor'] = value);
              },
            ),
            SizedBox(height: 16),

            // Status Warga
            _buildLabel('Status Warga', isRequired: true),
            SizedBox(height: 8),
            _buildDropdownField(
              value: terduga['status_warga'].isEmpty
                  ? null
                  : terduga['status_warga'],
              hint: 'Pilih Status',
              items: [
                DropdownMenuItem(value: 'dosen', child: Text('Dosen')),
                DropdownMenuItem(value: 'mahasiswa', child: Text('Mahasiswa')),
                DropdownMenuItem(value: 'staff', child: Text('Staff')),
                DropdownMenuItem(value: 'lainnya', child: Text('Lainnya')),
              ],
              onChanged: (value) =>
                  setState(() => terduga['status_warga'] = value!),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildSaksiCard(int index) {
    final Map<String, dynamic> saksi = report['saksi'][index];

    return Container(
      width: double.infinity,
      margin: EdgeInsets.only(bottom: 16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.03),
            blurRadius: 12,
            spreadRadius: 0,
            offset: Offset(0, 3),
          ),
        ],
      ),
      child: Padding(
        padding: const EdgeInsets.all(20.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Container(
                  padding: EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                  decoration: BoxDecoration(
                    color: Colors.green.shade50,
                    borderRadius: BorderRadius.circular(20),
                    border: Border.all(color: Colors.green.shade200),
                  ),
                  child: Text(
                    'Saksi ${index + 1}',
                    style: TextStyle(
                      fontSize: 13,
                      fontWeight: FontWeight.w600,
                      color: Colors.green.shade800,
                    ),
                  ),
                ),
                IconButton(
                  icon: Container(
                    padding: EdgeInsets.all(4),
                    decoration: BoxDecoration(
                      color: Colors.red.shade50,
                      shape: BoxShape.circle,
                    ),
                    child: Icon(
                      Icons.delete_outline,
                      color: Colors.red.shade700,
                      size: 16,
                    ),
                  ),
                  onPressed: () => removeSaksi(index),
                  tooltip: 'Hapus Saksi',
                  constraints: BoxConstraints(),
                  padding: EdgeInsets.all(4),
                ),
              ],
            ),
            SizedBox(height: 16),

            // Nama Saksi
            _buildLabel('Nama Lengkap Saksi', isRequired: true),
            SizedBox(height: 8),
            _buildTextField(
              controller: TextEditingController(text: saksi['nama_lengkap']),
              hintText: "Masukkan nama lengkap saksi",
              onChanged: (value) =>
                  setState(() => saksi['nama_lengkap'] = value),
            ),
            SizedBox(height: 16),

            // Email Saksi
            _buildLabel('Email Saksi', isRequired: true),
            SizedBox(height: 8),
            _buildTextField(
              controller: TextEditingController(text: saksi['email']),
              hintText: "Masukkan email saksi",
              keyboardType: TextInputType.emailAddress,
              onChanged: (value) => setState(() => saksi['email'] = value),
            ),
            SizedBox(height: 16),

            // Nomor Telepon Saksi
            _buildLabel('Nomor Telepon Saksi', isRequired: true),
            SizedBox(height: 8),
            _buildTextField(
              controller: TextEditingController(text: saksi['nomor_telepon']),
              hintText: "Masukkan nomor telepon saksi",
              keyboardType: TextInputType.phone,
              onChanged: (value) =>
                  setState(() => saksi['nomor_telepon'] = value),
            ),
          ],
        ),
      ),
    );
  }
}
