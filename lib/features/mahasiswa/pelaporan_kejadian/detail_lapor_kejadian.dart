import 'package:flutter/material.dart';
import 'dart:convert';
import 'package:intl/intl.dart';
import 'package:intl/date_symbol_data_local.dart';
import 'package:pelaporan_d3ti/shared/services/token_manager.dart';
import 'package:shared_preferences/shared_preferences.dart';
import "package:pelaporan_d3ti/shared/services/api_service.dart";
import "package:pelaporan_d3ti/shared/data/models/laporan.dart";

class DetailLaporanPage extends StatefulWidget {
  final Laporan? laporan;
  final int id;

  const DetailLaporanPage({
    Key? key,
    this.laporan,
    required this.id,
  }) : super(key: key);

  @override
  _DetailLaporanPageState createState() => _DetailLaporanPageState();
}

class _DetailLaporanPageState extends State<DetailLaporanPage> {
  bool isLoading = true;
  bool isAdmin = true; // Set berdasarkan role user
  bool showFullImage = false;
  bool showTanggapanModal = false;
  bool isSavingTanggapan = false;
  String? error;
  Laporan? laporan;
  TextEditingController tanggapanController = TextEditingController();
  Map<int, String> categories = {};
  final ApiService _apiService = ApiService();
  String? currentUser;

  @override
  void initState() {
    super.initState();
    // Initialize laporan with the provided value if available
    laporan = widget.laporan;
    // Initialize date formatting for Indonesia locale
    initializeDateFormatting('id_ID', null).then((_) {
      _loadData();
    });

    // Get current user info
    _getCurrentUser();
  }

  Future<void> _getCurrentUser() async {
    try {
      // First attempt: Get token from TokenManager
      final token = await TokenManager.getToken();

      if (token != null && token.isNotEmpty) {
        // Parse the token to get user information
        final parts = token.split('.');
        if (parts.length >= 2) {
          String normalizedPayload = base64Url.normalize(parts[1]);
          final payloadJson = utf8.decode(base64Url.decode(normalizedPayload));
          final payload = json.decode(payloadJson);

          // Extract username from token payload
          currentUser =
              payload['username'] ?? payload['name'] ?? payload['email'];
        }
      }

      // Second attempt: If token method fails, try SharedPreferences
      if (currentUser == null || currentUser!.isEmpty) {
        final prefs = await SharedPreferences.getInstance();
        final userName = prefs.getString('user_name');

        if (userName != null && userName.isNotEmpty) {
          currentUser = userName;
          print("Current user set from SharedPreferences: $currentUser");
          return;
        }
      }

      // Last resort: Use hardcoded fallback
      if (currentUser == null || currentUser!.isEmpty) {
        currentUser = "miftahul01"; // Using the provided login from the prompt
        print("Using fallback user: $currentUser");
      } else {
        print("Current user set to: $currentUser");
      }
    } catch (e) {
      print('Error getting current user: $e');
      // Set default value in case of error
      currentUser = "miftahul01"; // Using the provided login from the prompt
      print("Error occurred, using fallback user: $currentUser");
    }
  }

  Future<void> _loadData() async {
    setState(() {
      isLoading = true;
      error = null;
    });

    try {
      // Pertama, ambil data kategori
      await _fetchCategories();

      // Kemudian ambil detail laporan berdasarkan ID
      await _fetchLaporanDetail();
    } catch (e) {
      setState(() {
        error = "Gagal memuat data: $e";
        isLoading = false;
      });
    }
  }

  Future<void> _fetchCategories() async {
    try {
      // Gunakan ApiService untuk mengambil kategori
      categories = await _apiService.getCategories();
    } catch (e) {
      print('Error fetching categories: $e');
      // Kita tidak perlu menghentikan loading jika kategori gagal dimuat
      // Kita bisa menampilkan detail laporan tanpa nama kategori
    }
  }

  Future<void> _fetchLaporanDetail() async {
    try {
      // Use the dedicated API method to get laporan by ID
      final fetchedLaporan = await _apiService.getLaporanById(widget.id);

      setState(() {
        laporan = fetchedLaporan;
        isLoading = false;
      });

      // Proses data tanggapan jika ada
      _processTanggapanData();
    } catch (e) {
      setState(() {
        // If we have a previous laporan object from the constructor, keep using it
        if (laporan == null) {
          error = "Gagal memuat detail laporan: $e";
        } else {
          _showErrorMessage("Gagal memperbarui detail terbaru: $e");
        }
        isLoading = false;
      });
    }
  }

  void _processTanggapanData() {
    if (laporan?.tanggapan == null) return;

    // Tangani tanggapan dalam format string
    if (laporan!.tanggapan is String) {
      final tanggapanStr = laporan!.tanggapan as String;

      // Coba parse jika kemungkinan JSON string
      if (tanggapanStr.startsWith('[') && tanggapanStr.endsWith(']')) {
        try {
          final parsed = json.decode(tanggapanStr);
          if (parsed is List) {
            laporan!.tanggapan = parsed;
          }
        } catch (e) {
          print('Tanggapan bukan JSON valid: $e');
        }
      }
    }
  }

