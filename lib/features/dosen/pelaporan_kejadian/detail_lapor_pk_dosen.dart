import 'package:flutter/material.dart';
import 'dart:convert';
import 'package:intl/intl.dart';
import 'package:intl/date_symbol_data_local.dart';
import 'package:pelaporan_d3ti/shared/services/token_manager.dart';
import 'package:shared_preferences/shared_preferences.dart';
import "package:pelaporan_d3ti/shared/services/api_service.dart";
import "package:pelaporan_d3ti/shared/data/models/laporan.dart";

class DetailLaporanPKDosen extends StatefulWidget {
  final Laporan? laporan;
  final int id;

  const DetailLaporanPKDosen({
    Key? key,
    this.laporan,
    required this.id,
  }) : super(key: key);

  @override
  _DetailLaporanPKDosenState createState() => _DetailLaporanPKDosenState();
}

class _DetailLaporanPKDosenState extends State<DetailLaporanPKDosen> {
  bool isLoading = true;
  bool isAdmin = false; // Set to false for dosen view
  bool showFullImage = false;
  bool showTanggapanModal = false;
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

  // Improved version that also checks SharedPreferences
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

          if (currentUser != null) {
            print("Current user set from token: $currentUser");
            return;
          }
        }
      }

      // Second attempt: If token method fails, try SharedPreferences
      final prefs = await SharedPreferences.getInstance();
      final userName = prefs.getString('user_name');

      if (userName != null && userName.isNotEmpty) {
        currentUser = userName;
        print("Current user set from SharedPreferences: $currentUser");
        return;
      }

      // Last resort: Use hardcoded fallback
      currentUser = "miftahul01"; // Using the provided username from context
      print("Using fallback user: $currentUser");
    } catch (e) {
      print('Error getting current user: $e');
      // Set default value in case of error
      currentUser = "miftahul01"; // Using the provided username from context
      print("Error occurred, using fallback user: $currentUser");
    }
  }

  Future<void> _loadData() async {
    setState(() {
      isLoading = true;
      error = null;
    });

    try {
      // First, get categories data
      await _fetchCategories();

      // Then get report details by ID
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
      // Use ApiService to get categories
      categories = await _apiService.getCategories();
    } catch (e) {
      print('Error fetching categories: $e');
      // We don't need to stop loading if categories fail to load
      // We can display report details without category names
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

      // Process response data if available
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

    // Handle responses in string format
    if (laporan!.tanggapan is String) {
      final tanggapanStr = laporan!.tanggapan as String;

      // Try parsing if it could be a JSON string
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

  // Add save tanggapan function
  Future<void> saveTanggapan() async {
    if (tanggapanController.text.isEmpty || laporan == null) return;

    setState(() {
      isLoading = true;
    });

    try {
      // Get current date time using the local device time
      final now = DateTime.now();

      // Format to ensure we're getting the correct time
      print(
          "Current local time: ${DateFormat('yyyy-MM-dd HH:mm:ss').format(now)}");

      // Get current username from the context
      final username =
          currentUser ?? "miftahul01"; // Using the provided username

      // Prepare new tanggapan data
      final newTanggapan = {
        'text': tanggapanController.text,
        'timestamp':
            now.toIso8601String(), // Using standard ISO format for storing
        'user': username // Use dynamic username
      };

      // Prepare tanggapan array
      List<dynamic> tanggapanArray = [];

      // If there are previous responses
      if (laporan!.tanggapan != null) {
        var existingTanggapan = laporan!.tanggapan;

        if (existingTanggapan is String && existingTanggapan.isNotEmpty) {
          // Convert old format (string) to new format (array)
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

      // Add new response
      tanggapanArray.add(newTanggapan);

      // Use API service to update tanggapan, passing the current status
      await _apiService.updateLaporanTanggapan(widget.id, tanggapanArray,
          status: laporan!.status ?? 'verified' // Pass the current status
          );

      // Update local data
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
        isLoading = false;
      });
    }
  }

  Future<void> finishReport() async {
    if (laporan == null) return;

    try {
      // Show confirmation dialog
      final bool? confirm = await showDialog<bool>(
        context: context,
        builder: (context) => AlertDialog(
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(16),
          ),
          title: Row(
            children: [
              Icon(Icons.check_circle_outline, color: Colors.green),
              SizedBox(width: 10),
              Text('Tutup Kasus Laporan'),
            ],
          ),
          content: Text(
            'Apakah Anda yakin ingin menutup dan menyelesaikan kasus laporan ini?',
            style: TextStyle(color: Colors.grey[700]),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context, false),
              child: Text('Batal'),
              style: TextButton.styleFrom(foregroundColor: Colors.grey[600]),
            ),
            ElevatedButton(
              onPressed: () => Navigator.pop(context, true),
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.green,
                foregroundColor: Colors.white,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(8),
                ),
                elevation: 0,
              ),
              child: Text('Ya, Selesaikan!'),
            ),
          ],
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
        content: Row(
          children: [
            Icon(Icons.check_circle_outline, color: Colors.white),
            SizedBox(width: 10),
            Expanded(child: Text(message)),
          ],
        ),
        backgroundColor: Colors.green,
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
        margin: EdgeInsets.all(15),
        duration: Duration(seconds: 3),
      ),
    );
  }

  void _showErrorMessage(String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Row(
          children: [
            Icon(Icons.error_outline, color: Colors.white),
            SizedBox(width: 10),
            Expanded(child: Text(message)),
          ],
        ),
        backgroundColor: Colors.red[700],
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
        margin: EdgeInsets.all(15),
        duration: Duration(seconds: 3),
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

      // Use device's local timezone settings
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

      // Use device's local time
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
    return Scaffold(
      backgroundColor: Colors.white,
      appBar: AppBar(
        title: Text(
          'Detail Laporan Kejadian',
          style: TextStyle(
            color: Colors.grey[800],
            fontWeight: FontWeight.w600,
          ),
        ),
        backgroundColor: Colors.white,
        elevation: 0,
        iconTheme: IconThemeData(color: Colors.grey[800]),
        leading: IconButton(
          icon: Icon(Icons.arrow_back),
          onPressed: () {
            Navigator.pushReplacementNamed(context, '/laporpkdosen');
          },
        ),
        bottom: PreferredSize(
          preferredSize: Size.fromHeight(1),
          child: Container(
            height: 1,
            color: Colors.grey.shade200,
          ),
        ),
      ),
      body: isLoading
          ? _buildLoadingView()
          : error != null && laporan == null
              ? _buildErrorView()
              : laporan == null
                  ? Center(
                      child: Text(
                        'Data laporan tidak ditemukan',
                        style: TextStyle(color: Colors.grey[600], fontSize: 16),
                      ),
                    )
                  : _buildDetailContent(),
      floatingActionButton: laporan != null && laporan!.status != 'finished'
          ? Column(
              mainAxisAlignment: MainAxisAlignment.end,
              children: [
                // Add response button
                FloatingActionButton(
                  onPressed: () => _showTanggapanBottomSheet(),
                  tooltip: 'Tambah Tanggapan',
                  heroTag: 'tanggapan',
                  backgroundColor: Colors.blue,
                  elevation: 4,
                  child: Icon(Icons.comment),
                ),
                SizedBox(height: 16),
                // Add finish report button - only show for verified reports
                if (laporan!.status == 'verified')
                  FloatingActionButton(
                    onPressed: finishReport,
                    tooltip: 'Selesaikan Laporan',
                    heroTag: 'selesai',
                    backgroundColor: Colors.green,
                    elevation: 4,
                    child: Icon(Icons.check_circle_outline),
                  ),
              ],
            )
          : null,
    );
  }

  Widget _buildLoadingView() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          CircularProgressIndicator(
            valueColor: AlwaysStoppedAnimation<Color>(Colors.blue),
            strokeWidth: 3,
          ),
          SizedBox(height: 20),
          Text(
            'Memuat data...',
            style: TextStyle(color: Colors.grey[700], fontSize: 16),
          ),
        ],
      ),
    );
  }

  Widget _buildErrorView() {
    return Center(
      child: Container(
        padding: EdgeInsets.all(24),
        width: double.infinity,
        margin: EdgeInsets.all(20),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(16),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(0.06),
              blurRadius: 20,
              offset: Offset(0, 5),
            ),
          ],
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              padding: EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: Colors.red[50],
                shape: BoxShape.circle,
              ),
              child: Icon(
                Icons.error_outline,
                size: 40,
                color: Colors.red[700],
              ),
            ),
            SizedBox(height: 24),
            Text(
              'Terjadi Kesalahan',
              style: TextStyle(
                fontSize: 20,
                fontWeight: FontWeight.bold,
                color: Colors.grey[800],
              ),
            ),
            SizedBox(height: 8),
            Text(
              error!,
              textAlign: TextAlign.center,
              style: TextStyle(
                color: Colors.grey[600],
                fontSize: 16,
              ),
            ),
            SizedBox(height: 24),
            ElevatedButton.icon(
              onPressed: _loadData,
              icon: Icon(Icons.refresh),
              label: Text('Coba Lagi'),
              style: ElevatedButton.styleFrom(
                padding: EdgeInsets.symmetric(horizontal: 24, vertical: 12),
                backgroundColor: Colors.blue,
                foregroundColor: Colors.white,
                elevation: 0,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(10),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  void _showTanggapanBottomSheet() {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) {
        return Container(
          padding: EdgeInsets.only(
            bottom: MediaQuery.of(context).viewInsets.bottom,
          ),
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
          child: Padding(
            padding: EdgeInsets.all(20),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text(
                      'Tambah Tanggapan',
                      style: TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                        color: Colors.grey[800],
                      ),
                    ),
                    IconButton(
                      icon: Icon(Icons.close),
                      onPressed: () => Navigator.pop(context),
                      color: Colors.grey[700],
                    ),
                  ],
                ),
                SizedBox(height: 20),
                Container(
                  decoration: BoxDecoration(
                    color: Colors.grey[50],
                    borderRadius: BorderRadius.circular(12),
                    boxShadow: [
                      BoxShadow(
                        color: Colors.black.withOpacity(0.04),
                        blurRadius: 8,
                        offset: Offset(0, 2),
                      ),
                    ],
                  ),
                  child: TextField(
                    controller: tanggapanController,
                    decoration: InputDecoration(
                      hintText: 'Masukkan tanggapan anda di sini...',
                      hintStyle: TextStyle(color: Colors.grey[400]),
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(12),
                        borderSide: BorderSide.none,
                      ),
                      filled: true,
                      fillColor: Colors.grey[50],
                      contentPadding: EdgeInsets.all(16),
                    ),
                    style: TextStyle(fontSize: 15, color: Colors.grey[800]),
                    maxLines: 5,
                  ),
                ),
                SizedBox(height: 20),
                Row(
                  mainAxisAlignment: MainAxisAlignment.end,
                  children: [
                    TextButton(
                      onPressed: () => Navigator.pop(context),
                      child: Text('Batal'),
                      style: TextButton.styleFrom(
                        foregroundColor: Colors.grey[700],
                        padding:
                            EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(8),
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
                        padding:
                            EdgeInsets.symmetric(horizontal: 20, vertical: 12),
                        backgroundColor: Colors.blue,
                        foregroundColor: Colors.white,
                        elevation: 0,
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(8),
                        ),
                      ),
                      child: Text('Simpan Tanggapan'),
                    ),
                  ],
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  Widget _buildDetailContent() {
    return SingleChildScrollView(
      child: Padding(
        padding: const EdgeInsets.all(20.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Header section with subtle shadow
            _buildHeaderCard(),
            SizedBox(height: 24),

            // Card for Information
            _buildInfoCard(
              title: 'Informasi Kejadian',
              icon: Icons.info_outline,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  if (laporan!.categoryId != null)
                    Container(
                      margin: EdgeInsets.only(bottom: 20),
                      padding:
                          EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                      decoration: BoxDecoration(
                        color: Colors.blue.withOpacity(0.08),
                        borderRadius: BorderRadius.circular(20),
                        boxShadow: [
                          BoxShadow(
                            color: Colors.blue.withOpacity(0.05),
                            blurRadius: 4,
                            offset: Offset(0, 2),
                          ),
                        ],
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(Icons.label_outline,
                              size: 16, color: Colors.blue),
                          SizedBox(width: 6),
                          Text(
                            getCategoryName(laporan!.categoryId),
                            style: TextStyle(
                              color: Colors.blue[700],
                              fontWeight: FontWeight.w500,
                              fontSize: 14,
                            ),
                          ),
                        ],
                      ),
                    ),
                  _buildInfoGrid([
                    {
                      'label': 'Tanggal dan Waktu Kejadian',
                      'value': formatDateKejadian(laporan!.tanggalKejadian),
                      'icon': Icons.event,
                    },
                    {
                      'label': 'Kategori Kejadian',
                      'value': getCategoryName(laporan!.categoryId) ??
                          laporan!.jenisKejadian ??
                          '-',
                      'icon': Icons.category,
                    },
                  ]),
                ],
              ),
            ),

            SizedBox(height: 24),

            // Card for Details with more elegant styling
            _buildInfoCard(
              title: 'Detail Kejadian',
              icon: Icons.description_outlined,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  if (laporan!.judul != null)
                    Container(
                      margin: EdgeInsets.only(bottom: 16),
                      padding: EdgeInsets.all(16),
                      width: double.infinity,
                      decoration: BoxDecoration(
                        color: Colors.grey[50],
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: Text(
                        laporan!.judul!,
                        style: TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.bold,
                          color: Colors.grey[800],
                        ),
                      ),
                    ),
                  Container(
                    padding: EdgeInsets.all(16),
                    width: double.infinity,
                    decoration: BoxDecoration(
                      color: Colors.grey[50],
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Text(
                      laporan!.deskripsi ?? laporan!.deskripsiKejadian ?? '-',
                      style: TextStyle(
                        color: Colors.grey[800],
                        height: 1.6,
                        fontSize: 15,
                      ),
                    ),
                  ),
                  if (laporan!.imagePath != null ||
                      laporan!.fotoKejadian != null) ...[
                    SizedBox(height: 20),
                    Text(
                      'Foto Kejadian',
                      style: TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.w600,
                        color: Colors.grey[800],
                      ),
                    ),
                    SizedBox(height: 12),
                    GestureDetector(
                      onTap: () => _showFullImageDialog(),
                      child: Hero(
                        tag: 'report_image',
                        child: Container(
                          width: double.infinity,
                          constraints: BoxConstraints(
                            maxHeight: 220,
                          ),
                          decoration: BoxDecoration(
                            borderRadius: BorderRadius.circular(14),
                            boxShadow: [
                              BoxShadow(
                                color: Colors.black.withOpacity(0.08),
                                blurRadius: 12,
                                offset: Offset(0, 4),
                              ),
                            ],
                          ),
                          child: ClipRRect(
                            borderRadius: BorderRadius.circular(14),
                            child: Image.network(
                              _getImageUrl(
                                  laporan!.imagePath, laporan!.fotoKejadian),
                              fit: BoxFit.contain,
                              errorBuilder: (context, error, stackTrace) {
                                return Container(
                                  height: 200,
                                  color: Colors.grey[200],
                                  child: Center(
                                    child: Icon(
                                      Icons.broken_image_outlined,
                                      color: Colors.grey[400],
                                      size: 40,
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
                          color: Colors.grey[500],
                          fontStyle: FontStyle.italic,
                        ),
                      ),
                    ),
                  ],
                ],
              ),
            ),

            SizedBox(height: 24),

            // Card for Reporter with enhanced styling
            _buildInfoCard(
              title: 'Informasi Pelapor',
              icon: Icons.person_outline,
              child: _buildInfoGrid([
                {
                  'label': 'Nama',
                  'value': laporan!.namaPelapor ?? '-',
                  'icon': Icons.person,
                },
                {
                  'label': 'NI Pelapor',
                  'value': laporan!.niPelapor ?? '-',
                  'icon': Icons.badge,
                },
                {
                  'label': 'Email',
                  'value': laporan!.email ?? laporan!.emailPelapor ?? '-',
                  'icon': Icons.email,
                },
                {
                  'label': 'Telepon',
                  'value':
                      laporan!.nomorTelepon ?? laporan!.teleponPelapor ?? '-',
                  'icon': Icons.phone,
                },
                {
                  'label': 'Profesi',
                  'value': laporan!.profesi ?? '-',
                  'icon': Icons.work,
                },
                {
                  'label': 'Jenis Kelamin',
                  'value': laporan!.jenisKelamin ?? '-',
                  'icon': Icons.person_outline,
                },
                {
                  'label': 'Kelompok Umur',
                  'value': laporan!.umurPelapor ?? '-',
                  'icon': Icons.person_search,
                },
              ]),
            ),

            SizedBox(height: 24),

            // Card for Status with visual enhancements
            _buildInfoCard(
              title: 'Status Laporan',
              icon: Icons.analytics_outlined,
              child: _buildInfoGrid([
                {
                  'label': 'Status',
                  'value': formatStatus(laporan!.status ?? 'unverified'),
                  'icon': _getStatusIcon(laporan!.status ?? 'unverified'),
                  'widget': Container(
                    padding: EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                    decoration: BoxDecoration(
                      color: getStatusColor(laporan!.status ?? 'unverified')
                          .withOpacity(0.1),
                      borderRadius: BorderRadius.circular(20),
                      border: Border.all(
                        color: getStatusColor(laporan!.status ?? 'unverified')
                            .withOpacity(0.2),
                      ),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(
                          _getStatusIcon(laporan!.status ?? 'unverified'),
                          color:
                              getStatusColor(laporan!.status ?? 'unverified'),
                          size: 16,
                        ),
                        SizedBox(width: 8),
                        Text(
                          formatStatus(laporan!.status ?? 'unverified'),
                          style: TextStyle(
                            color:
                                getStatusColor(laporan!.status ?? 'unverified'),
                            fontWeight: FontWeight.w600,
                            fontSize: 14,
                          ),
                        ),
                      ],
                    ),
                  ),
                },
                {
                  'label': 'Tanggal Laporan',
                  'value': formatDate(laporan!.createdAt?.toIso8601String()),
                  'icon': Icons.calendar_today,
                },
                {
                  'label': 'Terakhir Diperbarui',
                  'value': formatDate(laporan!.updatedAt?.toIso8601String()),
                  'icon': Icons.update,
                },
              ]),
            ),

            // Additional bukti pelanggaran section if available
            if (laporan!.buktiPelanggaran != null &&
                laporan!.buktiPelanggaran!.isNotEmpty) ...[
              SizedBox(height: 24),
              _buildInfoCard(
                title: 'Bukti Pelanggaran',
                icon: Icons.assignment_outlined,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: laporan!.buktiPelanggaran!.map((bukti) {
                    return Container(
                      margin: EdgeInsets.only(bottom: 12),
                      padding: EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        color: Colors.green.withOpacity(0.05),
                        borderRadius: BorderRadius.circular(10),
                        border: Border.all(
                          color: Colors.green.withOpacity(0.2),
                        ),
                      ),
                      child: Row(
                        children: [
                          Container(
                            padding: EdgeInsets.all(6),
                            decoration: BoxDecoration(
                              color: Colors.green.withOpacity(0.1),
                              shape: BoxShape.circle,
                            ),
                            child: Icon(
                              Icons.check,
                              color: Colors.green,
                              size: 16,
                            ),
                          ),
                          SizedBox(width: 12),
                          Expanded(
                            child: Text(
                              bukti,
                              style: TextStyle(
                                color: Colors.grey[800],
                                fontSize: 14,
                                height: 1.4,
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

            // Tanggapan section with elegant styling
            if (hasTanggapan) ...[
              SizedBox(height: 24),
              _buildInfoCard(
                title: 'Tanggapan',
                icon: Icons.comment_outlined,
                child: _buildTanggapanContent(laporan!.tanggapan),
              ),
            ],

            if (laporan!.status == 'verified') ...[
              SizedBox(height: 32),
              _buildFinishReportButton(),
            ],

            SizedBox(height: 40),
          ],
        ),
      ),
    );
  }

  void _showFullImageDialog() {
    showDialog(
      context: context,
      builder: (BuildContext context) {
        return Dialog(
          backgroundColor: Colors.transparent,
          insetPadding: EdgeInsets.all(20),
          child: Stack(
            alignment: Alignment.topRight,
            children: [
              Hero(
                tag: 'report_image',
                child: Container(
                  width: double.infinity,
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(16),
                    boxShadow: [
                      BoxShadow(
                        color: Colors.black.withOpacity(0.2),
                        blurRadius: 20,
                        offset: Offset(0, 10),
                      ),
                    ],
                  ),
                  clipBehavior: Clip.antiAlias,
                  child: AspectRatio(
                    aspectRatio: 1,
                    child: InteractiveViewer(
                      minScale: 0.5,
                      maxScale: 4.0,
                      child: Image.network(
                        _getImageUrl(laporan!.imagePath, laporan!.fotoKejadian),
                        fit: BoxFit.contain,
                        errorBuilder: (context, error, stackTrace) {
                          return Center(
                            child: Column(
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: [
                                Icon(
                                  Icons.broken_image_outlined,
                                  color: Colors.grey[400],
                                  size: 60,
                                ),
                                SizedBox(height: 16),
                                Text(
                                  'Gambar tidak dapat dimuat',
                                  style: TextStyle(color: Colors.grey[600]),
                                ),
                              ],
                            ),
                          );
                        },
                      ),
                    ),
                  ),
                ),
              ),
              Material(
                color: Colors.transparent,
                child: IconButton(
                  icon: Container(
                    padding: EdgeInsets.all(4),
                    decoration: BoxDecoration(
                      color: Colors.black.withOpacity(0.5),
                      shape: BoxShape.circle,
                    ),
                    child: Icon(
                      Icons.close,
                      color: Colors.white,
                      size: 20,
                    ),
                  ),
                  onPressed: () => Navigator.pop(context),
                ),
              ),
            ],
          ),
        );
      },
    );
  }

  IconData _getStatusIcon(String status) {
    switch (status) {
      case 'unverified':
        return Icons.hourglass_empty_outlined;
      case 'verified':
        return Icons.pending_actions_outlined;
      case 'rejected':
        return Icons.cancel_outlined;
      case 'finished':
        return Icons.check_circle_outline;
      default:
        return Icons.help_outline;
    }
  }

  String _getImageUrl(dynamic imagePath, String? fotoKejadian) {
    final String baseUrl =
        // 'http://pelaporan-d3ti.my.id/Backend-Port/backend/engine/public/storage/laporan/';
        'https://v3422040.mhs.d3tiuns.com/Backend-Port/backend/engine/public/storage/laporan/';

    String? image;

    // Handle imagePath which can be List<String> or String
    if (imagePath is List<String> && imagePath.isNotEmpty) {
      image = imagePath.first;
    } else if (imagePath is String) {
      image = imagePath;
    } else {
      image = fotoKejadian;
    }

    if (image == null || image.isEmpty) return '';

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

  Widget _buildHeaderCard() {
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
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Left section with report number and icon
          Container(
            padding: EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: Colors.blue.withOpacity(0.1),
              borderRadius: BorderRadius.circular(12),
            ),
            child: Icon(
              Icons.article_outlined,
              color: Colors.blue[700],
              size: 24,
            ),
          ),
          SizedBox(width: 16),

          // Right section with title, number and status
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Detail Laporan Kejadian',
                  style: TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                    color: Colors.grey[800],
                  ),
                ),
                SizedBox(height: 6),
                Row(
                  children: [
                    Icon(
                      Icons.confirmation_number_outlined,
                      color: Colors.grey[600],
                      size: 14,
                    ),
                    SizedBox(width: 6),
                    Text(
                      laporan!.nomorLaporan ?? 'No. Laporan tidak tersedia',
                      style: TextStyle(
                        color: Colors.grey[600],
                        fontSize: 14,
                      ),
                    ),
                  ],
                ),
                SizedBox(height: 12),
                // Status badge moved below the report number
                Container(
                  padding: EdgeInsets.symmetric(horizontal: 14, vertical: 8),
                  decoration: BoxDecoration(
                    color: getStatusColor(laporan!.status ?? 'unverified')
                        .withOpacity(0.1),
                    borderRadius: BorderRadius.circular(20),
                    border: Border.all(
                      color: getStatusColor(laporan!.status ?? 'unverified')
                          .withOpacity(0.2),
                      width: 1,
                    ),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(
                        _getStatusIcon(laporan!.status ?? 'unverified'),
                        color: getStatusColor(laporan!.status ?? 'unverified'),
                        size: 14,
                      ),
                      SizedBox(width: 6),
                      Text(
                        formatStatus(laporan!.status ?? 'unverified'),
                        style: TextStyle(
                          color:
                              getStatusColor(laporan!.status ?? 'unverified'),
                          fontWeight: FontWeight.w600,
                          fontSize: 12,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildInfoCard({
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
              children: [
                if (icon != null) ...[
                  Container(
                    padding: EdgeInsets.all(8),
                    decoration: BoxDecoration(
                      color: Colors.blue.withOpacity(0.08),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Icon(
                      icon,
                      size: 18,
                      color: Colors.blue[700],
                    ),
                  ),
                  SizedBox(width: 12),
                ],
                Text(
                  title,
                  style: TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.w600,
                    color: Colors.grey[800],
                  ),
                ),
              ],
            ),
            Padding(
              padding: EdgeInsets.symmetric(vertical: 16),
              child: Divider(
                color: Colors.grey.shade200,
                height: 1,
              ),
            ),
            child,
          ],
        ),
      ),
    );
  }

  Widget _buildInfoGrid(List<Map<String, dynamic>> items) {
    bool isWideScreen = MediaQuery.of(context).size.width > 600;

    return Wrap(
      spacing: 24, // horizontal space between items
      runSpacing: 20, // vertical space between lines
      children: items.map((item) {
        return SizedBox(
          width: isWideScreen
              ? (MediaQuery.of(context).size.width - 130) /
                  2 // 2 columns for larger screens
              : double.infinity, // Full width for smaller screens
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Add icon if provided
              if (item['icon'] != null) ...[
                Container(
                  padding: EdgeInsets.all(6),
                  decoration: BoxDecoration(
                    color: Colors.grey[100],
                    borderRadius: BorderRadius.circular(6),
                  ),
                  child: Icon(
                    item['icon'] as IconData,
                    color: Colors.grey[600],
                    size: 16,
                  ),
                ),
                SizedBox(width: 12),
              ],
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      item['label'],
                      style: TextStyle(
                        color: Colors.grey[600],
                        fontSize: 13,
                      ),
                    ),
                    SizedBox(height: 6),
                    if (item['widget'] != null)
                      item['widget']
                    else
                      Text(
                        item['value'] ?? '-',
                        style: TextStyle(
                          color: Colors.grey[800],
                          fontWeight: FontWeight.w500,
                          fontSize: 15,
                        ),
                      ),
                  ],
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
        width: double.infinity,
        decoration: BoxDecoration(
          color: Colors.grey[50],
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: Colors.grey.shade200),
        ),
        child: Text(
          tanggapan,
          style: TextStyle(color: Colors.grey[800], height: 1.5),
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
              padding: EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: Colors.blue.withOpacity(0.03),
                borderRadius: BorderRadius.circular(12),
                border: Border.all(
                  color: Colors.blue.withOpacity(0.08),
                ),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // User info row
                  Row(
                    children: [
                      Container(
                        padding: EdgeInsets.all(8),
                        decoration: BoxDecoration(
                          color: Colors.blue.withOpacity(0.1),
                          shape: BoxShape.circle,
                        ),
                        child: Icon(
                          Icons.person_outline,
                          size: 16,
                          color: Colors.blue[700],
                        ),
                      ),
                      SizedBox(width: 10),
                      Text(
                        item['user'] ?? 'Admin',
                        style: TextStyle(
                          fontWeight: FontWeight.w600,
                          color: Colors.grey[800],
                          fontSize: 14,
                        ),
                      ),
                    ],
                  ),

                  // Timestamp moved below user info
                  SizedBox(height: 8),
                  Container(
                    padding: EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(color: Colors.grey.shade200),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(
                          Icons.access_time,
                          size: 12,
                          color: Colors.grey[600],
                        ),
                        SizedBox(width: 4),
                        Text(
                          formatDate(item['timestamp']),
                          style: TextStyle(
                            fontSize: 12,
                            color: Colors.grey[600],
                          ),
                        ),
                      ],
                    ),
                  ),

                  // Message content
                  SizedBox(height: 12),
                  Container(
                    width: double.infinity,
                    padding: EdgeInsets.all(16),
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Text(
                      item['text'] ?? '',
                      style: TextStyle(
                        color: Colors.grey[800],
                        height: 1.5,
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
        color: Colors.grey[100],
        borderRadius: BorderRadius.circular(12),
      ),
      child: Center(
        child: Text(
          'Tidak ada tanggapan',
          style: TextStyle(
            color: Colors.grey[600],
            fontStyle: FontStyle.italic,
          ),
        ),
      ),
    );
  }

  Widget _buildFinishReportButton() {
    return Container(
      width: double.infinity,
      decoration: BoxDecoration(
        boxShadow: [
          BoxShadow(
            color: Colors.green.withOpacity(0.2),
            blurRadius: 8,
            offset: Offset(0, 4),
          ),
        ],
      ),
      child: ElevatedButton.icon(
        icon: Icon(Icons.check_circle_outline, size: 20),
        label: Text(
          'Tutup dan Selesaikan Laporan',
          style: TextStyle(
            fontSize: 16,
            fontWeight: FontWeight.w600,
          ),
        ),
        style: ElevatedButton.styleFrom(
          backgroundColor: Colors.green,
          foregroundColor: Colors.white,
          elevation: 0,
          padding: EdgeInsets.symmetric(vertical: 16),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12),
          ),
        ),
        onPressed: finishReport,
      ),
    );
  }

  @override
  void dispose() {
    tanggapanController.dispose();
    super.dispose();
  }
}
