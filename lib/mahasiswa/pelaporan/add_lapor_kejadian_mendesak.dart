import 'dart:io';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:intl/intl.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';
import 'dart:async';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:timezone/timezone.dart' as tz;
import 'package:timezone/data/latest.dart' as tz_init;

class AddLaporKejadianMendesak extends StatefulWidget {
  const AddLaporKejadianMendesak({Key? key}) : super(key: key);

  @override
  State<AddLaporKejadianMendesak> createState() =>
      _AddLaporKejadianMendesakState();
}

class _AddLaporKejadianMendesakState extends State<AddLaporKejadianMendesak> {
  // Form key for validation
  final _formKey = GlobalKey<FormState>();

  // Timer for updating current time
  Timer? _timer;

  // Notifications
  final FlutterLocalNotificationsPlugin flutterLocalNotificationsPlugin =
      FlutterLocalNotificationsPlugin();

  // User information
  String _currentUserName = '';
  String _currentUserNIM = '';

  // Form data
  final TextEditingController _judulController = TextEditingController();
  final TextEditingController _tanggalKejadianController =
      TextEditingController();
  final TextEditingController _lampiranLinkController = TextEditingController();

  // Category data
  int? _selectedCategoryId;
  List<Map<String, dynamic>> _categories = [];

  // Image data
  final ImagePicker _picker = ImagePicker();
  List<XFile> _selectedImages = [];

  // Agreement checkbox
  bool _isAgreementChecked = false;

  // Loading state
  bool _isLoading = false;

  // Error mapping
  Map<String, List<String>> _errors = {};

  // Theme colors
  final Color _primaryColor = Color(0xFF00A2EA); // Primary blue
  final Color _secondaryColor = Color(0xFFF78052); // Orange accent
  final Color _backgroundColor = Color(0xFFF9FAFC); // Light background
  final Color _surfaceColor = Colors.white; // Card/surface color
  final Color _textColor = Color(0xFF2D3748); // Dark text
  final Color _subTextColor = Color(0xFF718096); // Light text
  final Color _borderColor = Color(0xFFE2E8F0); // Border color
  final Color _errorColor = Color(0xFFE53E3E); // Error red
  final Color _successColor = Color(0xFF38A169); // Success green
  final Color _warningColor = Color(0xFFED8936); // Warning orange
  final Color _disabledColor = Color(0xFFEDF2F7); // Disabled field color

  @override
  void initState() {
    super.initState();
    _fetchCategories();
    _loadUserData();
    _initializeNotifications();

    // Initialize with current Indonesia time
    _updateIndonesiaTime();

    // Set a timer to update the time every second
    _timer = Timer.periodic(Duration(seconds: 1), (timer) {
      _updateIndonesiaTime();
    });
  }

  @override
  void dispose() {
    _timer?.cancel();
    _judulController.dispose();
    _tanggalKejadianController.dispose();
    _lampiranLinkController.dispose();
    super.dispose();
  }

  // Update the current time in Indonesia timezone (UTC+7)
  void _updateIndonesiaTime() {
    // Get current time in UTC
    final now = DateTime.now().toUtc();

    // Convert to Indonesia timezone (UTC+7)
    final jakartaTime = now.add(Duration(hours: 7));

    // Format time for display and API (YYYY-MM-DD HH:MM:SS)
    final formattedTime = DateFormat('yyyy-MM-dd HH:mm:ss').format(jakartaTime);

    // Update controller if it's different from the current value
    if (_tanggalKejadianController.text != formattedTime) {
      setState(() {
        _tanggalKejadianController.text = formattedTime;
      });
    }
  }

  Future<void> _initializeNotifications() async {
    // Initialize timezone
    tz_init.initializeTimeZones();

    // Initialize notification settings for Android
    const AndroidInitializationSettings initializationSettingsAndroid =
        AndroidInitializationSettings('@mipmap/ic_launcher');

    // Initialize notification settings for iOS
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

    // Initialize plugin
    await flutterLocalNotificationsPlugin.initialize(
      initializationSettings,
      onDidReceiveNotificationResponse:
          (NotificationResponse notificationResponse) async {
        // Handle notification tap
        if (notificationResponse.payload != null) {
          debugPrint('Notification payload: ${notificationResponse.payload}');
          // Navigate to specific screen or perform an action based on payload
        }
      },
    );

    // Request permission for iOS and Android 13+
    await flutterLocalNotificationsPlugin
        .resolvePlatformSpecificImplementation<
            AndroidFlutterLocalNotificationsPlugin>()
        ?.requestNotificationsPermission();
  }

