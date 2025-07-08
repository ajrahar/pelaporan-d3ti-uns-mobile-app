import 'dart:io';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:intl/intl.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';
import 'package:shared_preferences/shared_preferences.dart';
// Import package untuk notifikasi
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:timezone/timezone.dart' as tz;
import 'package:timezone/data/latest.dart' as tz_init;

class AddLaporPKMendesakDosen extends StatefulWidget {
  const AddLaporPKMendesakDosen({Key? key}) : super(key: key);

  @override
  State<AddLaporPKMendesakDosen> createState() =>
      _AddLaporPKMendesakDosenState();
}

class _AddLaporPKMendesakDosenState extends State<AddLaporPKMendesakDosen> {
  // Inisialisasi plugin notifikasi lokal
  final FlutterLocalNotificationsPlugin flutterLocalNotificationsPlugin =
      FlutterLocalNotificationsPlugin();

  // Form key for validation
  final _formKey = GlobalKey<FormState>();

  // Form data
  final TextEditingController _judulController = TextEditingController();
  final TextEditingController _tanggalKejadianController =
      TextEditingController();
  final TextEditingController _lampiranLinkController = TextEditingController();

  // Category data
  int? _selectedCategoryId;
  List<Map<String, dynamic>> _categories = [];

  // Image data - Changed from XFile to File to match add_lapor_pkdosen.dart
  final ImagePicker _picker = ImagePicker();
  List<File> _imageFiles = []; // Changed from XFile to File

  // Agreement checkbox
  bool _isAgreementChecked = false;

  // Loading state
  bool _isLoading = false;

  // Error mapping
  Map<String, List<String>> _errors = {};

  // Theme colors
  final Color _primaryColor = const Color(0xFF00A2EA); // Blue primary color
  final Color _secondaryColor = const Color(0xFFF78052); // Orange accent color
  final Color _backgroundColor =
      const Color(0xFFF9FAFC); // Light background color
  final Color _cardColor = Colors.white; // Card color
  final Color _textColor = const Color(0xFF2D3748); // Dark text color
  final Color _subTextColor = const Color(0xFF718096); // Light text color
  final Color _borderColor = const Color(0xFFE2E8F0); // Border color
  final Color _errorColor = const Color(0xFFE53E3E); // Error color
  final Color _successColor = const Color(0xFF38A169); // Success color

  @override
  void initState() {
    super.initState();
    _fetchCategories();
    _loadUserData();
    _initializeNotifications(); // Inisialisasi notifikasi
    _updateCurrentTime();
  }

  // Update current time
  void _updateCurrentTime() {
    final now = DateTime.now();
    setState(() {
      _tanggalKejadianController.text =
          DateFormat('yyyy-MM-dd HH:mm').format(now);
    });
  }

