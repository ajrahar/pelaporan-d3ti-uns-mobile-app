import 'dart:io';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:intl/intl.dart';
import 'package:shared_preferences/shared_preferences.dart';
import "package:pelaporan_d3ti/shared/services/api_service.dart";
import 'package:http/http.dart' as http;
import 'dart:convert';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:timezone/timezone.dart' as tz;
import 'package:timezone/data/latest.dart' as tz_init;

class AddLaporKejadianPage extends StatefulWidget {
  const AddLaporKejadianPage({Key? key}) : super(key: key);

  @override
  _AddLaporKejadianPageState createState() => _AddLaporKejadianPageState();
}

class _AddLaporKejadianPageState extends State<AddLaporKejadianPage> {
  // Local notifications plugin
  final FlutterLocalNotificationsPlugin flutterLocalNotificationsPlugin =
      FlutterLocalNotificationsPlugin();

  // API service instance
  final ApiService _apiService = ApiService();

  // GlobalKey untuk mengelola form
  final _formKey = GlobalKey<FormState>();

  // Controller untuk input teks
  final TextEditingController _judulController = TextEditingController();
  final TextEditingController _deskripsiController = TextEditingController();
  final TextEditingController _nomorTeleponController = TextEditingController();
  final TextEditingController _namaPelaporController = TextEditingController();
  final TextEditingController _nimPelaporController = TextEditingController();
  final TextEditingController _lampiranLinkController = TextEditingController();

  // Controller untuk terlapor
  final List<Map<String, dynamic>> _terlaporList = [
    {
      'nama_lengkap': TextEditingController(),
      'email': TextEditingController(),
      'nomor_telepon': TextEditingController(),
      'jenis_kelamin': null,
      'umur_terlapor': null,
      'status_warga': null,
      'unit_kerja': null,
    }
  ];

  // Controller untuk saksi
  final List<Map<String, dynamic>> _saksiList = [
    {
      'nama_lengkap': TextEditingController(),
      'email': TextEditingController(),
      'nomor_telepon': TextEditingController(),
    }
  ];

  // Status loading dan errors
  bool _isLoading = false;
  bool _isLoadingCategories = true;
  String? _categoryError;
  Map<String, dynamic> _errors = {};

  // Variabel untuk menyimpan tanggal dan waktu
  DateTime? _selectedDate;
  TimeOfDay? _selectedTime;

  // Variabel untuk menyimpan gambar yang dipilih
  List<File> _imageFiles = [];

  // Daftar kategori dan kategori yang dipilih
  List<Map<String, dynamic>> _kategoriList = [];
  int? _selectedKategori;

  // Daftar bukti pelanggaran
  List<Map<String, dynamic>> _buktiOptions = [
    {'value': 'dokumen_rekaman', 'label': 'Dokumen dan/atau rekaman video'},
    {'value': 'foto_dokumentasi', 'label': 'Foto dokumentasi kejadian'},
    {'value': 'surat_pernyataan', 'label': 'Surat pernyataan kejadian'},
    {'value': 'laporan_saksi', 'label': 'Keterangan saksi kejadian'},
    {
      'value': 'identitas_sumber',
      'label': 'Identitas sumber informasi pihak ketiga'
    },
    {'value': 'lainnya', 'label': 'Lainnya'},
  ];
  List<String> _selectedBuktiPelanggaran = [];

  // Informasi pelapor
  String? _profesi;
  String? _jenisKelamin;
  String? _umurPelapor;
  bool _agreement = false;

  // Theme colors
  final Color _primaryColor = Color(0xFF00A2EA); // Blue
  final Color _secondaryColor = Color(0xFFF78052); // Orange
  final Color _errorColor = Color(0xFFE53E3E); // Red
  final Color _successColor = Color(0xFF38A169); // Green
  final Color _warningColor = Color(0xFFED8936); // Orange
  final Color _backgroundColor = Color(0xFFF9FAFC); // Light gray
  final Color _cardColor = Colors.white;
  final Color _textColor = Color(0xFF2D3748); // Dark gray
  final Color _lightTextColor = Color(0xFF718096); // Light gray text
  final Color _borderColor = Color(0xFFE2E8F0); // Border gray
  final Color _disabledColor = Color(0xFFEDF2F7); // Disabled gray

  @override
  void initState() {
    super.initState();
    _loadUserData();
    _fetchCategories();
    _initializeNotifications();
  }

  // Initialize the notification plugin
  Future<void> _initializeNotifications() async {
    // Initialize timezone
    tz_init.initializeTimeZones();

    // Initialize Android settings
    const AndroidInitializationSettings initializationSettingsAndroid =
        AndroidInitializationSettings('@mipmap/ic_launcher');

    // Initialize iOS settings
    final DarwinInitializationSettings initializationSettingsDarwin =
        DarwinInitializationSettings(
      requestAlertPermission: true,
      requestBadgePermission: true,
      requestSoundPermission: true,
    );

    // Complete initialization settings
    final InitializationSettings initializationSettings =
        InitializationSettings(
      android: initializationSettingsAndroid,
      iOS: initializationSettingsDarwin,
    );

    // Initialize the plugin
    await flutterLocalNotificationsPlugin.initialize(
      initializationSettings,
      onDidReceiveNotificationResponse: (NotificationResponse response) async {
        // Handle notification tap
        if (response.payload != null) {
          debugPrint('Notification payload: ${response.payload}');
          // You can handle navigation here when notification is tapped
        }
      },
    );

    // Request permissions for Android 13+
    await flutterLocalNotificationsPlugin
        .resolvePlatformSpecificImplementation<
            AndroidFlutterLocalNotificationsPlugin>()
        ?.requestNotificationsPermission();
  }

  // Show immediate notification
  Future<void> _showNotification({
    required String title,
    required String body,
    String? payload,
  }) async {
    const AndroidNotificationDetails androidDetails =
        AndroidNotificationDetails(
      'laporan_channel',
      'Laporan Notifications',
      channelDescription: 'Notifications for laporan submission status',
      importance: Importance.max,
      priority: Priority.high,
      ticker: 'ticker',
      color: Color(0xFF00A2EA), // Blue color for notification
      icon: '@mipmap/ic_launcher',
      enableVibration: true,
    );

    const DarwinNotificationDetails iOSDetails = DarwinNotificationDetails(
      presentAlert: true,
      presentBadge: true,
      presentSound: true,
    );

    const NotificationDetails notificationDetails = NotificationDetails(
      android: androidDetails,
      iOS: iOSDetails,
    );

    await flutterLocalNotificationsPlugin.show(
      DateTime.now().millisecond, // unique ID based on current time
      title,
      body,
      notificationDetails,
      payload: payload,
    );
  }

