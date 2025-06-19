import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:http/http.dart' as http;
import 'package:image_picker/image_picker.dart';
import 'dart:typed_data';
import 'dart:ui' as ui;
import 'package:flutter/services.dart';
import 'package:pelaporan_d3ti/services/api_service.dart';
import 'dart:async';
import 'package:intl/intl.dart';
// Add the reCAPTCHA import
import 'package:flutter_recaptcha_v2_compat/flutter_recaptcha_v2_compat.dart';
// Conditional imports for web-only libraries
import 'package:webview_flutter/webview_flutter.dart';
import 'package:shared_preferences/shared_preferences.dart';

// Define a function to safely import dart:html only on web
// ignore: uri_does_not_exist
import 'dart:html' if (dart.library.io) 'stub_html.dart' as html;
// ignore: uri_does_not_exist
import 'dart:ui_web' if (dart.library.io) 'stub_ui_web.dart' as ui_web;

// Create stub classes for non-web platforms
class HtmlElementPlaceholder {
  // Empty stub class
}

class AddLaporKsPage extends StatefulWidget {
  const AddLaporKsPage({Key? key}) : super(key: key);

  @override
  _AddLaporKsPageState createState() => _AddLaporKsPageState();
}

class _AddLaporKsPageState extends State<AddLaporKsPage> {
  final _formKey = GlobalKey<FormState>();
  bool isSubmitting = false;

  // Dynamic user information and time
  String _currentUserName = '';
  String _currentUserNIM = '';
  String _currentUserPhone = '';
  String _currentDateTime = '';
  Timer? _timeTimer;

  // Controllers for user fields
  final TextEditingController _namaPelaporController = TextEditingController();
  final TextEditingController _nimPelaporController = TextEditingController();
  final TextEditingController _nomorTeleponController = TextEditingController();

  // For reCAPTCHA
  String createdViewId = 'recaptcha_element';
  String? recaptchaToken;
  String? recaptchaError;

  // Add reCAPTCHA controller
  RecaptchaV2Controller recaptchaV2Controller = RecaptchaV2Controller();
  bool recaptchaVerified = false;

  // Focus node for the reCAPTCHA section
  final FocusNode recaptchaFocusNode = FocusNode();

  // Scroll controller for form scrolling
  final ScrollController _scrollController = ScrollController();

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
  final Color _primaryColor = Color(0xFF00457C); // Deep blue
  final Color _accentColor = Color(0xFFF44336); // Red accent
  final Color _textColor = Color(0xFF2D3748); // Dark text
  final Color _lightTextColor = Color(0xFF718096); // Light text
  final Color _backgroundColor = Color(0xFFF9FAFC); // Light background
  final Color _cardColor = Colors.white; // Card color
  final Color _borderColor = Color(0xFFE2E8F0); // Border color
  final Color _fieldColor = Color(0xFFFAFAFA); // Field background
  final Color _successColor = Color(0xFF38A169); // Success green
  final Color _errorColor = Color(0xFFE53E3E); // Error red
  final Color _warningColor = Color(0xFFF6AD55); // Warning orange
  final Color _infoColor = Color(0xFF3182CE); // Info blue
  final Color _disabledColor = Color(0xFFEDF2F7); // Disabled state

  @override
  void dispose() {
    // Dispose focus node
    recaptchaFocusNode.dispose();
    _scrollController.dispose();
    _timeTimer?.cancel();
    _namaPelaporController.dispose();
    _nimPelaporController.dispose();
    _nomorTeleponController.dispose();
    super.dispose();
  }

  @override
  void initState() {
    super.initState();

    // Initialize an empty terlapor and saksi
    addTerduga();
    addSaksi();

    // Load user data and update the form
    _loadUserData();

    // Update the current time
    _updateCurrentTime();

    // Start timer to update the time
    _timeTimer = Timer.periodic(Duration(seconds: 1), (timer) {
      _updateCurrentTime();
    });

    loadCategories();

    // Web-specific initialization
    if (kIsWeb) {
      _initializeWebViewForWeb();
    }
  }

  // Update the current Indonesian time (UTC+7)
  void _updateCurrentTime() {
    final now = DateTime.now().toUtc();
    final jakartaTime = now.add(Duration(hours: 7)); // UTC+7 for WIB
    final formattedTime = DateFormat('yyyy-MM-dd HH:mm:ss').format(jakartaTime);

    if (_currentDateTime != formattedTime) {
      setState(() {
        _currentDateTime = formattedTime;
      });
    }
  }

