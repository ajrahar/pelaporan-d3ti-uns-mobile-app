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

class AddLaporPKDosenPage extends StatefulWidget {
  const AddLaporPKDosenPage({Key? key}) : super(key: key);

  @override
  _AddLaporPKDosenPageState createState() => _AddLaporPKDosenPageState();
}

class _AddLaporPKDosenPageState extends State<AddLaporPKDosenPage> {
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
  final TextEditingController _nipPelaporController = TextEditingController();
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
  String? _jabatan;
  String? _jenisKelamin;
  String? _umurPelapor;
  bool _agreement = false;

  @override
  void initState() {
    super.initState();
    _loadUserData();
    _fetchCategories();
    _initializeNotifications();
  }

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
        }
      },
    );

    // Request permission untuk Android 13+
    await flutterLocalNotificationsPlugin
        .resolvePlatformSpecificImplementation<
            AndroidFlutterLocalNotificationsPlugin>()
        ?.requestNotificationsPermission();
  }

  // Method untuk menampilkan notifikasi
  Future<void> _showNotification({
    required String title,
    required String body,
    String? payload,
  }) async {
    const AndroidNotificationDetails androidDetails =
        AndroidNotificationDetails(
      'laporan_dosen_channel',
      'Laporan Dosen',
      channelDescription: 'Notifications for laporan dosen submission',
      importance: Importance.max,
      priority: Priority.high,
      ticker: 'ticker',
      color: Colors.blue, // Warna untuk notifikasi
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
      DateTime.now().millisecond, // ID unik berdasarkan waktu saat ini
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
        _nipPelaporController.text = prefs.getString('user_nik') ?? '';
        _nomorTeleponController.text = prefs.getString('user_no_telp') ?? '';
      });
    } catch (e) {
      print('Error loading user data: $e');
    }
  }

  // Fungsi untuk membuka date picker
  Future<void> _selectDate(BuildContext context) async {
    final DateTime? picked = await showDatePicker(
      context: context,
      initialDate: DateTime.now(),
      firstDate: DateTime(2020),
      lastDate: DateTime(2100),
      builder: (BuildContext context, Widget? child) {
        return Theme(
          data: ThemeData.light().copyWith(
            colorScheme: ColorScheme.light(
              primary: Colors.blue,
              onPrimary: Colors.white,
              surface: Colors.white,
              onSurface: Colors.black,
            ),
            dialogBackgroundColor: Colors.white,
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
      builder: (BuildContext context, Widget? child) {
        return Theme(
          data: ThemeData.light().copyWith(
            colorScheme: ColorScheme.light(
              primary: Colors.blue,
              onPrimary: Colors.white,
              surface: Colors.white,
              onSurface: Colors.black,
            ),
            dialogBackgroundColor: Colors.white,
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

    if (_jabatan == null) {
      _errors['jabatan'] = 'Jabatan harus dipilih';
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
    return isValid;
  }

  // Fungsi untuk menyimpan data laporan ke API
  Future<void> _saveLaporan() async {
    // Validasi form
    if (!await _validateForm()) {
      // Scroll ke error pertama
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Formulir berisi kesalahan. Silakan periksa kembali.'),
          backgroundColor: Colors.red.shade700,
          behavior: SnackBarBehavior.floating,
          margin: EdgeInsets.all(20),
          shape:
              RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
        ),
      );

      // Tampilkan notifikasi untuk validasi form gagal
      await _showNotification(
        title: 'Form Tidak Lengkap',
        body: 'Mohon lengkapi formulir yang ditandai merah.',
        payload: 'form_invalid',
      );

      return;
    }

    // Set loading state
    setState(() {
      _isLoading = true;
    });

    // Tampilkan notifikasi proses mengirim
    await _showNotification(
      title: 'Mengirim Laporan',
      body: 'Laporan "${_judulController.text}" sedang dikirim...',
      payload: 'sending',
    );

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
      request.fields['ni_pelapor'] = _nipPelaporController.text;
      request.fields['no_telp'] = _nomorTeleponController.text;
      request.fields['jabatan'] = _jabatan ?? '';
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

      if (response.statusCode == 200 || response.statusCode == 201) {
        final jsonResponse = json.decode(response.body);

        if (jsonResponse['status'] == true) {
          // Tampilkan notifikasi sukses
          await _showNotification(
            title: 'Laporan Berhasil',
            body:
                'Laporan "${_judulController.text}" telah berhasil dikirim dan akan diproses.',
            payload: 'success_${DateTime.now().millisecondsSinceEpoch}',
          );

          // Tampilkan dialog sukses
          showDialog(
            context: context,
            builder: (context) => AlertDialog(
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
                  SizedBox(width: 16),
                  Text('Berhasil!'),
                ],
              ),
              content: Text(
                'Laporan berhasil disimpan dan akan diproses.',
                style: TextStyle(fontSize: 16),
              ),
              actions: [
                TextButton(
                  onPressed: () {
                    Navigator.of(context).pop();
                    Navigator.pop(context); // Kembali ke halaman sebelumnya
                  },
                  child: Text('OK'),
                  style: TextButton.styleFrom(
                    foregroundColor: Colors.blue,
                    padding: EdgeInsets.symmetric(horizontal: 20, vertical: 10),
                  ),
                ),
              ],
            ),
          );
        } else {
          // Tampilkan notifikasi error API status false
          await _showNotification(
            title: 'Gagal',
            body: jsonResponse['message'] ?? 'Gagal menyimpan laporan',
            payload: 'api_logic_error',
          );

          // Show error message from API
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content:
                  Text(jsonResponse['message'] ?? 'Gagal menyimpan laporan'),
              backgroundColor: Colors.red.shade700,
              behavior: SnackBarBehavior.floating,
              margin: EdgeInsets.all(20),
              shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(10)),
            ),
          );
        }
      } else {
        // Tampilkan notifikasi error HTTP status code
        await _showNotification(
          title: 'Error',
          body: 'Gagal mengirim laporan. Status: ${response.statusCode}',
          payload: 'http_error_${response.statusCode}',
        );

        // Handle error response
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Gagal menyimpan laporan: ${response.statusCode}'),
            backgroundColor: Colors.red.shade700,
            behavior: SnackBarBehavior.floating,
            margin: EdgeInsets.all(20),
            shape:
                RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
          ),
        );
      }
    } catch (e) {
      // Tampilkan notifikasi untuk error exception
      await _showNotification(
        title: 'Error',
        body: 'Terjadi kesalahan: ${e.toString()}',
        payload: 'exception',
      );

      // Handle exception
      setState(() {
        _isLoading = false;
      });

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Error: $e'),
          backgroundColor: Colors.red.shade700,
          behavior: SnackBarBehavior.floating,
          margin: EdgeInsets.all(20),
          shape:
              RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      appBar: AppBar(
        title: Text(
          'Tambah Laporan Kejadian',
          style: TextStyle(
            color: Colors.grey[800],
            fontWeight: FontWeight.w600,
          ),
        ),
        backgroundColor: Colors.white,
        elevation: 0,
        iconTheme: IconThemeData(
          color: Colors.grey[800],
        ),
        bottom: PreferredSize(
          preferredSize: Size.fromHeight(1.0),
          child: Container(
            height: 1.0,
            color: Colors.grey.shade200,
          ),
        ),
      ),
      body: _isLoading
          ? Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  CircularProgressIndicator(
                    valueColor: AlwaysStoppedAnimation<Color>(Colors.blue),
                    strokeWidth: 3,
                  ),
                  SizedBox(height: 20),
                  Text(
                    'Memproses...',
                    style: TextStyle(
                      color: Colors.grey[700],
                      fontWeight: FontWeight.w500,
                      fontSize: 16,
                    ),
                  ),
                ],
              ),
            )
          : Form(
              key: _formKey,
              child: SingleChildScrollView(
                padding: EdgeInsets.all(20.0),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // SECTION 1: DETAIL LAPORAN
                    _buildSectionHeader('Detail Laporan'),
                    const SizedBox(height: 20),

                    _buildFormCard(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          _buildLabel('Judul Laporan', isRequired: true),
                          SizedBox(height: 8),
                          _buildTextField(
                            controller: _judulController,
                            hint: 'Masukkan judul laporan',
                            errorText: _errors['judul'],
                          ),
                          SizedBox(height: 20),
                          _buildLabel('Kategori', isRequired: true),
                          SizedBox(height: 8),
                          _isLoadingCategories
                              ? Center(
                                  child: Padding(
                                    padding: const EdgeInsets.symmetric(
                                        vertical: 12),
                                    child: CircularProgressIndicator(
                                      strokeWidth: 2,
                                      valueColor: AlwaysStoppedAnimation<Color>(
                                          Colors.blue),
                                    ),
                                  ),
                                )
                              : _categoryError != null
                                  ? Container(
                                      padding: EdgeInsets.all(12),
                                      decoration: BoxDecoration(
                                        color: Colors.red.shade50,
                                        borderRadius: BorderRadius.circular(8),
                                      ),
                                      child: Row(
                                        children: [
                                          Icon(
                                            Icons.error_outline,
                                            color: Colors.red,
                                            size: 18,
                                          ),
                                          SizedBox(width: 8),
                                          Expanded(
                                            child: Text(
                                              _categoryError!,
                                              style: TextStyle(
                                                color: Colors.red,
                                                fontSize: 14,
                                              ),
                                            ),
                                          ),
                                        ],
                                      ),
                                    )
                                  : _buildDropdown(
                                      value: _selectedKategori,
                                      items: filteredKategori
                                          .map((kategori) =>
                                              DropdownMenuItem<int>(
                                                value: kategori['id'],
                                                child: Text(kategori['nama']),
                                              ))
                                          .toList(),
                                      onChanged: (value) {
                                        setState(() {
                                          _selectedKategori = value as int?;
                                        });
                                      },
                                      hint: 'Pilih kategori',
                                      errorText: _errors['category_id'],
                                    ),
                          SizedBox(height: 20),
                          _buildLabel('Lampiran Link', isRequired: false),
                          SizedBox(height: 8),
                          _buildTextField(
                            controller: _lampiranLinkController,
                            hint: 'https://example.com',
                            errorText: _errors['lampiran_link'],
                          ),
                          SizedBox(height: 20),
                          _buildLabel('Deskripsi', isRequired: true),
                          SizedBox(height: 8),
                          _buildTextField(
                            controller: _deskripsiController,
                            hint: 'Berikan deskripsi atau kronologi kejadian',
                            errorText: _errors['deskripsi'],
                            maxLines: 4,
                          ),
                          SizedBox(height: 20),
                          _buildLabel('Tanggal & Waktu Kejadian',
                              isRequired: true),
                          SizedBox(height: 8),
                          InkWell(
                            onTap: () => _selectDate(context),
                            child: Container(
                              padding: EdgeInsets.symmetric(
                                vertical: 16,
                                horizontal: 16,
                              ),
                              decoration: BoxDecoration(
                                color: Colors.white,
                                borderRadius: BorderRadius.circular(12),
                                border: Border.all(
                                  color: _errors['tanggal_kejadian'] != null
                                      ? Colors.red
                                      : Colors.grey.shade300,
                                ),
                              ),
                              child: Row(
                                mainAxisAlignment:
                                    MainAxisAlignment.spaceBetween,
                                children: [
                                  Text(
                                    _selectedDate == null
                                        ? 'Pilih Tanggal & Waktu'
                                        : (_selectedTime == null
                                            ? DateFormat('dd MMM yyyy')
                                                .format(_selectedDate!)
                                            : '${DateFormat('dd MMM yyyy').format(_selectedDate!)} ${_selectedTime!.format(context)}'),
                                    style: TextStyle(
                                      color: _selectedDate == null
                                          ? Colors.grey.shade500
                                          : Colors.grey.shade800,
                                      fontSize: 15,
                                    ),
                                  ),
                                  Icon(
                                    Icons.calendar_today,
                                    color: Colors.grey.shade500,
                                    size: 20,
                                  ),
                                ],
                              ),
                            ),
                          ),
                          if (_errors['tanggal_kejadian'] != null)
                            Padding(
                              padding: const EdgeInsets.only(top: 8, left: 12),
                              child: Text(
                                _errors['tanggal_kejadian']!,
                                style: TextStyle(
                                  color: Colors.red,
                                  fontSize: 12,
                                ),
                              ),
                            ),
                        ],
                      ),
                    ),
                    SizedBox(height: 24),

                    _buildFormCard(
                      title: 'Lampiran Foto',
                      required: true,
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          // Upload buttons
                          Row(
                            children: [
                              Expanded(
                                child: _buildElevatedButton(
                                  onPressed: () =>
                                      _pickImage(ImageSource.camera),
                                  icon: Icons.camera_alt_outlined,
                                  label: 'Kamera',
                                  color: Colors.blue.shade600,
                                ),
                              ),
                              const SizedBox(width: 12),
                              Expanded(
                                child: _buildElevatedButton(
                                  onPressed: () =>
                                      _pickImage(ImageSource.gallery),
                                  icon: Icons.photo_library_outlined,
                                  label: 'Galeri',
                                  color: Colors.teal.shade600,
                                ),
                              ),
                            ],
                          ),

                          if (_errors['image_path'] != null)
                            Padding(
                              padding: const EdgeInsets.only(top: 12),
                              child: Container(
                                padding: EdgeInsets.symmetric(
                                    vertical: 8, horizontal: 12),
                                decoration: BoxDecoration(
                                  color: Colors.red.shade50,
                                  borderRadius: BorderRadius.circular(8),
                                  border:
                                      Border.all(color: Colors.red.shade200),
                                ),
                                child: Row(
                                  children: [
                                    Icon(
                                      Icons.error_outline,
                                      color: Colors.red,
                                      size: 18,
                                    ),
                                    SizedBox(width: 8),
                                    Expanded(
                                      child: Text(
                                        _errors['image_path']!,
                                        style: TextStyle(
                                          color: Colors.red,
                                          fontSize: 12,
                                        ),
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            ),

                          // Image previews
                          if (_imageFiles.isNotEmpty)
                            Padding(
                              padding: const EdgeInsets.only(top: 20),
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    'Preview:',
                                    style: TextStyle(
                                      fontSize: 14,
                                      fontWeight: FontWeight.w500,
                                      color: Colors.grey.shade700,
                                    ),
                                  ),
                                  SizedBox(height: 10),
                                  Container(
                                    height: 120,
                                    child: ListView.builder(
                                      scrollDirection: Axis.horizontal,
                                      itemCount: _imageFiles.length,
                                      itemBuilder: (context, index) {
                                        return Container(
                                          margin: EdgeInsets.only(right: 12),
                                          child: Stack(
                                            children: [
                                              Container(
                                                width: 120,
                                                height: 120,
                                                decoration: BoxDecoration(
                                                  borderRadius:
                                                      BorderRadius.circular(12),
                                                  boxShadow: [
                                                    BoxShadow(
                                                      color: Colors.black
                                                          .withOpacity(0.1),
                                                      blurRadius: 4,
                                                      offset: Offset(0, 2),
                                                    ),
                                                  ],
                                                ),
                                                child: ClipRRect(
                                                  borderRadius:
                                                      BorderRadius.circular(12),
                                                  child: Image.file(
                                                    _imageFiles[index],
                                                    fit: BoxFit.cover,
                                                  ),
                                                ),
                                              ),
                                              Positioned(
                                                right: 4,
                                                top: 4,
                                                child: InkWell(
                                                  onTap: () =>
                                                      _removeImage(index),
                                                  child: Container(
                                                    padding: EdgeInsets.all(4),
                                                    decoration: BoxDecoration(
                                                      color: Colors.white
                                                          .withOpacity(0.8),
                                                      shape: BoxShape.circle,
                                                      boxShadow: [
                                                        BoxShadow(
                                                          color: Colors.black26,
                                                          blurRadius: 2,
                                                        ),
                                                      ],
                                                    ),
                                                    child: Icon(
                                                      Icons.close,
                                                      size: 16,
                                                      color: Colors.red,
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
                              ),
                            ),
                        ],
                      ),
                    ),
                    SizedBox(height: 24),

                    // Bukti Pelanggaran section
                    _buildFormCard(
                      title: 'Bukti Pelanggaran',
                      required: true,
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Container(
                            decoration: BoxDecoration(
                              borderRadius: BorderRadius.circular(12),
                              border: Border.all(
                                color: _errors['bukti_pelanggaran'] != null
                                    ? Colors.red
                                    : Colors.transparent,
                              ),
                            ),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: _buktiOptions.map((option) {
                                bool isSelected = _selectedBuktiPelanggaran
                                    .contains(option['value']);
                                return Container(
                                  margin: EdgeInsets.only(bottom: 4),
                                  decoration: BoxDecoration(
                                    borderRadius: BorderRadius.circular(8),
                                    color: isSelected
                                        ? Colors.blue.shade50
                                        : Colors.transparent,
                                  ),
                                  child: CheckboxListTile(
                                    contentPadding:
                                        EdgeInsets.symmetric(horizontal: 8),
                                    title: Text(
                                      option['label'],
                                      style: TextStyle(
                                        fontSize: 14,
                                        color: Colors.grey[800],
                                        fontWeight: isSelected
                                            ? FontWeight.w500
                                            : FontWeight.normal,
                                      ),
                                    ),
                                    value: isSelected,
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
                                    controlAffinity:
                                        ListTileControlAffinity.leading,
                                    activeColor: Colors.blue,
                                    checkColor: Colors.white,
                                    dense: true,
                                    visualDensity: VisualDensity.compact,
                                    shape: RoundedRectangleBorder(
                                      borderRadius: BorderRadius.circular(8),
                                    ),
                                  ),
                                );
                              }).toList(),
                            ),
                          ),
                          if (_errors['bukti_pelanggaran'] != null)
                            Padding(
                              padding: const EdgeInsets.only(top: 8, left: 12),
                              child: Text(
                                _errors['bukti_pelanggaran']!,
                                style: TextStyle(
                                  color: Colors.red,
                                  fontSize: 12,
                                ),
                              ),
                            ),
                        ],
                      ),
                    ),
                    SizedBox(height: 32),

                    // SECTION 2: INFORMASI PELAPOR
                    _buildSectionHeader('Informasi Pelapor'),
                    const SizedBox(height: 20),

                    _buildFormCard(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          _buildLabel('Nama Pelapor'),
                          SizedBox(height: 8),
                          _buildTextField(
                            controller: _namaPelaporController,
                            hint: 'Nama pelapor',
                            readOnly: true,
                            backgroundColor: Colors.grey.shade50,
                          ),
                          SizedBox(height: 20),
                          _buildLabel('NIP Pelapor'),
                          SizedBox(height: 8),
                          _buildTextField(
                            controller: _nipPelaporController,
                            hint: 'NIP pelapor',
                            readOnly: true,
                            backgroundColor: Colors.grey.shade50,
                          ),
                          SizedBox(height: 20),
                          _buildLabel('Nomor Telepon'),
                          SizedBox(height: 8),
                          _buildTextField(
                            controller: _nomorTeleponController,
                            hint: 'Nomor telepon',
                            readOnly: true,
                            backgroundColor: Colors.grey.shade50,
                          ),
                          SizedBox(height: 20),
                          _buildLabel('Jabatan', isRequired: true),
                          SizedBox(height: 8),
                          _buildDropdown(
                            value: _jabatan,
                            items: [
                              DropdownMenuItem(
                                  value: 'Dosen', child: Text('Dosen')),
                              DropdownMenuItem(
                                  value: 'Kaprodi', child: Text('Kaprodi')),
                              DropdownMenuItem(
                                  value: 'Koordinator Mata Kuliah',
                                  child: Text('Koordinator Mata Kuliah')),
                              DropdownMenuItem(
                                  value: 'Lainnya', child: Text('Lainnya')),
                            ],
                            onChanged: (value) {
                              setState(() {
                                _jabatan = value as String?;
                              });
                            },
                            hint: 'Pilih Jabatan',
                            errorText: _errors['jabatan'],
                          ),
                        ],
                      ),
                    ),
                    SizedBox(height: 24),

                    // Gender & Age Card
                    _buildFormCard(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          // Jenis Kelamin Radio
                          _buildLabel('Jenis Kelamin', isRequired: true),
                          SizedBox(height: 8),
                          _buildRadioGroup(
                            groupValue: _jenisKelamin,
                            onChange: (value) {
                              setState(() {
                                _jenisKelamin = value;
                              });
                            },
                            options: [
                              {'value': 'laki-laki', 'label': 'Laki-laki'},
                              {'value': 'perempuan', 'label': 'Perempuan'},
                            ],
                            errorText: _errors['jenis_kelamin'],
                          ),
                          SizedBox(height: 20),

                          // Rentang Umur Radio
                          _buildLabel('Rentang Umur', isRequired: true),
                          SizedBox(height: 8),
                          _buildRadioGroup(
                            groupValue: _umurPelapor,
                            onChange: (value) {
                              setState(() {
                                _umurPelapor = value;
                              });
                            },
                            options: [
                              {'value': '20-40', 'label': '20 - 40 tahun'},
                              {'value': '41-60', 'label': '41 - 60 tahun'},
                              {'value': '60<', 'label': 'Lebih dari 60 tahun'},
                            ],
                            errorText: _errors['umur_pelapor'],
                          ),
                        ],
                      ),
                    ),
                    SizedBox(height: 32),

                    // SECTION 3: IDENTITAS TERLAPOR
                    _buildSectionHeader('Identitas Terlapor/Terduga'),
                    Padding(
                      padding: const EdgeInsets.only(top: 8, bottom: 20),
                      child: Text(
                        'Opsional: Anda dapat mengosongkan semua field terlapor jika tidak ingin mengisikan.',
                        style: TextStyle(
                          color: Colors.grey.shade700,
                          fontSize: 13,
                          fontStyle: FontStyle.italic,
                        ),
                      ),
                    ),

                    // List of terlapor
                    ...List.generate(_terlaporList.length, (index) {
                      return Column(
                        children: [
                          _buildTerlaporItem(index),
                          SizedBox(height: 16),
                        ],
                      );
                    }),

                    // Button to add more terlapor
                    Center(
                      child: _buildOutlinedButton(
                        onPressed: _addTerlapor,
                        icon: Icons.add,
                        label: 'Tambah Terlapor',
                      ),
                    ),
                    SizedBox(height: 32),

                    // SECTION 4: SAKSI
                    _buildSectionHeader('Saksi'),
                    Padding(
                      padding: const EdgeInsets.only(top: 8, bottom: 20),
                      child: Text(
                        'Opsional: Anda dapat mengosongkan semua field saksi jika tidak ingin mengisikan.',
                        style: TextStyle(
                          color: Colors.grey.shade700,
                          fontSize: 13,
                          fontStyle: FontStyle.italic,
                        ),
                      ),
                    ),

                    // List of saksi
                    ...List.generate(_saksiList.length, (index) {
                      return Column(
                        children: [
                          _buildSaksiItem(index),
                          SizedBox(height: 16),
                        ],
                      );
                    }),

                    // Button to add more saksi
                    Center(
                      child: _buildOutlinedButton(
                        onPressed: _addSaksi,
                        icon: Icons.add,
                        label: 'Tambah Saksi',
                      ),
                    ),
                    SizedBox(height: 32),

                    // SECTION 5: PERNYATAAN
                    _buildSectionHeader('Pernyataan'),
                    SizedBox(height: 20),

                    _buildFormCard(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'Dengan ini saya menyatakan bahwa:',
                            style: TextStyle(
                              fontWeight: FontWeight.w500,
                              color: Colors.grey.shade800,
                              fontSize: 15,
                            ),
                          ),
                          SizedBox(height: 16),
                          ...[
                            'Segala informasi yang saya berikan dalam laporan ini adalah benar dan dapat dipertanggungjawabkan.',
                            'Saya bersedia memberikan keterangan lebih lanjut apabila diperlukan untuk proses penanganan laporan.',
                            'Saya memahami bahwa memberikan laporan palsu dapat dikenakan sanksi sesuai dengan peraturan yang berlaku.'
                          ].map((text) => _buildStatementItem(text)),
                          SizedBox(height: 20),
                          Container(
                            padding: EdgeInsets.symmetric(
                                horizontal: 12, vertical: 8),
                            decoration: BoxDecoration(
                              color: _agreement
                                  ? Colors.blue.shade50
                                  : Colors.grey.shade50,
                              borderRadius: BorderRadius.circular(8),
                              border: Border.all(
                                color: _errors['agreement'] != null
                                    ? Colors.red
                                    : _agreement
                                        ? Colors.blue.shade200
                                        : Colors.grey.shade300,
                              ),
                            ),
                            child: Row(
                              children: [
                                SizedBox(
                                  width: 24,
                                  height: 24,
                                  child: Checkbox(
                                    value: _agreement,
                                    onChanged: (value) {
                                      setState(() {
                                        _agreement = value ?? false;
                                      });
                                    },
                                    activeColor: Colors.blue,
                                    checkColor: Colors.white,
                                    shape: RoundedRectangleBorder(
                                      borderRadius: BorderRadius.circular(4),
                                    ),
                                  ),
                                ),
                                SizedBox(width: 12),
                                Expanded(
                                  child: Text(
                                    'Saya menyetujui pernyataan di atas',
                                    style: TextStyle(
                                      fontSize: 14,
                                      color: Colors.grey.shade800,
                                      fontWeight: _agreement
                                          ? FontWeight.w500
                                          : FontWeight.normal,
                                    ),
                                  ),
                                ),
                              ],
                            ),
                          ),
                          if (_errors['agreement'] != null)
                            Padding(
                              padding: const EdgeInsets.only(top: 8, left: 12),
                              child: Text(
                                _errors['agreement']!,
                                style: TextStyle(
                                  color: Colors.red,
                                  fontSize: 12,
                                ),
                              ),
                            ),
                        ],
                      ),
                    ),

                    const SizedBox(height: 40),

                    // SUBMIT BUTTON
                    SizedBox(
                      width: double.infinity,
                      child: _buildSubmitButton(),
                    ),
                    SizedBox(height: 60),
                  ],
                ),
              ),
            ),
    );
  }

  // Helper Widgets
  Widget _buildSectionHeader(String title) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          title,
          style: TextStyle(
            fontSize: 18,
            fontWeight: FontWeight.bold,
            color: Colors.blue.shade800,
          ),
        ),
        SizedBox(height: 8),
        Container(
          width: 40,
          height: 3,
          decoration: BoxDecoration(
            color: Colors.blue.shade600,
            borderRadius: BorderRadius.circular(10),
          ),
        ),
      ],
    );
  }

  Widget _buildFormCard({
    String? title,
    bool required = false,
    required Widget child,
  }) {
    return Container(
      padding: EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: Colors.grey.withOpacity(0.08),
            blurRadius: 15,
            offset: Offset(0, 5),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          if (title != null) ...[
            _buildLabel(title, isRequired: required),
            SizedBox(height: 16),
          ],
          child,
        ],
      ),
    );
  }

  Widget _buildLabel(String text, {bool isRequired = false}) {
    return RichText(
      text: TextSpan(
        style: TextStyle(
          fontSize: 14,
          fontWeight: FontWeight.w500,
          color: Colors.grey[800],
        ),
        children: [
          TextSpan(text: text),
          if (isRequired)
            TextSpan(
              text: ' *',
              style: TextStyle(
                color: Colors.red.shade700,
                fontWeight: FontWeight.bold,
              ),
            ),
        ],
      ),
    );
  }

  Widget _buildTextField({
    required TextEditingController controller,
    required String hint,
    String? errorText,
    bool readOnly = false,
    int maxLines = 1,
    Color? backgroundColor,
  }) {
    return TextFormField(
      controller: controller,
      maxLines: maxLines,
      readOnly: readOnly,
      style: TextStyle(fontSize: 15),
      decoration: InputDecoration(
        contentPadding: EdgeInsets.symmetric(
          horizontal: 16,
          vertical: maxLines > 1 ? 16 : 0,
        ),
        hintText: hint,
        hintStyle: TextStyle(color: Colors.grey.shade400),
        errorText: errorText,
        fillColor: backgroundColor ?? Colors.white,
        filled: true,
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: BorderSide(
            color: errorText != null ? Colors.red : Colors.grey.shade300,
          ),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: BorderSide(
            color: errorText != null ? Colors.red : Colors.blue.shade400,
            width: 1.5,
          ),
        ),
        errorBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: BorderSide(
            color: Colors.red,
          ),
        ),
        focusedErrorBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: BorderSide(
            color: Colors.red,
            width: 1.5,
          ),
        ),
        errorStyle: TextStyle(fontSize: 12),
      ),
    );
  }

  Widget _buildDropdown({
    dynamic value,
    required List<DropdownMenuItem> items,
    required void Function(dynamic)? onChanged,
    required String hint,
    String? errorText,
  }) {
    return DropdownButtonFormField(
      value: value,
      items: items,
      onChanged: onChanged,
      style: TextStyle(fontSize: 15, color: Colors.grey.shade800),
      decoration: InputDecoration(
        contentPadding: EdgeInsets.symmetric(horizontal: 16, vertical: 0),
        hintText: hint,
        hintStyle: TextStyle(color: Colors.grey.shade400),
        errorText: errorText,
        filled: true,
        fillColor: Colors.white,
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: BorderSide(
            color: errorText != null ? Colors.red : Colors.grey.shade300,
          ),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: BorderSide(
            color: errorText != null ? Colors.red : Colors.blue.shade400,
            width: 1.5,
          ),
        ),
        errorBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: BorderSide(
            color: Colors.red,
          ),
        ),
        focusedErrorBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: BorderSide(
            color: Colors.red,
            width: 1.5,
          ),
        ),
        errorStyle: TextStyle(fontSize: 12),
      ),
      icon: Icon(Icons.keyboard_arrow_down, color: Colors.grey.shade600),
      isExpanded: true,
      dropdownColor: Colors.white,
      borderRadius: BorderRadius.circular(12),
    );
  }

  Widget _buildRadioGroup({
    required String? groupValue,
    required Function(String?) onChange,
    required List<Map<String, String>> options,
    String? errorText,
  }) {
    return Container(
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: errorText != null ? Colors.red : Colors.grey.shade200,
        ),
      ),
      child: Column(
        children: options.map((option) {
          bool isSelected = groupValue == option['value'];
          return Container(
            decoration: BoxDecoration(
              color: isSelected ? Colors.blue.shade50 : Colors.white,
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
                    ? BorderSide(color: Colors.grey.shade100)
                    : BorderSide.none,
              ),
            ),
            child: RadioListTile<String>(
              title: Text(
                option['label']!,
                style: TextStyle(
                  fontSize: 14,
                  color: Colors.grey.shade800,
                  fontWeight: isSelected ? FontWeight.w500 : FontWeight.normal,
                ),
              ),
              value: option['value']!,
              groupValue: groupValue,
              onChanged: (String? value) => onChange(value),
              activeColor: Colors.blue,
              contentPadding: EdgeInsets.symmetric(horizontal: 16, vertical: 4),
              dense: true,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(12),
              ),
            ),
          );
        }).toList(),
      ),
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
      label: Text(label),
      style: ElevatedButton.styleFrom(
        foregroundColor: Colors.white,
        backgroundColor: color,
        padding: EdgeInsets.symmetric(vertical: 16),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(12),
        ),
        elevation: 0,
      ),
    );
  }

  Widget _buildOutlinedButton({
    required VoidCallback onPressed,
    required IconData icon,
    required String label,
  }) {
    return OutlinedButton.icon(
      onPressed: onPressed,
      icon: Icon(icon, size: 18),
      label: Text(label),
      style: OutlinedButton.styleFrom(
        foregroundColor: Colors.blue,
        side: BorderSide(color: Colors.blue),
        padding: EdgeInsets.symmetric(vertical: 12, horizontal: 20),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(12),
        ),
      ),
    );
  }

  Widget _buildSubmitButton() {
    return ElevatedButton(
      onPressed: _agreement ? _saveLaporan : null,
      style: ElevatedButton.styleFrom(
        foregroundColor: Colors.white,
        backgroundColor: Colors.blue,
        disabledForegroundColor: Colors.white.withOpacity(0.38),
        disabledBackgroundColor: Colors.blue.withOpacity(0.12),
        padding: EdgeInsets.symmetric(vertical: 16),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(12),
        ),
        elevation: 0,
      ),
      child: Text(
        'Kirim Laporan',
        style: TextStyle(
          fontSize: 16,
          fontWeight: FontWeight.w600,
          letterSpacing: 0.5,
        ),
      ),
    );
  }

  Widget _buildStatementItem(String text) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 12.0),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            margin: EdgeInsets.only(top: 6),
            width: 6,
            height: 6,
            decoration: BoxDecoration(
              color: Colors.blue,
              shape: BoxShape.circle,
            ),
          ),
          SizedBox(width: 12),
          Expanded(
            child: Text(
              text,
              style: TextStyle(
                color: Colors.grey.shade700,
                height: 1.5,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildTerlaporItem(int index) {
    final item = _terlaporList[index];
    return _buildFormCard(
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
                ),
                child: Text(
                  'Terlapor #${index + 1}',
                  style: TextStyle(
                    fontWeight: FontWeight.w600,
                    color: Colors.amber.shade800,
                    fontSize: 13,
                  ),
                ),
              ),
              if (_terlaporList.length > 1)
                IconButton(
                  icon: Icon(Icons.delete_outline, color: Colors.red.shade400),
                  onPressed: () => _removeTerlapor(index),
                  tooltip: 'Hapus terlapor',
                  iconSize: 20,
                ),
            ],
          ),
          SizedBox(height: 16),

          if (_errors['terlapor_$index'] != null)
            Container(
              padding: EdgeInsets.all(12),
              margin: EdgeInsets.only(bottom: 16),
              decoration: BoxDecoration(
                color: Colors.red.shade50,
                borderRadius: BorderRadius.circular(8),
                border: Border.all(color: Colors.red.shade200),
              ),
              child: Row(
                children: [
                  Icon(
                    Icons.error_outline,
                    color: Colors.red,
                    size: 18,
                  ),
                  SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      _errors['terlapor_$index']!,
                      style: TextStyle(
                        color: Colors.red,
                        fontSize: 13,
                      ),
                    ),
                  ),
                ],
              ),
            ),

          // Terlapor form fields
          _buildLabel('Nama Lengkap'),
          SizedBox(height: 8),
          _buildTextField(
            controller: item['nama_lengkap'],
            hint: 'Nama lengkap terlapor',
          ),
          SizedBox(height: 16),

          _buildLabel('Email'),
          SizedBox(height: 8),
          _buildTextField(
            controller: item['email'],
            hint: 'Email terlapor',
          ),
          SizedBox(height: 16),

          _buildLabel('Nomor Telepon'),
          SizedBox(height: 8),
          _buildTextField(
            controller: item['nomor_telepon'],
            hint: 'Nomor telepon terlapor',
          ),
          SizedBox(height: 24),

          // Two columns layout for gender and age
          _buildLabel('Informasi Tambahan'),
          SizedBox(height: 12),
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Jenis Kelamin',
                      style: TextStyle(
                        fontSize: 13,
                        color: Colors.grey.shade600,
                      ),
                    ),
                    SizedBox(height: 8),
                    _buildRadioGroup(
                      groupValue: item['jenis_kelamin'],
                      onChange: (value) {
                        setState(() {
                          item['jenis_kelamin'] = value;
                        });
                      },
                      options: [
                        {'value': 'laki-laki', 'label': 'Laki-laki'},
                        {'value': 'perempuan', 'label': 'Perempuan'},
                      ],
                      errorText: null,
                    ),
                    SizedBox(height: 16),
                    Text(
                      'Status Warga UNS',
                      style: TextStyle(
                        fontSize: 13,
                        color: Colors.grey.shade600,
                      ),
                    ),
                    SizedBox(height: 8),
                    _buildDropdown(
                      value: item['status_warga'],
                      items: [
                        DropdownMenuItem(value: 'dosen', child: Text('Dosen')),
                        DropdownMenuItem(
                            value: 'mahasiswa', child: Text('Mahasiswa')),
                        DropdownMenuItem(value: 'staff', child: Text('Staff')),
                        DropdownMenuItem(
                            value: 'lainnya', child: Text('Lainnya')),
                      ],
                      onChanged: (value) {
                        setState(() {
                          item['status_warga'] = value;
                        });
                      },
                      hint: 'Pilih status',
                    ),
                  ],
                ),
              ),
              SizedBox(width: 20),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Rentang Umur',
                      style: TextStyle(
                        fontSize: 13,
                        color: Colors.grey.shade600,
                      ),
                    ),
                    SizedBox(height: 8),
                    _buildRadioGroup(
                      groupValue: item['umur_terlapor'],
                      onChange: (value) {
                        setState(() {
                          item['umur_terlapor'] = value;
                        });
                      },
                      options: [
                        {'value': '<20', 'label': 'Kurang dari 20 tahun'},
                        {'value': '20-40', 'label': '20 - 40 tahun'},
                        {'value': '40<', 'label': 'Lebih dari 40 tahun'},
                      ],
                      errorText: null,
                    ),
                  ],
                ),
              ),
            ],
          ),
          SizedBox(height: 16),

          // Unit Kerja
          Text(
            'Unit Kerja',
            style: TextStyle(
              fontSize: 13,
              color: Colors.grey.shade600,
            ),
          ),
          SizedBox(height: 8),
          _buildDropdown(
            value: item['unit_kerja'],
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
            hint: 'Pilih unit kerja',
          ),
        ],
      ),
    );
  }

  Widget _buildSaksiItem(int index) {
    final item = _saksiList[index];
    return _buildFormCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Container(
                padding: EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                decoration: BoxDecoration(
                  color: Colors.teal.shade50,
                  borderRadius: BorderRadius.circular(20),
                ),
                child: Text(
                  'Saksi #${index + 1}',
                  style: TextStyle(
                    fontWeight: FontWeight.w600,
                    color: Colors.teal.shade800,
                    fontSize: 13,
                  ),
                ),
              ),
              if (_saksiList.length > 1)
                IconButton(
                  icon: Icon(Icons.delete_outline, color: Colors.red.shade400),
                  onPressed: () => _removeSaksi(index),
                  tooltip: 'Hapus saksi',
                  iconSize: 20,
                ),
            ],
          ),
          SizedBox(height: 16),
          if (_errors['saksi_$index'] != null)
            Container(
              padding: EdgeInsets.all(12),
              margin: EdgeInsets.only(bottom: 16),
              decoration: BoxDecoration(
                color: Colors.red.shade50,
                borderRadius: BorderRadius.circular(8),
                border: Border.all(color: Colors.red.shade200),
              ),
              child: Row(
                children: [
                  Icon(
                    Icons.error_outline,
                    color: Colors.red,
                    size: 18,
                  ),
                  SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      _errors['saksi_$index']!,
                      style: TextStyle(
                        color: Colors.red,
                        fontSize: 13,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          _buildLabel('Nama Lengkap'),
          SizedBox(height: 8),
          _buildTextField(
            controller: item['nama_lengkap'],
            hint: 'Nama lengkap saksi',
          ),
          SizedBox(height: 16),
          _buildLabel('Email'),
          SizedBox(height: 8),
          _buildTextField(
            controller: item['email'],
            hint: 'Email saksi',
          ),
          SizedBox(height: 16),
          _buildLabel('Nomor Telepon'),
          SizedBox(height: 8),
          _buildTextField(
            controller: item['nomor_telepon'],
            hint: 'Nomor telepon saksi',
          ),
        ],
      ),
    );
  }

  @override
  void dispose() {
    // Dispose all controllers
    _judulController.dispose();
    _deskripsiController.dispose();
    _nomorTeleponController.dispose();
    _namaPelaporController.dispose();
    _nipPelaporController.dispose();
    _lampiranLinkController.dispose();

    // Dispose terlapor controllers
    for (var terlapor in _terlaporList) {
      terlapor['nama_lengkap'].dispose();
      terlapor['email'].dispose();
      terlapor['nomor_telepon'].dispose();
    }

    // Dispose saksi controllers
    for (var saksi in _saksiList) {
      saksi['nama_lengkap'].dispose();
      saksi['email'].dispose();
      saksi['nomor_telepon'].dispose();
    }

    super.dispose();
  }
}