  Future<void> saveTanggapan() async {
    if (tanggapanController.text.isEmpty || laporan == null) return;

    // Set loading state for tanggapan only
    setState(() {
      isSavingTanggapan = true;
    });

    try {
      // Get current date time using the local device time which should respect the device timezone
      // instead of manually adding 7 hours to UTC
      final now = DateTime.now();

      // Format to ensure we're getting the correct time
      print(
          "Current local time: ${DateFormat('yyyy-MM-dd HH:mm:ss').format(now)}");

      // Get current username, using the specified username from the context
      final username = currentUser ?? "miftahul01";

      // Persiapkan data tanggapan baru
      final newTanggapan = {
        'text': tanggapanController.text,
        'timestamp':
            now.toIso8601String(), // Using standard ISO format for storing
        'user': username // Use dynamic username
      };

      // Persiapkan array tanggapan
      List<dynamic> tanggapanArray = [];

      // Jika sudah ada tanggapan sebelumnya
      if (laporan!.tanggapan != null) {
        var existingTanggapan = laporan!.tanggapan;

        if (existingTanggapan is String && existingTanggapan.isNotEmpty) {
          // Konversi format lama (string) ke format baru (array)
          tanggapanArray.add({
            'text': existingTanggapan,
            'timestamp':
                laporan!.updatedAt?.toIso8601String() ?? now.toIso8601String(),
            'user': 'Admin'
          });
        } else if (existingTanggapan is List) {
          tanggapanArray = List<dynamic>.from(existingTanggapan);
        }
      }

      // Tambahkan tanggapan baru
      tanggapanArray.add(newTanggapan);

      // Use the API service to update tanggapan, passing the current status
      await _apiService.updateLaporanTanggapan(widget.id, tanggapanArray,
          status: laporan!.status ?? 'verified' // Pass the current status
          );

      // Update data lokal
      setState(() {
        laporan = laporan!.copyWith(tanggapan: tanggapanArray, updatedAt: now);
        tanggapanController.clear();
        showTanggapanModal = false;
      });

      _showSuccessMessage('Tanggapan berhasil disimpan');
    } catch (e) {
      _showErrorMessage('Gagal menyimpan tanggapan: $e');
    } finally {
      setState(() {
        isSavingTanggapan = false;
      });
    }
  }

