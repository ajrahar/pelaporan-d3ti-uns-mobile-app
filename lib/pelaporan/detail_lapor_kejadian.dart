import 'package:flutter/material.dart';
import 'dart:convert';
import 'package:intl/intl.dart';
import 'package:intl/date_symbol_data_local.dart';
import 'package:pelaporan_d3ti/services/token_manager.dart';
import '../services/api_service.dart';
import '../models/laporan.dart';

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

  // Get current username from token or other source
  Future<void> _getCurrentUser() async {
    try {
      // Get token from TokenManager
      final token = await TokenManager.getToken();

      if (token != null && token.isNotEmpty) {
        // Parse the token to get user information
        // JWT tokens are in format: header.payload.signature
        final parts = token.split('.');
        if (parts.length >= 2) {
          // Decode the payload part (middle part)
          String normalizedPayload = base64Url.normalize(parts[1]);
          final payloadJson = utf8.decode(base64Url.decode(normalizedPayload));
          final payload = json.decode(payloadJson);

          // Extract username from token payload
          // Check what field your JWT token uses for username
          currentUser =
              payload['username'] ?? payload['name'] ?? payload['email'];

          if (currentUser == null) {
            // Fallback if username is not in standard fields
            currentUser =
                "miftahul01"; // Using placeholder until you have a clear structure
          }
        }
      }

      if (currentUser == null) {
        // Fallback if token parsing fails
        currentUser = "miftahul01";
      }

      print("Current user set to: $currentUser");
    } catch (e) {
      print('Error getting current user: $e');
      currentUser = "miftahul01"; // Default fallback
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

    setState(() {
      isLoading = true;
    });

    try {
      // Get current date time in GMT+7 (Indonesia)
      final now = DateTime.now().toUtc().add(Duration(hours: 7));

      // Get current username, fallback if not available
      final username = currentUser ?? "miftahul01";

      // Persiapkan data tanggapan baru
      final newTanggapan = {
        'text': tanggapanController.text,
        'timestamp': now.toIso8601String(),
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

      // Use the API service to update tanggapan
      await _apiService.updateLaporanTanggapan(widget.id, tanggapanArray);

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
        isLoading = false;
      });
    }
  }

  Future<void> finishReport() async {
    if (laporan == null) return;

    try {
      // Tampilkan konfirmasi
      final bool? confirm = await showDialog<bool>(
        context: context,
        builder: (context) => AlertDialog(
          title: Text('Tutup Kasus Laporan'),
          content: Text(
              'Apakah Anda yakin ingin menutup dan menyelesaikan kasus laporan ini?'),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context, false),
              child: Text('Batal'),
            ),
            TextButton(
              onPressed: () => Navigator.pop(context, true),
              child: Text('Ya, Selesaikan!'),
            ),
          ],
        ),
      );

      if (confirm != true) return;

      setState(() {
        isLoading = true;
      });

      // Get current date time in GMT+7 (Indonesia)
      final now = DateTime.now().toUtc().add(Duration(hours: 7));

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
        content: Text(message),
        backgroundColor: Colors.green,
        behavior: SnackBarBehavior.floating,
      ),
    );
  }

  void _showErrorMessage(String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        backgroundColor: Colors.red,
        behavior: SnackBarBehavior.floating,
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

      // Ensure we're adding the +7 GMT adjustment for Indonesia timezone
      final indonesiaDate = date.toLocal();

      // Using dd-MM-yyyy HH:mm:ss format for dates in Status Laporan and tanggapan
      return DateFormat('dd-MM-yyyy HH:mm:ss').format(indonesiaDate);
    } catch (e) {
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
    return Scaffold(
      appBar: AppBar(
        title: Text('Detail Laporan Kejadian'),
        leading: IconButton(
          icon: Icon(Icons.arrow_back),
          onPressed: () {
            Navigator.pushReplacementNamed(context, '/laporkejadian');
          },
        ),
      ),
      body: isLoading
          ? Center(child: CircularProgressIndicator())
          : error != null && laporan == null
              ? Center(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Text(error!),
                      SizedBox(height: 16),
                      ElevatedButton(
                        onPressed: _loadData,
                        child: Text('Coba Lagi'),
                      ),
                    ],
                  ),
                )
              : laporan == null
                  ? Center(child: Text('Data laporan tidak ditemukan'))
                  : _buildDetailContent(),
    );
  }

  Widget _buildDetailContent() {
    return SingleChildScrollView(
      child: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Header section
            Row(
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Detail Laporan Kejadian',
                        style: TextStyle(
                            fontSize: 20, fontWeight: FontWeight.bold),
                      ),
                      SizedBox(height: 4),
                      Text(
                        laporan!.nomorLaporan ?? 'No. Laporan tidak tersedia',
                        style: TextStyle(color: Colors.grey[600]),
                      ),
                    ],
                  ),
                ),
                Container(
                  padding: EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                  decoration: BoxDecoration(
                    color: getStatusColor(laporan!.status ?? 'unverified')
                        .withOpacity(0.2),
                    borderRadius: BorderRadius.circular(16),
                  ),
                  child: Text(
                    formatStatus(laporan!.status ?? 'unverified'),
                    style: TextStyle(
                      color: getStatusColor(laporan!.status ?? 'unverified'),
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
              ],
            ),

            SizedBox(height: 24),

            // Card for Information
            _buildCard(
              title: 'Informasi Kejadian',
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  if (laporan!.categoryId != null)
                    Container(
                      margin: EdgeInsets.only(bottom: 16),
                      padding:
                          EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                      decoration: BoxDecoration(
                        color: Colors.blue.withOpacity(0.1),
                        borderRadius: BorderRadius.circular(6),
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(Icons.label, size: 16, color: Colors.blue),
                          SizedBox(width: 4),
                          Text(
                            getCategoryName(laporan!.categoryId),
                            style: TextStyle(color: Colors.blue),
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
                    // Lokasi Kejadian removed as requested
                  ]),
                ],
              ),
            ),

            SizedBox(height: 16),

            // Card for Details
            _buildCard(
              title: 'Detail Kejadian',
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  if (laporan!.judul != null)
                    Padding(
                      padding: const EdgeInsets.only(bottom: 8.0),
                      child: Text(
                        laporan!.judul!,
                        style: TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ),
                  Text(
                    laporan!.deskripsi ?? laporan!.deskripsiKejadian ?? '-',
                    style: TextStyle(height: 1.5),
                  ),
                  if (laporan!.imagePath != null ||
                      laporan!.fotoKejadian != null)
                    Padding(
                      padding: const EdgeInsets.only(top: 16.0),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'Foto Kejadian',
                            style: TextStyle(
                              fontSize: 16,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                          SizedBox(height: 8),
                          GestureDetector(
                            onTap: () {
                              setState(() {
                                showFullImage = true;
                              });
                              // Show dialog with full image
                              showDialog(
                                context: context,
                                builder: (context) => Dialog(
                                  child: Column(
                                    mainAxisSize: MainAxisSize.min,
                                    children: [
                                      Stack(
                                        alignment: Alignment.topRight,
                                        children: [
                                          Image.network(
                                            _getImageUrl(laporan!.imagePath,
                                                laporan!.fotoKejadian),
                                            fit: BoxFit.contain,
                                            errorBuilder:
                                                (context, error, stackTrace) {
                                              return Center(
                                                child: Text(
                                                    'Gambar tidak dapat dimuat'),
                                              );
                                            },
                                          ),
                                          IconButton(
                                            icon: Icon(Icons.close),
                                            onPressed: () {
                                              Navigator.pop(context);
                                            },
                                          ),
                                        ],
                                      ),
                                    ],
                                  ),
                                ),
                              );
                            },
                            child: Center(
                              child: Container(
                                constraints: BoxConstraints(
                                  maxHeight: 200,
                                ),
                                child: Image.network(
                                  _getImageUrl(laporan!.imagePath,
                                      laporan!.fotoKejadian),
                                  fit: BoxFit.contain,
                                  errorBuilder: (context, error, stackTrace) {
                                    return Center(
                                      child: Text('Gambar tidak dapat dimuat'),
                                    );
                                  },
                                ),
                              ),
                            ),
                          ),
                          Center(
                            child: Text(
                              'Klik untuk memperbesar gambar',
                              style: TextStyle(
                                fontSize: 12,
                                color: Colors.grey[600],
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                ],
              ),
            ),

            SizedBox(height: 16),

            // Card for Reporter
            _buildCard(
              title: 'Informasi Pelapor',
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

            SizedBox(height: 16),

            // Card for Status
            _buildCard(
              title: 'Status Laporan',
              child: _buildInfoGrid([
                {
                  'label': 'Status',
                  'value': formatStatus(laporan!.status ?? 'unverified'),
                  'widget': Container(
                    padding: EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                    decoration: BoxDecoration(
                      color: getStatusColor(laporan!.status ?? 'unverified')
                          .withOpacity(0.2),
                      borderRadius: BorderRadius.circular(16),
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
              SizedBox(height: 16),
              _buildCard(
                title: 'Bukti Pelanggaran',
                icon: Icons.assignment_outlined,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: laporan!.buktiPelanggaran!.map((bukti) {
                    return Padding(
                      padding: const EdgeInsets.only(bottom: 8.0),
                      child: Row(
                        children: [
                          Icon(Icons.check_circle_outline,
                              color: Colors.green, size: 18),
                          SizedBox(width: 8),
                          Text(bukti),
                        ],
                      ),
                    );
                  }).toList(),
                ),
              ),
            ],

            // Tanggapan section
            if (hasTanggapan) ...[
              SizedBox(height: 16),
              _buildCard(
                title: 'Tanggapan',
                icon: Icons.comment_outlined,
                child: _buildTanggapanContent(laporan!.tanggapan),
              ),
            ],

            // Admin buttons
            if (isAdmin) ...[
              SizedBox(height: 24),
              Row(
                children: [
                  if (laporan!.status != 'finished')
                    Expanded(
                      child: ElevatedButton.icon(
                        icon: Icon(Icons.comment_outlined),
                        label: Text('Tambah Tanggapan'),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: Colors.grey[200],
                          foregroundColor: Colors.black87,
                          padding: EdgeInsets.symmetric(vertical: 12),
                        ),
                        onPressed: () {
                          setState(() {
                            showTanggapanModal = true;
                          });

                          // Show bottom sheet for adding tanggapan
                          showModalBottomSheet(
                            context: context,
                            isScrollControlled: true,
                            builder: (context) {
                              return Padding(
                                padding: EdgeInsets.only(
                                  bottom:
                                      MediaQuery.of(context).viewInsets.bottom,
                                  left: 16,
                                  right: 16,
                                  top: 16,
                                ),
                                child: Column(
                                  mainAxisSize: MainAxisSize.min,
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Row(
                                      mainAxisAlignment:
                                          MainAxisAlignment.spaceBetween,
                                      children: [
                                        Text(
                                          'Tambah Tanggapan',
                                          style: TextStyle(
                                            fontSize: 18,
                                            fontWeight: FontWeight.bold,
                                          ),
                                        ),
                                        IconButton(
                                          icon: Icon(Icons.close),
                                          onPressed: () {
                                            Navigator.pop(context);
                                          },
                                        ),
                                      ],
                                    ),
                                    SizedBox(height: 16),
                                    TextField(
                                      controller: tanggapanController,
                                      decoration: InputDecoration(
                                        hintText:
                                            'Masukkan tanggapan anda di sini...',
                                        border: OutlineInputBorder(),
                                      ),
                                      maxLines: 5,
                                    ),
                                    SizedBox(height: 16),
                                    Row(
                                      mainAxisAlignment: MainAxisAlignment.end,
                                      children: [
                                        TextButton(
                                          onPressed: () {
                                            Navigator.pop(context);
                                          },
                                          child: Text('Batal'),
                                        ),
                                        SizedBox(width: 8),
                                        ElevatedButton(
                                          onPressed: () {
                                            Navigator.pop(context);
                                            saveTanggapan();
                                          },
                                          child: Text('Simpan Tanggapan'),
                                        ),
                                      ],
                                    ),
                                    SizedBox(height: 16),
                                  ],
                                ),
                              );
                            },
                          );
                        },
                      ),
                    ),
                  SizedBox(width: 12),
                  if (laporan!.status != 'finished' &&
                      laporan!.status != 'unverified')
                    Expanded(
                      child: ElevatedButton.icon(
                        icon: Icon(Icons.check_circle_outline),
                        label: Text('Tutup Laporan'),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: Colors.green,
                          foregroundColor: Colors.white,
                          padding: EdgeInsets.symmetric(vertical: 12),
                        ),
                        onPressed: finishReport,
                      ),
                    ),
                ],
              ),
            ],

            SizedBox(height: 24),
          ],
        ),
      ),
    );
  }

  String _getImageUrl(String? imagePath, String? fotoKejadian) {
    final String baseUrl = 'http://10.0.2.2:8000/storage/laporan/';

    // Pilih gambar yang tersedia
    String? image = imagePath ?? fotoKejadian;
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

  Widget _buildCard(
      {required String title, required Widget child, IconData? icon}) {
    return Container(
      width: double.infinity,
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(8),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.05),
            blurRadius: 10,
            offset: Offset(0, 4),
          ),
        ],
      ),
      child: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                if (icon != null) ...[
                  Icon(icon, size: 20),
                  SizedBox(width: 8),
                ],
                Text(
                  title,
                  style: TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ],
            ),
            Divider(height: 24),
            child,
          ],
        ),
      ),
    );
  }

  Widget _buildInfoGrid(List<Map<String, dynamic>> items) {
    return Wrap(
      spacing: 24,
      runSpacing: 16,
      children: items.map((item) {
        return SizedBox(
          width: MediaQuery.of(context).size.width > 600
              ? (MediaQuery.of(context).size.width - 80) /
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
              SizedBox(height: 4),
              if (item['widget'] != null)
                item['widget']
              else
                Text(
                  item['value'] ?? '-',
                  style: TextStyle(
                    fontWeight: FontWeight.w500,
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
      return Text(tanggapan);
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
              padding: EdgeInsets.all(12),
              decoration: BoxDecoration(
                border: Border(
                  left: BorderSide(
                    color: Colors.blue,
                    width: 3,
                  ),
                ),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text(
                        item['user'] ?? 'Admin',
                        style: TextStyle(
                          fontWeight: FontWeight.bold,
                          color: Colors.grey[700],
                        ),
                      ),
                      Text(
                        formatDate(item['timestamp']),
                        style: TextStyle(
                          fontSize: 12,
                          color: Colors.grey[600],
                        ),
                      ),
                    ],
                  ),
                  SizedBox(height: 8),
                  Text(
                    item['text'] ?? '',
                    style: TextStyle(height: 1.5),
                  ),
                ],
              ),
            );
          },
        ),
      );
    }

    return Text('Tidak ada tanggapan');
  }
}
