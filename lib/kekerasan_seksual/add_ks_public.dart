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
    'Bukti transfer, cek, bukti penyetoran, dan rekening koran bank',
    'Dokumen dan/atau rekaman',
    'Foto dokumentasi',
    'Surat disposisi perintah',
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
          title: const Text('Sukses!'),
          content: const Text('Laporan berhasil dikirimkan'),
          actions: <Widget>[
            TextButton(
              onPressed: () {
                Navigator.of(context).pop();
              },
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
          title: Text(title),
          content: Text(message),
          actions: <Widget>[
            TextButton(
              onPressed: () {
                Navigator.of(context).pop();
              },
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
        Container(
          width: double.infinity,
          padding: EdgeInsets.only(bottom: 8),
          decoration: BoxDecoration(
            border: Border(bottom: BorderSide(color: Colors.grey[300]!)),
          ),
          child: Text(
            'Verifikasi reCAPTCHA',
            style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
          ),
        ),
        SizedBox(height: 16),
        Container(
          padding: EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: Colors.grey[50],
            borderRadius: BorderRadius.circular(5),
            border: Border.all(color: Colors.grey[300]!),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'Verifikasi bahwa Anda bukan robot sebelum mengirimkan laporan',
                style: TextStyle(fontSize: 14),
              ),
              SizedBox(height: 16),

              // Directly display the reCAPTCHA widget in the form itself
              Container(
                width: double.infinity,
                height: 120, // Fixed height to contain the widget
                decoration: BoxDecoration(
                  border: Border.all(color: Colors.grey[300]!),
                  borderRadius: BorderRadius.circular(4),
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
                            content: Text('Verifikasi reCAPTCHA berhasil')),
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

              SizedBox(height: 10),
              Center(
                child: recaptchaVerified
                    ? Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Icon(Icons.check_circle, color: Colors.green),
                          SizedBox(width: 8),
                          Text(
                            'Verifikasi berhasil',
                            style: TextStyle(color: Colors.green),
                          ),
                        ],
                      )
                    : Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Icon(Icons.info, color: Colors.orange),
                          SizedBox(width: 8),
                          Text(
                            'Harap selesaikan verifikasi reCAPTCHA',
                            style: TextStyle(color: Colors.orange),
                          ),
                        ],
                      ),
              ),
              if (recaptchaError != null)
                Padding(
                  padding: const EdgeInsets.only(top: 8.0),
                  child: Text(
                    recaptchaError!,
                    style: TextStyle(color: Colors.red, fontSize: 12),
                    textAlign: TextAlign.center,
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
      ),
      body: Stack(
        children: [
          SingleChildScrollView(
            child: Padding(
              padding: const EdgeInsets.all(16.0),
              child: Column(
                children: [
                  // Informasi Satgas PPK Section
                  Card(
                    elevation: 4,
                    child: Padding(
                      padding: const EdgeInsets.all(16.0),
                      child: Column(
                        children: [
                          Text(
                            'Satuan Tugas Pencegahan dan Penanganan Kekerasan (PPK)',
                            style: Theme.of(context).textTheme.titleLarge,
                            textAlign: TextAlign.center,
                          ),
                          SizedBox(height: 16),
                          Text(
                            'Kami berkomitmen menciptakan lingkungan kampus yang ramah, aman, inklusif, setara, dan bebas dari segala bentuk kekerasan.',
                          ),
                          SizedBox(height: 8),
                          Text(
                            'Sesuai dengan Peraturan Menteri Pendidikan dan Kebudayaan Riset Teknologi Nomor 55 Tahun 2024, lingkup pencegahan dan penanganan kekerasan mencakup enam bentuk kekerasan:',
                          ),
                          SizedBox(height: 8),
                          Container(
                            padding: EdgeInsets.all(8),
                            decoration: BoxDecoration(
                              color: Colors.grey[100],
                              borderRadius: BorderRadius.circular(8),
                              border: Border.all(color: Colors.grey[300]!),
                            ),
                            child: Row(
                              children: [
                                Expanded(
                                  child: Column(
                                    crossAxisAlignment:
                                        CrossAxisAlignment.start,
                                    children: [
                                      _buildBulletPoint('Kekerasan fisik'),
                                      _buildBulletPoint('Kekerasan psikis'),
                                      _buildBulletPoint('Perundungan'),
                                    ],
                                  ),
                                ),
                                Expanded(
                                  child: Column(
                                    crossAxisAlignment:
                                        CrossAxisAlignment.start,
                                    children: [
                                      _buildBulletPoint('Kekerasan seksual'),
                                      _buildBulletPoint(
                                          'Diskriminasi dan intoleransi'),
                                      _buildBulletPoint(
                                          'Kebijakan yang mengandung kekerasan'),
                                    ],
                                  ),
                                ),
                              ],
                            ),
                          ),
                          SizedBox(height: 16),
                          ElevatedButton.icon(
                            style: ElevatedButton.styleFrom(
                              backgroundColor: Colors.red[600],
                              foregroundColor: Colors.white,
                            ),
                            onPressed: () async {
                              const url = 'https://satgasppk.uns.ac.id/';
                              // You'd need to implement URL launching here
                            },
                            icon: Icon(Icons.open_in_new),
                            label:
                                Text('Kunjungi Website Resmi Satgas PPK UNS'),
                          ),
                        ],
                      ),
                    ),
                  ),
                  SizedBox(height: 24),

                  // Form Card
                  Card(
                    elevation: 4,
                    child: Padding(
                      padding: const EdgeInsets.all(16.0),
                      child: Form(
                        key: _formKey,
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              'Laporan Kekerasan Seksual',
                              style: Theme.of(context).textTheme.titleLarge,
                              textAlign: TextAlign.center,
                            ),
                            SizedBox(height: 24),

                            // Detail Laporan Section
                            _buildSectionTitle('Detail Laporan'),
                            SizedBox(height: 16),

                            // Judul Laporan
                            TextFormField(
                              decoration: _inputDecoration('Judul Laporan',
                                  isRequired: true),
                              validator: (value) =>
                                  value == null || value.isEmpty
                                      ? 'Masukkan judul laporan'
                                      : null,
                              onChanged: (value) => report['title'] = value,
                            ),
                            SizedBox(height: 16),

                            // Kategori Dropdown
                            DropdownButtonFormField<String>(
                              decoration: _inputDecoration('Kategori',
                                  isRequired: true),
                              value: report['category'].isEmpty
                                  ? null
                                  : report['category'],
                              hint: Text('Pilih Kategori'),
                              items: getFilteredCategories().map((category) {
                                return DropdownMenuItem<String>(
                                  value: category['category_id'].toString(),
                                  child: Text(category['nama']),
                                );
                              }).toList(),
                              validator: (value) =>
                                  value == null ? 'Pilih kategori' : null,
                              onChanged: (value) =>
                                  setState(() => report['category'] = value!),
                            ),
                            SizedBox(height: 16),

                            // Bukti Pelanggaran Checkboxes
                            Text(
                              'Bukti Pelanggaran *',
                              style: TextStyle(
                                  fontSize: 14, fontWeight: FontWeight.bold),
                            ),
                            Container(
                              padding: EdgeInsets.all(8),
                              decoration: BoxDecoration(
                                color: Colors.grey[50],
                                borderRadius: BorderRadius.circular(5),
                                border: Border.all(color: Colors.grey[300]!),
                              ),
                              child: Column(
                                children: [
                                  ...buktiOptions.map(
                                    (option) => CheckboxListTile(
                                      title: Text(option,
                                          style: TextStyle(fontSize: 14)),
                                      value: selectedBukti.contains(option),
                                      controlAffinity:
                                          ListTileControlAffinity.leading,
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
                                        });
                                      },
                                    ),
                                  ),
                                  CheckboxListTile(
                                    title: Text('Lainnya',
                                        style: TextStyle(fontSize: 14)),
                                    value: showLainnyaInput,
                                    controlAffinity:
                                        ListTileControlAffinity.leading,
                                    contentPadding: EdgeInsets.zero,
                                    dense: true,
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
                                          left: 32.0, top: 8.0),
                                      child: TextFormField(
                                        decoration: InputDecoration(
                                          hintText: 'Sebutkan bukti lainnya',
                                          border: OutlineInputBorder(),
                                          contentPadding: EdgeInsets.symmetric(
                                              horizontal: 10, vertical: 8),
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
                                      child: Text(
                                        'Pilih setidaknya satu bukti pelanggaran',
                                        style: TextStyle(
                                            color: Colors.red, fontSize: 12),
                                      ),
                                    ),
                                ],
                              ),
                            ),
                            SizedBox(height: 16),

                            // Link Lampiran
                            TextFormField(
                              decoration: _inputDecoration(
                                'Link Lampiran Tambahan',
                                helperText:
                                    'Masukkan URL Google Drive, Dropbox, atau layanan cloud lainnya',
                              ),
                              onChanged: (value) =>
                                  report['lampiran_link'] = value,
                            ),
                            SizedBox(height: 16),

                            // Deskripsi Laporan
                            TextFormField(
                              decoration: _inputDecoration(
                                'Deskripsi',
                                isRequired: true,
                                hintText:
                                    'Berikan Deskripsi atau Kronologi Kejadian',
                              ),
                              validator: (value) =>
                                  value == null || value.isEmpty
                                      ? 'Masukkan deskripsi laporan'
                                      : null,
                              onChanged: (value) =>
                                  report['description'] = value,
                              maxLines: 5,
                            ),
                            SizedBox(height: 16),

                            // Tanggal & Waktu Kejadian
                            InkWell(
                              onTap: () async {
                                final DateTime? pickedDate =
                                    await showDatePicker(
                                  context: context,
                                  initialDate:
                                      report['incidentDate'] ?? DateTime.now(),
                                  firstDate: DateTime(2000),
                                  lastDate: DateTime.now(),
                                );

                                if (pickedDate != null) {
                                  final TimeOfDay? pickedTime =
                                      await showTimePicker(
                                    context: context,
                                    initialTime: TimeOfDay.fromDateTime(
                                        report['incidentDate'] ??
                                            DateTime.now()),
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
                                    isRequired: true),
                                child: Text(
                                  report['incidentDate'] != null
                                      ? "${report['incidentDate'].toLocal()}"
                                          .split('.')[0]
                                      : "Pilih Tanggal & Waktu",
                                ),
                              ),
                            ),
                            SizedBox(height: 16),

                            // Multiple Image Upload
                            Text(
                              'Lampiran Foto *',
                              style: TextStyle(
                                  fontSize: 14, fontWeight: FontWeight.bold),
                            ),
                            SizedBox(height: 8),
                            InkWell(
                              onTap: handleFileUpload,
                              child: Container(
                                height: 150,
                                decoration: BoxDecoration(
                                  border: Border.all(
                                      color: Colors.grey[300]!,
                                      width: 2,
                                      style: BorderStyle.solid),
                                  borderRadius: BorderRadius.circular(8),
                                  color: Colors.grey[50],
                                ),
                                child: Center(
                                  child: Column(
                                    mainAxisAlignment: MainAxisAlignment.center,
                                    children: [
                                      Icon(Icons.cloud_upload,
                                          size: 48, color: Colors.grey[400]),
                                      SizedBox(height: 8),
                                      Text(
                                          'Klik untuk memilih beberapa file foto'),
                                      SizedBox(height: 4),
                                      Text(
                                        'Format: JPG, PNG, GIF (Maks 5MB)',
                                        style: TextStyle(
                                            fontSize: 12,
                                            color: Colors.grey[600]),
                                      ),
                                    ],
                                  ),
                                ),
                              ),
                            ),

                            // Image Previews
                            if (imagePreviewBytes.isNotEmpty) ...[
                              SizedBox(height: 16),
                              Text(
                                'Preview Foto (${imagePreviewBytes.length} file)',
                                style: TextStyle(
                                    fontSize: 14, fontWeight: FontWeight.bold),
                              ),
                              SizedBox(height: 8),
                              GridView.builder(
                                shrinkWrap: true,
                                physics: NeverScrollableScrollPhysics(),
                                gridDelegate:
                                    SliverGridDelegateWithFixedCrossAxisCount(
                                  crossAxisCount: 3,
                                  crossAxisSpacing: 8,
                                  mainAxisSpacing: 8,
                                ),
                                itemCount: imagePreviewBytes.length,
                                itemBuilder: (context, index) {
                                  return Stack(
                                    children: [
                                      Container(
                                        decoration: BoxDecoration(
                                          border: Border.all(
                                              color: Colors.grey[300]!),
                                          borderRadius:
                                              BorderRadius.circular(8),
                                        ),
                                        child: ClipRRect(
                                          borderRadius:
                                              BorderRadius.circular(8),
                                          child: Image.memory(
                                            imagePreviewBytes[index],
                                            fit: BoxFit.cover,
                                            width: double.infinity,
                                            height: double.infinity,
                                          ),
                                        ),
                                      ),
                                      Positioned(
                                        top: 4,
                                        right: 4,
                                        child: InkWell(
                                          onTap: () => removeImage(index),
                                          child: Container(
                                            padding: EdgeInsets.all(4),
                                            decoration: BoxDecoration(
                                              color: Colors.red,
                                              shape: BoxShape.circle,
                                            ),
                                            child: Icon(
                                              Icons.close,
                                              size: 14,
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
                            SizedBox(height: 24),

                            // Informasi Pelapor Section
                            _buildSectionTitle('Informasi Pelapor'),
                            SizedBox(height: 16),

                            // Nama Pelapor
                            TextFormField(
                              decoration: _inputDecoration('Nama Pelapor',
                                  isRequired: true),
                              validator: (value) =>
                                  value == null || value.isEmpty
                                      ? 'Masukkan nama pelapor'
                                      : null,
                              onChanged: (value) =>
                                  report['reporterName'] = value,
                            ),
                            SizedBox(height: 16),

                            // NIM Pelapor
                            TextFormField(
                              decoration: _inputDecoration('NIM Pelapor',
                                  isRequired: true),
                              validator: (value) =>
                                  value == null || value.isEmpty
                                      ? 'Masukkan NIM pelapor'
                                      : null,
                              onChanged: (value) => report['nim'] = value,
                            ),
                            SizedBox(height: 16),

                            // Nomor HP Pelapor
                            TextFormField(
                              decoration: _inputDecoration('Nomor HP Pelapor',
                                  isRequired: true),
                              keyboardType: TextInputType.phone,
                              validator: (value) =>
                                  value == null || value.isEmpty
                                      ? 'Masukkan nomor HP pelapor'
                                      : null,
                              onChanged: (value) => report['phone'] = value,
                            ),
                            SizedBox(height: 16),

                            // Profesi
                            DropdownButtonFormField<String>(
                              decoration:
                                  _inputDecoration('Profesi', isRequired: true),
                              value: report['profesi'].isEmpty
                                  ? null
                                  : report['profesi'],
                              hint: Text('Pilih Profesi'),
                              items: [
                                DropdownMenuItem(
                                    value: 'dosen', child: Text('Dosen')),
                                DropdownMenuItem(
                                    value: 'mahasiswa',
                                    child: Text('Mahasiswa')),
                                DropdownMenuItem(
                                    value: 'staff', child: Text('Staff')),
                                DropdownMenuItem(
                                    value: 'lainnya', child: Text('Lainnya')),
                              ],
                              validator: (value) =>
                                  value == null ? 'Pilih profesi' : null,
                              onChanged: (value) =>
                                  setState(() => report['profesi'] = value!),
                            ),
                            SizedBox(height: 16),

                            // Jenis Kelamin
                            Text(
                              'Jenis Kelamin *',
                              style: TextStyle(
                                  fontSize: 14, fontWeight: FontWeight.bold),
                            ),
                            Row(
                              children: [
                                Expanded(
                                  child: RadioListTile<String>(
                                    title: Text('Laki-laki'),
                                    value: 'laki-laki',
                                    groupValue: report['jenis_kelamin'],
                                    onChanged: (value) {
                                      setState(() =>
                                          report['jenis_kelamin'] = value!);
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
                                          report['jenis_kelamin'] = value!);
                                    },
                                    contentPadding: EdgeInsets.zero,
                                    dense: true,
                                  ),
                                ),
                              ],
                            ),
                            SizedBox(height: 16),

                            // Umur Pelapor
                            Text(
                              'Rentang Umur *',
                              style: TextStyle(
                                  fontSize: 14, fontWeight: FontWeight.bold),
                            ),
                            Container(
                              padding: EdgeInsets.all(8),
                              decoration: BoxDecoration(
                                color: Colors.grey[50],
                                borderRadius: BorderRadius.circular(5),
                                border: Border.all(color: Colors.grey[300]!),
                              ),
                              child: Column(
                                children: [
                                  RadioListTile<String>(
                                    title: Text('Kurang dari 20 tahun'),
                                    value: '<20',
                                    groupValue: report['umur_pelapor'],
                                    onChanged: (value) {
                                      setState(() =>
                                          report['umur_pelapor'] = value!);
                                    },
                                    contentPadding: EdgeInsets.zero,
                                    dense: true,
                                  ),
                                  RadioListTile<String>(
                                    title: Text('20 - 40 tahun'),
                                    value: '20-40',
                                    groupValue: report['umur_pelapor'],
                                    onChanged: (value) {
                                      setState(() =>
                                          report['umur_pelapor'] = value!);
                                    },
                                    contentPadding: EdgeInsets.zero,
                                    dense: true,
                                  ),
                                  RadioListTile<String>(
                                    title: Text('Lebih dari 40 tahun'),
                                    value: '40<',
                                    groupValue: report['umur_pelapor'],
                                    onChanged: (value) {
                                      setState(() =>
                                          report['umur_pelapor'] = value!);
                                    },
                                    contentPadding: EdgeInsets.zero,
                                    dense: true,
                                  ),
                                ],
                              ),
                            ),
                            SizedBox(height: 24),

                            // Informasi Terduga/Terlapor Section
                            _buildSectionTitle('Informasi Terduga/Terlapor'),
                            SizedBox(height: 8),

                            // Anonymous Instruction Info Box
                            Container(
                              padding: EdgeInsets.all(12),
                              decoration: BoxDecoration(
                                color: Colors.blue[50],
                                border: Border(
                                  left:
                                      BorderSide(color: Colors.blue, width: 4),
                                ),
                                borderRadius: BorderRadius.circular(4),
                              ),
                              child: Row(
                                children: [
                                  Icon(Icons.info, color: Colors.blue),
                                  SizedBox(width: 8),
                                  Expanded(
                                    child: Text(
                                      'Jika terduga adalah anonim, berikan inputan "anonim" untuk nama dan "anonim@gmail.com" untuk email.',
                                      style: TextStyle(color: Colors.blue[700]),
                                    ),
                                  ),
                                ],
                              ),
                            ),
                            SizedBox(height: 16),

                            // Terduga/Terlapor List
                            ...List.generate(report['terlapor'].length,
                                (index) {
                              return _buildTerdugaCard(index);
                            }),

                            // Add Terduga Button
                            SizedBox(height: 8),
                            OutlinedButton.icon(
                              onPressed: addTerduga,
                              icon: Icon(Icons.add),
                              label: Text('Tambah Terduga/Terlapor'),
                            ),
                            SizedBox(height: 24),

                            // Informasi Saksi Section
                            _buildSectionTitle('Informasi Saksi'),
                            SizedBox(height: 16),

                            // Saksi List
                            ...List.generate(report['saksi'].length, (index) {
                              return _buildSaksiCard(index);
                            }),

                            // Add Saksi Button
                            SizedBox(height: 8),
                            OutlinedButton.icon(
                              onPressed: addSaksi,
                              icon: Icon(Icons.add),
                              label: Text('Tambah Saksi'),
                            ),
                            SizedBox(height: 24),

                            buildRecaptchaVerificationSection(),
                            SizedBox(height: 24),

                            // Pernyataan Section
                            _buildSectionTitle('Pernyataan'),
                            SizedBox(height: 16),
                            Container(
                              padding: EdgeInsets.all(16),
                              decoration: BoxDecoration(
                                color: Colors.grey[50],
                                borderRadius: BorderRadius.circular(5),
                                border: Border.all(color: Colors.grey[300]!),
                              ),
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text('Dengan ini saya menyatakan bahwa:',
                                      style: TextStyle(
                                          fontWeight: FontWeight.bold)),
                                  SizedBox(height: 8),
                                  _buildNumberedItem(1,
                                      'Segala informasi yang saya berikan dalam laporan ini adalah benar dan dapat dipertanggungjawabkan.'),
                                  _buildNumberedItem(2,
                                      'Saya bersedia memberikan keterangan lebih lanjut apabila diperlukan untuk proses penanganan laporan.'),
                                  _buildNumberedItem(3,
                                      'Saya memahami bahwa memberikan laporan palsu dapat dikenakan sanksi sesuai dengan peraturan yang berlaku.'),
                                  SizedBox(height: 12),
                                  CheckboxListTile(
                                    title: Text(
                                      'Saya menyetujui pernyataan di atas *',
                                      style: TextStyle(fontSize: 14),
                                    ),
                                    value: report['agreement'] == true,
                                    controlAffinity:
                                        ListTileControlAffinity.leading,
                                    contentPadding: EdgeInsets.zero,
                                    onChanged: (bool? value) {
                                      setState(() {
                                        report['agreement'] = value ?? false;
                                        showAgreementWarning = false;
                                      });
                                    },
                                  ),
                                  if (showAgreementWarning)
                                    Padding(
                                      padding:
                                          const EdgeInsets.only(left: 32.0),
                                      child: Text(
                                        'Anda harus menyetujui pernyataan ini untuk melanjutkan',
                                        style: TextStyle(
                                            color: Colors.red, fontSize: 12),
                                      ),
                                    ),
                                ],
                              ),
                            ),
                            SizedBox(height: 24),

                            // Form Actions
                            SizedBox(height: 24),
                            Row(
                              mainAxisAlignment: MainAxisAlignment.end,
                              children: [
                                OutlinedButton(
                                  onPressed: () {
                                    Navigator.of(context).pop();
                                  },
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
                                            SizedBox(width: 8),
                                            Text('Mengirim...'),
                                          ],
                                        )
                                      : Text('Simpan Laporan'),
                                ),
                              ],
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSectionTitle(String title) {
    return Container(
      width: double.infinity,
      padding: EdgeInsets.only(bottom: 8),
      decoration: BoxDecoration(
        border: Border(bottom: BorderSide(color: Colors.grey[300]!)),
      ),
      child: Text(
        title,
        style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
      ),
    );
  }

  Widget _buildBulletPoint(String text) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 2),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('• ', style: TextStyle(fontWeight: FontWeight.bold)),
          Expanded(child: Text(text)),
        ],
      ),
    );
  }

  Widget _buildNumberedItem(int number, String text) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('$number. ', style: TextStyle(fontWeight: FontWeight.bold)),
          Expanded(child: Text(text)),
        ],
      ),
    );
  }

  InputDecoration _inputDecoration(
    String label, {
    bool isRequired = false,
    String? helperText,
    String? hintText,
  }) {
    return InputDecoration(
      labelText: isRequired ? '$label *' : label,
      hintText: hintText,
      helperText: helperText,
      helperMaxLines: 2,
      border: OutlineInputBorder(),
      contentPadding: EdgeInsets.symmetric(horizontal: 12, vertical: 12),
    );
  }

  Widget _buildTerdugaCard(int index) {
    final Map<String, dynamic> terduga = report['terlapor'][index];

    return Card(
      margin: EdgeInsets.only(bottom: 16),
      color: Colors.grey[50],
      child: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text('Terduga ${index + 1}',
                    style:
                        TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
                IconButton(
                  icon: Icon(Icons.delete, color: Colors.red),
                  onPressed: () => removeTerduga(index),
                  tooltip: 'Hapus Terduga',
                  padding: EdgeInsets.zero,
                  constraints: BoxConstraints(),
                ),
              ],
            ),
            SizedBox(height: 16),

            // Nama Terduga
            TextFormField(
              decoration: _inputDecoration('Nama Lengkap',
                  isRequired: true, hintText: "Masukkan nama atau 'anonim'"),
              initialValue: terduga['nama_lengkap'],
              onChanged: (value) =>
                  setState(() => terduga['nama_lengkap'] = value),
            ),
            SizedBox(height: 16),

            // Email Terduga
            TextFormField(
              decoration: _inputDecoration('Email',
                  hintText: "Masukkan email atau 'anonim@gmail.com'"),
              initialValue: terduga['email'],
              keyboardType: TextInputType.emailAddress,
              onChanged: (value) => setState(() => terduga['email'] = value),
            ),
            SizedBox(height: 16),

            // Nomor Telepon Terduga
            TextFormField(
              decoration: _inputDecoration('Nomor Telepon'),
              initialValue: terduga['nomor_telepon'],
              keyboardType: TextInputType.phone,
              onChanged: (value) =>
                  setState(() => terduga['nomor_telepon'] = value),
            ),
            SizedBox(height: 16),

            // Jenis Kelamin
            Text(
              'Jenis Kelamin *',
              style: TextStyle(fontSize: 14, fontWeight: FontWeight.bold),
            ),
            Row(
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
            SizedBox(height: 16),

            // Status Warga
            DropdownButtonFormField<String>(
              decoration: _inputDecoration('Status Warga', isRequired: true),
              value: terduga['status_warga'].isEmpty
                  ? null
                  : terduga['status_warga'],
              hint: Text('Pilih Status'),
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
      margin: EdgeInsets.only(bottom: 16),
      color: Colors.grey[50],
      child: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text('Saksi ${index + 1}',
                    style:
                        TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
                IconButton(
                  icon: Icon(Icons.delete, color: Colors.red),
                  onPressed: () => removeSaksi(index),
                  tooltip: 'Hapus Saksi',
                  padding: EdgeInsets.zero,
                  constraints: BoxConstraints(),
                ),
              ],
            ),
            SizedBox(height: 16),

            // Nama Saksi
            TextFormField(
              decoration:
                  _inputDecoration('Nama Lengkap Saksi', isRequired: true),
              initialValue: saksi['nama_lengkap'],
              onChanged: (value) =>
                  setState(() => saksi['nama_lengkap'] = value),
            ),
            SizedBox(height: 16),

            // Email Saksi
            TextFormField(
              decoration: _inputDecoration('Email Saksi', isRequired: true),
              initialValue: saksi['email'],
              keyboardType: TextInputType.emailAddress,
              onChanged: (value) => setState(() => saksi['email'] = value),
            ),
            SizedBox(height: 16),

            // Nomor Telepon Saksi
            TextFormField(
              decoration:
                  _inputDecoration('Nomor Telepon Saksi', isRequired: true),
              initialValue: saksi['nomor_telepon'],
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