  Future<void> finishReport() async {
    if (laporan == null) return;

    try {
      // Tampilkan konfirmasi
      final bool? confirm = await showDialog<bool>(
        context: context,
        builder: (context) => Dialog(
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(16),
          ),
          elevation: 0,
          backgroundColor: Colors.transparent,
          child: Container(
            padding: EdgeInsets.all(20),
            decoration: BoxDecoration(
              color: Colors.white,
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
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Container(
                      padding: EdgeInsets.all(8),
                      decoration: BoxDecoration(
                        color: Colors.green.withOpacity(0.1),
                        shape: BoxShape.circle,
                      ),
                      child: Icon(
                        Icons.check_circle_outline,
                        color: Colors.green,
                        size: 24,
                      ),
                    ),
                    SizedBox(width: 12),
                    Expanded(
                      child: Text(
                        'Tutup Kasus Laporan',
                        style: TextStyle(
                          fontSize: 20,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ),
                  ],
                ),
                SizedBox(height: 16),
                Text(
                  'Apakah Anda yakin ingin menutup dan menyelesaikan kasus laporan ini?',
                  style: TextStyle(fontSize: 16),
                ),
                SizedBox(height: 24),
                Row(
                  mainAxisAlignment: MainAxisAlignment.end,
                  children: [
                    TextButton(
                      onPressed: () => Navigator.pop(context, false),
                      child: Text(
                        'Batal',
                        style: TextStyle(
                          color: Colors.grey[700],
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ),
                    SizedBox(width: 8),
                    ElevatedButton(
                      onPressed: () => Navigator.pop(context, true),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Colors.green,
                        foregroundColor: Colors.white,
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(8),
                        ),
                        elevation: 0,
                        padding:
                            EdgeInsets.symmetric(horizontal: 16, vertical: 10),
                      ),
                      child: Text(
                        'Ya, Selesaikan!',
                        style: TextStyle(fontWeight: FontWeight.bold),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ),
      );

      if (confirm != true) return;

      setState(() {
        isLoading = true;
      });

      // Get current date time using device's local time
      final now = DateTime.now();

      // Call the API to update status
      await _apiService.updateLaporanStatus(widget.id, 'finished');

      // Update local status
      setState(() {
        laporan = laporan!.copyWith(status: 'finished', updatedAt: now);
        isLoading = false;
      });

      _showSuccessMessage('Laporan berhasil ditutup dan selesai');
    } catch (e) {
      setState(() {
        isLoading = false;
      });
      _showErrorMessage('Gagal menyelesaikan laporan: $e');
    }
  }

  void _showSuccessMessage(String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Container(
          padding: EdgeInsets.symmetric(vertical: 8),
          child: Row(
            children: [
              Icon(Icons.check_circle, color: Colors.white),
              SizedBox(width: 12),
              Expanded(child: Text(message)),
            ],
          ),
        ),
        backgroundColor: Colors.green.shade700,
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
        margin: EdgeInsets.all(16),
        elevation: 4,
        duration: Duration(seconds: 3),
      ),
    );
  }

  void _showErrorMessage(String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Container(
          padding: EdgeInsets.symmetric(vertical: 8),
          child: Row(
            children: [
              Icon(Icons.error_outline, color: Colors.white),
              SizedBox(width: 12),
              Expanded(child: Text(message)),
            ],
          ),
        ),
        backgroundColor: Colors.red.shade700,
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
        margin: EdgeInsets.all(16),
        elevation: 4,
      ),
    );
  }

  String formatDate(String? dateString) {
    if (dateString == null || dateString.isEmpty) return '-';

    try {
      DateTime date;
      if (dateString.contains(' ') && !dateString.contains('T')) {
        date = DateTime.parse(dateString.replaceAll(' ', 'T'));
      } else {
        date = DateTime.parse(dateString);
      }

      // Use device's local timezone settings instead of manual adjustment
      // The toLocal() method will convert to the device's timezone
      final localDate = date.toLocal();

      // Using dd-MM-yyyy HH:mm:ss format for dates in Status Laporan and tanggapan
      return DateFormat('dd-MM-yyyy HH:mm:ss').format(localDate);
    } catch (e) {
      print('Error formatting date: $e for string: $dateString');
      return dateString;
    }
  }

  String formatDateKejadian(String? dateString) {
    if (dateString == null || dateString.isEmpty) return '-';

    try {
      DateTime date;
      if (dateString.contains(' ') && !dateString.contains('T')) {
        date = DateTime.parse(dateString.replaceAll(' ', 'T'));
      } else {
        date = DateTime.parse(dateString);
      }

      // Ensure we're adding the +7 GMT adjustment for Indonesia timezone
      final indonesiaDate = date.toLocal();

      // Using dd MMMM yyyy, HH:mm format for kejadian dates
      return DateFormat('dd MMMM yyyy, HH:mm', 'id_ID').format(indonesiaDate);
    } catch (e) {
      return dateString;
    }
  }

  String formatStatus(String status) {
    final Map<String, String> statusMap = {
      'unverified': 'Belum Diverifikasi',
      'verified': 'Diproses',
      'rejected': 'Ditolak',
      'finished': 'Laporan Selesai',
    };

    return statusMap[status] ?? status;
  }

  Color getStatusColor(String status) {
    switch (status) {
      case 'unverified':
        return Colors.orange;
      case 'verified':
        return Colors.blue;
      case 'rejected':
        return Colors.red;
      case 'finished':
        return Colors.green;
      default:
        return Colors.grey;
    }
  }

  String getCategoryName(int? categoryId) {
    if (categoryId == null) return '-';
    return categories[categoryId] ?? 'Kategori $categoryId';
  }

  bool get hasTanggapan {
    if (laporan?.tanggapan == null) return false;
    var tanggapan = laporan!.tanggapan;

    if (tanggapan is List) {
      return tanggapan.isNotEmpty;
    }

    return tanggapan is String && tanggapan.toString().trim().isNotEmpty;
  }

  @override
  Widget build(BuildContext context) {
    final ThemeData theme = Theme.of(context);

    return Scaffold(
      backgroundColor: Colors.grey.shade50,
      appBar: AppBar(
        elevation: 0,
        backgroundColor: Colors.white,
        title: Text(
          'Detail Laporan Kejadian',
          style: TextStyle(
            color: Colors.black87,
            fontWeight: FontWeight.w600,
          ),
        ),
        iconTheme: IconThemeData(color: Colors.black87),
        leading: IconButton(
          icon: Icon(Icons.arrow_back),
          onPressed: () {
            Navigator.pushReplacementNamed(context, '/reports');
          },
        ),
      ),
      body: Stack(
        children: [
          // Main content
          isLoading
              ? Center(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      CircularProgressIndicator(
                        valueColor: AlwaysStoppedAnimation<Color>(
                          theme.primaryColor,
                        ),
                      ),
                      SizedBox(height: 16),
                      Text(
                        'Memuat data...',
                        style: TextStyle(
                          color: Colors.grey[600],
                          fontSize: 16,
                        ),
                      ),
                    ],
                  ),
                )
              : error != null && laporan == null
                  ? Center(
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Icon(
                            Icons.error_outline,
                            size: 64,
                            color: Colors.red.shade400,
                          ),
                          SizedBox(height: 16),
                          Text(
                            error!,
                            style: TextStyle(
                              color: Colors.grey[700],
                              fontSize: 16,
                            ),
                          ),
                          SizedBox(height: 24),
                          ElevatedButton.icon(
                            onPressed: _loadData,
                            icon: Icon(Icons.refresh),
                            label: Text('Coba Lagi'),
                            style: ElevatedButton.styleFrom(
                              backgroundColor: theme.primaryColor,
                              foregroundColor: Colors.white,
                              padding: EdgeInsets.symmetric(
                                horizontal: 24,
                                vertical: 12,
                              ),
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(8),
                              ),
                            ),
                          ),
                        ],
                      ),
                    )
                  : laporan == null
                      ? Center(
                          child: Text(
                            'Data laporan tidak ditemukan',
                            style: TextStyle(
                              color: Colors.grey[700],
                              fontSize: 16,
                            ),
                          ),
                        )
                      : _buildDetailContent(),