  // Load user data from SharedPreferences
  Future<void> _loadUserData() async {
    try {
      final prefs = await SharedPreferences.getInstance();

      setState(() {
        _currentUserName = prefs.getString('user_name') ?? '';
        _currentUserNIM = prefs.getString('user_nim') ?? '';
        _currentUserPhone = prefs.getString('user_no_telp') ?? '';

        // Update the controllers
        _namaPelaporController.text = _currentUserName;
        _nimPelaporController.text = _currentUserNIM;
        _nomorTeleponController.text = _currentUserPhone;

        // Update report data
        report['reporterName'] = _currentUserName;
        report['nim'] = _currentUserNIM;
        report['phone'] = _currentUserPhone;
      });
    } catch (e) {
      print('Error loading user data: $e');

      // Show notification if user data can't be loaded
      _showSnackbar(
          'Data pengguna tidak dapat dimuat. Silakan isi form secara manual.',
          isError: true);
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
                  _showSnackbar('Verifikasi reCAPTCHA berhasil',
                      isSuccess: true);
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
            .map((entry) => {'category_id': entry.key, 'nama': entry.value})
            .toList();
        print("Categories loaded: ${categories.length}");
      });
    } catch (e) {
      print("Error loading categories: $e");
      // Show error to user
      _showSnackbar('Gagal memuat kategori: $e', isError: true);
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
        'unit_kerja': '',
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
        'reporterName': _currentUserName,
        'nim': _currentUserNIM,
        'phone': _currentUserPhone,
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

      // Reset controllers but keep the user data
      _namaPelaporController.text = _currentUserName;
      _nimPelaporController.text = _currentUserNIM;
      _nomorTeleponController.text = _currentUserPhone;
    });

    // Reset reCAPTCHA
    resetRecaptcha();

    // Show confirmation
    _showSnackbar('Formulir berhasil direset');
  }

  void _scrollToRecaptcha() {
    if (_scrollController.hasClients) {
      _scrollController.animateTo(
        _scrollController.position.maxScrollExtent - 300,
        duration: Duration(milliseconds: 500),
        curve: Curves.easeInOut,
      );
    }
  }

  void submitForm() async {
    // Update report with latest values from controllers
    report['reporterName'] = _namaPelaporController.text;
    report['nim'] = _nimPelaporController.text;
    report['phone'] = _nomorTeleponController.text;

    if (!_formKey.currentState!.validate()) {
      _showSnackbar('Formulir belum lengkap. Mohon periksa kembali.',
          isError: true);
      return;
    }

    // Validate agreement
    if (report['agreement'] != true) {
      setState(() {
        showAgreementWarning = true;
      });
      _showErrorDialog('Persetujuan Diperlukan',
          'Anda harus menyetujui pernyataan untuk melanjutkan');
      return;
    }

    // Validate reCAPTCHA
    if (!recaptchaVerified) {
      setState(() {
        recaptchaError =
            'Harap selesaikan verifikasi reCAPTCHA "Saya bukan robot"';
      });
      _showErrorDialog('Verifikasi Diperlukan',
          'Harap selesaikan verifikasi reCAPTCHA untuk melanjutkan');

      // Scroll to reCAPTCHA
      _scrollToRecaptcha();
      return;
    }

    // Update bukti_pelanggaran array before submission
    updateBuktiPelanggaran();

    // Validate bukti_pelanggaran
    if (report['bukti_pelanggaran'].isEmpty) {
      setState(() {
        showBuktiWarning = true;
      });
      _showSnackbar('Pilih minimal satu bukti pelanggaran', isError: true);
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

      // Get current username for the request
      final prefs = await SharedPreferences.getInstance();
      final String? username = prefs.getString('user_name');

      // Add text fields
      formData.fields.addAll({
        'judul': report['title'],
        'category_id': report['category'],
        'deskripsi': report['description'],
        'nama_pelapor': report['reporterName'],
        'nim_pelapor': report['nim'],
        'nomor_telepon': report['phone'],
        'tanggal_kejadian': report['incidentDate'].toIso8601String(),
        'current_datetime': _currentDateTime,
        'username': username ?? _currentUserName, // Dynamic username
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

        _showErrorDialog('Gagal Mengirim Formulir', errorMessage);
      }
    } catch (e) {
      _showErrorDialog('Kesalahan Jaringan',
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
        return Dialog(
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(16),
          ),
          elevation: 0,
          backgroundColor: Colors.transparent,
          child: Container(
            padding: EdgeInsets.all(24),
            decoration: BoxDecoration(
              color: _cardColor,
              shape: BoxShape.rectangle,
              borderRadius: BorderRadius.circular(16),
              boxShadow: [
                BoxShadow(
                  color: Colors.black26,
                  blurRadius: 10.0,
                  offset: Offset(0.0, 10.0),
                ),
              ],
            ),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: <Widget>[
                Container(
                  padding: EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: _successColor.withOpacity(0.1),
                    shape: BoxShape.circle,
                  ),
                  child: Icon(
                    Icons.check_circle,
                    color: _successColor,
                    size: 56,
                  ),
                ),
                SizedBox(height: 24),
                Text(
                  'Berhasil!',
                  style: TextStyle(
                    fontSize: 22,
                    fontWeight: FontWeight.w600,
                    color: _textColor,
                  ),
                ),
                SizedBox(height: 16),
                Text(
                  'Laporan Kekerasan Seksual berhasil dikirim. Terima kasih atas laporan Anda.',
                  style: TextStyle(
                    fontSize: 16,
                    color: _lightTextColor,
                  ),
                  textAlign: TextAlign.center,
                ),
                SizedBox(height: 24),
                ElevatedButton(
                  onPressed: () {
                    Navigator.of(context).pop();
                  },
                  style: ElevatedButton.styleFrom(
                    backgroundColor: _primaryColor,
                    foregroundColor: Colors.white,
                    padding: EdgeInsets.symmetric(horizontal: 40, vertical: 12),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(8),
                    ),
                    elevation: 0,
                  ),
                  child: Text(
                    'OK',
                    style: TextStyle(fontSize: 16, fontWeight: FontWeight.w600),
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  void _showSnackbar(String message,
      {bool isError = false, bool isSuccess = false}) {
    Color backgroundColor;
    IconData icon;

    if (isError) {
      backgroundColor = _errorColor;
      icon = Icons.error_outline;
    } else if (isSuccess) {
      backgroundColor = _successColor;
      icon = Icons.check_circle_outline;
    } else {
      backgroundColor = _infoColor;
      icon = Icons.info_outline;
    }

    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Row(
          children: [
            Icon(icon, color: Colors.white),
            SizedBox(width: 12),
            Expanded(
              child: Text(
                message,
                style: TextStyle(color: Colors.white),
              ),
            ),
          ],
        ),
        backgroundColor: backgroundColor,
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
        margin: EdgeInsets.all(12),
        duration: Duration(seconds: 4),
      ),
    );
  }

  void _showErrorDialog(String title, String message) {
    showDialog(
      context: context,
      builder: (BuildContext context) {
        return Dialog(
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(16),
          ),
          elevation: 0,
          backgroundColor: Colors.transparent,
          child: Container(
            padding: EdgeInsets.all(24),
            decoration: BoxDecoration(
              color: _cardColor,
              shape: BoxShape.rectangle,
              borderRadius: BorderRadius.circular(16),
              boxShadow: [
                BoxShadow(
                  color: Colors.black26,
                  blurRadius: 10.0,
                  offset: Offset(0.0, 10.0),
                ),
              ],
            ),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: <Widget>[
                Container(
                  padding: EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: _errorColor.withOpacity(0.1),
                    shape: BoxShape.circle,
                  ),
                  child: Icon(
                    Icons.error_outline,
                    color: _errorColor,
                    size: 56,
                  ),
                ),
                SizedBox(height: 24),
                Text(
                  title,
                  style: TextStyle(
                    fontSize: 22,
                    fontWeight: FontWeight.w600,
                    color: _textColor,
                  ),
                ),
                SizedBox(height: 16),
                Text(
                  message,
                  style: TextStyle(
                    fontSize: 16,
                    color: _lightTextColor,
                  ),
                  textAlign: TextAlign.center,
                ),
                SizedBox(height: 24),
                ElevatedButton(
                  onPressed: () {
                    Navigator.of(context).pop();
                  },
                  style: ElevatedButton.styleFrom(
                    backgroundColor: _primaryColor,
                    foregroundColor: Colors.white,
                    padding: EdgeInsets.symmetric(horizontal: 40, vertical: 12),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(8),
                    ),
                    elevation: 0,
                  ),
                  child: Text(
                    'OK',
                    style: TextStyle(fontSize: 16, fontWeight: FontWeight.w600),
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  // Add a method for building the reCAPTCHA verification section
  Widget buildRecaptchaVerificationSection() {
    return _buildSection(
      title: 'Verifikasi reCAPTCHA',
      icon: Icons.security,
      content: Container(
        padding: EdgeInsets.all(20),
        decoration: BoxDecoration(
          color: _fieldColor,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(
            color: recaptchaError != null
                ? _errorColor.withOpacity(0.5)
                : _borderColor,
          ),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(Icons.shield, color: _infoColor, size: 18),
                SizedBox(width: 12),
                Expanded(
                  child: Text(
                    'Verifikasi bahwa Anda bukan robot sebelum mengirimkan laporan',
                    style: TextStyle(fontSize: 15, color: _textColor),
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
                border: Border.all(color: _borderColor),
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
                    _showSnackbar('Verifikasi reCAPTCHA berhasil',
                        isSuccess: true);
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
                  ? Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(Icons.check_circle,
                            color: _successColor, size: 20),
                        SizedBox(width: 8),
                        Text(
                          'Verifikasi berhasil',
                          style: TextStyle(
                              color: _successColor,
                              fontWeight: FontWeight.w500),
                        ),
                      ],
                    )
                  : Column(
                      // Changed from Row to Column to stack vertically
                      children: [
                        Row(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Icon(Icons.info_outline,
                                color: _warningColor, size: 20),
                          ],
                        ),
                        SizedBox(height: 6), // Space between icon and text
                        Text(
                          'Harap selesaikan verifikasi reCAPTCHA',
                          style: TextStyle(
                              color: _warningColor,
                              fontWeight: FontWeight.w500),
                          textAlign: TextAlign.center,
                        ),
                      ],
                    ),
            ),
            if (recaptchaError != null)
              Padding(
                padding: const EdgeInsets.only(top: 12.0),
                child: Container(
                  padding: EdgeInsets.symmetric(vertical: 8, horizontal: 12),
                  decoration: BoxDecoration(
                    color: _errorColor.withOpacity(0.1),
                    borderRadius: BorderRadius.circular(6),
                  ),
                  child: Row(
                    children: [
                      Icon(Icons.error_outline, color: _errorColor, size: 16),
                      SizedBox(width: 8),
                      Expanded(
                        child: Text(
                          recaptchaError!,
                          style: TextStyle(color: _errorColor, fontSize: 13),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }

  // Build a section with title and bordered container
  Widget _buildSection({
    required String title,
    required Widget content,
    IconData? icon,
  }) {
    // Check if this is the title that causes overflow
    bool isTerlaporTitle = title == 'Informasi Terduga/Terlapor';

    return Container(
      margin: EdgeInsets.only(bottom: 32),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            crossAxisAlignment:
                CrossAxisAlignment.start, // Align to top for multiline title
            children: [
              if (icon != null) ...[
                Container(
                  padding: EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: _primaryColor.withOpacity(0.1),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Icon(icon, color: _primaryColor, size: 18),
                ),
                SizedBox(width: 12),
              ],
              Expanded(
                // Wrap in Expanded to prevent overflow
                child: isTerlaporTitle
                    ? Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'Informasi',
                            style: TextStyle(
                              fontSize: 18,
                              fontWeight: FontWeight.w600,
                              color: _textColor,
                            ),
                          ),
                          Text(
                            'Terduga/Terlapor',
                            style: TextStyle(
                              fontSize: 18,
                              fontWeight: FontWeight.w600,
                              color: _textColor,
                            ),
                          ),
                        ],
                      )
                    : Text(
                        title,
                        style: TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.w600,
                          color: _textColor,
                        ),
                      ),
              ),
            ],
          ),
          Divider(height: 24, thickness: 1, color: _borderColor),
          SizedBox(height: 8),
          content,
        ],
      ),
    );
  }

  Widget _buildFormFieldLabel(String label, {bool isRequired = false}) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8.0),
      child: RichText(
        text: TextSpan(
          style: TextStyle(
            fontSize: 14,
            fontWeight: FontWeight.w500,
            color: _textColor,
          ),
          children: [
            TextSpan(text: label),
            if (isRequired)
              TextSpan(
                text: ' *',
                style: TextStyle(
                  color: _accentColor,
                  fontWeight: FontWeight.bold,
                ),
              ),
          ],
        ),
      ),
    );
  }

  Widget _buildInfoBanner(String text) {
    return Container(
      margin: EdgeInsets.only(bottom: 24),
      padding: EdgeInsets.symmetric(vertical: 12, horizontal: 16),
      decoration: BoxDecoration(
        color: _infoColor.withOpacity(0.1),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: _infoColor.withOpacity(0.3)),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(Icons.info_outline, color: _infoColor, size: 20),
          SizedBox(width: 12),
          Expanded(
            child: Text(
              text,
              style: TextStyle(
                color: _infoColor,
                fontSize: 14,
              ),
            ),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: _backgroundColor,
      appBar: AppBar(
        elevation: 0,
        backgroundColor: _cardColor,
        title: Text(
          'Laporan Kekerasan Seksual',
          style: TextStyle(
            color: _textColor,
            fontWeight: FontWeight.w600,
          ),
        ),
        leading: IconButton(
          icon: Icon(Icons.arrow_back, color: _textColor),
          onPressed: () => Navigator.of(context).pop(),
        ),
      ),
      body: Stack(
        children: [
          SingleChildScrollView(
            controller: _scrollController,
            child: Padding(
              padding: const EdgeInsets.all(20.0),
              child: Column(
                children: [
                  Container(
                    width: double.infinity,
                    padding: EdgeInsets.all(16),
                    decoration: BoxDecoration(
                      color: _accentColor.withOpacity(0.1),
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(
                        color: _accentColor.withOpacity(0.3),
                        width: 1,
                      ),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            Container(
                              padding: EdgeInsets.all(8),
                              decoration: BoxDecoration(
                                color: Colors.white,
                                shape: BoxShape.circle,
                              ),
                              child: Icon(
                                Icons.privacy_tip,
                                color: _accentColor,
                                size: 24,
                              ),
                            ),
                            SizedBox(width: 12),
                            Expanded(
                              child: Text(
                                'Form Laporan Kekerasan Seksual',
                                style: TextStyle(
                                  fontSize: 18,
                                  fontWeight: FontWeight.w600,
                                  color: _accentColor,
                                ),
                              ),
                            ),
                          ],
                        ),
                        SizedBox(height: 12),
                        Text(
                          'Laporan Anda akan ditangani secara rahasia dan profesional. Isi formulir ini dengan selengkap mungkin untuk membantu penanganan kasus.',
                          style: TextStyle(
                            fontSize: 14,
                            height: 1.5,
                            color: _accentColor,
                          ),
                        ),
                      ],
                    ),
                  ),
                  SizedBox(height: 24),
                  Card(
                    elevation: 0,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(16),
                      side: BorderSide(color: _borderColor),
                    ),
                    clipBehavior: Clip.antiAlias,
                    child: Padding(
                      padding: const EdgeInsets.all(24.0),
                      child: Form(
                        key: _formKey,
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            // Detail Laporan Section
                            _buildSection(
                              title: 'Detail Laporan',
                              icon: Icons.description_outlined,
                              content: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  // Judul Laporan
                                  _buildFormFieldLabel('Judul Laporan',
                                      isRequired: true),
                                  TextFormField(
                                    decoration: _inputDecoration(
                                        'Masukkan judul laporan'),
                                    validator: (value) =>
                                        value == null || value.isEmpty
                                            ? 'Judul laporan tidak boleh kosong'
                                            : null,
                                    onChanged: (value) =>
                                        report['title'] = value,
                                  ),
                                  SizedBox(height: 20),

                                  // Kategori Dropdown
                                  _buildFormFieldLabel('Kategori',
                                      isRequired: true),
                                  Container(
                                    decoration: BoxDecoration(
                                      borderRadius: BorderRadius.circular(8),
                                      border: Border.all(color: _borderColor),
                                    ),
                                    child: DropdownButtonFormField<String>(
                                      decoration: _dropdownDecoration(),
                                      value: report['category'].isEmpty
                                          ? null
                                          : report['category'],
                                      hint: Text('Pilih Kategori'),
                                      items: getFilteredCategories()
                                          .map((category) {
                                        return DropdownMenuItem<String>(
                                          value: category['category_id']
                                              .toString(),
                                          child: Text(category['nama']),
                                        );
                                      }).toList(),
                                      validator: (value) => value == null
                                          ? 'Kategori harus dipilih'
                                          : null,
                                      onChanged: (value) => setState(
                                          () => report['category'] = value!),
                                      dropdownColor: _cardColor,
                                      isExpanded: true,
                                    ),
                                  ),
                                  SizedBox(height: 20),

                                  // Bukti Pelanggaran
                                  _buildFormFieldLabel('Bukti Pelanggaran',
                                      isRequired: true),
                                  Container(
                                    padding: EdgeInsets.symmetric(
                                        horizontal: 16, vertical: 16),
                                    decoration: BoxDecoration(
                                      color: _fieldColor,
                                      borderRadius: BorderRadius.circular(8),
                                      border: Border.all(
                                        color: showBuktiWarning
                                            ? _errorColor
                                            : _borderColor,
                                      ),
                                    ),
                                    child: Column(
                                      crossAxisAlignment:
                                          CrossAxisAlignment.start,
                                      children: [
                                        ...buktiOptions.map(
                                          (option) => _buildCheckboxTile(
                                            title: option,
                                            value:
                                                selectedBukti.contains(option),
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
                                                left: 32.0,
                                                top: 8.0,
                                                right: 8.0),
                                            child: TextFormField(
                                              decoration: _inputDecoration(
                                                'Sebutkan bukti lainnya',
                                                padding: EdgeInsets.symmetric(
                                                    horizontal: 12,
                                                    vertical: 12),
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
                                            padding: const EdgeInsets.only(
                                                top: 12.0, left: 4),
                                            child: Row(
                                              children: [
                                                Icon(Icons.error_outline,
                                                    color: _errorColor,
                                                    size: 14),
                                                SizedBox(width: 6),
                                                Text(
                                                  'Pilih setidaknya satu bukti pelanggaran',
                                                  style: TextStyle(
                                                    color: _errorColor,
                                                    fontSize: 12,
                                                  ),
                                                ),
                                              ],
                                            ),
                                          ),
                                      ],
                                    ),
                                  ),
                                  SizedBox(height: 20),

                                  // Link Lampiran
                                  _buildFormFieldLabel(
                                      'Link Lampiran Tambahan'),
                                  TextFormField(
                                    decoration: _inputDecoration(
                                        'Masukkan URL Google Drive, Dropbox, dsb'),
                                    onChanged: (value) =>
                                        report['lampiran_link'] = value,
                                    keyboardType: TextInputType.url,
                                  ),
                                  SizedBox(height: 6),
                                  Text(
                                    'Masukkan URL Google Drive, Dropbox, atau layanan cloud lainnya',
                                    style: TextStyle(
                                      color: _lightTextColor,
                                      fontSize: 12,
                                    ),
                                  ),
                                  SizedBox(height: 20),

                                  // Deskripsi Laporan
                                  _buildFormFieldLabel('Deskripsi',
                                      isRequired: true),
                                  TextFormField(
                                    decoration: _inputDecoration(
                                      'Berikan Deskripsi atau Kronologi Kejadian',
                                      contentPadding: EdgeInsets.all(16),
                                    ),
                                    validator: (value) => value == null ||
                                            value.isEmpty
                                        ? 'Deskripsi laporan tidak boleh kosong'
                                        : null,
                                    onChanged: (value) =>
                                        report['description'] = value,
                                    maxLines: 5,
                                  ),
                                  SizedBox(height: 20),

                                  // Tanggal & Waktu Kejadian
                                  _buildFormFieldLabel(
                                      'Tanggal & Waktu Kejadian',
                                      isRequired: true),
                                  InkWell(
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
                                                primary: _primaryColor,
                                                onPrimary: Colors.white,
                                              ),
                                              dialogBackgroundColor:
                                                  Colors.white,
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
                                                  primary: _primaryColor,
                                                  onPrimary: Colors.white,
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
                                      padding: EdgeInsets.symmetric(
                                          horizontal: 16, vertical: 14),
                                      decoration: BoxDecoration(
                                        borderRadius: BorderRadius.circular(8),
                                        border: Border.all(color: _borderColor),
                                      ),
                                      child: Row(
                                        children: [
                                          Icon(Icons.calendar_today,
                                              size: 20, color: _primaryColor),
                                          SizedBox(width: 16),
                                          Text(
                                            report['incidentDate'] != null
                                                ? "${report['incidentDate'].toLocal()}"
                                                    .split('.')[0]
                                                : "Pilih Tanggal & Waktu",
                                            style: TextStyle(
                                              fontSize: 15,
                                              color:
                                                  report['incidentDate'] != null
                                                      ? _textColor
                                                      : _lightTextColor,
                                            ),
                                          ),
                                          Spacer(),
                                          Icon(Icons.arrow_drop_down,
                                              color: _primaryColor),
                                        ],
                                      ),
                                    ),
                                  ),
                                  SizedBox(height: 20),

                                  // Multiple Image Upload
                                  _buildFormFieldLabel('Lampiran Foto',
                                      isRequired: true),
                                  InkWell(
                                    onTap: handleFileUpload,
                                    child: Container(
                                      height: 150,
                                      decoration: BoxDecoration(
                                        border: Border.all(
                                            color: _borderColor, width: 1),
                                        borderRadius: BorderRadius.circular(8),
                                        color: _fieldColor,
                                      ),
                                      child: Center(
                                        child: Column(
                                          mainAxisAlignment:
                                              MainAxisAlignment.center,
                                          children: [
                                            Icon(Icons.cloud_upload,
                                                size: 48,
                                                color: _primaryColor
                                                    .withOpacity(0.7)),
                                            SizedBox(height: 12),
                                            Text(
                                              'Klik untuk memilih beberapa file foto',
                                              style: TextStyle(
                                                color: _textColor,
                                                fontWeight: FontWeight.w500,
                                              ),
                                            ),
                                            SizedBox(height: 8),
                                            Text(
                                              'Format: JPG, PNG, GIF (Maks 5MB)',
                                              style: TextStyle(
                                                  fontSize: 12,
                                                  color: _lightTextColor),
                                            ),
                                          ],
                                        ),
                                      ),
                                    ),
                                  ),

                                  // Image Previews
                                  if (imagePreviewBytes.isNotEmpty) ...[
                                    SizedBox(height: 20),
                                    _buildFormFieldLabel('Preview Foto'),
                                    Text(
                                      'Total ${imagePreviewBytes.length} file terpilih',
                                      style: TextStyle(
                                        fontSize: 13,
                                        color: _lightTextColor,
                                        fontStyle: FontStyle.italic,
                                      ),
                                    ),
                                    SizedBox(height: 12),
                                    Container(
                                      height: 140,
                                      child: ListView.builder(
                                        scrollDirection: Axis.horizontal,
                                        itemCount: imagePreviewBytes.length,
                                        itemBuilder: (context, index) {
                                          return Container(
                                            margin: EdgeInsets.only(right: 12),
                                            width: 140,
                                            decoration: BoxDecoration(
                                              border: Border.all(
                                                  color: _borderColor),
                                              borderRadius:
                                                  BorderRadius.circular(8),
                                              boxShadow: [
                                                BoxShadow(
                                                  color: Colors.black
                                                      .withOpacity(0.05),
                                                  blurRadius: 4,
                                                  offset: Offset(0, 2),
                                                ),
                                              ],
                                            ),
                                            child: Stack(
                                              fit: StackFit.expand,
                                              children: [
                                                ClipRRect(
                                                  borderRadius:
                                                      BorderRadius.circular(8),
                                                  child: Image.memory(
                                                    imagePreviewBytes[index],
                                                    fit: BoxFit.cover,
                                                  ),
                                                ),
                                                Positioned(
                                                  top: 6,
                                                  right: 6,
                                                  child: InkWell(
                                                    onTap: () =>
                                                        removeImage(index),
                                                    child: Container(
                                                      padding:
                                                          EdgeInsets.all(6),
                                                      decoration: BoxDecoration(
                                                        color: Colors.white
                                                            .withOpacity(0.9),
                                                        shape: BoxShape.circle,
                                                        boxShadow: [
                                                          BoxShadow(
                                                            color:
                                                                Colors.black26,
                                                            blurRadius: 3,
                                                          ),
                                                        ],
                                                      ),
                                                      child: Icon(
                                                        Icons.close,
                                                        size: 14,
                                                        color: _accentColor,
                                                      ),
                                                    ),
                                                  ),
                                                ),
                                              ],
                                            ),
                                          );
                                        },
                                      ),
                                    ),
                                  ],
                                ],
                              ),
                            ),

                            // Informasi Pelapor Section
                            _buildSection(
                              title: 'Informasi Pelapor',
                              icon: Icons.person_outline,
                              content: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  // Nama Pelapor
                                  _buildFormFieldLabel('Nama Pelapor',
                                      isRequired: true),
                                  TextFormField(
                                    controller: _namaPelaporController,
                                    decoration: _inputDecoration(
                                        'Masukkan nama lengkap'),
                                    validator: (value) =>
                                        value == null || value.isEmpty
                                            ? 'Nama pelapor tidak boleh kosong'
                                            : null,
                                  ),
                                  SizedBox(height: 20),

                                  // NIM Pelapor
                                  _buildFormFieldLabel('NIM Pelapor',
                                      isRequired: true),
                                  TextFormField(
                                    controller: _nimPelaporController,
                                    decoration:
                                        _inputDecoration('Masukkan NIM'),
                                    validator: (value) =>
                                        value == null || value.isEmpty
                                            ? 'NIM pelapor tidak boleh kosong'
                                            : null,
                                  ),
                                  SizedBox(height: 20),

                                  // Nomor HP
                                  _buildFormFieldLabel('Nomor HP Pelapor',
                                      isRequired: true),
                                  TextFormField(
                                    controller: _nomorTeleponController,
                                    decoration:
                                        _inputDecoration('Contoh: 08123456789'),
                                    keyboardType: TextInputType.phone,
                                    validator: (value) => value == null ||
                                            value.isEmpty
                                        ? 'Nomor HP pelapor tidak boleh kosong'
                                        : null,
                                  ),
                                  SizedBox(height: 20),

                                  // Profesi
                                  _buildFormFieldLabel('Profesi',
                                      isRequired: true),
                                  Container(
                                    decoration: BoxDecoration(
                                      borderRadius: BorderRadius.circular(8),
                                      border: Border.all(color: _borderColor),
                                    ),
                                    child: DropdownButtonFormField<String>(
                                      decoration: _dropdownDecoration(),
                                      value: report['profesi'].isEmpty
                                          ? null
                                          : report['profesi'],
                                      hint: Text('Pilih Profesi'),
                                      items: [
                                        DropdownMenuItem(
                                            value: 'dosen',
                                            child: Text('Dosen')),
                                        DropdownMenuItem(
                                            value: 'mahasiswa',
                                            child: Text('Mahasiswa')),
                                        DropdownMenuItem(
                                            value: 'staff',
                                            child: Text('Staff')),
                                        DropdownMenuItem(
                                            value: 'lainnya',
                                            child: Text('Lainnya')),
                                      ],
                                      validator: (value) => value == null
                                          ? 'Profesi harus dipilih'
                                          : null,
                                      onChanged: (value) => setState(
                                          () => report['profesi'] = value!),
                                      dropdownColor: _cardColor,
                                      isExpanded: true,
                                    ),
                                  ),
                                  SizedBox(height: 20),

                                  // Jenis Kelamin
                                  _buildFormFieldLabel('Jenis Kelamin',
                                      isRequired: true),
                                  Container(
                                    decoration: BoxDecoration(
                                      color: _fieldColor,
                                      borderRadius: BorderRadius.circular(8),
                                      border: Border.all(color: _borderColor),
                                    ),
                                    padding: EdgeInsets.symmetric(
                                        horizontal: 16, vertical: 8),
                                    child: Row(
                                      children: [
                                        Expanded(
                                          child: RadioListTile<String>(
                                            title: Text('Laki-laki'),
                                            value: 'laki-laki',
                                            groupValue: report['jenis_kelamin'],
                                            onChanged: (value) {
                                              setState(() =>
                                                  report['jenis_kelamin'] =
                                                      value!);
                                            },
                                            contentPadding: EdgeInsets.zero,
                                            dense: true,
                                          ),
                                        ),
                                        Expanded(
                                          child: RadioListTile<String>(
                                            title: Text('Perempuan'),
                                            value: 'perempuan',
                                            groupValue: report['jenis_kelamin'],
                                            onChanged: (value) {
                                              setState(() =>
                                                  report['jenis_kelamin'] =
                                                      value!);
                                            },
                                            contentPadding: EdgeInsets.zero,
                                            dense: true,
                                          ),
                                        ),
                                      ],
                                    ),
                                  ),
                                  SizedBox(height: 20),

                                  // Umur Pelapor
                                  _buildFormFieldLabel('Rentang Umur',
                                      isRequired: true),
                                  Container(
                                    padding: EdgeInsets.symmetric(
                                        horizontal: 16, vertical: 8),
                                    decoration: BoxDecoration(
                                      color: _fieldColor,
                                      borderRadius: BorderRadius.circular(8),
                                      border: Border.all(color: _borderColor),
                                    ),
                                    child: Column(
                                      children: [
                                        _buildRadioTile(
                                          title: 'Kurang dari 20 tahun',
                                          value: '<20',
                                          groupValue: report['umur_pelapor'],
                                          onChanged: (value) => setState(() =>
                                              report['umur_pelapor'] = value!),
                                        ),
                                        Divider(
                                            height: 1,
                                            color:
                                                _borderColor.withOpacity(0.6)),
                                        _buildRadioTile(
                                          title: '20 - 40 tahun',
                                          value: '20-40',
                                          groupValue: report['umur_pelapor'],
                                          onChanged: (value) => setState(() =>
                                              report['umur_pelapor'] = value!),
                                        ),
                                        Divider(
                                            height: 1,
                                            color:
                                                _borderColor.withOpacity(0.6)),
                                        _buildRadioTile(
                                          title: 'Lebih dari 40 tahun',
                                          value: '40<',
                                          groupValue: report['umur_pelapor'],
                                          onChanged: (value) => setState(() =>
                                              report['umur_pelapor'] = value!),
                                        ),
                                      ],
                                    ),
                                  ),
                                ],
                              ),
                            ),

                            _buildSection(
                              title: 'Informasi Terduga/Terlapor',
                              icon: Icons.person_search_outlined,
                              content: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  _buildInfoBanner(
                                    'Jika terduga adalah anonim, berikan inputan "anonim" untuk nama dan "anonim@gmail.com" untuk email.',
                                  ),

                                  // Terduga/Terlapor List
                                  ...List.generate(report['terlapor'].length,
                                      (index) {
                                    return _buildTerdugaCard(index);
                                  }),

                                  // Add Terduga Button
                                  Center(
                                    child: TextButton.icon(
                                      onPressed: addTerduga,
                                      icon: Icon(Icons.add_circle_outline,
                                          color: _primaryColor),
                                      label: Text(
                                        'Tambah Terduga/Terlapor',
                                        style: TextStyle(color: _primaryColor),
                                      ),
                                      style: TextButton.styleFrom(
                                        padding: EdgeInsets.symmetric(
                                            vertical: 12, horizontal: 16),
                                      ),
                                    ),
                                  ),
                                ],
                              ),
                            ),

                            // Informasi Saksi Section
                            _buildSection(
                              title: 'Informasi Saksi',
                              icon: Icons.people_alt_outlined,
                              content: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  // Saksi List
                                  ...List.generate(report['saksi'].length,
                                      (index) {
                                    return _buildSaksiCard(index);
                                  }),

                                  // Add Saksi Button
                                  Center(
                                    child: TextButton.icon(
                                      onPressed: addSaksi,
                                      icon: Icon(Icons.add_circle_outline,
                                          color: _primaryColor),
                                      label: Text(
                                        'Tambah Saksi',
                                        style: TextStyle(color: _primaryColor),
                                      ),
                                      style: TextButton.styleFrom(
                                        padding: EdgeInsets.symmetric(
                                            vertical: 12, horizontal: 16),
                                      ),
                                    ),
                                  ),
                                ],
                              ),
                            ),

                            // reCAPTCHA Verification Section
                            buildRecaptchaVerificationSection(),

                            // Pernyataan Section
                            _buildSection(
                              title: 'Pernyataan',
                              icon: Icons.gavel_outlined,
                              content: Container(
                                padding: EdgeInsets.all(20),
                                decoration: BoxDecoration(
                                  color: _fieldColor,
                                  borderRadius: BorderRadius.circular(12),
                                  border: Border.all(
                                    color: showAgreementWarning
                                        ? _errorColor
                                        : _borderColor,
                                  ),
                                ),
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Row(
                                      children: [
                                        Icon(
                                          Icons.verified_user,
                                          color: _primaryColor,
                                          size: 18,
                                        ),
                                        SizedBox(width: 10),
                                        Expanded(
                                          child: Column(
                                            crossAxisAlignment:
                                                CrossAxisAlignment.start,
                                            children: [
                                              Text(
                                                'Dengan ini saya menyatakan',
                                                style: TextStyle(
                                                  fontWeight: FontWeight.w600,
                                                  fontSize: 15,
                                                  color: _textColor,
                                                ),
                                              ),
                                              Text(
                                                'bahwa:',
                                                style: TextStyle(
                                                  fontWeight: FontWeight.w600,
                                                  fontSize: 15,
                                                  color: _textColor,
                                                ),
                                              ),
                                            ],
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
                                    Container(
                                      padding: EdgeInsets.symmetric(
                                          vertical: 12, horizontal: 16),
                                      decoration: BoxDecoration(
                                        borderRadius: BorderRadius.circular(8),
                                        color: report['agreement'] == true
                                            ? _successColor.withOpacity(0.1)
                                            : showAgreementWarning
                                                ? _errorColor.withOpacity(0.1)
                                                : Colors.white,
                                        border: Border.all(
                                          color: report['agreement'] == true
                                              ? _successColor
                                              : showAgreementWarning
                                                  ? _errorColor
                                                  : _borderColor,
                                        ),
                                      ),
                                      child: Row(
                                        children: [
                                          SizedBox(
                                            height: 24,
                                            width: 24,
                                            child: Checkbox(
                                              value:
                                                  report['agreement'] == true,
                                              onChanged: (bool? value) {
                                                setState(() {
                                                  report['agreement'] =
                                                      value ?? false;
                                                  showAgreementWarning = false;
                                                });
                                              },
                                              activeColor: _primaryColor,
                                              shape: RoundedRectangleBorder(
                                                borderRadius:
                                                    BorderRadius.circular(4),
                                              ),
                                            ),
                                          ),
                                          SizedBox(width: 12),
                                          Expanded(
                                            child: RichText(
                                              text: TextSpan(
                                                style: TextStyle(
                                                  fontSize: 14,
                                                  color: _textColor,
                                                ),
                                                children: [
                                                  TextSpan(
                                                    text:
                                                        'Saya menyetujui pernyataan di atas',
                                                    style: TextStyle(
                                                      fontWeight:
                                                          FontWeight.w500,
                                                    ),
                                                  ),
                                                  TextSpan(
                                                    text: ' *',
                                                    style: TextStyle(
                                                      color: _accentColor,
                                                      fontWeight:
                                                          FontWeight.bold,
                                                    ),
                                                  ),
                                                ],
                                              ),
                                            ),
                                          ),
                                        ],
                                      ),
                                    ),
                                    if (showAgreementWarning)
                                      Padding(
                                        padding: const EdgeInsets.only(
                                            top: 12.0, left: 4),
                                        child: Row(
                                          children: [
                                            Icon(Icons.error_outline,
                                                color: _errorColor, size: 14),
                                            SizedBox(width: 6),
                                            Text(
                                              'Anda harus menyetujui pernyataan ini untuk melanjutkan',
                                              style: TextStyle(
                                                color: _errorColor,
                                                fontSize: 12,
                                              ),
                                            ),
                                          ],
                                        ),
                                      ),
                                  ],
                                ),
                              ),
                            ),

                            // Form Actions
                            Container(
                              margin: EdgeInsets.only(top: 32, bottom: 16),
                              child: Row(
                                children: [
                                  Expanded(
                                    child: OutlinedButton.icon(
                                      onPressed: resetForm,
                                      icon: Icon(Icons.refresh),
                                      label: Text('Reset'),
                                      style: OutlinedButton.styleFrom(
                                        foregroundColor: _lightTextColor,
                                        side: BorderSide(color: _borderColor),
                                        padding:
                                            EdgeInsets.symmetric(vertical: 16),
                                        shape: RoundedRectangleBorder(
                                          borderRadius:
                                              BorderRadius.circular(8),
                                        ),
                                      ),
                                    ),
                                  ),
                                  SizedBox(width: 16),
                                  Expanded(
                                    flex: 2,
                                    child: ElevatedButton(
                                      onPressed: isSubmitting ||
                                              !recaptchaVerified ||
                                              report['agreement'] != true
                                          ? null
                                          : submitForm,
                                      style: ElevatedButton.styleFrom(
                                        backgroundColor: _accentColor,
                                        foregroundColor: Colors.white,
                                        padding:
                                            EdgeInsets.symmetric(vertical: 16),
                                        disabledBackgroundColor:
                                            _accentColor.withOpacity(0.3),
                                        shape: RoundedRectangleBorder(
                                          borderRadius:
                                              BorderRadius.circular(8),
                                        ),
                                        elevation: 0,
                                      ),
                                      child: Row(
                                        mainAxisAlignment:
                                            MainAxisAlignment.center,
                                        children: isSubmitting
                                            ? [
                                                SizedBox(
                                                  height: 20,
                                                  width: 20,
                                                  child:
                                                      CircularProgressIndicator(
                                                    strokeWidth: 3,
                                                    valueColor:
                                                        AlwaysStoppedAnimation<
                                                                Color>(
                                                            Colors.white),
                                                  ),
                                                ),
                                                SizedBox(width: 12),
                                                Text(
                                                  'Mengirim...',
                                                  style: TextStyle(
                                                    fontSize: 16,
                                                    fontWeight: FontWeight.w600,
                                                  ),
                                                ),
                                              ]
                                            : [
                                                Icon(Icons.send, size: 20),
                                                SizedBox(width: 12),
                                                Text(
                                                  'Kirim Laporan',
                                                  style: TextStyle(
                                                    fontSize: 16,
                                                    fontWeight: FontWeight.w600,
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
                        ),
                      ),
                    ),
                  ),
                  SizedBox(height: 24),
                ],
              ),
            ),
          ),

          // Loading overlay
          if (isSubmitting)
            Container(
              color: Colors.black.withOpacity(0.3),
              child: Center(
                child: Card(
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(16),
                  ),
                  child: Padding(
                    padding: const EdgeInsets.all(24.0),
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        CircularProgressIndicator(
                          valueColor:
                              AlwaysStoppedAnimation<Color>(_primaryColor),
                        ),
                        SizedBox(height: 16),
                        Text(
                          'Mengirim Laporan...',
                          style: TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.w500,
                            color: _textColor,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ),
        ],
      ),
    );
  }

  Widget _buildTerdugaCard(int index) {
    final Map<String, dynamic> terduga = report['terlapor'][index];

    return Container(
      margin: EdgeInsets.only(bottom: 20),
      child: Card(
        elevation: 0,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(12),
          side: BorderSide(color: _borderColor),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Container(
              padding: EdgeInsets.symmetric(horizontal: 16, vertical: 12),
              decoration: BoxDecoration(
                color: _primaryColor.withOpacity(0.05),
                borderRadius: BorderRadius.only(
                  topLeft: Radius.circular(12),
                  topRight: Radius.circular(12),
                ),
              ),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Row(
                    children: [
                      Icon(Icons.person_outline,
                          color: _primaryColor, size: 18),
                      SizedBox(width: 8),
                      Text(
                        'Terduga ${index + 1}',
                        style: TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.w600,
                          color: _primaryColor,
                        ),
                      ),
                    ],
                  ),
                  IconButton(
                    icon: Icon(Icons.delete_outline, color: _accentColor),
                    onPressed: () => removeTerduga(index),
                    tooltip: 'Hapus Terduga',
                    padding: EdgeInsets.zero,
                    constraints: BoxConstraints(),
                    visualDensity: VisualDensity.compact,
                  ),
                ],
              ),
            ),
            Padding(
              padding: const EdgeInsets.all(16.0),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Nama Terduga
                  _buildFormFieldLabel('Nama Lengkap', isRequired: true),
                  TextFormField(
                    decoration: _inputDecoration('Masukkan nama atau "anonim"'),
                    initialValue: terduga['nama_lengkap'],
                    onChanged: (value) =>
                        setState(() => terduga['nama_lengkap'] = value),
                  ),
                  SizedBox(height: 16),

                  // Email Terduga
                  _buildFormFieldLabel('Email'),
                  TextFormField(
                    decoration: _inputDecoration(
                        'Masukkan email atau "anonim@gmail.com"'),
                    initialValue: terduga['email'],
                    keyboardType: TextInputType.emailAddress,
                    onChanged: (value) =>
                        setState(() => terduga['email'] = value),
                  ),
                  SizedBox(height: 16),

                  // Nomor Telepon Terduga
                  _buildFormFieldLabel('Nomor Telepon'),
                  TextFormField(
                    decoration: _inputDecoration('Contoh: 08123456789'),
                    initialValue: terduga['nomor_telepon'],
                    keyboardType: TextInputType.phone,
                    onChanged: (value) =>
                        setState(() => terduga['nomor_telepon'] = value),
                  ),
                  SizedBox(height: 16),

                  // Jenis Kelamin
                  _buildFormFieldLabel('Jenis Kelamin'),
                  Container(
                    decoration: BoxDecoration(
                      color: _fieldColor,
                      borderRadius: BorderRadius.circular(8),
                      border: Border.all(color: _borderColor),
                    ),
                    padding: EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                    child: Row(
                      children: [
                        Expanded(
                          child: RadioListTile<String>(
                            title: Text('Laki-laki'),
                            value: 'laki-laki',
                            groupValue: terduga['jenis_kelamin'],
                            onChanged: (value) {
                              setState(() => terduga['jenis_kelamin'] = value!);
                            },
                            contentPadding: EdgeInsets.zero,
                            dense: true,
                          ),
                        ),
                        Expanded(
                          child: RadioListTile<String>(
                            title: Text('Perempuan'),
                            value: 'perempuan',
                            groupValue: terduga['jenis_kelamin'],
                            onChanged: (value) {
                              setState(() => terduga['jenis_kelamin'] = value!);
                            },
                            contentPadding: EdgeInsets.zero,
                            dense: true,
                          ),
                        ),
                      ],
                    ),
                  ),
                  SizedBox(height: 16),

                  // Rentang Umur Terduga
                  _buildFormFieldLabel('Rentang Umur'),
                  Container(
                    decoration: BoxDecoration(
                      color: _fieldColor,
                      borderRadius: BorderRadius.circular(8),
                      border: Border.all(color: _borderColor),
                    ),
                    child: Column(
                      children: [
                        _buildRadioTile(
                          title: 'Kurang dari 20 tahun',
                          value: '<20',
                          groupValue: terduga['umur_terlapor'],
                          onChanged: (value) =>
                              setState(() => terduga['umur_terlapor'] = value!),
                        ),
                        Divider(
                            height: 1, color: _borderColor.withOpacity(0.6)),
                        _buildRadioTile(
                          title: '20 - 40 tahun',
                          value: '20-40',
                          groupValue: terduga['umur_terlapor'],
                          onChanged: (value) =>
                              setState(() => terduga['umur_terlapor'] = value!),
                        ),
                        Divider(
                            height: 1, color: _borderColor.withOpacity(0.6)),
                        _buildRadioTile(
                          title: 'Lebih dari 40 tahun',
                          value: '40<',
                          groupValue: terduga['umur_terlapor'],
                          onChanged: (value) =>
                              setState(() => terduga['umur_terlapor'] = value!),
                        ),
                      ],
                    ),
                  ),
                  SizedBox(height: 16),

                  // Status Warga
                  _buildFormFieldLabel('Status Warga'),
                  Container(
                    decoration: BoxDecoration(
                      borderRadius: BorderRadius.circular(8),
                      border: Border.all(color: _borderColor),
                    ),
                    child: DropdownButtonFormField<String>(
                      decoration: _dropdownDecoration(),
                      value: terduga['status_warga'].isEmpty
                          ? null
                          : terduga['status_warga'],
                      hint: Text('Pilih Status'),
                      items: [
                        DropdownMenuItem(value: 'dosen', child: Text('Dosen')),
                        DropdownMenuItem(
                            value: 'mahasiswa', child: Text('Mahasiswa')),
                        DropdownMenuItem(value: 'staff', child: Text('Staff')),
                        DropdownMenuItem(
                            value: 'lainnya', child: Text('Lainnya')),
                      ],
                      onChanged: (value) =>
                          setState(() => terduga['status_warga'] = value!),
                      dropdownColor: _cardColor,
                      isExpanded: true,
                    ),
                  ),

                  SizedBox(height: 16),

                  // Unit Kerja
                  _buildFormFieldLabel('Unit Kerja'),
                  TextFormField(
                    decoration: _inputDecoration('Masukkan unit kerja'),
                    initialValue: terduga['unit_kerja'],
                    onChanged: (value) =>
                        setState(() => terduga['unit_kerja'] = value),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildSaksiCard(int index) {
    final Map<String, dynamic> saksi = report['saksi'][index];

    return Container(
      margin: EdgeInsets.only(bottom: 20),
      child: Card(
        elevation: 0,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(12),
          side: BorderSide(color: _borderColor),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Container(
              padding: EdgeInsets.symmetric(horizontal: 16, vertical: 12),
              decoration: BoxDecoration(
                color: _primaryColor.withOpacity(0.05),
                borderRadius: BorderRadius.only(
                  topLeft: Radius.circular(12),
                  topRight: Radius.circular(12),
                ),
              ),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Row(
                    children: [
                      Icon(Icons.people_alt_outlined,
                          color: _primaryColor, size: 18),
                      SizedBox(width: 8),
                      Text(
                        'Saksi ${index + 1}',
                        style: TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.w600,
                          color: _primaryColor,
                        ),
                      ),
                    ],
                  ),
                  IconButton(
                    icon: Icon(Icons.delete_outline, color: _accentColor),
                    onPressed: () => removeSaksi(index),
                    tooltip: 'Hapus Saksi',
                    padding: EdgeInsets.zero,
                    constraints: BoxConstraints(),
                    visualDensity: VisualDensity.compact,
                  ),
                ],
              ),
            ),
            Padding(
              padding: const EdgeInsets.all(16.0),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Nama Saksi
                  _buildFormFieldLabel('Nama Lengkap Saksi', isRequired: true),
                  TextFormField(
                    decoration: _inputDecoration('Masukkan nama lengkap'),
                    initialValue: saksi['nama_lengkap'],
                    onChanged: (value) =>
                        setState(() => saksi['nama_lengkap'] = value),
                  ),
                  SizedBox(height: 16),

                  // Email Saksi
                  _buildFormFieldLabel('Email Saksi'),
                  TextFormField(
                    decoration: _inputDecoration('Masukkan email'),
                    initialValue: saksi['email'],
                    keyboardType: TextInputType.emailAddress,
                    onChanged: (value) =>
                        setState(() => saksi['email'] = value),
                  ),
                  SizedBox(height: 16),

                  // Nomor Telepon Saksi
                  _buildFormFieldLabel('Nomor Telepon Saksi'),
                  TextFormField(
                    decoration: _inputDecoration('Contoh: 08123456789'),
                    initialValue: saksi['nomor_telepon'],
                    keyboardType: TextInputType.phone,
                    onChanged: (value) =>
                        setState(() => saksi['nomor_telepon'] = value),
                  ),
                ],
              ),
            ),
          ],
        ),
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
            padding: EdgeInsets.all(4),
            margin: EdgeInsets.only(right: 10, top: 2),
            decoration: BoxDecoration(
              color: _primaryColor.withOpacity(0.1),
              shape: BoxShape.circle,
            ),
            child: Text(
              '$number',
              style: TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.w600,
                color: _primaryColor,
              ),
            ),
          ),
          Expanded(
            child: Text(
              text,
              style: TextStyle(
                fontSize: 14,
                color: _lightTextColor,
                height: 1.5,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildCheckboxTile({
    required String title,
    required bool value,
    required Function(bool?) onChanged,
  }) {
    return Container(
      margin: EdgeInsets.only(bottom: 8),
      child: Row(
        children: [
          SizedBox(
            height: 24,
            width: 24,
            child: Checkbox(
              value: value,
              onChanged: onChanged,
              activeColor: _primaryColor,
              shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(4)),
            ),
          ),
          SizedBox(width: 10),
          Expanded(
            child: Text(
              title,
              style: TextStyle(fontSize: 14, color: _textColor),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildRadioTile({
    required String title,
    required String value,
    required String? groupValue,
    required Function(String?) onChanged,
  }) {
    return RadioListTile<String>(
      title: Text(title),
      value: value,
      groupValue: groupValue,
      onChanged: onChanged,
      contentPadding: EdgeInsets.symmetric(horizontal: 16),
      dense: true,
      activeColor: _primaryColor,
    );
  }

  InputDecoration _inputDecoration(
    String hintText, {
    EdgeInsetsGeometry contentPadding =
        const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
    EdgeInsetsGeometry padding = const EdgeInsets.all(0),
  }) {
    return InputDecoration(
      hintText: hintText,
      hintStyle: TextStyle(color: _lightTextColor),
      filled: false,
      contentPadding: contentPadding,
      border: OutlineInputBorder(
        borderRadius: BorderRadius.circular(8),
        borderSide: BorderSide(color: _borderColor),
      ),
      enabledBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(8),
        borderSide: BorderSide(color: _borderColor),
      ),
      focusedBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(8),
        borderSide: BorderSide(color: _primaryColor),
      ),
      errorBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(8),
        borderSide: BorderSide(color: _errorColor),
      ),
      focusedErrorBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(8),
        borderSide: BorderSide(color: _errorColor),
      ),
    );
  }

  InputDecoration _dropdownDecoration() {
    return InputDecoration(
      filled: false,
      contentPadding: EdgeInsets.symmetric(horizontal: 16, vertical: 0),
      border: InputBorder.none,
      enabledBorder: InputBorder.none,
      focusedBorder: InputBorder.none,
      errorBorder: InputBorder.none,
      focusedErrorBorder: InputBorder.none,
    );
  }
}