  // Metode untuk inisialisasi notifikasi lokal
  Future<void> _initializeNotifications() async {
    // Initialize timezone
    tz_init.initializeTimeZones();

    // Initialize settings for Android
    const AndroidInitializationSettings initializationSettingsAndroid =
        AndroidInitializationSettings('@mipmap/ic_launcher');

    // Initialize settings for iOS
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

  // Metode untuk menampilkan notifikasi
  Future<void> _showNotification({
    required String title,
    required String body,
    String? payload,
  }) async {
    const AndroidNotificationDetails androidDetails =
        AndroidNotificationDetails(
      'laporan_mendesak_dosen',
      'Laporan Mendesak Dosen',
      channelDescription: 'Notifications for urgent reports',
      importance: Importance.max,
      priority: Priority.high,
      ticker: 'ticker',
      color: Color(0xFF00A2EA), // Blue primary color
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

  Future<void> _loadUserData() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      // You would implement your own decryption mechanism here
    } catch (e) {
      // Tampilkan notifikasi jika gagal memuat data
      await _showNotification(
        title: 'Perhatian',
        body: 'Gagal memuat data pengguna',
        payload: 'user_data_error',
      );
    }
  }

  Future<void> _fetchCategories() async {
    setState(() => _isLoading = true);

    try {
      // final response = await http.get(Uri.parse('http://pelaporan-d3ti.my.id/api/category'));
      final response = await http.get(
        Uri.parse('https://v3422040.mhs.d3tiuns.com/api/category'),
      );

      if (response.statusCode == 200) {
        final List<dynamic> data = json.decode(response.body);
        setState(() {
          _categories = List<Map<String, dynamic>>.from(data);

          // Find the "Darurat dan Mendesak" category
          final mendesakCategory = _categories.firstWhere(
              (cat) => cat['nama'] == "Darurat dan Mendesak",
              orElse: () => _categories.isNotEmpty
                  ? _categories.first
                  : {'category_id': 21, 'nama': "Darurat dan Mendesak"});

          _selectedCategoryId = mendesakCategory['category_id'];
        });

        // Notifikasi kategori berhasil dimuat
        await _showNotification(
          title: 'Informasi',
          body: 'Kategori berhasil dimuat',
          payload: 'categories_loaded',
        );
      } else {
        _setFallbackCategory();

        // Notifikasi error loading kategori
        await _showNotification(
          title: 'Perhatian',
          body: 'Gagal memuat kategori. Menggunakan kategori default.',
          payload: 'categories_error',
        );
      }
    } catch (e) {
      _setFallbackCategory();

      // Notifikasi error
      await _showNotification(
        title: 'Error',
        body: 'Terjadi kesalahan saat memuat kategori: ${e.toString()}',
        payload: 'categories_exception',
      );
    } finally {
      setState(() => _isLoading = false);
    }
  }

  void _setFallbackCategory() {
    setState(() {
      _categories = [
        {'category_id': 21, 'nama': "Darurat dan Mendesak"}
      ];
      _selectedCategoryId = 21;
    });
  }

  // Updated to use File instead of XFile, similar to add_lapor_pkdosen.dart
  Future<void> _pickImage(ImageSource source) async {
    try {
      final picker = ImagePicker();
      final pickedFile = await picker.pickImage(
        source: source,
        imageQuality: 80, // Compression quality
      );

      if (pickedFile != null) {
        setState(() {
          _imageFiles.add(File(pickedFile.path));
        });

        // Notifikasi gambar berhasil dipilih
        await _showNotification(
          title: 'Sukses',
          body:
              'Gambar berhasil dipilih dari ${source == ImageSource.camera ? 'kamera' : 'galeri'}',
          payload: 'image_selected',
        );
      }
    } catch (e) {
      _showSnackBar('Error memilih gambar: $e', isError: true);

      // Show notification if image picking fails
      await _showNotification(
        title: 'Peringatan',
        body: 'Tidak dapat mengambil gambar: ${e.toString()}',
        payload: 'image_error',
      );
    }
  }

  // Function to remove image
  void _removeImage(int index) {
    setState(() {
      _imageFiles.removeAt(index);
    });
  }

  Future<void> _selectDateTime() async {
    final DateTime? pickedDate = await showDatePicker(
      context: context,
      initialDate: DateTime.now(),
      firstDate: DateTime(2020),
      lastDate: DateTime.now(),
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

    if (pickedDate != null) {
      final TimeOfDay? pickedTime = await showTimePicker(
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

      if (pickedTime != null) {
        final DateTime combinedDateTime = DateTime(
          pickedDate.year,
          pickedDate.month,
          pickedDate.day,
          pickedTime.hour,
          pickedTime.minute,
        );

        setState(() {
          _tanggalKejadianController.text =
              DateFormat('yyyy-MM-dd HH:mm').format(combinedDateTime);
        });
      }
    }
  }

  bool _validateForm() {
    _errors.clear();

    if (_judulController.text.isEmpty) {
      _errors['judul'] = ['Judul laporan harus diisi'];
    }

    if (_tanggalKejadianController.text.isEmpty) {
      _errors['tanggal_kejadian'] = ['Tanggal dan waktu kejadian harus diisi'];
    }

    if (_imageFiles.isEmpty) {
      _errors['image_path'] = ['Lampiran foto harus diisi'];
    }

    // Remove validation for lampiran_link as it's now optional
    // if (_lampiranLinkController.text.isEmpty) {
    //   _errors['lampiran_link'] = ['Lampiran link harus diisi'];
    // }

    if (!_isAgreementChecked) {
      _errors['agreement'] = [
        'Anda harus menyetujui pernyataan untuk melanjutkan'
      ];
    }

    setState(() {});

    // Jika ada error, tampilkan notifikasi
    if (_errors.isNotEmpty) {
      _showNotification(
        title: 'Form Tidak Lengkap',
        body: 'Mohon lengkapi formulir yang ditandai merah',
        payload: 'form_validation_error',
      );

      _showSnackBar('Formulir belum lengkap. Mohon periksa kembali.',
          isError: true);
    }

    return _errors.isEmpty;
  }

  void _showSnackBar(String message, {bool isError = false}) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Row(
          children: [
            Icon(
              isError ? Icons.error_outline : Icons.info_outline,
              color: Colors.white,
            ),
            const SizedBox(width: 12),
            Expanded(child: Text(message)),
          ],
        ),
        backgroundColor: isError ? _errorColor : _primaryColor,
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
        margin: const EdgeInsets.all(12),
        duration: const Duration(seconds: 4),
      ),
    );
  }