          // Show a non-blocking loading indicator for saving tanggapan only
          if (isSavingTanggapan)
            Positioned(
              top: 16,
              right: 16,
              child: Container(
                padding: EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(30),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black12,
                      blurRadius: 10,
                      spreadRadius: 1,
                    ),
                  ],
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    SizedBox(
                      width: 20,
                      height: 20,
                      child: CircularProgressIndicator(
                        strokeWidth: 2,
                        valueColor:
                            AlwaysStoppedAnimation<Color>(theme.primaryColor),
                      ),
                    ),
                    SizedBox(width: 12),
                    Text(
                      'Menyimpan tanggapan...',
                      style: TextStyle(
                        color: Colors.grey[800],
                        fontSize: 14,
                        fontWeight: FontWeight.w500,
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

  Widget _buildDetailContent() {
    return SingleChildScrollView(
      physics: BouncingScrollPhysics(),
      child: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Header section
            _buildHeaderCard(),

            SizedBox(height: 20),

            // Card for Information
            _buildCard(
              title: 'Informasi Kejadian',
              icon: Icons.info_outline,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  if (laporan!.categoryId != null)
                    Container(
                      margin: EdgeInsets.only(bottom: 16),
                      padding:
                          EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                      decoration: BoxDecoration(
                        color: Colors.blue.withOpacity(0.08),
                        borderRadius: BorderRadius.circular(20),
                        border: Border.all(
                          color: Colors.blue.withOpacity(0.3),
                          width: 1,
                        ),
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(Icons.label, size: 16, color: Colors.blue),
                          SizedBox(width: 6),
                          Text(
                            getCategoryName(laporan!.categoryId),
                            style: TextStyle(
                              color: Colors.blue,
                              fontWeight: FontWeight.w500,
                            ),
                          ),
                        ],
                      ),
                    ),
                  _buildInfoGrid([
                    {
                      'label': 'Tanggal dan Waktu Kejadian',
                      'value': formatDateKejadian(laporan!.tanggalKejadian),
                    },
                    {
                      'label': 'Kategori Kejadian',
                      'value': getCategoryName(laporan!.categoryId) ??
                          laporan!.jenisKejadian ??
                          '-',
                    },
                  ]),
                ],
              ),
            ),

            SizedBox(height: 20),

            // Card for Details
            _buildCard(
              title: 'Detail Kejadian',
              icon: Icons.description_outlined,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  if (laporan!.judul != null)
                    Padding(
                      padding: const EdgeInsets.only(bottom: 12.0),
                      child: Text(
                        laporan!.judul!,
                        style: TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.bold,
                          color: Colors.black87,
                        ),
                      ),
                    ),
                  Text(
                    laporan!.deskripsi ?? laporan!.deskripsiKejadian ?? '-',
                    style: TextStyle(
                      height: 1.5,
                      fontSize: 15,
                      color: Colors.black87,
                    ),
                  ),
                  if (laporan!.imagePath != null ||
                      laporan!.fotoKejadian != null)
                    Padding(
                      padding: const EdgeInsets.only(top: 24.0),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            children: [
                              Icon(Icons.photo_outlined,
                                  size: 18, color: Colors.grey[700]),
                              SizedBox(width: 8),
                              Text(
                                'Foto Kejadian',
                                style: TextStyle(
                                  fontSize: 16,
                                  fontWeight: FontWeight.bold,
                                  color: Colors.grey[800],
                                ),
                              ),
                            ],
                          ),
                          SizedBox(height: 12),
                          Container(
                            decoration: BoxDecoration(
                              borderRadius: BorderRadius.circular(12),
                              boxShadow: [
                                BoxShadow(
                                  color: Colors.black.withOpacity(0.08),
                                  blurRadius: 15,
                                  spreadRadius: 1,
                                  offset: Offset(0, 5),
                                ),
                              ],
                            ),
                            child: ClipRRect(
                              borderRadius: BorderRadius.circular(12),
                              child: GestureDetector(
                                onTap: () {
                                  setState(() {
                                    showFullImage = true;
                                  });
                                  // Show dialog with full image
                                  showDialog(
                                    context: context,
                                    builder: (context) => Dialog(
                                      backgroundColor: Colors.transparent,
                                      elevation: 0,
                                      insetPadding: EdgeInsets.all(16),
                                      child: Column(
                                        mainAxisSize: MainAxisSize.min,
                                        children: [
                                          Stack(
                                            alignment: Alignment.topRight,
                                            children: [
                                              ClipRRect(
                                                borderRadius:
                                                    BorderRadius.circular(8),
                                                child: Image.network(
                                                  _getImageUrl(
                                                      laporan!.imagePath,
                                                      laporan!.fotoKejadian),
                                                  fit: BoxFit.contain,
                                                  errorBuilder: (context, error,
                                                      stackTrace) {
                                                    return Container(
                                                      padding:
                                                          EdgeInsets.all(20),
                                                      color: Colors.grey[200],
                                                      child: Icon(
                                                        Icons.broken_image,
                                                        size: 48,
                                                        color: Colors.grey[500],
                                                      ),
                                                    );
                                                  },
                                                ),
                                              ),
                                              Material(
                                                color: Colors.transparent,
                                                child: Padding(
                                                  padding:
                                                      const EdgeInsets.all(8.0),
                                                  child: Container(
                                                    decoration: BoxDecoration(
                                                      shape: BoxShape.circle,
                                                      color: Colors.black
                                                          .withOpacity(0.5),
                                                    ),
                                                    child: IconButton(
                                                      icon: Icon(
                                                        Icons.close,
                                                        color: Colors.white,
                                                      ),
                                                      onPressed: () {
                                                        Navigator.pop(context);
                                                      },
                                                    ),
                                                  ),
                                                ),
                                              ),
                                            ],
                                          ),
                                        ],
                                      ),
                                    ),
                                  );
                                },
                                child: Container(
                                  constraints: BoxConstraints(
                                    maxHeight: 240,
                                  ),
                                  width: double.infinity,
                                  child: Image.network(
                                    _getImageUrl(laporan!.imagePath,
                                        laporan!.fotoKejadian),
                                    fit: BoxFit.cover,
                                    errorBuilder: (context, error, stackTrace) {
                                      return Container(
                                        height: 200,
                                        color: Colors.grey[200],
                                        child: Center(
                                          child: Column(
                                            mainAxisAlignment:
                                                MainAxisAlignment.center,
                                            children: [
                                              Icon(
                                                Icons.broken_image,
                                                size: 48,
                                                color: Colors.grey[500],
                                              ),
                                              SizedBox(height: 16),
                                              Text(
                                                'Gambar tidak dapat dimuat',
                                                style: TextStyle(
                                                  color: Colors.grey[700],
                                                ),
                                              ),
                                            ],
                                          ),
                                        ),
                                      );
                                    },
                                  ),
                                ),
                              ),
                            ),
                          ),
                          SizedBox(height: 8),
                          Center(
                            child: Text(
                              'Klik untuk memperbesar gambar',
                              style: TextStyle(
                                fontSize: 13,
                                color: Colors.grey[600],
                                fontStyle: FontStyle.italic,
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                ],
              ),
            ),

            SizedBox(height: 20),

            // Card for Reporter
            _buildCard(
              title: 'Informasi Pelapor',
              icon: Icons.person_outline,
              child: _buildInfoGrid([
                {
                  'label': 'Nama',
                  'value': laporan!.namaPelapor ?? '-',
                },
                {
                  'label': 'NI Pelapor',
                  'value': laporan!.niPelapor ?? '-',
                },
                {
                  'label': 'Email',
                  'value': laporan!.email ?? laporan!.emailPelapor ?? '-',
                },
                {
                  'label': 'Telepon',
                  'value':
                      laporan!.nomorTelepon ?? laporan!.teleponPelapor ?? '-',
                },
                {
                  'label': 'Profesi',
                  'value': laporan!.profesi ?? '-',
                },
                {
                  'label': 'Jenis Kelamin',
                  'value': laporan!.jenisKelamin ?? '-',
                },
                {
                  'label': 'Kelompok Umur',
                  'value': laporan!.umurPelapor ?? '-',
                },
              ]),
            ),

            SizedBox(height: 20),

            // Card for Status
            _buildCard(
              title: 'Status Laporan',
              icon: Icons.event_note_outlined,
              child: _buildInfoGrid([
                {
                  'label': 'Status',
                  'value': formatStatus(laporan!.status ?? 'unverified'),
                  'widget': Container(
                    padding: EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                    decoration: BoxDecoration(
                      color: getStatusColor(laporan!.status ?? 'unverified')
                          .withOpacity(0.12),
                      borderRadius: BorderRadius.circular(20),
                      border: Border.all(
                        color: getStatusColor(laporan!.status ?? 'unverified')
                            .withOpacity(0.3),
                        width: 1,
                      ),
                    ),
                    child: Text(
                      formatStatus(laporan!.status ?? 'unverified'),
                      style: TextStyle(
                        color: getStatusColor(laporan!.status ?? 'unverified'),
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),
                },
                {
                  'label': 'Tanggal Laporan',
                  'value': formatDate(laporan!.createdAt?.toIso8601String()),
                },
                {
                  'label': 'Terakhir Diperbarui',
                  'value': formatDate(laporan!.updatedAt?.toIso8601String()),
                },
              ]),
            ),

            // Additional bukti pelanggaran section if available
            if (laporan!.buktiPelanggaran != null &&
                laporan!.buktiPelanggaran!.isNotEmpty) ...[
              SizedBox(height: 20),
              _buildCard(
                title: 'Bukti Pelanggaran',
                icon: Icons.assignment_outlined,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: laporan!.buktiPelanggaran!.map((bukti) {
                    return Container(
                      margin: EdgeInsets.only(bottom: 8),
                      padding:
                          EdgeInsets.symmetric(vertical: 8, horizontal: 12),
                      decoration: BoxDecoration(
                        color: Colors.green.withOpacity(0.05),
                        borderRadius: BorderRadius.circular(8),
                        border: Border.all(
                          color: Colors.green.withOpacity(0.2),
                        ),
                      ),
                      child: Row(
                        children: [
                          Icon(Icons.check_circle_outline,
                              color: Colors.green, size: 18),
                          SizedBox(width: 12),
                          Expanded(
                            child: Text(
                              bukti,
                              style: TextStyle(
                                color: Colors.green.shade800,
                              ),
                            ),
                          ),
                        ],
                      ),
                    );
                  }).toList(),
                ),
              ),
            ],

            // Tanggapan section
            if (hasTanggapan) ...[
              SizedBox(height: 20),
              _buildCard(
                title: 'Tanggapan',
                icon: Icons.comment_outlined,
                child: _buildTanggapanContent(laporan!.tanggapan),
              ),
            ],

            // Admin buttons
            if (isAdmin) ...[
              SizedBox(height: 24),
              _buildActionButtons(),
            ],

            SizedBox(height: 24),
          ],
        ),
      ),
    );
  }

  Widget _buildHeaderCard() {
    return Container(
      width: double.infinity,
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.05),
            blurRadius: 15,
            spreadRadius: 1,
            offset: Offset(0, 5),
          ),
        ],
      ),
      child: Padding(
        padding: const EdgeInsets.all(20.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Container(
                  padding: EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: Colors.blue.withOpacity(0.1),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Icon(
                    Icons.article_outlined,
                    color: Colors.blue,
                    size: 28,
                  ),
                ),
                SizedBox(width: 16),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Detail Laporan Kejadian',
                        style: TextStyle(
                          fontSize: 20,
                          fontWeight: FontWeight.bold,
                          color: Colors.black87,
                        ),
                      ),
                      SizedBox(height: 8),
                      // Status badge added here - between title and report number
                      Container(
                        padding:
                            EdgeInsets.symmetric(horizontal: 14, vertical: 6),
                        decoration: BoxDecoration(
                          color: getStatusColor(laporan!.status ?? 'unverified')
                              .withOpacity(0.12),
                          borderRadius: BorderRadius.circular(20),
                          border: Border.all(
                            color:
                                getStatusColor(laporan!.status ?? 'unverified')
                                    .withOpacity(0.3),
                            width: 1,
                          ),
                        ),
                        child: Text(
                          formatStatus(laporan!.status ?? 'unverified'),
                          style: TextStyle(
                            color:
                                getStatusColor(laporan!.status ?? 'unverified'),
                            fontWeight: FontWeight.bold,
                            fontSize: 13,
                          ),
                        ),
                      ),
                      SizedBox(height: 8),
                      Text(
                        laporan!.nomorLaporan ?? 'No. Laporan tidak tersedia',
                        style: TextStyle(
                          color: Colors.grey[700],
                          fontSize: 14,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildActionButtons() {
    return Row(
      children: [
        if (laporan!.status != 'finished')
          Expanded(
            child: ElevatedButton.icon(
              icon: Icon(Icons.comment_outlined),
              label: Text('Tambah Tanggapan'),
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.blue.shade50,
                foregroundColor: Colors.blue.shade800,
                elevation: 0,
                padding: EdgeInsets.symmetric(vertical: 14),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                  side: BorderSide(color: Colors.blue.shade200),
                ),
              ),
              onPressed: () {
                setState(() {
                  showTanggapanModal = true;
                });

                // Show bottom sheet for adding tanggapan
                showModalBottomSheet(
                  context: context,
                  isScrollControlled: true,
                  backgroundColor: Colors.transparent,
                  builder: (context) {
                    return StatefulBuilder(
                      builder: (context, setState) {
                        return Container(
                          decoration: BoxDecoration(
                            color: Colors.white,
                            borderRadius: BorderRadius.only(
                              topLeft: Radius.circular(24),
                              topRight: Radius.circular(24),
                            ),
                            boxShadow: [
                              BoxShadow(
                                color: Colors.black.withOpacity(0.1),
                                blurRadius: 10,
                                offset: Offset(0, -5),
                              ),
                            ],
                          ),
                          padding: EdgeInsets.only(
                            bottom: MediaQuery.of(context).viewInsets.bottom,
                            left: 20,
                            right: 20,
                            top: 20,
                          ),
                          child: Column(
                            mainAxisSize: MainAxisSize.min,
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Center(
                                child: Container(
                                  width: 40,
                                  height: 4,
                                  decoration: BoxDecoration(
                                    color: Colors.grey[300],
                                    borderRadius: BorderRadius.circular(2),
                                  ),
                                ),
                              ),
                              SizedBox(height: 20),
                              Row(
                                children: [
                                  Container(
                                    padding: EdgeInsets.all(10),
                                    decoration: BoxDecoration(
                                      color: Colors.blue.withOpacity(0.1),
                                      borderRadius: BorderRadius.circular(10),
                                    ),
                                    child: Icon(
                                      Icons.comment_outlined,
                                      color: Colors.blue,
                                      size: 20,
                                    ),
                                  ),
                                  SizedBox(width: 12),
                                  Expanded(
                                    child: Text(
                                      'Tambah Tanggapan',
                                      style: TextStyle(
                                        fontSize: 18,
                                        fontWeight: FontWeight.bold,
                                        color: Colors.grey[800],
                                      ),
                                    ),
                                  ),
                                  IconButton(
                                    icon: Icon(Icons.close),
                                    onPressed: () {
                                      Navigator.pop(context);
                                    },
                                    color: Colors.grey[600],
                                  ),
                                ],
                              ),
                              SizedBox(height: 20),
                              Container(
                                padding: EdgeInsets.all(2),
                                decoration: BoxDecoration(
                                  borderRadius: BorderRadius.circular(12),
                                  border: Border.all(
                                    color: Colors.grey[300]!,
                                    width: 1,
                                  ),
                                ),
                                child: TextField(
                                  controller: tanggapanController,
                                  decoration: InputDecoration(
                                    hintText:
                                        'Masukkan tanggapan Anda di sini...',
                                    hintStyle: TextStyle(
                                      color: Colors.grey[400],
                                      fontSize: 15,
                                    ),
                                    border: OutlineInputBorder(
                                      borderSide: BorderSide.none,
                                      borderRadius: BorderRadius.circular(8),
                                    ),
                                    filled: true,
                                    fillColor: Colors.grey[50],
                                    contentPadding: EdgeInsets.all(16),
                                  ),
                                  style: TextStyle(
                                    fontSize: 15,
                                    color: Colors.black87,
                                    height: 1.5,
                                  ),
                                  maxLines: 5,
                                ),
                              ),
                              SizedBox(height: 24),
                              Row(
                                mainAxisAlignment: MainAxisAlignment.end,
                                children: [
                                  TextButton(
                                    onPressed: () {
                                      Navigator.pop(context);
                                    },
                                    style: TextButton.styleFrom(
                                      padding: EdgeInsets.symmetric(
                                        horizontal: 16,
                                        vertical: 12,
                                      ),
                                      shape: RoundedRectangleBorder(
                                        borderRadius: BorderRadius.circular(8),
                                      ),
                                    ),
                                    child: Text(
                                      'Batal',
                                      style: TextStyle(
                                        color: Colors.grey[700],
                                        fontWeight: FontWeight.w600,
                                      ),
                                    ),
                                  ),
                                  SizedBox(width: 12),
                                  ElevatedButton(
                                    onPressed: () {
                                      Navigator.pop(context);
                                      saveTanggapan();
                                    },
                                    style: ElevatedButton.styleFrom(
                                      backgroundColor: Colors.blue,
                                      foregroundColor: Colors.white,
                                      padding: EdgeInsets.symmetric(
                                        horizontal: 20,
                                        vertical: 12,
                                      ),
                                      shape: RoundedRectangleBorder(
                                        borderRadius: BorderRadius.circular(8),
                                      ),
                                      elevation: 0,
                                    ),
                                    child: Text(
                                      'Simpan Tanggapan',
                                      style: TextStyle(
                                        fontWeight: FontWeight.bold,
                                      ),
                                    ),
                                  ),
                                ],
                              ),
                              SizedBox(height: 20),
                            ],
                          ),
                        );
                      },
                    );
                  },
                );
              },
            ),
          ),
        SizedBox(width: 12),
        if (laporan!.status != 'finished' && laporan!.status != 'unverified')
          Expanded(
            child: ElevatedButton.icon(
              icon: Icon(Icons.check_circle_outline),
              label: Text('Tutup Laporan'),
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.green.shade500,
                foregroundColor: Colors.white,
                elevation: 0,
                padding: EdgeInsets.symmetric(vertical: 14),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
              ),
              onPressed: finishReport,
            ),
          ),
      ],
    );
  }

  String _getImageUrl(dynamic imagePath, String? fotoKejadian) {
    final String baseUrl =
        // 'http://pelaporan-d3ti.my.id/Backend-Port/backend/engine/public/storage/laporan/';
        'https://v3422040.mhs.d3tiuns.com/Backend-Port/backend/engine/public/storage/laporan/';

    // Handle imagePath if it's a List<String>
    String? image;
    if (imagePath is List && imagePath.isNotEmpty) {
      image = imagePath[0].toString();
    } else if (imagePath is String) {
      image = imagePath;
    } else {
      image = fotoKejadian;
    }

    if (image == null) return '';

    // If it contains a comma, it might be a list of images
    if (image.contains(',')) {
      // Just use the first image for display
      image = image.split(',').first.trim();
    }

    // Jika sudah URL lengkap
    if (image.startsWith('http')) {
      return image;
    }

    // Jika path relatif
    return baseUrl + image;
  }

  Widget _buildCard({
    required String title,
    required Widget child,
    IconData? icon,
  }) {
    return Container(
      width: double.infinity,
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.05),
            blurRadius: 15,
            spreadRadius: 1,
            offset: Offset(0, 5),
          ),
        ],
      ),
      child: Padding(
        padding: const EdgeInsets.all(20.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                if (icon != null) ...[
                  Container(
                    padding: EdgeInsets.all(8),
                    decoration: BoxDecoration(
                      color: Colors.blue.withOpacity(0.08),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Icon(icon, size: 18, color: Colors.blue.shade700),
                  ),
                  SizedBox(width: 12),
                ],
                Text(
                  title,
                  style: TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.bold,
                    color: Colors.grey[800],
                  ),
                ),
              ],
            ),
            Divider(
              height: 32,
              thickness: 1,
              color: Colors.grey[100],
            ),
            child,
          ],
        ),
      ),
    );
  }

  Widget _buildInfoGrid(List<Map<String, dynamic>> items) {
    return Wrap(
      spacing: 24,
      runSpacing: 20,
      children: items.map((item) {
        return SizedBox(
          width: MediaQuery.of(context).size.width > 600
              ? (MediaQuery.of(context).size.width - 120) /
                  2 // 2 columns for larger screens
              : double.infinity, // Full width for smaller screens
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                item['label'],
                style: TextStyle(
                  color: Colors.grey[600],
                  fontSize: 14,
                ),
              ),
              SizedBox(height: 6),
              if (item['widget'] != null)
                item['widget']
              else
                Text(
                  item['value'] ?? '-',
                  style: TextStyle(
                    fontWeight: FontWeight.w500,
                    fontSize: 15,
                    color: Colors.grey[800],
                  ),
                ),
            ],
          ),
        );
      }).toList(),
    );
  }

  Widget _buildTanggapanContent(dynamic tanggapan) {
    if (tanggapan is String) {
      // Old format: string
      return Container(
        padding: EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: Colors.grey.shade50,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: Colors.grey.shade200),
        ),
        child: Text(
          tanggapan,
          style: TextStyle(
            height: 1.5,
            fontSize: 15,
          ),
        ),
      );
    } else if (tanggapan is List) {
      // New format: array of objects
      return Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: List.generate(
          tanggapan.length,
          (index) {
            final item = tanggapan[index];
            return Container(
              margin: EdgeInsets.only(
                  bottom: index < tanggapan.length - 1 ? 16 : 0),
              decoration: BoxDecoration(
                color: Colors.grey.shade50,
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: Colors.blue.shade100),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Container(
                    padding: EdgeInsets.symmetric(horizontal: 16, vertical: 10),
                    decoration: BoxDecoration(
                      color: Colors.blue.shade50,
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
                            Container(
                              padding: EdgeInsets.all(6),
                              decoration: BoxDecoration(
                                color: Colors.white,
                                shape: BoxShape.circle,
                                border: Border.all(color: Colors.blue.shade200),
                              ),
                              child: Icon(
                                Icons.person_outline,
                                color: Colors.blue.shade700,
                                size: 14,
                              ),
                            ),
                            SizedBox(width: 8),
                            Text(
                              item['user'] ?? 'Admin',
                              style: TextStyle(
                                fontWeight: FontWeight.bold,
                                color: Colors.blue.shade800,
                              ),
                            ),
                          ],
                        ),
                        Row(
                          children: [
                            Icon(
                              Icons.access_time,
                              size: 14,
                              color: Colors.grey[600],
                            ),
                            SizedBox(width: 4),
                            Text(
                              formatDate(item['timestamp']),
                              style: TextStyle(
                                fontSize: 12,
                                color: Colors.grey[700],
                              ),
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
                  Container(
                    padding: EdgeInsets.all(16),
                    child: Text(
                      item['text'] ?? '',
                      style: TextStyle(
                        height: 1.5,
                        fontSize: 15,
                        color: Colors.grey[800],
                      ),
                    ),
                  ),
                ],
              ),
            );
          },
        ),
      );
    }

    return Container(
      padding: EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.grey.shade100,
        borderRadius: BorderRadius.circular(12),
      ),
      child: Center(
        child: Text(
          'Tidak ada tanggapan',
          style: TextStyle(
            fontStyle: FontStyle.italic,
            color: Colors.grey[600],
          ),
        ),
      ),
    );
  }
}
