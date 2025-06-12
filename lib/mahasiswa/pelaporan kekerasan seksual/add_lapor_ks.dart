import 'dart:convert';
import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:image_picker/image_picker.dart';
import 'package:intl/intl.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:http/http.dart' as http;
import '../../models/laporan_kekerasan.dart';
import '../../models/laporan_kekerasan_form.dart';
import '../../services/api_service.dart';
import 'dart:typed_data';

// Conditionally import web-specific libraries
import 'package:flutter_recaptcha_v2_compat/flutter_recaptcha_v2_compat.dart';
import 'package:webview_flutter/webview_flutter.dart';

// Define a function to safely import dart:html only on web
// ignore: uri_does_not_exist
import 'dart:html' if (dart.library.io) 'stub_html.dart' as html;
// ignore: uri_does_not_exist
import 'dart:ui_web' if (dart.library.io) 'stub_ui_web.dart' as ui_web;

class AddLaporKsPage extends StatefulWidget {
  const AddLaporKsPage({Key? key}) : super(key: key);

  @override
  _AddLaporKsPageState createState() => _AddLaporKsPageState();
}

class _AddLaporKsPageState extends State<AddLaporKsPage> {
  // GlobalKey untuk mengelola form
  final _formKey = GlobalKey<FormState>();

  // Controller untuk input teks
  final TextEditingController _judulController = TextEditingController();
  final TextEditingController _deskripsiController = TextEditingController();
  final TextEditingController _nomorTeleponController = TextEditingController();
  final TextEditingController _namaPelaporController = TextEditingController();
  final TextEditingController _nimPelaporController = TextEditingController();
  final TextEditingController _lampiranLinkController = TextEditingController();
  final TextEditingController _buktiLainnyaController = TextEditingController();

  // Variabel untuk menyimpan tanggal
  DateTime? _selectedDate;

  // Variabel untuk menyimpan gambar yang dipilih
  File? _imageFile;
  List<XFile>? selectedFiles;
  List<Uint8List> imagePreviewBytes = [];

  // Daftar jenis kekerasan yang dipilih
  String? _selectedJenisKekerasan;
  String? _selectedProfesi;
  String? _selectedJenisKelamin;
  String? _selectedUmurPelapor;

  // List untuk menyimpan kategori dari API
  List<String> _jenisKekerasanList = [];

  // Map untuk menyimpan kategori dari API
  Map<int, String> _categoriesMap = {};
  // Map terbalik untuk pencarian ID berdasarkan nama kategori
  Map<String, int> _categoryNameToIdMap = {};

  // For reCAPTCHA
  String createdViewId = 'recaptcha_element';
  String? recaptchaToken;
  String? recaptchaError;
  RecaptchaV2Controller recaptchaV2Controller = RecaptchaV2Controller();
  bool recaptchaVerified = false;
  final FocusNode recaptchaFocusNode = FocusNode();

  // For bukti pelanggaran checkboxes
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
  bool agreement = false;

  // Status loading
  bool _isLoading = false;
  bool _isLoadingCategories = true;
  bool isSubmitting = false;

  // For terduga/terlapor and saksi
  List<Map<String, dynamic>> terlapor = [
    {
      'nama_lengkap': '',
      'email': '',
      'nomor_telepon': '',
      'status_warga': '',
      'jenis_kelamin': ''
    }
  ];

  List<Map<String, dynamic>> saksi = [
    {'nama_lengkap': '', 'email': '', 'nomor_telepon': ''}
  ];

  @override
  void initState() {
    super.initState();
    _loadUserData();
    _loadCategories();

    // Initialize web components if on web platform
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

  void resetRecaptcha() {
    if (kIsWeb) {
      recaptchaV2Controller.reload();
      setState(() {
        recaptchaVerified = false;
        recaptchaError = null;
      });
    }
  }

  // Fungsi untuk memuat kategori dari API
  Future<void> _loadCategories() async {
    setState(() {
      _isLoadingCategories = true;
    });

    try {
      final ApiService apiService = ApiService();
      final categories = await apiService.getCategories();

      setState(() {
        _categoriesMap = categories;

        // Buat map terbalik untuk pencarian ID berdasarkan nama
        _categoriesMap.forEach((key, value) {
          _categoryNameToIdMap[value] = key;
        });

        // Update _jenisKekerasanList dengan hanya kategori yang dimulai dengan "Kekerasan"
        _jenisKekerasanList = _categoriesMap.values
            .where((categoryName) => categoryName.startsWith('Kekerasan'))
            .toList();

        _isLoadingCategories = false;
      });
    } catch (e) {
      print('Error loading categories: $e');
      // Jika gagal memuat kategori, sediakan daftar default
      setState(() {
        _jenisKekerasanList = [
          'Kekerasan Verbal',
          'Kekerasan Fisik',
          'Pelecehan Seksual',
          'Intimidasi',
          'Lainnya'
        ];
        _isLoadingCategories = false;
      });
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Gagal memuat kategori laporan')),
      );
    }
  }