  Future<void> _submitForm() async {
    if (!_validateForm()) return;

    setState(() => _isLoading = true);

    // Notifikasi proses pengiriman dimulai
    await _showNotification(
      title: 'Mengirim Laporan',
      body: 'Laporan "${_judulController.text}" sedang dikirim...',
      payload: 'sending',
    );

    try {
      // Create multipart request
      final request = http.MultipartRequest(
        'POST',
        // Uri.parse('http://pelaporan-d3ti.my.id/api/laporan/add_laporan'),
        Uri.parse('https://v3422040.mhs.d3tiuns.com/api/laporan/add_laporan'),
      );

      // Get token from shared preferences
      final prefs = await SharedPreferences.getInstance();
      final String? token = prefs.getString('auth_token');

      if (token != null) {
        request.headers['Authorization'] = 'Bearer $token';
      }

      // Add text fields
      request.fields['judul'] = _judulController.text;
      request.fields['category_id'] = _selectedCategoryId.toString();
      request.fields['deskripsi'] = '-';
      request.fields['tanggal_kejadian'] = _tanggalKejadianController.text;
      request.fields['profesi'] = 'Dosen';
      request.fields['jenis_kelamin'] = 'laki-laki';
      request.fields['umur_pelapor'] = '20-40';

      // Only add lampiran_link if it's not empty (since it's now optional)
      if (_lampiranLinkController.text.isNotEmpty) {
        request.fields['lampiran_link'] = _lampiranLinkController.text;
      }

      // Add terlapor data
      request.fields['terlapor[0][nama_lengkap]'] = 'Nama Terlapor';
      request.fields['terlapor[0][email]'] = 'terlapor@example.com';
      request.fields['terlapor[0][nomor_telepon]'] = '081234567890';
      request.fields['terlapor[0][status_warga]'] = 'mahasiswa';
      request.fields['terlapor[0][unit_kerja]'] = 'Fakultas Teknik';
      request.fields['terlapor[0][jenis_kelamin]'] = 'laki-laki';
      request.fields['terlapor[0][umur_terlapor]'] = '20-40';

      // Add saksi data
      request.fields['saksi[0][nama_lengkap]'] = 'Nama Saksi';
      request.fields['saksi[0][email]'] = 'saksi@example.com';
      request.fields['saksi[0][nomor_telepon]'] = '089876543210';

      // Add bukti_pelanggaran
      request.fields['bukti_pelanggaran[0]'] = 'foto_dokumentasi';

      // Add agreement
      request.fields['agreement'] = '1';

      // Add images - Updated to use File instead of XFile
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
      final response = await request.send();

      // Check response
      if (response.statusCode >= 200 && response.statusCode < 300) {
        // Success notification
        await _showNotification(
          title: 'Berhasil',
          body:
              'Laporan kejadian mendesak "${_judulController.text}" berhasil dikirim',
          payload: 'success',
        );

        // Success dialog
        _showSuccessDialog();
      } else {
        // Error
        final responseData = await response.stream.bytesToString();
        final errorData = json.decode(responseData);

        setState(() {
          if (errorData is Map) {
            _errors = Map<String, List<String>>.from(errorData
                .map((key, value) => MapEntry(key, List<String>.from(value))));
          }
        });

        // Error notification
        await _showNotification(
          title: 'Gagal',
          body:
              'Terjadi kesalahan saat mengirim laporan. Status: ${response.statusCode}',
          payload: 'api_error_${response.statusCode}',
        );

        _showErrorDialog('Terjadi kesalahan saat mengirim laporan');
      }
    } catch (e) {
      // Exception notification
      await _showNotification(
        title: 'Error',
        body: 'Terjadi kesalahan: ${e.toString()}',
        payload: 'exception',
      );

      _showErrorDialog('Terjadi kesalahan: $e');
    } finally {
      setState(() => _isLoading = false);
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
            padding: const EdgeInsets.all(20),
            decoration: BoxDecoration(
              color: _cardColor,
              shape: BoxShape.rectangle,
              borderRadius: BorderRadius.circular(16),
              boxShadow: [
                BoxShadow(
                  color: Colors.black26,
                  blurRadius: 10.0,
                  offset: const Offset(0.0, 10.0),
                ),
              ],
            ),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: <Widget>[
                Container(
                  padding: const EdgeInsets.all(16),
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
                const SizedBox(height: 24),
                Text(
                  'Berhasil!',
                  style: TextStyle(
                    fontSize: 22,
                    fontWeight: FontWeight.w600,
                    color: _textColor,
                  ),
                ),
                const SizedBox(height: 16),
                Text(
                  'Laporan kejadian mendesak berhasil dikirim',
                  style: TextStyle(
                    fontSize: 16,
                    color: _subTextColor,
                  ),
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: 24),
                ElevatedButton(
                  onPressed: () {
                    Navigator.of(context).pop();
                    Navigator.of(context).pop(); // Navigate back
                  },
                  style: ElevatedButton.styleFrom(
                    foregroundColor: Colors.white,
                    backgroundColor: _primaryColor,
                    padding: const EdgeInsets.symmetric(
                        horizontal: 40, vertical: 12),
                    elevation: 0,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(8),
                    ),
                  ),
                  child: const Text(
                    'OK',
                    style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  void _showErrorDialog(String message) {
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
            padding: const EdgeInsets.all(20),
            decoration: BoxDecoration(
              color: _cardColor,
              shape: BoxShape.rectangle,
              borderRadius: BorderRadius.circular(16),
              boxShadow: [
                BoxShadow(
                  color: Colors.black26,
                  blurRadius: 10.0,
                  offset: const Offset(0.0, 10.0),
                ),
              ],
            ),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: <Widget>[
                Container(
                  padding: const EdgeInsets.all(16),
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
                const SizedBox(height: 24),
                Text(
                  'Error!',
                  style: TextStyle(
                    fontSize: 22,
                    fontWeight: FontWeight.w600,
                    color: _textColor,
                  ),
                ),
                const SizedBox(height: 16),
                Text(
                  message,
                  style: TextStyle(
                    fontSize: 16,
                    color: _subTextColor,
                  ),
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: 24),
                ElevatedButton(
                  onPressed: () {
                    Navigator.of(context).pop();
                  },
                  style: ElevatedButton.styleFrom(
                    foregroundColor: Colors.white,
                    backgroundColor: _primaryColor,
                    padding: const EdgeInsets.symmetric(
                        horizontal: 40, vertical: 12),
                    elevation: 0,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(8),
                    ),
                  ),
                  child: const Text(
                    'OK',
                    style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );
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
          'Laporan Kejadian Mendesak',
          style: TextStyle(
            color: _textColor,
            fontWeight: FontWeight.w600,
            fontSize: 18,
          ),
        ),
        centerTitle: true,
      ),
      body: _isLoading && _categories.isEmpty
          ? Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  CircularProgressIndicator(color: _primaryColor),
                  const SizedBox(height: 16),
                  Text(
                    'Memuat data...',
                    style: TextStyle(
                      color: _subTextColor,
                      fontSize: 16,
                    ),
                  ),
                ],
              ),
            )
          : SingleChildScrollView(
              padding: const EdgeInsets.all(20.0),
              child: Form(
                key: _formKey,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // Form header - Info banner
                    _buildInfoBanner(),
                    const SizedBox(height: 24),

                    // Section 1: Detail Laporan
                    _buildSectionHeader(
                        'Detail Laporan', Icons.description_outlined),

                    // Judul Laporan
                    _buildFormField(
                      label: 'Judul Laporan',
                      isRequired: true,
                      child: TextFormField(
                        controller: _judulController,
                        decoration: _inputDecoration(
                          hintText: 'Masukkan judul laporan',
                          errorText: _errors['judul']?.first,
                          prefixIcon: Icons.title,
                        ),
                        style: TextStyle(fontSize: 15, color: _textColor),
                      ),
                    ),

                    // Real-time Indonesia Time
                    _buildFormField(
                      label: 'Waktu Kejadian (WIB)',
                      isRequired: true,
                      child: InkWell(
                        onTap: _selectDateTime,
                        child: Container(
                          padding: const EdgeInsets.symmetric(
                              horizontal: 16, vertical: 16),
                          decoration: BoxDecoration(
                            borderRadius: BorderRadius.circular(8),
                            border: Border.all(
                              color: _errors['tanggal_kejadian'] != null
                                  ? _errorColor
                                  : _borderColor,
                            ),
                          ),
                          child: Row(
                            children: [
                              Icon(Icons.access_time,
                                  color: _primaryColor, size: 20),
                              const SizedBox(width: 12),
                              Expanded(
                                child: Text(
                                  _tanggalKejadianController.text,
                                  style: TextStyle(
                                    fontSize: 15,
                                    color: _textColor,
                                  ),
                                ),
                              ),
                              Icon(Icons.calendar_today,
                                  color: _subTextColor, size: 20),
                            ],
                          ),
                        ),
                      ),
                      errorText: _errors['tanggal_kejadian']?.first,
                    ),

                    // Lampiran Foto - Updated with camera and gallery buttons like add_lapor_pkdosen.dart
                    _buildFormField(
                      label: 'Lampiran Foto',
                      isRequired: true,
                      errorText: _errors['image_path']?.first,
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          // Upload buttons - Similar to add_lapor_pkdosen.dart
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
                          const SizedBox(height: 8),
                          Row(
                            children: [
                              Icon(Icons.info_outline,
                                  size: 16, color: _subTextColor),
                              const SizedBox(width: 8),
                              Expanded(
                                child: Text(
                                  'Anda dapat mengambil foto dengan kamera atau memilih dari galeri',
                                  style: TextStyle(
                                      color: _subTextColor, fontSize: 13),
                                ),
                              ),
                            ],
                          ),

                          // Image previews
                          if (_imageFiles.isNotEmpty)
                            Container(
                              margin: const EdgeInsets.only(top: 16),
                              height: 120,
                              child: ListView.builder(
                                scrollDirection: Axis.horizontal,
                                itemCount: _imageFiles.length,
                                itemBuilder: (context, index) {
                                  return Stack(
                                    children: [
                                      Container(
                                        margin:
                                            const EdgeInsets.only(right: 12),
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
                                              offset: const Offset(0, 2),
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
                                            padding: const EdgeInsets.all(4),
                                            decoration: BoxDecoration(
                                              color: Colors.white,
                                              shape: BoxShape.circle,
                                              boxShadow: [
                                                BoxShadow(
                                                  color: Colors.black26,
                                                  blurRadius: 3,
                                                  offset: const Offset(0, 1),
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

                    // Kategori
                    _buildFormField(
                      label: 'Kategori',
                      isRequired: true,
                      child: Container(
                        decoration: BoxDecoration(
                          borderRadius: BorderRadius.circular(8),
                          color: const Color(0xFFEDF2F7),
                          border: Border.all(color: _borderColor),
                        ),
                        padding: const EdgeInsets.symmetric(
                            horizontal: 16, vertical: 16),
                        child: Row(
                          children: [
                            Icon(Icons.category_outlined,
                                color: _primaryColor, size: 20),
                            const SizedBox(width: 12),
                            Expanded(
                              child: Text(
                                "Darurat dan Mendesak",
                                style: TextStyle(
                                  fontSize: 15,
                                  color: _textColor,
                                ),
                              ),
                            ),
                            Text(
                              "(tidak dapat diubah)",
                              style: TextStyle(
                                fontSize: 13,
                                fontStyle: FontStyle.italic,
                                color: _subTextColor,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),

                    // Lampiran Link - now optional
                    _buildFormField(
                      label: 'Lampiran Link',
                      isRequired: false, // Changed to false to make it optional
                      child: TextFormField(
                        controller: _lampiranLinkController,
                        decoration: _inputDecoration(
                          hintText: 'https://www.example.com (opsional)',
                          errorText: _errors['lampiran_link']?.first,
                          prefixIcon: Icons.link,
                        ),
                        style: TextStyle(fontSize: 15, color: _textColor),
                      ),
                    ),

                    const SizedBox(height: 16),

                    // Pernyataan Section
                    _buildSectionHeader('Pernyataan', Icons.gavel_outlined),

                    Container(
                      margin: const EdgeInsets.only(bottom: 24),
                      padding: const EdgeInsets.all(20),
                      decoration: BoxDecoration(
                        color: _cardColor,
                        borderRadius: BorderRadius.circular(12),
                        boxShadow: [
                          BoxShadow(
                            color: Colors.black.withOpacity(0.03),
                            blurRadius: 10,
                            offset: const Offset(0, 4),
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
                              const SizedBox(width: 10),
                              Expanded(
                                child: Text(
                                  'Dengan ini saya menyatakan bahwa:',
                                  style: TextStyle(
                                    fontWeight: FontWeight.w600,
                                    fontSize: 15,
                                    color: _textColor,
                                  ),
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 16),
                          _buildStatementItem(
                            '1. Segala informasi yang saya berikan dalam laporan ini adalah benar dan dapat dipertanggungjawabkan.',
                          ),
                          _buildStatementItem(
                            '2. Saya bersedia memberikan keterangan lebih lanjut apabila diperlukan untuk proses penanganan laporan.',
                          ),
                          _buildStatementItem(
                            '3. Saya memahami bahwa memberikan laporan palsu dapat dikenakan sanksi sesuai dengan peraturan yang berlaku.',
                          ),
                          const SizedBox(height: 16),
                          Container(
                            padding: const EdgeInsets.symmetric(
                                vertical: 12, horizontal: 16),
                            decoration: BoxDecoration(
                              borderRadius: BorderRadius.circular(8),
                              color: _errors['agreement'] != null
                                  ? _errorColor.withOpacity(0.1)
                                  : _primaryColor.withOpacity(0.05),
                              border: Border.all(
                                color: _errors['agreement'] != null
                                    ? _errorColor
                                    : _primaryColor.withOpacity(0.2),
                              ),
                            ),
                            child: Row(
                              children: [
                                SizedBox(
                                  height: 24,
                                  width: 24,
                                  child: Checkbox(
                                    value: _isAgreementChecked,
                                    onChanged: (value) {
                                      setState(() {
                                        _isAgreementChecked = value!;
                                      });
                                    },
                                    activeColor: _primaryColor,
                                    shape: RoundedRectangleBorder(
                                      borderRadius: BorderRadius.circular(4),
                                    ),
                                  ),
                                ),
                                const SizedBox(width: 12),
                                Expanded(
                                  child: Text(
                                    'Saya menyetujui pernyataan di atas',
                                    style: TextStyle(
                                      fontSize: 14,
                                      fontWeight: FontWeight.w500,
                                      color: _textColor,
                                    ),
                                  ),
                                ),
                                const SizedBox(width: 8),
                                Text(
                                  '*',
                                  style: TextStyle(
                                    color: _errorColor,
                                    fontWeight: FontWeight.bold,
                                    fontSize: 16,
                                  ),
                                ),
                              ],
                            ),
                          ),
                          if (_errors['agreement'] != null)
                            Padding(
                              padding: const EdgeInsets.only(left: 8, top: 8),
                              child: Text(
                                _errors['agreement']!.first,
                                style:
                                    TextStyle(color: _errorColor, fontSize: 12),
                              ),
                            ),
                        ],
                      ),
                    ),

                    // Form Actions
                    Padding(
                      padding: const EdgeInsets.symmetric(vertical: 16),
                      child: Row(
                        children: [
                          Expanded(
                            child: OutlinedButton.icon(
                              onPressed: () => Navigator.of(context).pop(),
                              icon: const Icon(Icons.arrow_back),
                              label: const Text('Kembali'),
                              style: OutlinedButton.styleFrom(
                                foregroundColor: _subTextColor,
                                padding:
                                    const EdgeInsets.symmetric(vertical: 16),
                                side: BorderSide(color: _borderColor),
                                shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(8),
                                ),
                              ),
                            ),
                          ),
                          const SizedBox(width: 16),
                          Expanded(
                            flex: 2,
                            child: ElevatedButton.icon(
                              onPressed: _isLoading || !_isAgreementChecked
                                  ? null
                                  : _submitForm,
                              icon: _isLoading
                                  ? SizedBox(
                                      width: 24,
                                      height: 24,
                                      child: CircularProgressIndicator(
                                        color: Colors.white,
                                        strokeWidth: 2,
                                      ),
                                    )
                                  : const Icon(Icons.send),
                              label: Text(
                                  _isLoading ? 'Mengirim...' : 'Kirim Laporan'),
                              style: ElevatedButton.styleFrom(
                                foregroundColor: Colors.white,
                                backgroundColor: _primaryColor,
                                disabledForegroundColor:
                                    Colors.white.withOpacity(0.5),
                                disabledBackgroundColor:
                                    _primaryColor.withOpacity(0.5),
                                padding:
                                    const EdgeInsets.symmetric(vertical: 16),
                                elevation: 0,
                                shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(8),
                                ),
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
    );
  }

  // Helper method to build elevated button - similar to add_lapor_pkdosen.dart
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
        padding: const EdgeInsets.symmetric(vertical: 16),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(12),
        ),
        elevation: 0,
      ),
    );
  }

  Widget _buildInfoBanner() {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(vertical: 20, horizontal: 24),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(12),
        color: _secondaryColor.withOpacity(0.1),
        border: Border.all(
          color: _secondaryColor.withOpacity(0.3),
          width: 1,
        ),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(
            Icons.warning_amber_rounded,
            color: _secondaryColor,
            size: 24,
          ),
          const SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Laporan Kejadian Mendesak',
                  style: TextStyle(
                    fontWeight: FontWeight.w600,
                    fontSize: 16,
                    color: _textColor,
                  ),
                ),
                const SizedBox(height: 8),
                Text(
                  'Gunakan form ini untuk melaporkan kejadian yang memerlukan respons segera dari pihak berwenang. Laporan akan diprioritaskan dalam penanganannya.',
                  style: TextStyle(
                    color: _subTextColor,
                    height: 1.5,
                    fontSize: 14,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSectionHeader(String title, IconData icon) {
    return Container(
      margin: const EdgeInsets.only(top: 16, bottom: 24),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(10),
            decoration: BoxDecoration(
              color: _primaryColor.withOpacity(0.1),
              borderRadius: BorderRadius.circular(8),
            ),
            child: Icon(icon, color: _primaryColor, size: 20),
          ),
          const SizedBox(width: 16),
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
      margin: const EdgeInsets.only(bottom: 24),
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
                  fontWeight: FontWeight.w500,
                ),
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
          if (errorText != null)
            Padding(
              padding: const EdgeInsets.only(left: 8, top: 6),
              child: Text(
                errorText,
                style: TextStyle(color: _errorColor, fontSize: 12),
              ),
            ),
        ],
      ),
    );
  }

  Widget _buildStatementItem(String text) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 12.0),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const SizedBox(width: 12),
          Expanded(
            child: Text(
              text,
              style: TextStyle(
                color: _subTextColor,
                fontSize: 14,
                height: 1.5,
              ),
            ),
          ),
        ],
      ),
    );
  }

  InputDecoration _inputDecoration({
    required String hintText,
    String? errorText,
    IconData? prefixIcon,
  }) {
    return InputDecoration(
      hintText: hintText,
      hintStyle: TextStyle(color: Colors.grey.shade400, fontSize: 14),
      errorText: errorText,
      errorStyle:
          const TextStyle(fontSize: 0, height: 0), // Hide default error text
      prefixIcon: prefixIcon != null
          ? Icon(prefixIcon,
              color: errorText != null ? _errorColor : _primaryColor, size: 20)
          : null,
      contentPadding: EdgeInsets.symmetric(
        vertical: 16,
        horizontal: prefixIcon == null ? 16 : 0,
      ),
      border: OutlineInputBorder(
        borderRadius: BorderRadius.circular(8),
        borderSide: BorderSide(color: _borderColor),
      ),
      enabledBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(8),
        borderSide:
            BorderSide(color: errorText != null ? _errorColor : _borderColor),
      ),
      focusedBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(8),
        borderSide: BorderSide(color: _primaryColor, width: 1.5),
      ),
      errorBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(8),
        borderSide: BorderSide(color: _errorColor),
      ),
      focusedErrorBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(8),
        borderSide: BorderSide(color: _errorColor, width: 1.5),
      ),
      filled: false,
    );
  }

  @override
  void dispose() {
    _judulController.dispose();
    _tanggalKejadianController.dispose();
    _lampiranLinkController.dispose();
    super.dispose();
  }
}