  Future<void> _fetchCategories() async {
    setState(() {
      _isLoadingCategories = true;
      _categoryError = null;
    });

    try {
      final Map<int, String> categories = await _apiService.getCategories();

      if (categories.isNotEmpty) {
        // Track category names we've already added
        Set<String> addedCategoryNames = {};
        List<Map<String, dynamic>> categoryList = [];

        categories.forEach((id, name) {
          // Only add this category if we haven't seen this name before
          if (!addedCategoryNames.contains(name.toLowerCase())) {
            categoryList.add({'id': id, 'nama': name});
            addedCategoryNames.add(name.toLowerCase());
          }
        });

        setState(() {
          _kategoriList = categoryList;
          _isLoadingCategories = false;
        });

        print('Categories loaded (deduplicated): ${_kategoriList.length}');
      } else {
        setState(() {
          _categoryError = 'Tidak ada kategori yang tersedia';
          _isLoadingCategories = false;
        });
      }
    } catch (e) {
      print('Error fetching categories: $e');
      setState(() {
        _categoryError = 'Gagal memuat kategori: $e';
        _isLoadingCategories = false;

        // Fallback to default categories if API fails
        _kategoriList = [
          {'id': 1, 'nama': 'Kehilangan Barang'},
          {'id': 2, 'nama': 'Kerusakan Fasilitas'},
          {'id': 5, 'nama': 'Kecelakaan'},
          {'id': 6, 'nama': 'Lainnya'}
        ];
      });

      // Show notification for category loading error
      _showNotification(
        title: 'Peringatan',
        body: 'Gagal memuat kategori. Menggunakan kategori default.',
        payload: 'category_error',
      );
    }
  }

