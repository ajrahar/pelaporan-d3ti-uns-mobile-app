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

class AddKSPublicPage extends StatefulWidget {
  const AddKSPublicPage({Key? key}) : super(key: key);

  @override
  _AddKSPublicPageState createState() => _AddKSPublicPageState();
}

class _AddKSPublicPageState extends State<AddKSPublicPage> {
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

  // Theme colors
  final Color primaryColor = Color.fromARGB(255, 192, 92, 92); // Indigo color
  final Color accentColor = Color(0xFFEC407A); // Pink accent
  final Color backgroundColor = Colors.white;
  final Color cardColor = Colors.white;
  final Color textColor = Color(0xFF37474F);
  final Color errorColor = Color(0xFFE53935);
  final Color successColor = Color(0xFF43A047);
  final Color infoColor = Color(0xFF1E88E5);
  final Color warningColor = Color(0xFFFFA000);
  final Color dividerColor = Color(0xFFEEEEEE);

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
                      content: Text('reCAPTCHA verification successful'),
                      backgroundColor: successColor,
                    ),
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
        SnackBar(
          content: Text('Failed to load categories: $e'),
          backgroundColor: errorColor,
        ),
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
        'jenis_kelamin': '',
        'umur_terlapor': '',
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
          shape:
              RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
          title: Row(
            children: [
              Icon(Icons.check_circle, color: successColor),
              SizedBox(width: 10),
              Text('Sukses!', style: TextStyle(color: textColor)),
            ],
          ),
          content: const Text('Laporan berhasil dikirimkan'),
          actions: <Widget>[
            TextButton(
              onPressed: () {
                Navigator.of(context).pop();
              },
              style: TextButton.styleFrom(foregroundColor: primaryColor),
              child: const Text('OK'),
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
          shape:
              RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
          title: Row(
            children: [
              Icon(Icons.error_outline, color: errorColor),
              SizedBox(width: 10),
              Text(title, style: TextStyle(color: textColor)),
            ],
          ),
          content: Text(message),
          actions: <Widget>[
            TextButton(
              onPressed: () {
                Navigator.of(context).pop();
              },
              style: TextButton.styleFrom(foregroundColor: primaryColor),
              child: const Text('OK'),
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
          padding: EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: Colors.grey[50],
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: dividerColor, width: 1),
            boxShadow: [
              BoxShadow(
                color: Colors.grey.withOpacity(0.05),
                spreadRadius: 1,
                blurRadius: 5,
                offset: Offset(0, 2),
              ),
            ],
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Icon(Icons.security, color: primaryColor, size: 20),
                  SizedBox(height: 8),
                  Text(
                    'Verifikasi bahwa Anda bukan robot sebelum mengirimkan laporan',
                    style: TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.w500,
                      color: textColor,
                    ),
                  ),
                ],
              ),
              SizedBox(height: 16),

              // Directly display the reCAPTCHA widget in the form itself
              Container(
                width: double.infinity,
                height: 120, // Fixed height to contain the widget
                decoration: BoxDecoration(
                  border: Border.all(color: dividerColor),
                  borderRadius: BorderRadius.circular(8),
                  color: Colors.white,
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
                          backgroundColor: successColor,
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
                child: AnimatedContainer(
                  duration: Duration(milliseconds: 300),
                  padding: EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                  decoration: BoxDecoration(
                    color: recaptchaVerified
                        ? successColor.withOpacity(0.1)
                        : warningColor.withOpacity(0.1),
                    borderRadius: BorderRadius.circular(20),
                    border: Border.all(
                      color: recaptchaVerified ? successColor : warningColor,
                    ),
                  ),
                  child: recaptchaVerified
                      ? Row(
                          mainAxisSize: MainAxisSize.min,
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Icon(Icons.check_circle,
                                color: successColor, size: 18),
                            SizedBox(width: 8),
                            Text(
                              'Verifikasi berhasil',
                              style: TextStyle(
                                color: successColor,
                                fontWeight: FontWeight.w500,
                              ),
                            ),
                          ],
                        )
                      : Column(
                          mainAxisSize: MainAxisSize.min,
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Icon(Icons.info, color: warningColor, size: 18),
                            SizedBox(height: 8),
                            Text(
                              'Harap selesaikan verifikasi reCAPTCHA',
                              style: TextStyle(
                                color: warningColor,
                                fontWeight: FontWeight.w500,
                              ),
                              textAlign: TextAlign.center,
                            ),
                          ],
                        ),
                ),
              ),
              if (recaptchaError != null)
                Padding(
                  padding: const EdgeInsets.only(top: 12.0),
                  child: Center(
                    child: Text(
                      recaptchaError!,
                      style: TextStyle(
                        color: errorColor,
                        fontSize: 12,
                        fontWeight: FontWeight.w500,
                      ),
                      textAlign: TextAlign.center,
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
      appBar: AppBar(
        title: const Text('Laporan Kekerasan Seksual'),
        backgroundColor: Colors.white,
        foregroundColor: primaryColor,
        centerTitle: true,
        elevation: 0,
      ),
      backgroundColor: Color(0xFFF8F9FA),
      body: SafeArea(
        child: Stack(
          children: [
            SingleChildScrollView(
              physics: BouncingScrollPhysics(),
              child: Padding(
                padding: const EdgeInsets.fromLTRB(20.0, 10.0, 20.0, 40.0),
                child: Column(
                  children: [
                    // Informasi Satgas PPK Section
                    _buildHeaderCard(),
                    SizedBox(height: 24),

                    // Form Card
                    _buildFormSection(),
                  ],
                ),
              ),
            ),
            // Loading Indicator
            if (isSubmitting)
              Container(
                color: Colors.black.withOpacity(0.5),
                child: Center(
                  child: Card(
                    elevation: 8,
                    shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(16)),
                    child: Padding(
                      padding: const EdgeInsets.all(20.0),
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          CircularProgressIndicator(
                            valueColor:
                                AlwaysStoppedAnimation<Color>(primaryColor),
                          ),
                          SizedBox(height: 16),
                          Text(
                            'Sedang mengirim laporan...',
                            style: TextStyle(fontWeight: FontWeight.w500),
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }

  // Header information card
  Widget _buildHeaderCard() {
    return Card(
      elevation: 0,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      clipBehavior: Clip.antiAlias,
      margin: EdgeInsets.zero,
      child: Container(
        decoration: BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: [primaryColor, Color(0xFF3949AB)],
          ),
        ),
        child: Padding(
          padding: const EdgeInsets.all(24.0),
          child: Column(
            children: [
              Text(
                'Satuan Tugas Pencegahan dan Penanganan Kekerasan (PPK)',
                style: TextStyle(
                  fontSize: 22,
                  fontWeight: FontWeight.bold,
                  color: Colors.white,
                  height: 1.3,
                ),
                textAlign: TextAlign.center,
              ),
              SizedBox(height: 16),
              Container(
                padding: EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                decoration: BoxDecoration(
                  color: Colors.white.withOpacity(0.15),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Text(
                  'Kami berkomitmen menciptakan lingkungan kampus yang ramah, aman, inklusif, setara, dan bebas dari segala bentuk kekerasan.',
                  style: TextStyle(
                    color: Colors.white,
                    fontSize: 14,
                    fontWeight: FontWeight.w500,
                  ),
                  textAlign: TextAlign.center,
                ),
              ),
              SizedBox(height: 20),
              Text(
                'Sesuai dengan Peraturan Menteri Pendidikan dan Kebudayaan Riset Teknologi Nomor 55 Tahun 2024, lingkup pencegahan dan penanganan kekerasan mencakup enam bentuk kekerasan:',
                style: TextStyle(
                  color: Colors.white.withOpacity(0.95),
                  fontSize: 14,
                ),
                textAlign: TextAlign.center,
              ),
              SizedBox(height: 16),
              Container(
                padding: EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(12),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withOpacity(0.1),
                      blurRadius: 10,
                      spreadRadius: 0,
                    ),
                  ],
                ),
                child: Row(
                  children: [
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          _buildTypeBullet('Kekerasan fisik'),
                          _buildTypeBullet('Kekerasan psikis'),
                          _buildTypeBullet('Perundungan'),
                        ],
                      ),
                    ),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          _buildTypeBullet('Kekerasan seksual'),
                          _buildTypeBullet('Diskriminasi dan intoleransi'),
                          _buildTypeBullet(
                              'Kebijakan yang mengandung kekerasan'),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
              SizedBox(height: 20),
              ElevatedButton.icon(
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.white,
                  foregroundColor: primaryColor,
                  padding: EdgeInsets.symmetric(horizontal: 24, vertical: 12),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(30),
                  ),
                  elevation: 3,
                ),
                onPressed: () async {
                  const url = 'https://satgasppk.uns.ac.id/';
                  // You'd need to implement URL launching here
                },
                icon: Icon(Icons.open_in_new, size: 18),
                label: Text(
                  'Kunjungi Website Resmi Satgas PPK UNS',
                  style: TextStyle(fontWeight: FontWeight.bold),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  // Main form section
  Widget _buildFormSection() {
    return Card(
      elevation: 0,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      child: Padding(
        padding: const EdgeInsets.all(24.0),
        child: Form(
          key: _formKey,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Center(
                child: Container(
                  decoration: BoxDecoration(
                    border: Border(
                      bottom: BorderSide(color: primaryColor, width: 2),
                    ),
                  ),
                  padding: EdgeInsets.only(bottom: 8),
                  child: Text(
                    'Laporan Kekerasan Seksual',
                    style: TextStyle(
                      fontSize: 20,
                      fontWeight: FontWeight.bold,
                      color: textColor,
                    ),
                  ),
                ),
              ),
              SizedBox(height: 32),

              // Detail Laporan Section
              _buildSectionTitle('Detail Laporan'),
              SizedBox(height: 20),

              // Judul Laporan
              _buildTextField(
                label: 'Judul Laporan',
                isRequired: true,
                onChanged: (value) => report['title'] = value,
                validator: (value) => value == null || value.isEmpty
                    ? 'Masukkan judul laporan'
                    : null,
              ),
              SizedBox(height: 20),

              // Kategori Dropdown
              _buildDropdown(
                label: 'Kategori',
                isRequired: true,
                value: report['category'].isEmpty ? null : report['category'],
                hint: 'Pilih Kategori',
                items: getFilteredCategories().map((category) {
                  return DropdownMenuItem<String>(
                    value: category['category_id'].toString(),
                    child: Text(category['nama']),
                  );
                }).toList(),
                validator: (value) => value == null ? 'Pilih kategori' : null,
                onChanged: (value) =>
                    setState(() => report['category'] = value!),
              ),
              SizedBox(height: 20),

              // Bukti Pelanggaran Checkboxes
              _buildFormLabel('Bukti Pelanggaran', isRequired: true),
              SizedBox(height: 8),
              _buildBuktiPelanggaranSection(),
              SizedBox(height: 20),

              // Link Lampiran
              _buildTextField(
                label: 'Link Lampiran Tambahan',
                helperText:
                    'Masukkan URL Google Drive, Dropbox, atau layanan cloud lainnya',
                onChanged: (value) => report['lampiran_link'] = value,
              ),
              SizedBox(height: 20),

              // Deskripsi Laporan
              _buildTextField(
                label: 'Deskripsi',
                isRequired: true,
                hintText: 'Berikan Deskripsi atau Kronologi Kejadian',
                onChanged: (value) => report['description'] = value,
                validator: (value) => value == null || value.isEmpty
                    ? 'Masukkan deskripsi laporan'
                    : null,
                maxLines: 5,
              ),
              SizedBox(height: 20),

              // Tanggal & Waktu Kejadian
              _buildDateTimePicker(),
              SizedBox(height: 20),

              // Multiple Image Upload
              _buildFormLabel('Lampiran Foto', isRequired: true),
              SizedBox(height: 8),
              _buildImageUploader(),

              // Image Previews
              if (imagePreviewBytes.isNotEmpty) ...[
                SizedBox(height: 16),
                _buildImagePreviews(),
              ],
              SizedBox(height: 32),

              // Informasi Pelapor Section
              _buildSectionTitle('Informasi Pelapor'),
              SizedBox(height: 20),

              // Nama Pelapor
              _buildTextField(
                label: 'Nama Pelapor',
                isRequired: true,
                onChanged: (value) => report['reporterName'] = value,
                validator: (value) => value == null || value.isEmpty
                    ? 'Masukkan nama pelapor'
                    : null,
              ),
              SizedBox(height: 20),

              // NIM Pelapor
              _buildTextField(
                label: 'NIM Pelapor',
                isRequired: true,
                onChanged: (value) => report['nim'] = value,
                validator: (value) => value == null || value.isEmpty
                    ? 'Masukkan NIM pelapor'
                    : null,
              ),
              SizedBox(height: 20),

              // Nomor HP Pelapor
              _buildTextField(
                label: 'Nomor HP Pelapor',
                isRequired: true,
                keyboardType: TextInputType.phone,
                onChanged: (value) => report['phone'] = value,
                validator: (value) => value == null || value.isEmpty
                    ? 'Masukkan nomor HP pelapor'
                    : null,
              ),
              SizedBox(height: 20),

              // Profesi
              _buildDropdown(
                label: 'Profesi',
                isRequired: true,
                value: report['profesi'].isEmpty ? null : report['profesi'],
                hint: 'Pilih Profesi',
                items: [
                  DropdownMenuItem(value: 'dosen', child: Text('Dosen')),
                  DropdownMenuItem(
                      value: 'mahasiswa', child: Text('Mahasiswa')),
                  DropdownMenuItem(value: 'staff', child: Text('Staff')),
                  DropdownMenuItem(value: 'lainnya', child: Text('Lainnya')),
                ],
                validator: (value) => value == null ? 'Pilih profesi' : null,
                onChanged: (value) =>
                    setState(() => report['profesi'] = value!),
              ),
              SizedBox(height: 20),

              // Jenis Kelamin
              _buildFormLabel('Jenis Kelamin', isRequired: true),
              SizedBox(height: 8),
              _buildGenderSelector(
                groupValue: report['jenis_kelamin'],
                onChanged: (value) =>
                    setState(() => report['jenis_kelamin'] = value!),
              ),
              SizedBox(height: 20),

              // Umur Pelapor
              _buildFormLabel('Rentang Umur', isRequired: true),
              SizedBox(height: 8),
              _buildAgeRangeSelector(
                groupValue: report['umur_pelapor'],
                onChanged: (value) =>
                    setState(() => report['umur_pelapor'] = value!),
              ),
              SizedBox(height: 32),

              // Informasi Terduga/Terlapor Section
              _buildSectionTitle('Informasi Terduga/Terlapor'),
              SizedBox(height: 16),

              // Anonymous Instruction Info Box
              _buildInfoBox(
                'Jika terduga adalah anonim, berikan inputan "anonim" untuk nama dan "anonim@gmail.com" untuk email.',
                icon: Icons.info,
                color: infoColor,
              ),
              SizedBox(height: 20),

              // Terduga/Terlapor List
              ...List.generate(report['terlapor'].length, (index) {
                return _buildTerdugaCard(index);
              }),

              // Add Terduga Button
              SizedBox(height: 16),
              Center(
                child: _buildOutlinedIconButton(
                  icon: Icons.person_add,
                  label: 'Tambah Terduga/Terlapor',
                  onPressed: addTerduga,
                ),
              ),
              SizedBox(height: 32),

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
                child: _buildOutlinedIconButton(
                  icon: Icons.person_add,
                  label: 'Tambah Saksi',
                  onPressed: addSaksi,
                ),
              ),
              SizedBox(height: 32),

              buildRecaptchaVerificationSection(),
              SizedBox(height: 32),

              // Pernyataan Section
              _buildSectionTitle('Pernyataan'),
              SizedBox(height: 20),
              _buildAgreementSection(),
              SizedBox(height: 32),

              // Form Actions
              _buildFormActions(),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildSectionTitle(String title) {
    return Container(
      width: double.infinity,
      padding: EdgeInsets.only(bottom: 12),
      decoration: BoxDecoration(
        border: Border(
          bottom: BorderSide(
            color: primaryColor.withOpacity(0.3),
            width: 2,
          ),
        ),
      ),
      child: Row(
        children: [
          Container(
            width: 4,
            height: 18,
            decoration: BoxDecoration(
              color: primaryColor,
              borderRadius: BorderRadius.circular(2),
            ),
            margin: EdgeInsets.only(right: 8),
          ),
          Text(
            title,
            style: TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.bold,
              color: textColor,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildFormLabel(String label, {bool isRequired = false}) {
    return RichText(
      text: TextSpan(
        style: TextStyle(
          fontSize: 15,
          fontWeight: FontWeight.w500,
          color: textColor,
        ),
        children: [
          TextSpan(text: label),
          if (isRequired)
            TextSpan(
              text: ' *',
              style: TextStyle(
                color: errorColor,
                fontWeight: FontWeight.bold,
              ),
            ),
        ],
      ),
    );
  }

  Widget _buildTypeBullet(String text) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            margin: EdgeInsets.only(top: 5),
            width: 6,
            height: 6,
            decoration: BoxDecoration(
              color: primaryColor,
              shape: BoxShape.circle,
            ),
          ),
          SizedBox(width: 8),
          Expanded(
            child: Text(
              text,
              style: TextStyle(
                fontSize: 13,
                color: textColor,
                height: 1.4,
              ),
            ),
          ),
        ],
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
            width: 24,
            height: 24,
            decoration: BoxDecoration(
              color: primaryColor,
              shape: BoxShape.circle,
            ),
            child: Center(
              child: Text(
                number.toString(),
                style: TextStyle(
                  color: Colors.white,
                  fontWeight: FontWeight.bold,
                  fontSize: 14,
                ),
              ),
            ),
          ),
          SizedBox(width: 12),
          Expanded(
            child: Text(
              text,
              style: TextStyle(color: textColor, height: 1.5),
            ),
          ),
        ],
      ),
    );
  }

  InputDecoration _inputDecoration(
    String label, {
    bool isRequired = false,
    String? helperText,
    String? hintText,
    Widget? prefixIcon,
  }) {
    return InputDecoration(
      labelText: isRequired ? '$label *' : label,
      hintText: hintText,
      helperText: helperText,
      helperMaxLines: 2,
      prefixIcon: prefixIcon,
      contentPadding: EdgeInsets.symmetric(horizontal: 16, vertical: 16),
      border: OutlineInputBorder(
        borderRadius: BorderRadius.circular(8),
        borderSide: BorderSide(color: Colors.grey[300]!),
      ),
      focusedBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(8),
        borderSide: BorderSide(color: primaryColor, width: 2),
      ),
      enabledBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(8),
        borderSide: BorderSide(color: Colors.grey[300]!),
      ),
      errorBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(8),
        borderSide: BorderSide(color: errorColor),
      ),
      focusedErrorBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(8),
        borderSide: BorderSide(color: errorColor, width: 2),
      ),
      filled: true,
      fillColor: Colors.white,
    );
  }

  Widget _buildTextField({
    required String label,
    bool isRequired = false,
    String? helperText,
    String? hintText,
    void Function(String)? onChanged,
    String? Function(String?)? validator,
    TextInputType? keyboardType,
    int maxLines = 1,
    Widget? prefixIcon,
  }) {
    return TextFormField(
      decoration: _inputDecoration(
        label,
        isRequired: isRequired,
        helperText: helperText,
        hintText: hintText,
        prefixIcon: prefixIcon,
      ),
      validator: validator,
      onChanged: onChanged,
      keyboardType: keyboardType,
      maxLines: maxLines,
      style: TextStyle(color: textColor),
    );
  }

  Widget _buildDropdown({
    required String label,
    bool isRequired = false,
    String? value,
    required String hint,
    required List<DropdownMenuItem<String>> items,
    void Function(String?)? onChanged,
    String? Function(String?)? validator,
  }) {
    return DropdownButtonFormField<String>(
      decoration: _inputDecoration(
        label,
        isRequired: isRequired,
      ),
      value: value,
      hint: Text(hint),
      items: items,
      validator: validator,
      onChanged: onChanged,
      icon: Icon(Icons.arrow_drop_down, color: primaryColor),
      isExpanded: true,
      dropdownColor: Colors.white,
      style: TextStyle(color: textColor),
    );
  }

  Widget _buildBuktiPelanggaranSection() {
    return Container(
      padding: EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: showBuktiWarning ? errorColor : dividerColor),
        boxShadow: [
          BoxShadow(
            color: Colors.grey.withOpacity(0.05),
            spreadRadius: 1,
            blurRadius: 5,
            offset: Offset(0, 2),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          ...buktiOptions.map(
            (option) => Theme(
              data: ThemeData(
                checkboxTheme: CheckboxThemeData(
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(4),
                  ),
                ),
              ),
              child: CheckboxListTile(
                title: Text(option,
                    style: TextStyle(fontSize: 14, color: textColor)),
                value: selectedBukti.contains(option),
                activeColor: primaryColor,
                controlAffinity: ListTileControlAffinity.leading,
                contentPadding: EdgeInsets.zero,
                dense: true,
                onChanged: (bool? value) {
                  setState(() {
                    if (value == true) {
                      selectedBukti.add(option);
                    } else {
                      selectedBukti.remove(option);
                    }
                    updateBuktiPelanggaran();
                    showBuktiWarning = false;
                  });
                },
              ),
            ),
          ),
          Theme(
            data: ThemeData(
              checkboxTheme: CheckboxThemeData(
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(4),
                ),
              ),
            ),
            child: CheckboxListTile(
              title: Text('Lainnya',
                  style: TextStyle(fontSize: 14, color: textColor)),
              value: showLainnyaInput,
              activeColor: primaryColor,
              controlAffinity: ListTileControlAffinity.leading,
              contentPadding: EdgeInsets.zero,
              dense: true,
              onChanged: (bool? value) {
                setState(() {
                  showLainnyaInput = value ?? false;
                  updateBuktiPelanggaran();
                });
              },
            ),
          ),
          if (showLainnyaInput)
            Padding(
              padding: const EdgeInsets.only(left: 32.0, top: 8.0),
              child: TextFormField(
                decoration: InputDecoration(
                  hintText: 'Sebutkan bukti lainnya',
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(8),
                  ),
                  contentPadding:
                      EdgeInsets.symmetric(horizontal: 12, vertical: 12),
                  filled: true,
                  fillColor: Colors.white,
                ),
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
              padding: const EdgeInsets.only(top: 8.0),
              child: Row(
                children: [
                  Icon(Icons.error_outline, color: errorColor, size: 14),
                  SizedBox(width: 4),
                  Text(
                    'Pilih setidaknya satu bukti pelanggaran',
                    style: TextStyle(color: errorColor, fontSize: 12),
                  ),
                ],
              ),
            ),
        ],
      ),
    );
  }

  Widget _buildDateTimePicker() {
    return InkWell(
      onTap: () async {
        final DateTime? pickedDate = await showDatePicker(
          context: context,
          initialDate: report['incidentDate'] ?? DateTime.now(),
          firstDate: DateTime(2000),
          lastDate: DateTime.now(),
          builder: (context, child) {
            return Theme(
              data: Theme.of(context).copyWith(
                colorScheme: ColorScheme.light(
                  primary: primaryColor,
                  onPrimary: Colors.white,
                  surface: Colors.white,
                  onSurface: textColor,
                ),
              ),
              child: child!,
            );
          },
        );

        if (pickedDate != null) {
          final TimeOfDay? pickedTime = await showTimePicker(
            context: context,
            initialTime: TimeOfDay.fromDateTime(
              report['incidentDate'] ?? DateTime.now(),
            ),
            builder: (context, child) {
              return Theme(
                data: Theme.of(context).copyWith(
                  colorScheme: ColorScheme.light(
                    primary: primaryColor,
                    onPrimary: Colors.white,
                    surface: Colors.white,
                    onSurface: textColor,
                  ),
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
      child: InputDecorator(
        decoration: _inputDecoration(
          'Tanggal & Waktu Kejadian',
          isRequired: true,
          prefixIcon: Icon(Icons.calendar_today, color: primaryColor),
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text(
              report['incidentDate'] != null
                  ? "${report['incidentDate'].toLocal()}".split('.')[0]
                  : "Pilih Tanggal & Waktu",
              style: TextStyle(color: textColor),
            ),
            Icon(Icons.arrow_drop_down, color: primaryColor),
          ],
        ),
      ),
    );
  }

  Widget _buildImageUploader() {
    return InkWell(
      onTap: handleFileUpload,
      borderRadius: BorderRadius.circular(12),
      child: Container(
        height: 150,
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(12),
          border: Border.all(
              color: dividerColor, width: 1.5, style: BorderStyle.solid),
          color: Colors.white,
        ),
        child: Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(Icons.cloud_upload_rounded,
                  size: 48, color: primaryColor.withOpacity(0.7)),
              SizedBox(height: 16),
              Text(
                'Klik untuk memilih beberapa file foto',
                style: TextStyle(
                  fontWeight: FontWeight.w500,
                  color: textColor,
                ),
              ),
              SizedBox(height: 8),
              Text(
                'Format: JPG, PNG, GIF (Maks 5MB)',
                style: TextStyle(
                  fontSize: 12,
                  color: Colors.grey[600],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildImagePreviews() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.symmetric(vertical: 8.0),
          child: Row(
            children: [
              Icon(Icons.photo_library, size: 18, color: primaryColor),
              SizedBox(width: 8),
              Text(
                'Preview Foto (${imagePreviewBytes.length} file)',
                style: TextStyle(
                  fontWeight: FontWeight.w500,
                  color: textColor,
                ),
              ),
            ],
          ),
        ),
        SizedBox(height: 8),
        GridView.builder(
          shrinkWrap: true,
          physics: NeverScrollableScrollPhysics(),
          gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
            crossAxisCount: 3,
            crossAxisSpacing: 12,
            mainAxisSpacing: 12,
          ),
          itemCount: imagePreviewBytes.length,
          itemBuilder: (context, index) {
            return Stack(
              children: [
                Container(
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(12),
                    boxShadow: [
                      BoxShadow(
                        color: Colors.black.withOpacity(0.1),
                        blurRadius: 4,
                        offset: Offset(0, 2),
                      ),
                    ],
                  ),
                  child: ClipRRect(
                    borderRadius: BorderRadius.circular(12),
                    child: Image.memory(
                      imagePreviewBytes[index],
                      fit: BoxFit.cover,
                      width: double.infinity,
                      height: double.infinity,
                    ),
                  ),
                ),
                Positioned(
                  top: 6,
                  right: 6,
                  child: InkWell(
                    onTap: () => removeImage(index),
                    child: Container(
                      padding: EdgeInsets.all(4),
                      decoration: BoxDecoration(
                        color: Colors.black.withOpacity(0.6),
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
            );
          },
        ),
      ],
    );
  }

  Widget _buildGenderSelector({
    required String? groupValue,
    required void Function(String?) onChanged,
  }) {
    return Container(
      padding: EdgeInsets.all(4),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: dividerColor),
      ),
      child: Row(
        children: [
          Expanded(
            child: RadioListTile<String>(
              title: Text(
                'Laki-laki',
                style: TextStyle(fontSize: 14, color: textColor),
              ),
              value: 'laki-laki',
              groupValue: groupValue,
              onChanged: onChanged,
              activeColor: primaryColor,
              contentPadding: EdgeInsets.symmetric(horizontal: 8),
              dense: true,
            ),
          ),
          Expanded(
            child: RadioListTile<String>(
              title: Text(
                'Perempuan',
                style: TextStyle(fontSize: 14, color: textColor),
              ),
              value: 'perempuan',
              groupValue: groupValue,
              onChanged: onChanged,
              activeColor: primaryColor,
              contentPadding: EdgeInsets.symmetric(horizontal: 8),
              dense: true,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildAgeRangeSelector({
    required String? groupValue,
    required void Function(String?) onChanged,
  }) {
    return Container(
      padding: EdgeInsets.all(8),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: dividerColor),
      ),
      child: Column(
        children: [
          RadioListTile<String>(
            title: Text(
              'Kurang dari 20 tahun',
              style: TextStyle(fontSize: 14, color: textColor),
            ),
            value: '<20',
            groupValue: groupValue,
            onChanged: onChanged,
            activeColor: primaryColor,
            contentPadding: EdgeInsets.zero,
            dense: true,
          ),
          Divider(height: 1, thickness: 1, color: dividerColor),
          RadioListTile<String>(
            title: Text(
              '20 - 40 tahun',
              style: TextStyle(fontSize: 14, color: textColor),
            ),
            value: '20-40',
            groupValue: groupValue,
            onChanged: onChanged,
            activeColor: primaryColor,
            contentPadding: EdgeInsets.zero,
            dense: true,
          ),
          Divider(height: 1, thickness: 1, color: dividerColor),
          RadioListTile<String>(
            title: Text(
              'Lebih dari 40 tahun',
              style: TextStyle(fontSize: 14, color: textColor),
            ),
            value: '40<',
            groupValue: groupValue,
            onChanged: onChanged,
            activeColor: primaryColor,
            contentPadding: EdgeInsets.zero,
            dense: true,
          ),
        ],
      ),
    );
  }

  Widget _buildInfoBox(String text,
      {required IconData icon, required Color color}) {
    return Container(
      padding: EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: color.withOpacity(0.1),
        borderRadius: BorderRadius.circular(12),
        border: Border(left: BorderSide(color: color, width: 4)),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon, color: color, size: 20),
          SizedBox(width: 12),
          Expanded(
            child: Text(
              text,
              style: TextStyle(
                color: color.withOpacity(0.9),
                fontSize: 14,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildOutlinedIconButton({
    required IconData icon,
    required String label,
    required VoidCallback onPressed,
  }) {
    return OutlinedButton.icon(
      onPressed: onPressed,
      icon: Icon(icon, size: 18),
      label: Text(
        label,
        style: TextStyle(fontWeight: FontWeight.w500),
      ),
      style: OutlinedButton.styleFrom(
        foregroundColor: primaryColor,
        side: BorderSide(color: primaryColor),
        padding: EdgeInsets.symmetric(horizontal: 20, vertical: 12),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(30),
        ),
      ),
    );
  }

  Widget _buildTerdugaCard(int index) {
    final Map<String, dynamic> terduga = report['terlapor'][index];

    return Card(
      margin: EdgeInsets.only(bottom: 24),
      elevation: 0,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: Container(
        padding: const EdgeInsets.all(20.0),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: dividerColor),
          boxShadow: [
            BoxShadow(
              color: Colors.grey.withOpacity(0.1),
              spreadRadius: 1,
              blurRadius: 5,
              offset: Offset(0, 2),
            ),
          ],
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Container(
                  padding: EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                  decoration: BoxDecoration(
                    color: primaryColor,
                    borderRadius: BorderRadius.circular(20),
                  ),
                  child: Text(
                    'Terduga ${index + 1}',
                    style: TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.bold,
                      color: Colors.white,
                    ),
                  ),
                ),
                IconButton(
                  icon: Container(
                    padding: EdgeInsets.all(4),
                    decoration: BoxDecoration(
                      color: errorColor.withOpacity(0.1),
                      shape: BoxShape.circle,
                    ),
                    child:
                        Icon(Icons.delete_outline, color: errorColor, size: 20),
                  ),
                  onPressed: () => removeTerduga(index),
                  tooltip: 'Hapus Terduga',
                  padding: EdgeInsets.zero,
                  constraints: BoxConstraints(),
                ),
              ],
            ),
            SizedBox(height: 20),

            // Nama Terduga
            _buildTextField(
              label: 'Nama Lengkap',
              isRequired: true,
              hintText: "Masukkan nama atau 'anonim'",
              onChanged: (value) =>
                  setState(() => terduga['nama_lengkap'] = value),
              prefixIcon: Icon(Icons.person_outline, color: primaryColor),
            ),
            SizedBox(height: 16),

            // Email Terduga
            _buildTextField(
              label: 'Email',
              hintText: "Masukkan email atau 'anonim@gmail.com'",
              onChanged: (value) => setState(() => terduga['email'] = value),
              keyboardType: TextInputType.emailAddress,
              prefixIcon: Icon(Icons.email_outlined, color: primaryColor),
            ),
            SizedBox(height: 16),

            // Nomor Telepon Terduga
            _buildTextField(
              label: 'Nomor Telepon',
              onChanged: (value) =>
                  setState(() => terduga['nomor_telepon'] = value),
              keyboardType: TextInputType.phone,
              prefixIcon: Icon(Icons.phone_outlined, color: primaryColor),
            ),
            SizedBox(height: 16),

            // Jenis Kelamin
            _buildFormLabel('Jenis Kelamin', isRequired: true),
            SizedBox(height: 8),
            _buildGenderSelector(
              groupValue: terduga['jenis_kelamin'],
              onChanged: (value) =>
                  setState(() => terduga['jenis_kelamin'] = value!),
            ),
            SizedBox(height: 16),

            // Rentang Umur Terduga
            _buildFormLabel('Rentang Umur', isRequired: true),
            SizedBox(height: 8),
            _buildAgeRangeSelector(
              groupValue: terduga['umur_terlapor'],
              onChanged: (value) =>
                  setState(() => terduga['umur_terlapor'] = value!),
            ),
            SizedBox(height: 16),

            // Status Warga
            _buildDropdown(
              label: 'Status Warga',
              isRequired: true,
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

    return Card(
      margin: EdgeInsets.only(bottom: 24),
      elevation: 0,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: Container(
        padding: const EdgeInsets.all(20.0),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: dividerColor),
          boxShadow: [
            BoxShadow(
              color: Colors.grey.withOpacity(0.1),
              spreadRadius: 1,
              blurRadius: 5,
              offset: Offset(0, 2),
            ),
          ],
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Container(
                  padding: EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                  decoration: BoxDecoration(
                    color: infoColor,
                    borderRadius: BorderRadius.circular(20),
                  ),
                  child: Text(
                    'Saksi ${index + 1}',
                    style: TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.bold,
                      color: Colors.white,
                    ),
                  ),
                ),
                IconButton(
                  icon: Container(
                    padding: EdgeInsets.all(4),
                    decoration: BoxDecoration(
                      color: errorColor.withOpacity(0.1),
                      shape: BoxShape.circle,
                    ),
                    child:
                        Icon(Icons.delete_outline, color: errorColor, size: 20),
                  ),
                  onPressed: () => removeSaksi(index),
                  tooltip: 'Hapus Saksi',
                  padding: EdgeInsets.zero,
                  constraints: BoxConstraints(),
                ),
              ],
            ),
            SizedBox(height: 20),

            // Nama Saksi
            _buildTextField(
              label: 'Nama Lengkap Saksi',
              isRequired: true,
              onChanged: (value) =>
                  setState(() => saksi['nama_lengkap'] = value),
              prefixIcon: Icon(Icons.person_outline, color: infoColor),
            ),
            SizedBox(height: 16),

            // Email Saksi
            _buildTextField(
              label: 'Email Saksi',
              isRequired: true,
              onChanged: (value) => setState(() => saksi['email'] = value),
              keyboardType: TextInputType.emailAddress,
              prefixIcon: Icon(Icons.email_outlined, color: infoColor),
            ),
            SizedBox(height: 16),

            // Nomor Telepon Saksi
            _buildTextField(
              label: 'Nomor Telepon Saksi',
              isRequired: true,
              onChanged: (value) =>
                  setState(() => saksi['nomor_telepon'] = value),
              keyboardType: TextInputType.phone,
              prefixIcon: Icon(Icons.phone_outlined, color: infoColor),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildAgreementSection() {
    return Container(
      padding: EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        border:
            Border.all(color: showAgreementWarning ? errorColor : dividerColor),
        boxShadow: [
          BoxShadow(
            color: Colors.grey.withOpacity(0.05),
            spreadRadius: 1,
            blurRadius: 5,
            offset: Offset(0, 2),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Icon(Icons.gavel, color: primaryColor, size: 20),
              SizedBox(height: 8),
              Text(
                'Dengan ini saya menyatakan bahwa:',
                style: TextStyle(
                  fontWeight: FontWeight.bold,
                  color: textColor,
                ),
              ),
            ],
          ),
          SizedBox(height: 16),
          _buildNumberedItem(
            1,
            'Segala informasi yang saya berikan dalam laporan ini adalah benar dan dapat dipertanggungjawabkan.',
          ),
          _buildNumberedItem(
            2,
            'Saya bersedia memberikan keterangan lebih lanjut apabila diperlukan untuk proses penanganan laporan.',
          ),
          _buildNumberedItem(
            3,
            'Saya memahami bahwa memberikan laporan palsu dapat dikenakan sanksi sesuai dengan peraturan yang berlaku.',
          ),
          SizedBox(height: 16),
          Theme(
            data: ThemeData(
              checkboxTheme: CheckboxThemeData(
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(4),
                ),
              ),
            ),
            child: CheckboxListTile(
              title: Text(
                'Saya menyetujui pernyataan di atas *',
                style: TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.w500,
                  color: textColor,
                ),
              ),
              value: report['agreement'] == true,
              activeColor: primaryColor,
              controlAffinity: ListTileControlAffinity.leading,
              contentPadding: EdgeInsets.zero,
              onChanged: (bool? value) {
                setState(() {
                  report['agreement'] = value ?? false;
                  showAgreementWarning = false;
                });
              },
            ),
          ),
          if (showAgreementWarning)
            Padding(
              padding: const EdgeInsets.only(left: 32.0, top: 8.0),
              child: Row(
                children: [
                  Icon(Icons.error_outline, color: errorColor, size: 14),
                  SizedBox(width: 4),
                  Text(
                    'Anda harus menyetujui pernyataan ini untuk melanjutkan',
                    style: TextStyle(color: errorColor, fontSize: 12),
                  ),
                ],
              ),
            ),
        ],
      ),
    );
  }

  Widget _buildFormActions() {
    return Row(
      mainAxisAlignment: MainAxisAlignment.end,
      children: [
        OutlinedButton(
          onPressed: () {
            Navigator.of(context).pop();
          },
          style: OutlinedButton.styleFrom(
            foregroundColor: textColor,
            padding: EdgeInsets.symmetric(horizontal: 24, vertical: 14),
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(30),
            ),
            side: BorderSide(color: Colors.grey[400]!),
          ),
          child: Text(
            'Batal',
            style: TextStyle(fontWeight: FontWeight.w500),
          ),
        ),
        SizedBox(width: 16),
        ElevatedButton(
          onPressed:
              (!report['agreement'] || !recaptchaVerified || isSubmitting)
                  ? null
                  : submitForm,
          style: ElevatedButton.styleFrom(
            backgroundColor: accentColor,
            foregroundColor: Colors.white,
            padding: EdgeInsets.symmetric(horizontal: 32, vertical: 14),
            disabledBackgroundColor: Colors.grey[400],
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(30),
            ),
            elevation: 2,
          ),
          child: isSubmitting
              ? Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    SizedBox(
                      height: 18,
                      width: 18,
                      child: CircularProgressIndicator(
                        strokeWidth: 2,
                        valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
                      ),
                    ),
                    SizedBox(width: 10),
                    Text(
                      'Mengirim...',
                      style: TextStyle(fontWeight: FontWeight.bold),
                    ),
                  ],
                )
              : Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(Icons.send),
                    SizedBox(width: 8),
                    Text(
                      'Simpan Laporan',
                      style: TextStyle(fontWeight: FontWeight.bold),
                    ),
                  ],
                ),
        ),
      ],
    );
  }
}