  Future<void> _showNotification(String title, String body) async {
    // Define Android notification details
    AndroidNotificationDetails androidNotificationDetails =
        AndroidNotificationDetails(
      'laporan_channel_id',
      'Laporan Notifications',
      channelDescription: 'Notifications related to reports',
      importance: Importance.max,
      priority: Priority.high,
      ticker: 'ticker',
      enableVibration: true,
      icon: '@mipmap/ic_launcher',
      color: _primaryColor,
    );

    // Define iOS notification details
    const DarwinNotificationDetails darwinNotificationDetails =
        DarwinNotificationDetails(
      presentAlert: true,
      presentBadge: true,
      presentSound: true,
    );

    // Create platform-specific notification details
    NotificationDetails notificationDetails = NotificationDetails(
      android: androidNotificationDetails,
      iOS: darwinNotificationDetails,
    );

    // Show notification
    await flutterLocalNotificationsPlugin.show(
      0,
      title,
      body,
      notificationDetails,
      payload: 'laporan_submitted',
    );
  }

  Future<void> _loadUserData() async {
    try {
      final prefs = await SharedPreferences.getInstance();

      // Get username from shared preferences
      final username = prefs.getString('user_name');
      final nim = prefs.getString('user_nim');

      setState(() {
        _currentUserName = username ?? 'Unknown User';
        _currentUserNIM = nim ?? '';
      });

      print('Loaded user data: $_currentUserName, NIM: $_currentUserNIM');
    } catch (e) {
      print('Error loading user data: $e');
      setState(() {
        _currentUserName = 'Unknown User';
        _currentUserNIM = '';
      });
    }
  }