  // Filter kategori sesuai permintaan (tidak menampilkan kategori yang berawalan "Kekerasan")
  List<Map<String, dynamic>> get filteredKategori {
    return _kategoriList
        .where((kategori) =>
            !kategori['nama'].toString().toLowerCase().startsWith('kekerasan'))
        .toList();
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

      // Show notification if user data can't be loaded
      _showNotification(
        title: 'Info',
        body:
            'Data pengguna tidak dapat dimuat. Silakan isi form secara manual.',
        payload: 'user_data_error',
      );
    }
  }

  // Fungsi untuk membuka date picker
  Future<void> _selectDate(BuildContext context) async {
    final DateTime? picked = await showDatePicker(
      context: context,
      initialDate: DateTime.now(),
      firstDate: DateTime(2020),
      lastDate: DateTime(2100),
      builder: (context, child) {
        return Theme(
          data: Theme.of(context).copyWith(
            colorScheme: ColorScheme.light(
              primary: _primaryColor,
              onPrimary: Colors.white,
              surface: Colors.white,
              onSurface: _textColor,
            ),
            textButtonTheme: TextButtonThemeData(
              style: TextButton.styleFrom(
                foregroundColor: _primaryColor,
              ),
            ),
          ),
          child: child!,
        );
      },
    );
    if (picked != null) {
      setState(() {
        _selectedDate = picked;
      });

      // Setelah memilih tanggal, buka time picker
      _selectTime(context);
    }
  }

  // Fungsi untuk membuka time picker
  Future<void> _selectTime(BuildContext context) async {
    final TimeOfDay? picked = await showTimePicker(
      context: context,
      initialTime: TimeOfDay.now(),
      builder: (context, child) {
        return Theme(
          data: Theme.of(context).copyWith(
            colorScheme: ColorScheme.light(
              primary: _primaryColor,
              onPrimary: Colors.white,
              surface: Colors.white,
              onSurface: _textColor,
            ),
            textButtonTheme: TextButtonThemeData(
              style: TextButton.styleFrom(
                foregroundColor: _primaryColor,
              ),
            ),
          ),
          child: child!,
        );
      },
    );
    if (picked != null) {
      setState(() {
        _selectedTime = picked;
      });
    }
  }

  // Fungsi untuk memilih gambar dari galeri atau kamera
  Future<void> _pickImage(ImageSource source) async {
    try {
      final picker = ImagePicker();
      final pickedFile = await picker.pickImage(
        source: source,
        imageQuality: 80, // Kompresi kualitas gambar
      );

      if (pickedFile != null) {
        setState(() {
          _imageFiles.add(File(pickedFile.path));
        });
      }
    } catch (e) {
      // Show notification if image picking fails
      _showNotification(
        title: 'Peringatan',
        body: 'Tidak dapat mengambil gambar: ${e.toString()}',
        payload: 'image_error',
      );
    }
  }

  // Fungsi untuk menghapus gambar
  void _removeImage(int index) {
    setState(() {
      _imageFiles.removeAt(index);
    });
  }

  // Fungsi untuk menambah terlapor
  void _addTerlapor() {
    setState(() {
      _terlaporList.add({
        'nama_lengkap': TextEditingController(),
        'email': TextEditingController(),
        'nomor_telepon': TextEditingController(),
        'jenis_kelamin': null,
        'umur_terlapor': null,
        'status_warga': null,
        'unit_kerja': null,
      });
    });
  }

  // Fungsi untuk menghapus terlapor
  void _removeTerlapor(int index) {
    if (_terlaporList.length > 1) {
      setState(() {
        _terlaporList.removeAt(index);
      });
    }
  }

  // Fungsi untuk menambah saksi
  void _addSaksi() {
    setState(() {
      _saksiList.add({
        'nama_lengkap': TextEditingController(),
        'email': TextEditingController(),
        'nomor_telepon': TextEditingController(),
      });
    });
  }

  // Fungsi untuk menghapus saksi
  void _removeSaksi(int index) {
    if (_saksiList.length > 1) {
      setState(() {
        _saksiList.removeAt(index);
      });
    }
  }

  // Validasi form
  bool _validateForm() {
    _errors = {};
    bool isValid = true;

    // Validasi field wajib
    if (_judulController.text.isEmpty) {
      _errors['judul'] = 'Judul tidak boleh kosong';
      isValid = false;
    }

    if (_selectedKategori == null) {
      _errors['category_id'] = 'Kategori harus dipilih';
      isValid = false;
    }

    if (_imageFiles.isEmpty) {
      _errors['image_path'] = 'Bukti laporan harus diunggah';
      isValid = false;
    }

    if (_deskripsiController.text.isEmpty) {
      _errors['deskripsi'] = 'Deskripsi tidak boleh kosong';
      isValid = false;
    }

    if (_selectedDate == null) {
      _errors['tanggal_kejadian'] = 'Tanggal kejadian harus dipilih';
      isValid = false;
    }

    if (_profesi == null) {
      _errors['profesi'] = 'Profesi harus dipilih';
      isValid = false;
    }

    if (_jenisKelamin == null) {
      _errors['jenis_kelamin'] = 'Jenis kelamin harus dipilih';
      isValid = false;
    }

    if (_umurPelapor == null) {
      _errors['umur_pelapor'] = 'Rentang umur harus dipilih';
      isValid = false;
    }

    if (_selectedBuktiPelanggaran.isEmpty) {
      _errors['bukti_pelanggaran'] = 'Pilih minimal satu alat bukti';
      isValid = false;
    }

    if (!_agreement) {
      _errors['agreement'] = 'Anda harus menyetujui pernyataan';
      isValid = false;
    }

    // Validasi terlapor (jika ada data yang diisi)
    for (int i = 0; i < _terlaporList.length; i++) {
      final terlapor = _terlaporList[i];
      bool hasData = terlapor['nama_lengkap'].text.isNotEmpty ||
          terlapor['email'].text.isNotEmpty ||
          terlapor['nomor_telepon'].text.isNotEmpty;

      if (hasData) {
        if (terlapor['nama_lengkap'].text.isEmpty) {
          _errors['terlapor_$i'] = 'Nama terlapor harus diisi';
          isValid = false;
        }
      }
    }

    // Validasi saksi (jika ada data yang diisi)
    for (int i = 0; i < _saksiList.length; i++) {
      final saksi = _saksiList[i];
      bool hasData = saksi['nama_lengkap'].text.isNotEmpty ||
          saksi['email'].text.isNotEmpty ||
          saksi['nomor_telepon'].text.isNotEmpty;

      if (hasData) {
        if (saksi['nama_lengkap'].text.isEmpty) {
          _errors['saksi_$i'] = 'Nama saksi harus diisi';
          isValid = false;
        }
      }
    }

    setState(() {}); // Update UI dengan error

    if (!isValid) {
      // Show validation error notification
      _showNotification(
        title: 'Periksa Kembali',
        body:
            'Formulir berisi kesalahan. Silakan periksa bagian yang ditandai.',
        payload: 'validation_error',
      );
    }

    return isValid;
  }

  // Fungsi untuk menyimpan data laporan ke API
  Future<void> _saveLaporan() async {
    // Validasi form
    if (!_validateForm()) {
      // Scroll ke error pertama
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Formulir berisi kesalahan. Silakan periksa kembali.'),
          backgroundColor: _errorColor,
          behavior: SnackBarBehavior.floating,
          shape:
              RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
          margin: EdgeInsets.all(16),
        ),
      );
      return;
    }

    // Set loading state
    setState(() {
      _isLoading = true;
    });

    try {
      // Format tanggal dan waktu ke string
      String formattedDateTime = '';
      if (_selectedDate != null) {
        if (_selectedTime != null) {
          final datetime = DateTime(
            _selectedDate!.year,
            _selectedDate!.month,
            _selectedDate!.day,
            _selectedTime!.hour,
            _selectedTime!.minute,
          );
          formattedDateTime =
              DateFormat('yyyy-MM-dd HH:mm:ss').format(datetime);
        } else {
          formattedDateTime = DateFormat('yyyy-MM-dd').format(_selectedDate!);
        }
      }

      // Siapkan data terlapor
      final terlapor = _terlaporList
          .map((item) {
            // Filter data yang kosong
            if (item['nama_lengkap'].text.isEmpty) {
              return null;
            }

            return {
              'nama_lengkap': item['nama_lengkap'].text,
              'email': item['email'].text,
              'nomor_telepon': item['nomor_telepon'].text,
              'jenis_kelamin': item['jenis_kelamin'],
              'umur_terlapor': item['umur_terlapor'],
              'status_warga': item['status_warga'],
              'unit_kerja': item['unit_kerja'],
            };
          })
          .where((item) => item != null)
          .toList();

      // Siapkan data saksi
      final saksi = _saksiList
          .map((item) {
            // Filter data yang kosong
            if (item['nama_lengkap'].text.isEmpty) {
              return null;
            }

            return {
              'nama_lengkap': item['nama_lengkap'].text,
              'email': item['email'].text,
              'nomor_telepon': item['nomor_telepon'].text,
            };
          })
          .where((item) => item != null)
          .toList();

      // Get token for authentication
      final token = await _apiService.getAuthToken();

      // Create multipart request
      var request = http.MultipartRequest(
        'POST',
        Uri.parse('${_apiService.baseUrl}/laporan/add_laporan'),
      );

      // Add headers
      if (token != null && token.isNotEmpty) {
        request.headers['Authorization'] = 'Bearer $token';
      }
      request.headers['Accept'] = 'application/json';

      // Add text fields
      request.fields['judul'] = _judulController.text;
      request.fields['category_id'] = _selectedKategori.toString();
      request.fields['deskripsi'] = _deskripsiController.text;
      request.fields['tanggal_kejadian'] = formattedDateTime;
      request.fields['nama_pelapor'] = _namaPelaporController.text;
      request.fields['ni_pelapor'] = _nimPelaporController.text;
      request.fields['no_telp'] = _nomorTeleponController.text;
      request.fields['profesi'] = _profesi ?? '';
      request.fields['jenis_kelamin'] = _jenisKelamin ?? '';
      request.fields['umur_pelapor'] = _umurPelapor ?? '';

      if (_lampiranLinkController.text.isNotEmpty) {
        request.fields['lampiran_link'] = _lampiranLinkController.text;
      }

      // Add bukti pelanggaran
      for (int i = 0; i < _selectedBuktiPelanggaran.length; i++) {
        request.fields['bukti_pelanggaran[$i]'] = _selectedBuktiPelanggaran[i];
      }

      // Add terlapor
      for (int i = 0; i < terlapor.length; i++) {
        terlapor[i]?.forEach((key, value) {
          if (value != null && value.toString().isNotEmpty) {
            request.fields['terlapor[$i][$key]'] = value.toString();
          }
        });
      }

      // Add saksi
      for (int i = 0; i < saksi.length; i++) {
        saksi[i]?.forEach((key, value) {
          if (value != null && value.toString().isNotEmpty) {
            request.fields['saksi[$i][$key]'] = value.toString();
          }
        });
      }

      // Add image files
      for (int i = 0; i < _imageFiles.length; i++) {
        final file = _imageFiles[i];
        final stream = http.ByteStream(file.openRead());
        final length = await file.length();
        final fileName = file.path.split('/').last;

        final multipartFile = http.MultipartFile('image_path[]', stream, length,
            filename: fileName);
        request.files.add(multipartFile);
      }

      // Send the request
      final streamedResponse = await request.send();
      final response = await http.Response.fromStream(streamedResponse);

      print('API Response (${response.statusCode}): ${response.body}');

      // Reset loading state
      setState(() {
        _isLoading = false;
      });

      // In _saveLaporan() method
      if (response.statusCode == 200 || response.statusCode == 201) {
        final jsonResponse = json.decode(response.body);

        if (jsonResponse['status'] == true) {
          // SUCCESS CASE - Only show success notification
          await _showNotification(
            title: 'Laporan Berhasil!',
            body:
                'Laporan "${_judulController.text}" telah berhasil dikirim dan akan diproses.',
            payload: 'report_success',
          );

          // Success dialog
          showDialog(
            context: context,
            builder: (context) => AlertDialog(
              shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(16)),
              title: Row(
                children: [
                  Icon(Icons.check_circle, color: _successColor, size: 28),
                  SizedBox(width: 10),
                  Text('Berhasil!', style: TextStyle(color: _successColor)),
                ],
              ),
              content: Text(
                'Laporan berhasil disimpan dan akan diproses.',
                style: TextStyle(fontSize: 15, color: _textColor),
              ),
              actions: [
                TextButton(
                  onPressed: () {
                    Navigator.of(context).pop();
                    Navigator.pop(context); // Return to previous page
                  },
                  style: TextButton.styleFrom(
                    foregroundColor: _primaryColor,
                    textStyle: TextStyle(fontWeight: FontWeight.w600),
                  ),
                  child: Text('OK'),
                ),
              ],
            ),
          );
          // Don't show any other notifications/messages in success case
          return; // Exit early to avoid showing any error messages
        } else {
          // API returned success HTTP code but status:false in response body
          _showNotification(
            title: 'Perhatian',
            body: jsonResponse['message'] ?? 'Gagal menyimpan laporan',
            payload: 'api_logic_error',
          );

          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content:
                  Text(jsonResponse['message'] ?? 'Gagal menyimpan laporan'),
              backgroundColor: _warningColor,
              behavior: SnackBarBehavior.floating,
              shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(10)),
              margin: EdgeInsets.all(16),
            ),
          );
        }
      } else {
        // Clear HTTP error case
        _showNotification(
          title: 'Error',
          body: 'Gagal mengirim laporan (Status: ${response.statusCode})',
          payload: 'http_error_${response.statusCode}',
        );

        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Gagal menyimpan laporan: ${response.statusCode}'),
            backgroundColor: _errorColor,
            behavior: SnackBarBehavior.floating,
            shape:
                RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
            margin: EdgeInsets.all(16),
          ),
        );
      }
    } catch (e) {
      // Handle exception
      setState(() {
        _isLoading = false;
      });

      _showNotification(
        title: 'Error',
        body: 'Terjadi kesalahan: ${e.toString()}',
        payload: 'exception',
      );

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Error: $e'),
          backgroundColor: _errorColor,
          behavior: SnackBarBehavior.floating,
          shape:
              RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
          margin: EdgeInsets.all(16),
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: _backgroundColor,
      appBar: AppBar(
        elevation: 0,
        backgroundColor: Colors.white,
        leading: IconButton(
          icon: Icon(Icons.arrow_back, color: _textColor),
          onPressed: () => Navigator.of(context).pop(),
        ),
        title: Text(
          'Tambah Laporan Kejadian',
          style: TextStyle(
            color: _textColor,
            fontWeight: FontWeight.w600,
            fontSize: 18,
          ),
        ),
      ),
      body: _isLoading
          ? Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  CircularProgressIndicator(color: _primaryColor),
                  SizedBox(height: 16),
                  Text(
                    'Mengirim laporan...',
                    style: TextStyle(
                      color: _lightTextColor,
                      fontSize: 16,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                ],
              ),
            )
          : Form(
              key: _formKey,
              child: SingleChildScrollView(
                padding: EdgeInsets.symmetric(horizontal: 20, vertical: 24),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // SECTION 1: DETAIL LAPORAN
                    _buildSectionHeader(
                        'Detail Laporan', Icons.description_outlined),

                    _buildFormField(
                      label: 'Judul Laporan',
                      isRequired: true,
                      errorText: _errors['judul'],
                      child: TextFormField(
                        controller: _judulController,
                        decoration: _inputDecoration(
                          hintText: 'Masukkan judul laporan',
                          errorText: _errors['judul'],
                          prefixIcon: Icons.title,
                        ),
                        style: TextStyle(fontSize: 15, color: _textColor),
                      ),
                    ),

                    _buildFormField(
                      label: 'Kategori',
                      isRequired: true,
                      errorText: _errors['category_id'],
                      child: _isLoadingCategories
                          ? Center(
                              child: Padding(
                                padding:
                                    const EdgeInsets.symmetric(vertical: 16),
                                child: CircularProgressIndicator(
                                    strokeWidth: 2, color: _primaryColor),
                              ),
                            )
                          : _categoryError != null
                              ? Padding(
                                  padding:
                                      const EdgeInsets.symmetric(vertical: 12),
                                  child: Text(_categoryError!,
                                      style: TextStyle(color: _errorColor)),
                                )
                              : DropdownButtonFormField<int>(
                                  value: _selectedKategori,
                                  decoration: _inputDecoration(
                                    hintText: 'Pilih kategori',
                                    errorText: _errors['category_id'],
                                    prefixIcon: Icons.category,
                                  ),
                                  items: filteredKategori.map((kategori) {
                                    return DropdownMenuItem<int>(
                                      value: kategori['id'],
                                      child: Text(kategori['nama']),
                                    );
                                  }).toList(),
                                  onChanged: (value) {
                                    setState(() {
                                      _selectedKategori = value;
                                    });
                                  },
                                  dropdownColor: Colors.white,
                                  style: TextStyle(
                                      fontSize: 15, color: _textColor),
                                ),
                    ),

                    _buildFormField(
                      label: 'Lampiran Link',
                      isRequired: false,
                      errorText: _errors['lampiran_link'],
                      child: TextFormField(
                        controller: _lampiranLinkController,
                        decoration: _inputDecoration(
                          hintText: 'https://example.com',
                          errorText: _errors['lampiran_link'],
                          prefixIcon: Icons.link,
                        ),
                        style: TextStyle(fontSize: 15, color: _textColor),
                      ),
                    ),

                    _buildFormField(
                      label: 'Deskripsi',
                      isRequired: true,
                      errorText: _errors['deskripsi'],
                      child: TextFormField(
                        controller: _deskripsiController,
                        maxLines: 4,
                        decoration: _inputDecoration(
                          hintText: 'Berikan deskripsi atau kronologi kejadian',
                          errorText: _errors['deskripsi'],
                          prefixIcon: Icons.description,
                          alignLabelWithHint: true,
                        ),
                        style: TextStyle(fontSize: 15, color: _textColor),
                      ),
                    ),

                    _buildFormField(
                      label: 'Tanggal & Waktu Kejadian',
                      isRequired: true,
                      errorText: _errors['tanggal_kejadian'],
                      child: InkWell(
                        onTap: () => _selectDate(context),
                        child: InputDecorator(
                          decoration: _inputDecoration(
                            hintText: 'Pilih Tanggal & Waktu',
                            errorText: _errors['tanggal_kejadian'],
                            prefixIcon: Icons.calendar_today,
                          ),
                          child: Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              Text(
                                _selectedDate == null
                                    ? 'Pilih Tanggal & Waktu'
                                    : (_selectedTime == null
                                        ? DateFormat('dd MMM yyyy')
                                            .format(_selectedDate!)
                                        : '${DateFormat('dd MMM yyyy').format(_selectedDate!)} ${_selectedTime!.format(context)}'),
                                style: TextStyle(
                                  fontSize: 15,
                                  color: _selectedDate == null
                                      ? Colors.grey.shade400
                                      : _textColor,
                                ),
                              ),
                              Icon(Icons.arrow_drop_down,
                                  color: _lightTextColor),
                            ],
                          ),
                        ),
                      ),
                    ),

                    _buildFormField(
                      label: 'Lampiran Foto',
                      isRequired: true,
                      errorText: _errors['image_path'],
                      child: Column(
                        children: [
                          // Upload buttons
                          Row(
                            children: [
                              Expanded(
                                child: _buildElevatedButton(
                                  onPressed: () =>
                                      _pickImage(ImageSource.camera),
                                  icon: Icons.camera_alt,
                                  label: 'Kamera',
                                  color: _primaryColor,
                                ),
                              ),
                              SizedBox(width: 12),
                              Expanded(
                                child: _buildElevatedButton(
                                  onPressed: () =>
                                      _pickImage(ImageSource.gallery),
                                  icon: Icons.photo_library,
                                  label: 'Galeri',
                                  color: Colors.teal,
                                ),
                              ),
                            ],
                          ),

                          // Image previews
                          if (_imageFiles.isNotEmpty)
                            Container(
                              margin: EdgeInsets.only(top: 16),
                              height: 120,
                              child: ListView.builder(
                                scrollDirection: Axis.horizontal,
                                itemCount: _imageFiles.length,
                                itemBuilder: (context, index) {
                                  return Stack(
                                    children: [
                                      Container(
                                        margin: EdgeInsets.only(right: 12),
                                        width: 120,
                                        decoration: BoxDecoration(
                                          border:
                                              Border.all(color: _borderColor),
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
                                        child: ClipRRect(
                                          borderRadius:
                                              BorderRadius.circular(11),
                                          child: Image.file(
                                            _imageFiles[index],
                                            fit: BoxFit.cover,
                                          ),
                                        ),
                                      ),
                                      Positioned(
                                        right: 14,
                                        top: 4,
                                        child: InkWell(
                                          onTap: () => _removeImage(index),
                                          child: Container(
                                            padding: EdgeInsets.all(4),
                                            decoration: BoxDecoration(
                                              color: Colors.white,
                                              shape: BoxShape.circle,
                                              boxShadow: [
                                                BoxShadow(
                                                  color: Colors.black26,
                                                  blurRadius: 3,
                                                  offset: Offset(0, 1),
                                                ),
                                              ],
                                            ),
                                            child: Icon(
                                              Icons.close,
                                              size: 16,
                                              color: _errorColor,
                                            ),
                                          ),
                                        ),
                                      ),
                                    ],
                                  );
                                },
                              ),
                            ),
                        ],
                      ),
                    ),

                    // Bukti Pelanggaran section
                    _buildFormField(
                      label: 'Bukti Pelanggaran',
                      isRequired: true,
                      errorText: _errors['bukti_pelanggaran'],
                      child: Container(
                        padding:
                            EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                        decoration: BoxDecoration(
                          color: Colors.white,
                          borderRadius: BorderRadius.circular(12),
                          border: Border.all(
                            color: _errors['bukti_pelanggaran'] != null
                                ? _errorColor
                                : _borderColor,
                          ),
                        ),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: _buktiOptions.map((option) {
                            return _buildCheckboxTile(
                              title: option['label'],
                              value: _selectedBuktiPelanggaran
                                  .contains(option['value']),
                              onChanged: (bool? value) {
                                setState(() {
                                  if (value == true) {
                                    _selectedBuktiPelanggaran
                                        .add(option['value']);
                                  } else {
                                    _selectedBuktiPelanggaran
                                        .remove(option['value']);
                                  }
                                });
                              },
                            );
                          }).toList(),
                        ),
                      ),
                    ),

                    // SECTION 2: INFORMASI PELAPOR
                    _buildSectionHeader(
                        'Informasi Pelapor', Icons.person_outline),

                    _buildFormField(
                      label: 'Nama Pelapor',
                      child: TextFormField(
                        controller: _namaPelaporController,
                        readOnly: true,
                        style: TextStyle(fontSize: 15, color: _textColor),
                        decoration: _inputDecoration(
                          hintText: 'Nama lengkap pelapor',
                          prefixIcon: Icons.person,
                          filled: true,
                          fillColor: _disabledColor,
                        ),
                      ),
                    ),

                    _buildFormField(
                      label: 'NIM Pelapor',
                      child: TextFormField(
                        controller: _nimPelaporController,
                        readOnly: true,
                        style: TextStyle(fontSize: 15, color: _textColor),
                        decoration: _inputDecoration(
                          hintText: 'NIM pelapor',
                          prefixIcon: Icons.badge,
                          filled: true,
                          fillColor: _disabledColor,
                        ),
                      ),
                    ),

                    _buildFormField(
                      label: 'Nomor Telepon',
                      child: TextFormField(
                        controller: _nomorTeleponController,
                        readOnly: true,
                        style: TextStyle(fontSize: 15, color: _textColor),
                        decoration: _inputDecoration(
                          hintText: 'Nomor telepon',
                          prefixIcon: Icons.phone,
                          filled: true,
                          fillColor: _disabledColor,
                        ),
                      ),
                    ),

                    _buildFormField(
                      label: 'Profesi',
                      isRequired: true,
                      errorText: _errors['profesi'],
                      child: DropdownButtonFormField<String>(
                        value: _profesi,
                        decoration: _inputDecoration(
                          hintText: 'Pilih profesi',
                          errorText: _errors['profesi'],
                          prefixIcon: Icons.work,
                        ),
                        items: [
                          DropdownMenuItem(
                              value: 'Mahasiswa', child: Text('Mahasiswa')),
                          DropdownMenuItem(
                              value: 'Dosen', child: Text('Dosen')),
                          DropdownMenuItem(
                              value: 'Staff', child: Text('Staff')),
                          DropdownMenuItem(
                              value: 'Lainnya', child: Text('Lainnya')),
                        ],
                        onChanged: (value) {
                          setState(() {
                            _profesi = value;
                          });
                        },
                        style: TextStyle(fontSize: 15, color: _textColor),
                      ),
                    ),

                    // Jenis Kelamin Radio
                    _buildFormField(
                      label: 'Jenis Kelamin',
                      isRequired: true,
                      errorText: _errors['jenis_kelamin'],
                      child: Container(
                        decoration: BoxDecoration(
                          color: Colors.white,
                          borderRadius: BorderRadius.circular(12),
                          border: Border.all(
                            color: _errors['jenis_kelamin'] != null
                                ? _errorColor
                                : _borderColor,
                          ),
                        ),
                        child: Column(
                          children: [
                            _buildRadioTile(
                              title: 'Laki-laki',
                              value: 'laki-laki',
                              groupValue: _jenisKelamin,
                              onChanged: (value) {
                                setState(() {
                                  _jenisKelamin = value;
                                });
                              },
                            ),
                            Divider(
                                height: 1,
                                thickness: 1,
                                color: _borderColor.withOpacity(0.5)),
                            _buildRadioTile(
                              title: 'Perempuan',
                              value: 'perempuan',
                              groupValue: _jenisKelamin,
                              onChanged: (value) {
                                setState(() {
                                  _jenisKelamin = value;
                                });
                              },
                            ),
                          ],
                        ),
                      ),
                    ),

                    // Rentang Umur Radio
                    _buildFormField(
                      label: 'Rentang Umur',
                      isRequired: true,
                      errorText: _errors['umur_pelapor'],
                      child: Container(
                        decoration: BoxDecoration(
                          color: Colors.white,
                          borderRadius: BorderRadius.circular(12),
                          border: Border.all(
                            color: _errors['umur_pelapor'] != null
                                ? _errorColor
                                : _borderColor,
                          ),
                        ),
                        child: Column(
                          children: [
                            _buildRadioTile(
                              title: 'Kurang dari 20 tahun',
                              value: '<20',
                              groupValue: _umurPelapor,
                              onChanged: (value) {
                                setState(() {
                                  _umurPelapor = value;
                                });
                              },
                            ),
                            Divider(
                                height: 1,
                                thickness: 1,
                                color: _borderColor.withOpacity(0.5)),
                            _buildRadioTile(
                              title: '20 - 40 tahun',
                              value: '20-40',
                              groupValue: _umurPelapor,
                              onChanged: (value) {
                                setState(() {
                                  _umurPelapor = value;
                                });
                              },
                            ),
                            Divider(
                                height: 1,
                                thickness: 1,
                                color: _borderColor.withOpacity(0.5)),
                            _buildRadioTile(
                              title: 'Lebih dari 40 tahun',
                              value: '40<',
                              groupValue: _umurPelapor,
                              onChanged: (value) {
                                setState(() {
                                  _umurPelapor = value;
                                });
                              },
                            ),
                          ],
                        ),
                      ),
                    ),

                    // SECTION 3: IDENTITAS TERLAPOR
                    _buildSectionHeader('Identitas Terlapor/Terduga',
                        Icons.person_search_outlined),

                    Padding(
                      padding: const EdgeInsets.only(top: 8.0, bottom: 16.0),
                      child: Row(
                        children: [
                          Icon(Icons.info_outline,
                              size: 16, color: _lightTextColor),
                          SizedBox(width: 8),
                          Expanded(
                            child: Text(
                              'Opsional: Anda dapat mengosongkan semua field terlapor jika tidak ingin mengisikan.',
                              style: TextStyle(
                                color: _lightTextColor,
                                fontSize: 14,
                                fontStyle: FontStyle.italic,
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),

                    // List of terlapor
                    ...List.generate(_terlaporList.length, (index) {
                      return _buildTerlaporItem(index);
                    }),

                    // Button to add more terlapor
                    Padding(
                      padding: const EdgeInsets.only(top: 8.0, bottom: 16.0),
                      child: _buildOutlinedButton(
                        onPressed: _addTerlapor,
                        icon: Icons.add,
                        label: 'Tambah Terlapor',
                        color: _primaryColor,
                      ),
                    ),

                    // SECTION 4: SAKSI
                    _buildSectionHeader('Saksi', Icons.people_alt_outlined),

                    Padding(
                      padding: const EdgeInsets.only(top: 8.0, bottom: 16.0),
                      child: Row(
                        children: [
                          Icon(Icons.info_outline,
                              size: 16, color: _lightTextColor),
                          SizedBox(width: 8),
                          Expanded(
                            child: Text(
                              'Opsional: Anda dapat mengosongkan semua field saksi jika tidak ingin mengisikan.',
                              style: TextStyle(
                                color: _lightTextColor,
                                fontSize: 14,
                                fontStyle: FontStyle.italic,
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),

                    // List of saksi
                    ...List.generate(_saksiList.length, (index) {
                      return _buildSaksiItem(index);
                    }),

                    // Button to add more saksi
                    Padding(
                      padding: const EdgeInsets.only(top: 8.0, bottom: 16.0),
                      child: _buildOutlinedButton(
                        onPressed: _addSaksi,
                        icon: Icons.add,
                        label: 'Tambah Saksi',
                        color: _primaryColor,
                      ),
                    ),

                    // SECTION 5: PERNYATAAN
                    _buildSectionHeader('Pernyataan', Icons.gavel_outlined),

                    Container(
                      margin: EdgeInsets.symmetric(vertical: 16),
                      padding: EdgeInsets.all(20),
                      decoration: BoxDecoration(
                        color: Colors.white,
                        borderRadius: BorderRadius.circular(12),
                        boxShadow: [
                          BoxShadow(
                            color: Colors.black.withOpacity(0.03),
                            blurRadius: 10,
                            offset: Offset(0, 4),
                          ),
                        ],
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            children: [
                              Icon(Icons.verified_user,
                                  color: _primaryColor, size: 20),
                              SizedBox(width: 10),
                              Text(
                                'Dengan ini saya menyatakan bahwa:',
                                style: TextStyle(
                                  fontWeight: FontWeight.w600,
                                  fontSize: 15,
                                  color: _textColor,
                                ),
                              ),
                            ],
                          ),
                          SizedBox(height: 16),
                          _buildListItem(
                              'Segala informasi yang saya berikan dalam laporan ini adalah benar dan dapat dipertanggungjawabkan.'),
                          _buildListItem(
                              'Saya bersedia memberikan keterangan lebih lanjut apabila diperlukan untuk proses penanganan laporan.'),
                          _buildListItem(
                              'Saya memahami bahwa memberikan laporan palsu dapat dikenakan sanksi sesuai dengan peraturan yang berlaku.'),
                          SizedBox(height: 16),
                          Container(
                            padding: EdgeInsets.symmetric(
                                vertical: 8, horizontal: 12),
                            decoration: BoxDecoration(
                              borderRadius: BorderRadius.circular(8),
                              color: _errors['agreement'] != null
                                  ? _errorColor.withOpacity(0.1)
                                  : Colors.grey.shade50,
                              border: Border.all(
                                color: _errors['agreement'] != null
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
                                    value: _agreement,
                                    onChanged: (value) {
                                      setState(() {
                                        _agreement = value ?? false;
                                      });
                                    },
                                    activeColor: _primaryColor,
                                    shape: RoundedRectangleBorder(
                                        borderRadius: BorderRadius.circular(4)),
                                  ),
                                ),
                                SizedBox(width: 12),
                                Expanded(
                                  child: Text(
                                    'Saya menyetujui pernyataan di atas',
                                    style: TextStyle(
                                      fontSize: 14,
                                      color: _textColor,
                                    ),
                                  ),
                                ),
                              ],
                            ),
                          ),
                          if (_errors['agreement'] != null)
                            Padding(
                              padding: const EdgeInsets.only(left: 8, top: 8),
                              child: Text(
                                _errors['agreement'],
                                style:
                                    TextStyle(color: _errorColor, fontSize: 12),
                              ),
                            ),
                        ],
                      ),
                    ),

                    SizedBox(height: 32),

                    // SUBMIT BUTTON
                    SizedBox(
                      width: double.infinity,
                      height: 54,
                      child: ElevatedButton(
                        onPressed: _agreement ? _saveLaporan : null,
                        style: ElevatedButton.styleFrom(
                          foregroundColor: Colors.white,
                          backgroundColor: _primaryColor,
                          disabledForegroundColor:
                              Colors.white.withOpacity(0.4),
                          disabledBackgroundColor:
                              _primaryColor.withOpacity(0.3),
                          elevation: 0,
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(12),
                          ),
                        ),
                        child: Row(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Icon(Icons.send),
                            SizedBox(width: 12),
                            Text(
                              'Kirim Laporan',
                              style: TextStyle(
                                fontSize: 16,
                                fontWeight: FontWeight.w600,
                                letterSpacing: 0.5,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                    SizedBox(height: 24),
                  ],
                ),
              ),
            ),
    );
  }

  // Helper Widgets
  Widget _buildSectionHeader(String title, IconData icon) {
    return Container(
      margin: EdgeInsets.only(top: 16, bottom: 24),
      child: Row(
        children: [
          Container(
            padding: EdgeInsets.all(10),
            decoration: BoxDecoration(
              color: _primaryColor.withOpacity(0.1),
              borderRadius: BorderRadius.circular(8),
            ),
            child: Icon(icon, color: _primaryColor, size: 20),
          ),
          SizedBox(width: 16),
          Text(
            title,
            style: TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.w600,
              color: _textColor,
              letterSpacing: 0.2,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildFormField({
    required String label,
    bool isRequired = false,
    String? errorText,
    required Widget child,
  }) {
    return Container(
      margin: EdgeInsets.only(bottom: 24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: const EdgeInsets.only(left: 4, bottom: 8),
            child: RichText(
              text: TextSpan(
                style: TextStyle(
                    fontSize: 15,
                    color: _textColor,
                    fontWeight: FontWeight.w500),
                children: [
                  TextSpan(text: label),
                  if (isRequired)
                    TextSpan(
                      text: ' *',
                      style: TextStyle(
                        color: _errorColor,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                ],
              ),
            ),
          ),
          child,
        ],
      ),
    );
  }

  InputDecoration _inputDecoration({
    required String hintText,
    String? errorText,
    IconData? prefixIcon,
    bool filled = false,
    Color? fillColor,
    bool alignLabelWithHint = false,
  }) {
    return InputDecoration(
      hintText: hintText,
      hintStyle: TextStyle(color: Colors.grey.shade400, fontSize: 14),
      errorText: errorText,
      errorStyle: TextStyle(color: _errorColor, fontSize: 12),
      prefixIcon: prefixIcon != null
          ? Icon(prefixIcon,
              color: errorText != null ? _errorColor : _primaryColor, size: 20)
          : null,
      contentPadding: EdgeInsets.symmetric(
        vertical: 16,
        horizontal: prefixIcon == null ? 16 : 0,
      ),
      border: OutlineInputBorder(
        borderRadius: BorderRadius.circular(12),
        borderSide: BorderSide(color: _borderColor),
      ),
      enabledBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(12),
        borderSide:
            BorderSide(color: errorText != null ? _errorColor : _borderColor),
      ),
      focusedBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(12),
        borderSide: BorderSide(color: _primaryColor, width: 1.5),
      ),
      errorBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(12),
        borderSide: BorderSide(color: _errorColor),
      ),
      focusedErrorBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(12),
        borderSide: BorderSide(color: _errorColor, width: 1.5),
      ),
      filled: filled,
      fillColor: fillColor,
      alignLabelWithHint: alignLabelWithHint,
    );
  }

  Widget _buildElevatedButton({
    required VoidCallback onPressed,
    required IconData icon,
    required String label,
    required Color color,
  }) {
    return ElevatedButton.icon(
      onPressed: onPressed,
      icon: Icon(icon),
      label: Text(
        label,
        style: TextStyle(
          fontWeight: FontWeight.w500,
          letterSpacing: 0.3,
        ),
      ),
      style: ElevatedButton.styleFrom(
        foregroundColor: Colors.white,
        backgroundColor: color,
        padding: EdgeInsets.symmetric(vertical: 14),
        elevation: 0,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(12),
        ),
      ),
    );
  }

  Widget _buildOutlinedButton({
    required VoidCallback onPressed,
    required IconData icon,
    required String label,
    required Color color,
  }) {
    return OutlinedButton.icon(
      onPressed: onPressed,
      icon: Icon(icon),
      label: Text(
        label,
        style: TextStyle(
          fontWeight: FontWeight.w500,
          letterSpacing: 0.3,
        ),
      ),
      style: OutlinedButton.styleFrom(
        foregroundColor: color,
        side: BorderSide(color: color),
        padding: EdgeInsets.symmetric(vertical: 14),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(12),
        ),
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
      title: Text(
        title,
        style: TextStyle(fontSize: 15, color: _textColor),
      ),
      value: value,
      groupValue: groupValue,
      onChanged: onChanged,
      activeColor: _primaryColor,
      contentPadding: EdgeInsets.symmetric(horizontal: 10),
      dense: true,
      visualDensity: VisualDensity.compact,
    );
  }

  Widget _buildCheckboxTile({
    required String title,
    required bool value,
    required Function(bool?) onChanged,
  }) {
    return CheckboxListTile(
      title: Text(
        title,
        style: TextStyle(fontSize: 14, color: _textColor),
      ),
      value: value,
      onChanged: onChanged,
      activeColor: _primaryColor,
      contentPadding: EdgeInsets.symmetric(horizontal: 0, vertical: 0),
      dense: true,
      visualDensity: VisualDensity.compact,
      controlAffinity: ListTileControlAffinity.leading,
    );
  }

  Widget _buildListItem(String text) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 12.0),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('•',
              style: TextStyle(
                  fontWeight: FontWeight.bold,
                  fontSize: 16,
                  color: _primaryColor)),
          SizedBox(width: 8),
          Expanded(
            child: Text(
              text,
              style:
                  TextStyle(height: 1.4, fontSize: 14, color: _lightTextColor),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildTerlaporItem(int index) {
    final item = _terlaporList[index];

    return Container(
      margin: EdgeInsets.only(bottom: 24),
      padding: EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.03),
            blurRadius: 10,
            offset: Offset(0, 4),
          ),
        ],
        border: _errors['terlapor_$index'] != null
            ? Border.all(color: _errorColor.withOpacity(0.5), width: 1.5)
            : null,
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
                  color: _primaryColor.withOpacity(0.1),
                  borderRadius: BorderRadius.circular(20),
                ),
                child: Row(
                  children: [
                    Icon(Icons.person_outline, color: _primaryColor, size: 16),
                    SizedBox(width: 6),
                    Text(
                      'Terlapor #${index + 1}',
                      style: TextStyle(
                        fontWeight: FontWeight.w600,
                        color: _primaryColor,
                        fontSize: 14,
                      ),
                    ),
                  ],
                ),
              ),
              if (_terlaporList.length > 1)
                IconButton(
                  icon: Icon(Icons.delete_outline, color: _errorColor),
                  onPressed: () => _removeTerlapor(index),
                  tooltip: 'Hapus terlapor',
                  iconSize: 20,
                  padding: EdgeInsets.all(4),
                  constraints: BoxConstraints(),
                ),
            ],
          ),

          if (_errors['terlapor_$index'] != null)
            Container(
              padding: EdgeInsets.all(12),
              margin: EdgeInsets.only(top: 12, bottom: 12),
              decoration: BoxDecoration(
                color: _errorColor.withOpacity(0.1),
                borderRadius: BorderRadius.circular(8),
              ),
              child: Row(
                children: [
                  Icon(Icons.error_outline, color: _errorColor, size: 16),
                  SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      _errors['terlapor_$index'],
                      style: TextStyle(color: _errorColor, fontSize: 13),
                    ),
                  ),
                ],
              ),
            ),

          SizedBox(height: 16),

          // Nama lengkap
          _buildFormField(
            label: 'Nama Lengkap',
            child: TextFormField(
              controller: item['nama_lengkap'],
              style: TextStyle(fontSize: 15, color: _textColor),
              decoration: _inputDecoration(
                hintText: 'Nama lengkap terlapor',
                prefixIcon: Icons.person,
              ),
            ),
          ),

          // Email
          _buildFormField(
            label: 'Email',
            child: TextFormField(
              controller: item['email'],
              keyboardType: TextInputType.emailAddress,
              style: TextStyle(fontSize: 15, color: _textColor),
              decoration: _inputDecoration(
                hintText: 'Email terlapor',
                prefixIcon: Icons.email_outlined,
              ),
            ),
          ),

          // Nomor telepon
          _buildFormField(
            label: 'Nomor Telepon',
            child: TextFormField(
              controller: item['nomor_telepon'],
              keyboardType: TextInputType.phone,
              style: TextStyle(fontSize: 15, color: _textColor),
              decoration: _inputDecoration(
                hintText: 'Nomor telepon terlapor',
                prefixIcon: Icons.phone_outlined,
              ),
            ),
          ),

          // Two columns for gender and age
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Left column - Jenis Kelamin
              Expanded(
                child: _buildFormField(
                  label: 'Jenis Kelamin',
                  child: Container(
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(color: _borderColor),
                    ),
                    child: Column(
                      children: [
                        _buildRadioTile(
                          title: 'Laki-laki',
                          value: 'laki-laki',
                          groupValue: item['jenis_kelamin'],
                          onChanged: (value) {
                            setState(() {
                              item['jenis_kelamin'] = value;
                            });
                          },
                        ),
                        Divider(
                            height: 1,
                            thickness: 1,
                            color: _borderColor.withOpacity(0.5)),
                        _buildRadioTile(
                          title: 'Perempuan',
                          value: 'perempuan',
                          groupValue: item['jenis_kelamin'],
                          onChanged: (value) {
                            setState(() {
                              item['jenis_kelamin'] = value;
                            });
                          },
                        ),
                      ],
                    ),
                  ),
                ),
              ),
              SizedBox(width: 16),

              // Right column - Rentang Umur
              Expanded(
                child: _buildFormField(
                  label: 'Rentang Umur',
                  child: Container(
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(color: _borderColor),
                    ),
                    child: Column(
                      children: [
                        _buildRadioTile(
                          title: 'Kurang dari 20 tahun',
                          value: '<20',
                          groupValue: item['umur_terlapor'],
                          onChanged: (value) {
                            setState(() {
                              item['umur_terlapor'] = value;
                            });
                          },
                        ),
                        Divider(
                            height: 1,
                            thickness: 1,
                            color: _borderColor.withOpacity(0.5)),
                        _buildRadioTile(
                          title: '20 - 40 tahun',
                          value: '20-40',
                          groupValue: item['umur_terlapor'],
                          onChanged: (value) {
                            setState(() {
                              item['umur_terlapor'] = value;
                            });
                          },
                        ),
                        Divider(
                            height: 1,
                            thickness: 1,
                            color: _borderColor.withOpacity(0.5)),
                        _buildRadioTile(
                          title: 'Lebih dari 40 tahun',
                          value: '40<',
                          groupValue: item['umur_terlapor'],
                          onChanged: (value) {
                            setState(() {
                              item['umur_terlapor'] = value;
                            });
                          },
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ],
          ),

          // Status Warga UNS
          _buildFormField(
            label: 'Status Warga UNS',
            child: DropdownButtonFormField<String>(
              value: item['status_warga'],
              decoration: _inputDecoration(
                hintText: 'Pilih status',
                prefixIcon: Icons.school_outlined,
              ),
              items: [
                DropdownMenuItem(value: 'dosen', child: Text('Dosen')),
                DropdownMenuItem(value: 'mahasiswa', child: Text('Mahasiswa')),
                DropdownMenuItem(value: 'staff', child: Text('Staff')),
                DropdownMenuItem(value: 'lainnya', child: Text('Lainnya')),
              ],
              onChanged: (value) {
                setState(() {
                  item['status_warga'] = value;
                });
              },
              style: TextStyle(fontSize: 15, color: _textColor),
            ),
          ),

          // Unit Kerja
          _buildFormField(
            label: 'Unit Kerja',
            child: DropdownButtonFormField<String>(
              value: item['unit_kerja'],
              decoration: _inputDecoration(
                hintText: 'Pilih unit kerja',
                prefixIcon: Icons.business_outlined,
              ),
              items: [
                DropdownMenuItem(
                    value: 'Fakultas Teknik', child: Text('Fakultas Teknik')),
                DropdownMenuItem(
                    value: 'Fakultas MIPA', child: Text('Fakultas MIPA')),
                DropdownMenuItem(
                    value: 'Fakultas Ekonomi', child: Text('Fakultas Ekonomi')),
                DropdownMenuItem(
                    value: 'Fakultas Hukum', child: Text('Fakultas Hukum')),
                DropdownMenuItem(
                    value: 'Fakultas Kedokteran',
                    child: Text('Fakultas Kedokteran')),
              ],
              onChanged: (value) {
                setState(() {
                  item['unit_kerja'] = value;
                });
              },
              style: TextStyle(fontSize: 15, color: _textColor),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSaksiItem(int index) {
    final item = _saksiList[index];

    return Container(
      margin: EdgeInsets.only(bottom: 24),
      padding: EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.03),
            blurRadius: 10,
            offset: Offset(0, 4),
          ),
        ],
        border: _errors['saksi_$index'] != null
            ? Border.all(color: _errorColor.withOpacity(0.5), width: 1.5)
            : null,
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
                  color: _secondaryColor.withOpacity(0.1),
                  borderRadius: BorderRadius.circular(20),
                ),
                child: Row(
                  children: [
                    Icon(Icons.people_alt_outlined,
                        color: _secondaryColor, size: 16),
                    SizedBox(width: 6),
                    Text(
                      'Saksi #${index + 1}',
                      style: TextStyle(
                        fontWeight: FontWeight.w600,
                        color: _secondaryColor,
                        fontSize: 14,
                      ),
                    ),
                  ],
                ),
              ),
              if (_saksiList.length > 1)
                IconButton(
                  icon: Icon(Icons.delete_outline, color: _errorColor),
                  onPressed: () => _removeSaksi(index),
                  tooltip: 'Hapus saksi',
                  iconSize: 20,
                  padding: EdgeInsets.all(4),
                  constraints: BoxConstraints(),
                ),
            ],
          ),

          if (_errors['saksi_$index'] != null)
            Container(
              padding: EdgeInsets.all(12),
              margin: EdgeInsets.only(top: 12, bottom: 12),
              decoration: BoxDecoration(
                color: _errorColor.withOpacity(0.1),
                borderRadius: BorderRadius.circular(8),
              ),
              child: Row(
                children: [
                  Icon(Icons.error_outline, color: _errorColor, size: 16),
                  SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      _errors['saksi_$index'],
                      style: TextStyle(color: _errorColor, fontSize: 13),
                    ),
                  ),
                ],
              ),
            ),

          SizedBox(height: 16),

          // Nama Lengkap
          _buildFormField(
            label: 'Nama Lengkap',
            child: TextFormField(
              controller: item['nama_lengkap'],
              style: TextStyle(fontSize: 15, color: _textColor),
              decoration: _inputDecoration(
                hintText: 'Nama lengkap saksi',
                prefixIcon: Icons.person,
              ),
            ),
          ),

          // Email
          _buildFormField(
            label: 'Email',
            child: TextFormField(
              controller: item['email'],
              keyboardType: TextInputType.emailAddress,
              style: TextStyle(fontSize: 15, color: _textColor),
              decoration: _inputDecoration(
                hintText: 'Email saksi',
                prefixIcon: Icons.email_outlined,
              ),
            ),
          ),

          // Nomor Telepon
          _buildFormField(
            label: 'Nomor Telepon',
            child: TextFormField(
              controller: item['nomor_telepon'],
              keyboardType: TextInputType.phone,
              style: TextStyle(fontSize: 15, color: _textColor),
              decoration: _inputDecoration(
                hintText: 'Nomor telepon saksi',
                prefixIcon: Icons.phone_outlined,
              ),
            ),
          ),
        ],
      ),
    );
  }

  @override
  void dispose() {
    // Dispose of controllers
    _judulController.dispose();
    _deskripsiController.dispose();
    _nomorTeleponController.dispose();
    _namaPelaporController.dispose();
    _nimPelaporController.dispose();
    _lampiranLinkController.dispose();

    // Dispose of terlapor controllers
    for (var terlapor in _terlaporList) {
      terlapor['nama_lengkap'].dispose();
      terlapor['email'].dispose();
      terlapor['nomor_telepon'].dispose();
    }

    // Dispose of saksi controllers
    for (var saksi in _saksiList) {
      saksi['nama_lengkap'].dispose();
      saksi['email'].dispose();
      saksi['nomor_telepon'].dispose();
    }

    super.dispose();
  }
}