  // Fungsi untuk memuat data user dari SharedPreferences
  Future<void> _loadUserData() async {
    try {
      final prefs = await SharedPreferences.getInstance();

      setState(() {
        _namaPelaporController.text = prefs.getString('user_name') ?? '';
        _nimPelaporController.text = prefs.getString('user_nim') ?? '';
        _nomorTeleponController.text = prefs.getString('user_no_telp') ?? '';
      });
    } catch (e) {
      print('Error loading user data: $e');
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Gagal memuat data pengguna')),
      );
    }
  }

  // Fungsi untuk membuka date picker
  Future<void> _selectDate(BuildContext context) async {
    final DateTime? picked = await showDatePicker(
      context: context,
      initialDate: DateTime.now(),
      firstDate: DateTime(2020),
      lastDate: DateTime.now(),
    );
    if (picked != null) {
      final TimeOfDay? pickedTime = await showTimePicker(
        context: context,
        initialTime: TimeOfDay.fromDateTime(DateTime.now()),
      );

      if (pickedTime != null) {
        setState(() {
          _selectedDate = DateTime(
            picked.year,
            picked.month,
            picked.day,
            pickedTime.hour,
            pickedTime.minute,
          );
        });
      } else {
        setState(() {
          _selectedDate = picked;
        });
      }
    }
  }

  // Fungsi untuk memilih gambar dari galeri atau kamera
  Future<void> _pickImage(ImageSource source) async {
    try {
      final picker = ImagePicker();
      final pickedFile = await picker.pickImage(source: source);

      if (pickedFile != null) {
        final bytes = await pickedFile.readAsBytes();

        // Check file size
        if (bytes.length > 5 * 1024 * 1024) {
          // 5MB limit
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('Ukuran gambar melebihi batas 5MB')),
          );
          return;
        }

        setState(() {
          _imageFile = File(pickedFile.path);

          // Also update for web compatibility
          if (selectedFiles == null) {
            selectedFiles = [];
          }
          selectedFiles!.add(pickedFile);

          imagePreviewBytes.add(bytes);
        });
      }
    } catch (e) {
      print('Error picking image: $e');
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Gagal memilih gambar')),
      );
    }
  }

  // Multiple image picker for web
  Future<void> handleMultipleFileUpload() async {
    final ImagePicker picker = ImagePicker();
    try {
      final List<XFile> images = await picker.pickMultiImage();

      if (images.isNotEmpty) {
        // Check file sizes
        List<String> oversizedFiles = [];
        List<Uint8List> validPreviews = [];
        List<XFile> validFiles = [];

        for (var image in images) {
          final bytes = await image.readAsBytes();
          if (bytes.length > 5 * 1024 * 1024) {
            oversizedFiles.add(image.name);
          } else {
            validPreviews.add(bytes);
            validFiles.add(image);
          }
        }

        if (oversizedFiles.isNotEmpty) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
                content: Text(
                    'File berikut melebihi batas 5MB: ${oversizedFiles.join(", ")}')),
          );
        }

        setState(() {
          if (selectedFiles == null) {
            selectedFiles = [];
          }
          selectedFiles!.addAll(validFiles);
          imagePreviewBytes.addAll(validPreviews);

          // Update single image file for compatibility with existing code
          if (validFiles.isNotEmpty && _imageFile == null) {
            _imageFile = File(validFiles.first.path);
          }
        });
      }
    } catch (e) {
      print('Error picking multiple images: $e');
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Gagal memilih gambar')),
      );
    }
  }

  void removeImage(int index) {
    setState(() {
      imagePreviewBytes.removeAt(index);
      selectedFiles!.removeAt(index);

      // Update single image file for compatibility with existing code
      if (selectedFiles!.isEmpty) {
        _imageFile = null;
      } else {
        _imageFile = File(selectedFiles!.first.path);
      }
    });
  }

  List<String> updateBuktiPelanggaran() {
    List<String> buktiArray = [...selectedBukti];

    if (showLainnyaInput && buktiLainnya.trim().isNotEmpty) {
      buktiArray.add('Lainnya: ${buktiLainnya.trim()}');
    }

    setState(() {
      // Store in a state variable if needed
    });

    return buktiArray;
  }

  // Add terduga functions
  void addTerduga() {
    setState(() {
      terlapor.add({
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
      terlapor.removeAt(index);
      if (terlapor.isEmpty) {
        addTerduga(); // Always keep at least one terduga field
      }
    });
  }

  // Add saksi functions
  void addSaksi() {
    setState(() {
      saksi.add({'nama_lengkap': '', 'email': '', 'nomor_telepon': ''});
    });
  }

  void removeSaksi(int index) {
    setState(() {
      saksi.removeAt(index);
      if (saksi.isEmpty) {
        addSaksi(); // Always keep at least one saksi field
      }
    });
  }

  // Validasi form yang lebih lengkap
  bool _validateForm() {
    if (_formKey.currentState!.validate() &&
        _selectedDate != null &&
        _selectedJenisKekerasan != null) {
      // Check if at least one evidence type is selected when buktiOptions are shown
      if (selectedBukti.isEmpty && !showLainnyaInput) {
        setState(() {
          showBuktiWarning = true;
        });
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Pilih setidaknya satu bukti pelanggaran')),
        );
        return false;
      }

      // Check if "lainnya" text is entered when that option is selected
      if (showLainnyaInput && buktiLainnya.trim().isEmpty) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Masukkan detail bukti lainnya')),
        );
        return false;
      }

      // Check if image is uploaded on non-web platform or selectedFiles on web
      if (!kIsWeb && _imageFile == null) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Bukti foto harus diunggah')),
        );
        return false;
      }

      if (kIsWeb && (selectedFiles == null || selectedFiles!.isEmpty)) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Bukti foto harus diunggah')),
        );
        return false;
      }

      // Check reCAPTCHA on web
      if (kIsWeb && !recaptchaVerified) {
        setState(() {
          recaptchaError = 'Harap selesaikan verifikasi reCAPTCHA';
        });
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
              content: Text(
                  'Harap selesaikan verifikasi reCAPTCHA untuk melanjutkan')),
        );
        return false;
      }

      // Check agreement checkbox
      if (!agreement) {
        setState(() {
          showAgreementWarning = true;
        });
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
              content:
                  Text('Anda harus menyetujui pernyataan untuk melanjutkan')),
        );
        return false;
      }

      return true;
    }

    if (_selectedDate == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Tanggal kejadian harus dipilih')),
      );
    }

    if (_selectedJenisKekerasan == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Jenis kekerasan harus dipilih')),
      );
    }

    return false;
  }

  // Fungsi untuk menampilkan dialog konfirmasi
  Future<bool> _showConfirmationDialog() async {
    bool confirm = false;
    await showDialog(
      context: context,
      builder: (BuildContext context) {
        return AlertDialog(
          title: Text('Konfirmasi'),
          content: Text('Apakah Anda yakin ingin mengirim laporan ini?'),
          actions: <Widget>[
            TextButton(
              onPressed: () {
                Navigator.of(context).pop();
                confirm = false;
              },
              child: Text('Batal'),
            ),
            TextButton(
              onPressed: () {
                Navigator.of(context).pop();
                confirm = true;
              },
              child: Text('Ya, Kirim'),
              style: TextButton.styleFrom(
                foregroundColor: Colors.white,
                backgroundColor: Color(0xFFE53935),
              ),
            ),
          ],
        );
      },
    );
    return confirm;
  }

  // Fungsi untuk menyimpan data laporan kekerasan seksual ke API
  Future<void> _saveLaporan() async {
    if (!_validateForm()) {
      return;
    }

    final bool confirmSubmit = await _showConfirmationDialog();
    if (!confirmSubmit) {
      return;
    }

    setState(() {
      isSubmitting = true;
    });

    try {
      // Get bukti pelanggaran array
      final buktiPelanggaranArray = updateBuktiPelanggaran();

      // Get categoryId from the _categoryNameToIdMap using the selected jenis kekerasan
      int categoryId;
      if (_categoryNameToIdMap.containsKey(_selectedJenisKekerasan)) {
        // If we've loaded the categories from API, use the correct ID
        categoryId = _categoryNameToIdMap[_selectedJenisKekerasan]!;
      } else {
        // Fallback mapping if API categories couldn't be loaded
        switch (_selectedJenisKekerasan) {
          case 'Kekerasan Verbal':
            categoryId = 1;
            break;
          case 'Kekerasan Fisik':
            categoryId = 2;
            break;
          case 'Pelecehan Seksual':
            categoryId = 3;
            break;
          case 'Intimidasi':
            categoryId = 4;
            break;
          case 'Lainnya':
          default:
            categoryId = 5;
            break;
        }
      }

      // Filter out empty terlapor and saksi entries
      List<Map<String, dynamic>> terlaporFiltered =
          terlapor.where((t) => t['nama_lengkap'].trim().isNotEmpty).toList();

      List<Map<String, dynamic>> saksiFiltered =
          saksi.where((s) => s['nama_lengkap'].trim().isNotEmpty).toList();

      // Prepare image files
      List<File> imageFiles = [];
      if (!kIsWeb && _imageFile != null) {
        imageFiles.add(_imageFile!);
      }

      // Submit report using the appropriate method
      if (kIsWeb) {
        // If on web, use a MultipartRequest to handle the form submission
        var formData = http.MultipartRequest(
            'POST',
            Uri.parse(
                'https://v3422040.mhs.d3tiuns.com/api/laporan_kekerasan/add_laporan'));

        // Add text fields
        formData.fields.addAll({
          'judul': _judulController.text,
          'category_id': categoryId.toString(),
          'deskripsi': _deskripsiController.text,
          'nama_pelapor': _namaPelaporController.text,
          'nim_pelapor': _nimPelaporController.text,
          'nomor_telepon': _nomorTeleponController.text,
          'tanggal_kejadian': _selectedDate != null
              ? DateFormat('yyyy-MM-dd HH:mm:ss').format(_selectedDate!)
              : '',
          'current_datetime': DateTime.now().toString(),
          'username': 'miftahul01', // Using the username from the context
          'profesi': _selectedProfesi ?? '',
          'jenis_kelamin': _selectedJenisKelamin ?? '',
          'umur_pelapor': _selectedUmurPelapor ?? '',
        });

        // Add reCAPTCHA token if available
        if (recaptchaToken != null) {
          formData.fields['g-recaptcha-response'] = recaptchaToken!;
        }

        // Add lampiran_link if available
        if (_lampiranLinkController.text.isNotEmpty) {
          formData.fields['lampiran_link'] = _lampiranLinkController.text;
        }

        // Add bukti_pelanggaran as array
        for (var bukti in buktiPelanggaranArray) {
          formData.fields['bukti_pelanggaran[]'] = bukti;
        }

        // Add terlapor with proper array format for Laravel
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
        formData.fields['agreement'] = agreement.toString();

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

        // Send request
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
      } else {
        // For non-web platforms, use the existing ApiService method
        final ApiService apiService = ApiService();
        final result = await apiService.submitLaporanKekerasan(
          title: _judulController.text,
          categoryId: categoryId,
          description: _deskripsiController.text,
          tanggalKejadian: DateFormat('yyyy-MM-dd').format(_selectedDate!),
          namaPelapor: _namaPelaporController.text,
          nimPelapor: _nimPelaporController.text,
          nomorTelepon: _nomorTeleponController.text,
          buktiPelanggaran: buktiPelanggaranArray,
          terlapor: terlaporFiltered,
          saksi: saksiFiltered,
          imageFiles: imageFiles,
          agreement: agreement,
        );

        _showSuccessDialog();
      }
    } catch (e) {
      print('Error submitting report: $e');
      _showErrorDialog(
          'Error', 'Terjadi kesalahan saat mengirim laporan: ${e.toString()}');
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
                Navigator.of(context).pop(); // Return to previous screen
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

  void resetForm() {
    setState(() {
      _judulController.text = '';
      _deskripsiController.text = '';
      _nomorTeleponController.text = '';
      _lampiranLinkController.text = '';
      _buktiLainnyaController.text = '';
      _selectedDate = null;
      _imageFile = null;
      _selectedJenisKekerasan = null;
      _selectedProfesi = null;
      _selectedJenisKelamin = null;
      _selectedUmurPelapor = null;
      selectedBukti = [];
      showLainnyaInput = false;
      buktiLainnya = '';
      showBuktiWarning = false;
      showAgreementWarning = false;
      imagePreviewBytes = [];
      selectedFiles = null;
      recaptchaError = null;
      recaptchaVerified = false;
      agreement = false;

      // Reset terlapor and saksi
      terlapor = [
        {
          'nama_lengkap': '',
          'email': '',
          'nomor_telepon': '',
          'status_warga': '',
          'jenis_kelamin': ''
        }
      ];

      saksi = [
        {'nama_lengkap': '', 'email': '', 'nomor_telepon': ''}
      ];

      // Load user data again
      _loadUserData();
    });

    // Reset reCAPTCHA if on web
    if (kIsWeb) {
      resetRecaptcha();
    }
  }

  Widget buildRecaptchaVerificationSection() {
    if (!kIsWeb) return SizedBox.shrink();

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

              // Direct RecaptchaV2 widget
              Container(
                height: 150,
                width: double.infinity,
                decoration: BoxDecoration(
                  border: Border.all(color: Colors.grey[300]!),
                  borderRadius: BorderRadius.circular(4),
                ),
                child: RecaptchaV2(
                  apiKey:
                      "6LeIxAcTAAAAAJcZVRqyHh71UMIEGNQ_MXjiZKhI", // Test key
                  apiSecret:
                      "6LeIxAcTAAAAAGG-vFI1TnRWxMZNFuojJ4WifJWe", // Test key
                  controller: recaptchaV2Controller,
                  onVerifiedError: (err) {
                    setState(() {
                      recaptchaVerified = false;
                      recaptchaError = err;
                    });
                    print("reCAPTCHA error: $err");
                  },
                  onVerifiedSuccessfully: (success) {
                    setState(() {
                      recaptchaVerified = success;
                      recaptchaError = null;
                      recaptchaToken =
                          "verified_successfully"; // Placeholder token
                    });

                    if (success) {
                      ScaffoldMessenger.of(context).showSnackBar(
                        SnackBar(
                            content: Text('Verifikasi reCAPTCHA berhasil')),
                      );
                    }
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

  Widget _buildTerdugaCard(int index) {
    final Map<String, dynamic> terduga = terlapor[index];

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
              decoration: InputDecoration(
                labelText: 'Nama Lengkap *',
                hintText: "Masukkan nama atau 'anonim'",
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(8),
                ),
              ),
              initialValue: terduga['nama_lengkap'],
              onChanged: (value) =>
                  setState(() => terduga['nama_lengkap'] = value),
            ),
            SizedBox(height: 16),

            // Email Terduga
            TextFormField(
              decoration: InputDecoration(
                labelText: 'Email',
                hintText: "Masukkan email atau 'anonim@gmail.com'",
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(8),
                ),
              ),
              initialValue: terduga['email'],
              keyboardType: TextInputType.emailAddress,
              onChanged: (value) => setState(() => terduga['email'] = value),
            ),
            SizedBox(height: 16),

            // Nomor Telepon Terduga
            TextFormField(
              decoration: InputDecoration(
                labelText: 'Nomor Telepon',
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(8),
                ),
              ),
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

            // Rentang Umur Terduga
            Text(
              'Rentang Umur *',
              style: TextStyle(fontSize: 14, fontWeight: FontWeight.bold),
            ),
            Container(
              decoration: BoxDecoration(
                color: Colors.grey[50],
                borderRadius: BorderRadius.circular(8),
                border: Border.all(color: Colors.grey[300]!),
              ),
              padding: EdgeInsets.symmetric(vertical: 8),
              child: Column(
                children: [
                  RadioListTile<String>(
                    title: Text('Kurang dari 20 tahun'),
                    value: '<20',
                    groupValue: terduga['umur_terlapor'],
                    onChanged: (value) {
                      setState(() => terduga['umur_terlapor'] = value!);
                    },
                    contentPadding: EdgeInsets.symmetric(horizontal: 16),
                    dense: true,
                  ),
                  RadioListTile<String>(
                    title: Text('20 - 40 tahun'),
                    value: '20-40',
                    groupValue: terduga['umur_terlapor'],
                    onChanged: (value) {
                      setState(() => terduga['umur_terlapor'] = value!);
                    },
                    contentPadding: EdgeInsets.symmetric(horizontal: 16),
                    dense: true,
                  ),
                  RadioListTile<String>(
                    title: Text('Lebih dari 40 tahun'),
                    value: '40<',
                    groupValue: terduga['umur_terlapor'],
                    onChanged: (value) {
                      setState(() => terduga['umur_terlapor'] = value!);
                    },
                    contentPadding: EdgeInsets.symmetric(horizontal: 16),
                    dense: true,
                  ),
                ],
              ),
            ),
            SizedBox(height: 16),

            // Status Warga
            DropdownButtonFormField<String>(
              decoration: InputDecoration(
                labelText: 'Status Warga *',
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(8),
                ),
              ),
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
    final Map<String, dynamic> saksiItem = saksi[index];

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
              decoration: InputDecoration(
                labelText: 'Nama Lengkap Saksi',
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(8),
                ),
              ),
              initialValue: saksiItem['nama_lengkap'],
              onChanged: (value) =>
                  setState(() => saksiItem['nama_lengkap'] = value),
            ),
            SizedBox(height: 16),

            // Email Saksi
            TextFormField(
              decoration: InputDecoration(
                labelText: 'Email Saksi',
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(8),
                ),
              ),
              initialValue: saksiItem['email'],
              keyboardType: TextInputType.emailAddress,
              onChanged: (value) => setState(() => saksiItem['email'] = value),
            ),
            SizedBox(height: 16),

            // Nomor Telepon Saksi
            TextFormField(
              decoration: InputDecoration(
                labelText: 'Nomor Telepon Saksi',
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(8),
                ),
              ),
              initialValue: saksiItem['nomor_telepon'],
              keyboardType: TextInputType.phone,
              onChanged: (value) =>
                  setState(() => saksiItem['nomor_telepon'] = value),
            ),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text('Laporan Kekerasan Seksual'),
        backgroundColor: Color(0xFFE53935),
      ),
      body: _isLoading || _isLoadingCategories
          ? Center(child: CircularProgressIndicator())
          : Padding(
              padding: const EdgeInsets.all(16.0),
              child: Form(
                key: _formKey,
                child: SingleChildScrollView(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      // Detail Laporan Section
                      _buildSectionTitle('Detail Laporan'),
                      SizedBox(height: 16),

                      // Judul Laporan
                      RichText(
                        text: const TextSpan(
                          style: TextStyle(fontSize: 16, color: Colors.black),
                          children: [
                            TextSpan(
                                text: 'Judul Laporan *',
                                style: TextStyle(fontWeight: FontWeight.bold)),
                          ],
                        ),
                      ),
                      SizedBox(height: 8),
                      TextFormField(
                        controller: _judulController,
                        decoration: InputDecoration(
                          hintText: 'Judul Laporan',
                          hintStyle: TextStyle(
                            color: Colors.grey[500],
                          ),
                          border: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(8),
                          ),
                        ),
                        validator: (value) {
                          if (value == null || value.isEmpty) {
                            return 'Judul tidak boleh kosong';
                          }
                          return null;
                        },
                      ),
                      SizedBox(height: 16),

                      // Kategori/Jenis Kekerasan
                      RichText(
                        text: const TextSpan(
                          style: TextStyle(fontSize: 16, color: Colors.black),
                          children: [
                            TextSpan(
                                text: 'Jenis Kekerasan *',
                                style: TextStyle(fontWeight: FontWeight.bold)),
                          ],
                        ),
                      ),
                      SizedBox(height: 8),
                      DropdownButtonFormField<String>(
                        decoration: InputDecoration(
                          labelText: 'Jenis Kekerasan',
                          labelStyle: TextStyle(color: Colors.grey[500]),
                          border: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(8),
                          ),
                        ),
                        value: _selectedJenisKekerasan,
                        items: _jenisKekerasanList.map((String jenis) {
                          return DropdownMenuItem<String>(
                            value: jenis,
                            child: Text(jenis),
                          );
                        }).toList(),
                        onChanged: (String? newValue) {
                          setState(() {
                            _selectedJenisKekerasan = newValue;
                          });
                        },
                        validator: (value) {
                          if (value == null || value.isEmpty) {
                            return 'Jenis kekerasan harus dipilih';
                          }
                          return null;
                        },
                      ),
                      SizedBox(height: 16),

                      // Bukti Pelanggaran Checkboxes
                      Text(
                        'Bukti Pelanggaran *',
                        style: TextStyle(
                            fontSize: 16, fontWeight: FontWeight.bold),
                      ),
                      SizedBox(height: 8),
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
                                    showBuktiWarning = false;
                                  });
                                },
                              ),
                            ),
                            CheckboxListTile(
                              title: Text('Lainnya',
                                  style: TextStyle(fontSize: 14)),
                              value: showLainnyaInput,
                              controlAffinity: ListTileControlAffinity.leading,
                              contentPadding: EdgeInsets.zero,
                              dense: true,
                              onChanged: (bool? value) {
                                setState(() {
                                  showLainnyaInput = value ?? false;
                                });
                              },
                            ),
                            if (showLainnyaInput)
                              Padding(
                                padding:
                                    const EdgeInsets.only(left: 32.0, top: 8.0),
                                child: TextFormField(
                                  controller: _buktiLainnyaController,
                                  decoration: InputDecoration(
                                    hintText: 'Sebutkan bukti lainnya',
                                    border: OutlineInputBorder(
                                      borderRadius: BorderRadius.circular(8),
                                    ),
                                    contentPadding: EdgeInsets.symmetric(
                                        horizontal: 10, vertical: 8),
                                  ),
                                  onChanged: (value) {
                                    setState(() {
                                      buktiLainnya = value;
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

                      // Link Lampiran - New field
                      Text(
                        'Link Lampiran Tambahan',
                        style: TextStyle(
                            fontSize: 16, fontWeight: FontWeight.bold),
                      ),
                      SizedBox(height: 8),
                      TextFormField(
                        controller: _lampiranLinkController,
                        decoration: InputDecoration(
                          hintText: 'Link Google Drive, Dropbox, dsb',
                          hintStyle: TextStyle(color: Colors.grey[500]),
                          helperText:
                              'Opsional: Masukkan URL Google Drive, Dropbox, atau layanan cloud lainnya',
                          border: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(8),
                          ),
                        ),
                      ),
                      SizedBox(height: 16),

                      // Deskripsi Laporan
                      RichText(
                        text: const TextSpan(
                          style: TextStyle(fontSize: 16, color: Colors.black),
                          children: [
                            TextSpan(
                                text: "Deskripsi Laporan *",
                                style: TextStyle(fontWeight: FontWeight.bold)),
                          ],
                        ),
                      ),
                      SizedBox(height: 8),
                      TextFormField(
                        controller: _deskripsiController,
                        maxLines: 5,
                        decoration: InputDecoration(
                          hintText: 'Berikan Deskripsi atau Kronologi Kejadian',
                          hintStyle: TextStyle(color: Colors.grey[500]),
                          border: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(8),
                          ),
                        ),
                        validator: (value) {
                          if (value == null || value.isEmpty) {
                            return 'Deskripsi tidak boleh kosong';
                          }
                          return null;
                        },
                      ),
                      SizedBox(height: 16),

                      // Tanggal Kejadian
                      RichText(
                        text: const TextSpan(
                          style: TextStyle(fontSize: 16, color: Colors.black),
                          children: [
                            TextSpan(
                                text: "Tanggal & Waktu Kejadian *",
                                style: TextStyle(fontWeight: FontWeight.bold)),
                          ],
                        ),
                      ),
                      SizedBox(height: 8),
                      InkWell(
                        onTap: () => _selectDate(context),
                        child: InputDecorator(
                          decoration: InputDecoration(
                            border: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(8),
                            ),
                          ),
                          child: Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              Text(
                                _selectedDate == null
                                    ? 'Pilih Tanggal & Waktu'
                                    : DateFormat('yyyy-MM-dd HH:mm')
                                        .format(_selectedDate!),
                                style: TextStyle(
                                  color: _selectedDate == null
                                      ? Colors.grey
                                      : Colors.black,
                                ),
                              ),
                              Icon(Icons.calendar_today, color: Colors.grey),
                            ],
                          ),
                        ),
                      ),
                      SizedBox(height: 16),

                      // Bukti Foto Section
                      RichText(
                        text: const TextSpan(
                          style: TextStyle(fontSize: 16, color: Colors.black),
                          children: [
                            TextSpan(
                                text: "Bukti Foto *",
                                style: TextStyle(fontWeight: FontWeight.bold)),
                          ],
                        ),
                      ),
                      SizedBox(height: 8),

                      // Foto upload buttons - different based on platform
                      kIsWeb
                          ? InkWell(
                              onTap: handleMultipleFileUpload,
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
                            )
                          : Row(
                              mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                              children: [
                                ElevatedButton.icon(
                                  onPressed: () =>
                                      _pickImage(ImageSource.camera),
                                  icon: Icon(Icons.camera_alt),
                                  label: Text('Ambil Gambar'),
                                  style: ElevatedButton.styleFrom(
                                    backgroundColor: Color(0xFF00A2EA),
                                  ),
                                ),
                                ElevatedButton.icon(
                                  onPressed: () =>
                                      _pickImage(ImageSource.gallery),
                                  icon: Icon(Icons.photo_library),
                                  label: Text('Pilih dari Galeri'),
                                  style: ElevatedButton.styleFrom(
                                    backgroundColor: Color(0xFF00A2EA),
                                  ),
                                ),
                              ],
                            ),
                      SizedBox(height: 16),

                      // Preview Gambar
                      if (!kIsWeb && _imageFile != null)
                        Center(
                          child: Column(
                            children: [
                              Text(
                                'Preview Foto',
                                style: TextStyle(
                                    fontSize: 14, fontWeight: FontWeight.bold),
                              ),
                              SizedBox(height: 8),
                              Stack(
                                children: [
                                  Image.file(
                                    _imageFile!,
                                    height: 200,
                                    width: double.infinity,
                                    fit: BoxFit.cover,
                                  ),
                                  Positioned(
                                    top: 4,
                                    right: 4,
                                    child: InkWell(
                                      onTap: () {
                                        setState(() {
                                          _imageFile = null;
                                        });
                                      },
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
                              ),
                            ],
                          ),
                        ),

                      // Multiple image previews for web
                      if (kIsWeb && imagePreviewBytes.isNotEmpty) ...[
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
                                    border:
                                        Border.all(color: Colors.grey[300]!),
                                    borderRadius: BorderRadius.circular(8),
                                  ),
                                  child: ClipRRect(
                                    borderRadius: BorderRadius.circular(8),
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

                      SizedBox(height: 8),
                      // Nama Pelapor
                      TextFormField(
                        controller: _namaPelaporController,
                        decoration: InputDecoration(
                          hintText: 'Nama Pelapor',
                          hintStyle: TextStyle(color: Colors.grey[500]),
                          border: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(8),
                          ),
                        ),
                        validator: (value) {
                          if (value == null || value.isEmpty) {
                            return 'Nama pelapor tidak boleh kosong';
                          }
                          return null;
                        },
                      ),
                      SizedBox(height: 16),

                      // NIM Pelapor
                      RichText(
                        text: const TextSpan(
                          style: TextStyle(fontSize: 16, color: Colors.black),
                          children: [
                            TextSpan(
                                text: "NIM Pelapor *",
                                style: TextStyle(fontWeight: FontWeight.bold)),
                          ],
                        ),
                      ),
                      SizedBox(height: 8),
                      TextFormField(
                        controller: _nimPelaporController,
                        keyboardType: TextInputType.number,
                        decoration: InputDecoration(
                          hintText: 'NIM Pelapor',
                          hintStyle: TextStyle(color: Colors.grey[500]),
                          border: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(8),
                          ),
                        ),
                        validator: (value) {
                          if (value == null || value.isEmpty) {
                            return 'NIM pelapor tidak boleh kosong';
                          }
                          return null;
                        },
                      ),
                      SizedBox(height: 16),

                      // Nomor Telepon Pelapor
                      RichText(
                        text: const TextSpan(
                          style: TextStyle(fontSize: 16, color: Colors.black),
                          children: [
                            TextSpan(
                                text: "Nomor Telepon Pelapor *",
                                style: TextStyle(fontWeight: FontWeight.bold)),
                          ],
                        ),
                      ),
                      SizedBox(height: 8),
                      TextFormField(
                        controller: _nomorTeleponController,
                        keyboardType: TextInputType.phone,
                        decoration: InputDecoration(
                          hintText: 'Nomor Telepon Pelapor',
                          hintStyle: TextStyle(color: Colors.grey[500]),
                          border: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(8),
                          ),
                        ),
                        validator: (value) {
                          if (value == null || value.isEmpty) {
                            return 'Nomor telepon tidak boleh kosong';
                          }
                          return null;
                        },
                      ),
                      SizedBox(height: 16),

                      // Profesi - New field
                      Text(
                        'Profesi *',
                        style: TextStyle(
                            fontSize: 16, fontWeight: FontWeight.bold),
                      ),
                      SizedBox(height: 8),
                      DropdownButtonFormField<String>(
                        decoration: InputDecoration(
                          hintText: 'Pilih Profesi',
                          border: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(8),
                          ),
                        ),
                        value: _selectedProfesi,
                        items: [
                          DropdownMenuItem(
                              value: 'dosen', child: Text('Dosen')),
                          DropdownMenuItem(
                              value: 'mahasiswa', child: Text('Mahasiswa')),
                          DropdownMenuItem(
                              value: 'staff', child: Text('Staff')),
                          DropdownMenuItem(
                              value: 'lainnya', child: Text('Lainnya')),
                        ],
                        onChanged: (value) {
                          setState(() {
                            _selectedProfesi = value;
                          });
                        },
                      ),
                      SizedBox(height: 16),

                      // Jenis Kelamin - New field
                      Text(
                        'Jenis Kelamin *',
                        style: TextStyle(
                            fontSize: 16, fontWeight: FontWeight.bold),
                      ),
                      SizedBox(height: 8),
                      Row(
                        children: [
                          Expanded(
                            child: RadioListTile<String>(
                              title: Text('Laki-laki'),
                              value: 'laki-laki',
                              groupValue: _selectedJenisKelamin,
                              onChanged: (value) {
                                setState(() {
                                  _selectedJenisKelamin = value;
                                });
                              },
                              contentPadding: EdgeInsets.zero,
                              dense: true,
                            ),
                          ),
                          Expanded(
                            child: RadioListTile<String>(
                              title: Text('Perempuan'),
                              value: 'perempuan',
                              groupValue: _selectedJenisKelamin,
                              onChanged: (value) {
                                setState(() {
                                  _selectedJenisKelamin = value;
                                });
                              },
                              contentPadding: EdgeInsets.zero,
                              dense: true,
                            ),
                          ),
                        ],
                      ),
                      SizedBox(height: 16),

                      // Umur Pelapor - New field
                      Text(
                        'Rentang Umur *',
                        style: TextStyle(
                            fontSize: 16, fontWeight: FontWeight.bold),
                      ),
                      SizedBox(height: 8),
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
                              groupValue: _selectedUmurPelapor,
                              onChanged: (value) {
                                setState(() {
                                  _selectedUmurPelapor = value;
                                });
                              },
                              contentPadding: EdgeInsets.zero,
                              dense: true,
                            ),
                            RadioListTile<String>(
                              title: Text('20 - 40 tahun'),
                              value: '20-40',
                              groupValue: _selectedUmurPelapor,
                              onChanged: (value) {
                                setState(() {
                                  _selectedUmurPelapor = value;
                                });
                              },
                              contentPadding: EdgeInsets.zero,
                              dense: true,
                            ),
                            RadioListTile<String>(
                              title: Text('Lebih dari 40 tahun'),
                              value: '40<',
                              groupValue: _selectedUmurPelapor,
                              onChanged: (value) {
                                setState(() {
                                  _selectedUmurPelapor = value;
                                });
                              },
                              contentPadding: EdgeInsets.zero,
                              dense: true,
                            ),
                          ],
                        ),
                      ),
                      SizedBox(height: 24),

                      // Informasi Terduga/Terlapor Section - New section
                      _buildSectionTitle('Informasi Terduga/Terlapor'),
                      SizedBox(height: 8),

                      // Anonymous Instruction Info Box
                      Container(
                        padding: EdgeInsets.all(12),
                        decoration: BoxDecoration(
                          color: Colors.blue[50],
                          border: Border(
                            left: BorderSide(color: Colors.blue, width: 4),
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
                      ...List.generate(terlapor.length, (index) {
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

                      // Informasi Saksi Section - New section
                      _buildSectionTitle('Informasi Saksi'),
                      SizedBox(height: 16),

                      // Saksi List
                      ...List.generate(saksi.length, (index) {
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

                      // Add reCAPTCHA for web
                      if (kIsWeb) buildRecaptchaVerificationSection(),
                      SizedBox(height: 24),

                      // Pernyataan Section - New section
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
                                style: TextStyle(fontWeight: FontWeight.bold)),
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
                              value: agreement,
                              controlAffinity: ListTileControlAffinity.leading,
                              contentPadding: EdgeInsets.zero,
                              onChanged: (bool? value) {
                                setState(() {
                                  agreement = value ?? false;
                                  showAgreementWarning = false;
                                });
                              },
                            ),
                            if (showAgreementWarning)
                              Padding(
                                padding: const EdgeInsets.only(left: 32.0),
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

                      // Form Submit Button
                      isSubmitting
                          ? Center(child: CircularProgressIndicator())
                          : ElevatedButton(
                              onPressed: _saveLaporan,
                              style: ElevatedButton.styleFrom(
                                foregroundColor: Colors.white,
                                backgroundColor: Color(0xFFE53935),
                                shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(8),
                                ),
                                padding: EdgeInsets.symmetric(vertical: 16),
                                minimumSize: Size(double.infinity, 50),
                              ),
                              child: Row(
                                mainAxisAlignment: MainAxisAlignment.center,
                                children: [
                                  Icon(Icons.save, size: 18),
                                  SizedBox(width: 8),
                                  Text(
                                    'Simpan Laporan',
                                    style: TextStyle(fontSize: 16),
                                  ),
                                ],
                              ),
                            ),
                      SizedBox(height: 24),
                    ],
                  ),
                ),
              ),
            ),
    );
  }

  @override
  void dispose() {
    // Dispose controllers
    _judulController.dispose();
    _deskripsiController.dispose();
    _nomorTeleponController.dispose();
    _namaPelaporController.dispose();
    _nimPelaporController.dispose();
    _lampiranLinkController.dispose();
    _buktiLainnyaController.dispose();
    recaptchaFocusNode.dispose();
    super.dispose();
  }
}

// Define stub classes for non-web platforms if needed
class HtmlElementPlaceholder {
  // Empty stub class
}