  Future<void> _fetchCategories() async {
    setState(() => _isLoading = true);

    try {
      final response = await http
          .get(Uri.parse('https://v3422040.mhs.d3tiuns.com/api/category'));

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
      } else {
        _setFallbackCategory();
      }
    } catch (e) {
      _setFallbackCategory();
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

  Future<void> _pickImages() async {
    try {
      final List<XFile> images = await _picker.pickMultiImage();
      if (images.isNotEmpty) {
        setState(() {
          _selectedImages.addAll(images);
        });
      }
    } catch (e) {
      _showSnackBar('Error saat memilih gambar: $e', isError: true);
    }
  }

  void _removeImage(int index) {
    setState(() {
      _selectedImages.removeAt(index);
    });
  }

  bool _validateForm() {
    _errors.clear();

    if (_judulController.text.isEmpty) {
      _errors['judul'] = ['Judul laporan harus diisi'];
    }

    if (_tanggalKejadianController.text.isEmpty) {
      _errors['tanggal_kejadian'] = ['Tanggal dan waktu kejadian harus diisi'];
    }

    if (_selectedImages.isEmpty) {
      _errors['image_path'] = ['Lampiran foto harus diisi'];
    }

    if (_lampiranLinkController.text.isEmpty) {
      _errors['lampiran_link'] = ['Lampiran link harus diisi'];
    } else if (!_lampiranLinkController.text.startsWith('http')) {
      _errors['lampiran_link'] = [
        'Link harus dimulai dengan http:// atau https://'
      ];
    }

    if (!_isAgreementChecked) {
      _errors['agreement'] = [
        'Anda harus menyetujui pernyataan untuk melanjutkan'
      ];
    }

    setState(() {});
    return _errors.isEmpty;
  }

  Future<void> _submitForm() async {
    if (!_validateForm()) {
      _showSnackBar('Form belum lengkap. Mohon periksa kembali.',
          isError: true);
      return;
    }

    setState(() => _isLoading = true);

    try {
      // Create multipart request
      final request = http.MultipartRequest(
        'POST',
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

      // User data
      request.fields['nama_pelapor'] = _currentUserName;
      request.fields['ni_pelapor'] = _currentUserNIM;
      request.fields['profesi'] = 'Mahasiswa';
      request.fields['jenis_kelamin'] = 'laki-laki';
      request.fields['umur_pelapor'] = '20-40';
      request.fields['lampiran_link'] = _lampiranLinkController.text;

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

      // Add images
      for (var i = 0; i < _selectedImages.length; i++) {
        final file = await http.MultipartFile.fromPath(
          'image_path[]',
          _selectedImages[i].path,
        );
        request.files.add(file);
      }

      // Send the request
      final response = await request.send();

      // Check response
      if (response.statusCode >= 200 && response.statusCode < 300) {
        // Success - Show notification
        await _showNotification(
          'Laporan Berhasil Dikirim',
          'Laporan kejadian mendesak "${_judulController.text}" telah berhasil dikirim',
        );

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

        _showErrorDialog('Terjadi kesalahan saat mengirim laporan');
      }
    } catch (e) {
      _showErrorDialog('Terjadi kesalahan: $e');
    } finally {
      setState(() => _isLoading = false);
    }
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
            SizedBox(width: 12),
            Expanded(child: Text(message)),
          ],
        ),
        backgroundColor: isError ? _errorColor : _primaryColor,
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
        margin: EdgeInsets.all(12),
        duration: Duration(seconds: 4),
      ),
    );
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
            padding: EdgeInsets.all(20),
            decoration: BoxDecoration(
              color: _surfaceColor,
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
                  'Laporan kejadian mendesak berhasil dikirim',
                  style: TextStyle(
                    fontSize: 16,
                    color: _subTextColor,
                  ),
                  textAlign: TextAlign.center,
                ),
                SizedBox(height: 24),
                ElevatedButton(
                  onPressed: () {
                    Navigator.of(context).pop();
                    Navigator.of(context).pop(); // Navigate back
                  },
                  style: ElevatedButton.styleFrom(
                    foregroundColor: Colors.white,
                    backgroundColor: _primaryColor,
                    padding: EdgeInsets.symmetric(horizontal: 40, vertical: 12),
                    elevation: 0,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(8),
                    ),
                  ),
                  child: Text(
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
            padding: EdgeInsets.all(20),
            decoration: BoxDecoration(
              color: _surfaceColor,
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
                  'Error!',
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
                    color: _subTextColor,
                  ),
                  textAlign: TextAlign.center,
                ),
                SizedBox(height: 24),
                ElevatedButton(
                  onPressed: () {
                    Navigator.of(context).pop();
                  },
                  style: ElevatedButton.styleFrom(
                    foregroundColor: Colors.white,
                    backgroundColor: _primaryColor,
                    padding: EdgeInsets.symmetric(horizontal: 40, vertical: 12),
                    elevation: 0,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(8),
                    ),
                  ),
                  child: Text(
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
        backgroundColor: _surfaceColor,
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
                  SizedBox(height: 16),
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
                    // Form header
                    _buildInfoBanner(),
                    SizedBox(height: 24),

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

                    // User Information Field
                    _buildUserInfoField(),

                    // Real-time Indonesia Time
                    _buildCurrentTimeField(),

                    // Lampiran Foto
                    _buildFormField(
                      label: 'Lampiran Foto',
                      isRequired: true,
                      errorText: _errors['image_path']?.first,
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          ElevatedButton.icon(
                            onPressed: _pickImages,
                            icon: Icon(Icons.photo_library),
                            label: Text('Pilih Foto'),
                            style: ElevatedButton.styleFrom(
                              foregroundColor: Colors.white,
                              backgroundColor: _primaryColor,
                              padding: EdgeInsets.symmetric(
                                  horizontal: 20, vertical: 12),
                              elevation: 0,
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(8),
                              ),
                            ),
                          ),
                          SizedBox(height: 8),
                          Row(
                            children: [
                              Icon(Icons.info_outline,
                                  size: 16, color: _subTextColor),
                              SizedBox(width: 8),
                              Expanded(
                                child: Text(
                                  'Anda dapat memilih beberapa foto sekaligus',
                                  style: TextStyle(
                                      color: _subTextColor, fontSize: 13),
                                ),
                              ),
                            ],
                          ),
                          SizedBox(height: 16),
                          _selectedImages.isNotEmpty
                              ? _buildImagePreviewList()
                              : Container(),
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
                          color: _disabledColor,
                          border: Border.all(color: _borderColor),
                        ),
                        padding:
                            EdgeInsets.symmetric(horizontal: 16, vertical: 16),
                        child: Row(
                          children: [
                            Icon(Icons.category_outlined,
                                color: _primaryColor, size: 20),
                            SizedBox(width: 12),
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

                    // Lampiran Link
                    _buildFormField(
                      label: 'Lampiran Link',
                      isRequired: true,
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          TextFormField(
                            controller: _lampiranLinkController,
                            decoration: _inputDecoration(
                              hintText: 'https://www.example.com',
                              errorText: _errors['lampiran_link']?.first,
                              prefixIcon: Icons.link,
                            ),
                            keyboardType: TextInputType.url,
                            style: TextStyle(fontSize: 15, color: _textColor),
                          ),
                          SizedBox(height: 8),
                          Padding(
                            padding: const EdgeInsets.only(left: 8),
                            child: Row(
                              children: [
                                Icon(Icons.info_outline,
                                    size: 14, color: _subTextColor),
                                SizedBox(width: 8),
                                Expanded(
                                  child: Text(
                                    'Masukkan URL yang valid, contoh: https://www.example.com',
                                    style: TextStyle(
                                        color: _subTextColor, fontSize: 12),
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ],
                      ),
                    ),

                    // Pernyataan
                    _buildSectionHeader('Pernyataan', Icons.gavel_outlined),

                    Container(
                      margin: EdgeInsets.only(bottom: 24),
                      padding: EdgeInsets.all(20),
                      decoration: BoxDecoration(
                        color: _surfaceColor,
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
                          _buildStatementItem(
                              '1. Segala informasi yang saya berikan dalam laporan ini adalah benar dan dapat dipertanggungjawabkan.'),
                          _buildStatementItem(
                              '2. Saya bersedia memberikan keterangan lebih lanjut apabila diperlukan untuk proses penanganan laporan.'),
                          _buildStatementItem(
                              '3. Saya memahami bahwa memberikan laporan palsu dapat dikenakan sanksi sesuai dengan peraturan yang berlaku.'),
                          SizedBox(height: 16),
                          Container(
                            padding: EdgeInsets.symmetric(
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
                                SizedBox(width: 12),
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
                                SizedBox(width: 8),
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
                              icon: Icon(Icons.arrow_back),
                              label: Text('Kembali'),
                              style: OutlinedButton.styleFrom(
                                foregroundColor: _subTextColor,
                                padding: EdgeInsets.symmetric(vertical: 16),
                                side: BorderSide(color: _borderColor),
                                shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(8),
                                ),
                              ),
                            ),
                          ),
                          SizedBox(width: 16),
                          Expanded(
                            flex: 2,
                            child: ElevatedButton.icon(
                              onPressed: _isLoading || !_isAgreementChecked
                                  ? null
                                  : _submitForm,
                              icon: _isLoading
                                  ? Container(
                                      width: 24,
                                      height: 24,
                                      padding: const EdgeInsets.all(2.0),
                                      child: CircularProgressIndicator(
                                        color: Colors.white,
                                        strokeWidth: 3,
                                      ),
                                    )
                                  : Icon(Icons.send),
                              label: Text(
                                  _isLoading ? 'Mengirim...' : 'Kirim Laporan'),
                              style: ElevatedButton.styleFrom(
                                foregroundColor: Colors.white,
                                backgroundColor: _primaryColor,
                                disabledForegroundColor:
                                    Colors.white.withOpacity(0.5),
                                disabledBackgroundColor:
                                    _primaryColor.withOpacity(0.5),
                                padding: EdgeInsets.symmetric(vertical: 16),
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

  // Widget for displaying the Indonesia time (constantly updating)
  Widget _buildCurrentTimeField() {
    return _buildFormField(
      label: 'Waktu Kejadian (WIB)',
      isRequired: true,
      child: Container(
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(8),
          border: Border.all(color: _primaryColor.withOpacity(0.5)),
          color: _primaryColor.withOpacity(0.05),
        ),
        padding: EdgeInsets.symmetric(horizontal: 16, vertical: 16),
        child: Row(
          children: [
            Icon(Icons.access_time, color: _primaryColor, size: 20),
            SizedBox(width: 12),
            Expanded(
              child: Text(
                _tanggalKejadianController.text,
                style: TextStyle(
                  fontSize: 15,
                  color: _textColor,
                  fontWeight: FontWeight.w500,
                ),
              ),
            ),
            Container(
              padding: EdgeInsets.symmetric(horizontal: 8, vertical: 4),
              decoration: BoxDecoration(
                color: _primaryColor.withOpacity(0.1),
                borderRadius: BorderRadius.circular(12),
              ),
              child: Row(
                children: [
                  Icon(Icons.sync, color: _primaryColor, size: 14),
                  SizedBox(width: 4),
                  Text(
                    'Real-time',
                    style: TextStyle(
                      fontSize: 12,
                      color: _primaryColor,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  // Widget for displaying the current user
  Widget _buildUserInfoField() {
    return _buildFormField(
      label: 'Pelapor',
      isRequired: true,
      child: Container(
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(8),
          border: Border.all(color: _borderColor),
          color: _disabledColor,
        ),
        padding: EdgeInsets.symmetric(horizontal: 16, vertical: 16),
        child: Row(
          children: [
            Icon(Icons.person, color: _primaryColor, size: 20),
            SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    _currentUserName,
                    style: TextStyle(
                      fontSize: 15,
                      color: _textColor,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                  if (_currentUserNIM.isNotEmpty)
                    Text(
                      _currentUserNIM,
                      style: TextStyle(
                        fontSize: 13,
                        color: _subTextColor,
                      ),
                    ),
                ],
              ),
            ),
            Icon(Icons.verified_user,
                color: _primaryColor.withOpacity(0.7), size: 16),
          ],
        ),
      ),
    );
  }

  Widget _buildInfoBanner() {
    return Container(
      width: double.infinity,
      padding: EdgeInsets.symmetric(vertical: 20, horizontal: 24),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(12),
        color: _warningColor.withOpacity(0.1),
        border: Border.all(
          color: _warningColor.withOpacity(0.3),
          width: 1,
        ),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(
            Icons.warning_amber_rounded,
            color: _warningColor,
            size: 24,
          ),
          SizedBox(width: 16),
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
                SizedBox(height: 8),
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

  Widget _buildImagePreviewList() {
    return Container(
      height: 120,
      child: ListView.builder(
        scrollDirection: Axis.horizontal,
        itemCount: _selectedImages.length,
        itemBuilder: (context, index) {
          return Stack(
            children: [
              Container(
                margin: EdgeInsets.only(right: 12),
                width: 120,
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(12),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withOpacity(0.05),
                      blurRadius: 5,
                      offset: Offset(0, 2),
                    ),
                  ],
                ),
                child: ClipRRect(
                  borderRadius: BorderRadius.circular(12),
                  child: Image.file(
                    File(_selectedImages[index].path),
                    fit: BoxFit.cover,
                  ),
                ),
              ),
              Positioned(
                top: 4,
                right: 16,
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
    );
  }

  Widget _buildStatementItem(String text) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 12.0),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(width: 12),
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
    IconData? suffixIcon,
  }) {
    return InputDecoration(
      hintText: hintText,
      hintStyle: TextStyle(color: Colors.grey.shade400, fontSize: 14),
      errorText: errorText,
      errorStyle: TextStyle(fontSize: 0, height: 0), // Hide default error text
      prefixIcon: prefixIcon != null
          ? Icon(prefixIcon, color: _primaryColor, size: 20)
          : null,
      suffixIcon: suffixIcon != null
          ? Icon(suffixIcon, color: _subTextColor, size: 20)
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
}
