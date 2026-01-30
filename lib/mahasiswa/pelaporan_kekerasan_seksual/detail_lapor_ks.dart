import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:pelaporan_d3ti/models/laporan_kekerasan.dart';
import 'package:pelaporan_d3ti/services/api_service.dart';
import 'package:pelaporan_d3ti/components/sidebar.dart';
import 'package:intl/date_symbol_data_local.dart';
import 'dart:async';
import 'package:shared_preferences/shared_preferences.dart';

class DetailLaporanKekerasanPage extends StatefulWidget {
  final LaporanKekerasan? laporan;
  final int id;

  const DetailLaporanKekerasanPage({
    Key? key,
    this.laporan,
    required this.id,
  }) : super(key: key);

  @override
  _DetailLaporanKekerasanPageState createState() =>
      _DetailLaporanKekerasanPageState();
}

class _DetailLaporanKekerasanPageState
    extends State<DetailLaporanKekerasanPage> {
  final ApiService _apiService = ApiService();
  bool _loading = true;
  String? _error;
  LaporanKekerasan? _laporan;
  Map<int, String> _categories = {};
  bool _dateFormatInitialized = false;

  // Theme colors for elegant white design
  final Color _primaryColor = Color(0xFF00457C); // Deep blue
  final Color _accentColor = Color(0xFFF44336); // Red accent
  final Color _backgroundColor = Color(0xFFF9FAFC); // Light background
  final Color _cardColor = Colors.white; // Card color
  final Color _textColor = Color(0xFF2D3748); // Dark text
  final Color _lightTextColor = Color(0xFF718096); // Light text
  final Color _borderColor = Color(0xFFE2E8F0); // Border color
  final Color _shadowColor = Color(0x0A000000); // Soft shadow

  // Dynamic user info and time
  String _currentDateTime = '';
  String _currentUserName = '';
  Timer? _timeTimer;

  @override
  void initState() {
    super.initState();
    _initializeDateFormatting();
    _getUserInfo();
    _updateCurrentTime();

    // Set up timer to update time regularly
    _timeTimer = Timer.periodic(Duration(seconds: 1), (timer) {
      _updateCurrentTime();
    });

    // If laporan is passed, use it directly, otherwise fetch from API
    if (widget.laporan != null) {
      setState(() {
        _laporan = widget.laporan;
        _loading = false;
      });
      _fetchCategories();
    } else {
      _fetchData();
    }
  }

  @override
  void dispose() {
    _timeTimer?.cancel();
    super.dispose();
  }

  // Update current date/time - Indonesian time (UTC+7)
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

  Future<void> _getUserInfo() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      String? userName = prefs.getString('user_name');

      if (userName == null || userName.isEmpty) {
        userName = "Pengguna"; // Default fallback
      }

      setState(() {
        _currentUserName = userName!;
      });
    } catch (e) {
      print('Error getting user info: $e');
      setState(() {
        _currentUserName = "Pengguna"; // Default fallback
      });
    }
  }

  Future<void> _initializeDateFormatting() async {
    try {
      await initializeDateFormatting('id_ID', null);
      setState(() {
        _dateFormatInitialized = true;
      });
    } catch (e) {
      print('Error initializing date formatting: $e');
    }
  }

  Future<void> _fetchCategories() async {
    try {
      final categoriesResponse = await _apiService.getCategories();
      setState(() {
        _categories = categoriesResponse;
      });
    } catch (e) {
      print('Error fetching categories: $e');
      // Set default categories as fallback
      setState(() {
        _categories = {
          16: 'Kekerasan Seksual',
          17: 'Kekerasan Fisik',
          18: 'Kekerasan Verbal',
          19: 'Kekerasan Psikologis'
        };
      });
    }
  }

  Future<void> _fetchData() async {
    setState(() {
      _loading = true;
      _error = null;
    });

    try {
      // Fetch categories
      await _fetchCategories();

      // Fetch laporan detail
      final laporan = await _apiService.getLaporanKekerasanById(widget.id);
      setState(() {
        _laporan = laporan;
        _loading = false;
      });
    } catch (e) {
      setState(() {
        _error = 'Terjadi kesalahan saat memuat data: $e';
        _loading = false;
      });
    }
  }

  String _formatDate(DateTime? date) {
    if (date == null) {
      return '-';
    }

    try {
      // Try with Indonesian locale if initialized
      if (_dateFormatInitialized) {
        final DateFormat formatter = DateFormat('dd MMMM yyyy, HH:mm', 'id_ID');
        return formatter.format(date);
      } else {
        // Fallback to standard locale if Indonesian isn't initialized
        final DateFormat formatter = DateFormat('dd MMMM yyyy, HH:mm');
        return formatter.format(date);
      }
    } catch (e) {
      print('Error formatting date: $e');
      // Fallback to simple format if there's an error
      return '${date.day}/${date.month}/${date.year} ${date.hour}:${date.minute.toString().padLeft(2, '0')}';
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: _backgroundColor,
      appBar: AppBar(
        elevation: 0,
        backgroundColor: _cardColor,
        title: Text(
          'Detail Laporan Kekerasan',
          style: TextStyle(color: _textColor, fontWeight: FontWeight.w600),
        ),
        iconTheme: IconThemeData(color: _textColor),
        actions: [
          IconButton(
            icon: Icon(Icons.refresh, color: _primaryColor),
            onPressed: _fetchData,
            tooltip: 'Muat ulang data',
          ),
        ],
      ),
      drawer: Sidebar(),
      body: _loading
          ? Center(
              child: CircularProgressIndicator(
                valueColor: AlwaysStoppedAnimation<Color>(_primaryColor),
              ),
            )
          : _error != null
              ? _buildErrorWidget()
              : _laporan == null
                  ? _buildEmptyDataWidget()
                  : _buildDetailContent(),
    );
  }

  Widget _buildEmptyDataWidget() {
    return Center(
      child: Container(
        padding: const EdgeInsets.all(24),
        width: double.infinity,
        constraints: BoxConstraints(maxWidth: 500),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.search_off, size: 80, color: Colors.grey[300]),
            SizedBox(height: 24),
            Text(
              'Data tidak ditemukan',
              style: TextStyle(
                fontSize: 24,
                fontWeight: FontWeight.bold,
                color: _textColor,
              ),
            ),
            SizedBox(height: 16),
            Text(
              'Laporan dengan ID ${widget.id} tidak dapat ditemukan atau telah dihapus.',
              textAlign: TextAlign.center,
              style: TextStyle(
                fontSize: 16,
                color: _lightTextColor,
              ),
            ),
            SizedBox(height: 32),
            ElevatedButton.icon(
              icon: Icon(Icons.arrow_back),
              label: Text('Kembali ke Daftar Laporan'),
              style: ElevatedButton.styleFrom(
                backgroundColor: _primaryColor,
                foregroundColor: Colors.white,
                padding: EdgeInsets.symmetric(horizontal: 24, vertical: 16),
                elevation: 0,
                shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(8)),
              ),
              onPressed: () => Navigator.of(context).pop(),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildErrorWidget() {
    return Center(
      child: Container(
        padding: const EdgeInsets.all(24),
        width: double.infinity,
        constraints: BoxConstraints(maxWidth: 500),
        decoration: BoxDecoration(
          color: _cardColor,
          borderRadius: BorderRadius.circular(16),
          boxShadow: [
            BoxShadow(
              color: _shadowColor,
              blurRadius: 15,
              offset: Offset(0, 5),
            ),
          ],
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Container(
              padding: EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: _accentColor.withOpacity(0.1),
                shape: BoxShape.circle,
              ),
              child: Icon(Icons.error_outline, color: _accentColor, size: 48),
            ),
            SizedBox(height: 24),
            Text(
              'Terjadi kesalahan',
              style: TextStyle(
                  fontSize: 22, fontWeight: FontWeight.bold, color: _textColor),
            ),
            SizedBox(height: 12),
            Text(
              _error ?? 'Tidak dapat mengakses data laporan',
              textAlign: TextAlign.center,
              style: TextStyle(fontSize: 16, color: _lightTextColor),
            ),
            SizedBox(height: 24),
            Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                ElevatedButton.icon(
                  onPressed: _fetchData,
                  icon: Icon(Icons.refresh),
                  label: Text('Coba Lagi'),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: _primaryColor,
                    foregroundColor: Colors.white,
                    padding: EdgeInsets.symmetric(horizontal: 24, vertical: 12),
                    elevation: 0,
                    shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(8)),
                  ),
                ),
                SizedBox(width: 12),
                OutlinedButton.icon(
                  onPressed: () => Navigator.of(context).pop(),
                  icon: Icon(Icons.arrow_back),
                  label: Text('Kembali'),
                  style: OutlinedButton.styleFrom(
                    foregroundColor: _primaryColor,
                    padding: EdgeInsets.symmetric(horizontal: 24, vertical: 12),
                    side: BorderSide(color: _primaryColor),
                    shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(8)),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildDetailContent() {
    return Stack(
      children: [
        SingleChildScrollView(
          padding: EdgeInsets.all(20),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Back button
              _buildBackButton(),
              SizedBox(height: 24),

              // Main content
              _buildHeaderCard(),
              SizedBox(height: 20),
              _buildInfoCard('Informasi Laporan', _buildLaporanInfo()),
              SizedBox(height: 20),
              _buildInfoCard('Deskripsi Kejadian', _buildDeskripsiSection()),
              SizedBox(height: 20),
              if (_laporan!.terlapor != null && _laporan!.terlapor!.isNotEmpty)
                _buildInfoCard('Informasi Terlapor', _buildTerlaporSection()),
              SizedBox(height: 20),
              if (_laporan!.saksi != null && _laporan!.saksi!.isNotEmpty)
                _buildInfoCard('Informasi Saksi', _buildSaksiSection()),
              if (_laporan!.imagePath != null &&
                  _laporan!.imagePath!.isNotEmpty) ...[
                SizedBox(height: 20),
                _buildInfoCard('Lampiran Gambar', _buildImageSection()),
              ],
              SizedBox(height: 80), // Space at the bottom
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildBackButton() {
    return OutlinedButton.icon(
      onPressed: () => Navigator.of(context).pop(),
      icon: Icon(Icons.arrow_back),
      label: Text('Kembali ke Daftar Laporan'),
      style: OutlinedButton.styleFrom(
        foregroundColor: _primaryColor,
        padding: EdgeInsets.symmetric(horizontal: 16, vertical: 12),
        side: BorderSide(color: _primaryColor.withOpacity(0.5)),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
      ),
    );
  }

  Widget _buildHeaderCard() {
    String categoryName =
        _categories[_laporan!.categoryId] ?? 'Kekerasan Seksual';
    Color categoryColor = categoryName.toLowerCase().contains('seksual')
        ? _accentColor
        : _primaryColor;

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        color: _cardColor,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: _shadowColor,
            blurRadius: 15,
            offset: Offset(0, 5),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Title
          Text(
            _laporan!.judul ?? 'Tidak ada judul',
            style: TextStyle(
              fontSize: 22,
              fontWeight: FontWeight.bold,
              color: _textColor,
              height: 1.3,
            ),
          ),
          SizedBox(height: 16),

          // Category badge
          Container(
            padding: EdgeInsets.symmetric(horizontal: 12, vertical: 6),
            decoration: BoxDecoration(
              color: categoryColor.withOpacity(0.1),
              borderRadius: BorderRadius.circular(20),
              border: Border.all(color: categoryColor.withOpacity(0.2)),
            ),
            child: Text(
              categoryName,
              style: TextStyle(
                color: categoryColor,
                fontWeight: FontWeight.w600,
                fontSize: 14,
              ),
            ),
          ),

          // Report Number - Now below the category
          SizedBox(height: 12),
          Row(
            children: [
              Icon(Icons.tag, color: _lightTextColor, size: 16),
              SizedBox(width: 8),
              Text(
                'No. Laporan: ${_laporan!.nomorLaporanKekerasan ?? "-"}',
                style: TextStyle(
                  color: _lightTextColor,
                  fontWeight: FontWeight.w500,
                ),
              ),
            ],
          ),

          // Report date
          SizedBox(height: 12),
          Row(
            children: [
              Icon(Icons.event_note, color: _lightTextColor, size: 16),
              SizedBox(width: 8),
              Text(
                ' ${_formatDate(_laporan!.createdAt)}',
                style: TextStyle(
                  color: _lightTextColor,
                  fontSize: 14,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildInfoCard(String title, Widget content) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        color: _cardColor,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: _shadowColor,
            blurRadius: 15,
            offset: Offset(0, 5),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(
                _getIconForTitle(title),
                color: _primaryColor,
                size: 18,
              ),
              SizedBox(width: 10),
              Text(
                title,
                style: TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.w600,
                  color: _textColor,
                ),
              ),
            ],
          ),
          SizedBox(height: 4),
          Divider(height: 20, thickness: 1, color: _borderColor),
          SizedBox(height: 8),
          content,
        ],
      ),
    );
  }

  IconData _getIconForTitle(String title) {
    switch (title) {
      case 'Informasi Laporan':
        return Icons.info_outline;
      case 'Deskripsi Kejadian':
        return Icons.description_outlined;
      case 'Informasi Terlapor':
        return Icons.person_search_outlined;
      case 'Informasi Saksi':
        return Icons.people_alt_outlined;
      case 'Lampiran Gambar':
        return Icons.image_outlined;
      default:
        return Icons.article_outlined;
    }
  }

  Widget _buildLaporanInfo() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _buildInfoRow('Nama Pelapor', _laporan!.namaPelapor ?? '-'),
        SizedBox(height: 12),
        _buildInfoRow('NIM Pelapor', _laporan!.nimPelapor ?? '-'),
        SizedBox(height: 12),
        _buildInfoRow('Nomor Telepon', _laporan!.nomorTelepon ?? '-'),
        SizedBox(height: 12),
        _buildInfoRow(
            'Tanggal Kejadian', _formatDate(_laporan!.tanggalKejadian)),
      ],
    );
  }

  Widget _buildDeskripsiSection() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Container(
          width: double.infinity,
          padding: EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: _backgroundColor,
            borderRadius: BorderRadius.circular(8),
            border: Border.all(color: _borderColor),
          ),
          child: Text(
            _laporan!.deskripsi ?? 'Tidak ada deskripsi',
            style: TextStyle(
              fontSize: 15,
              color: _textColor,
              height: 1.5,
            ),
          ),
        ),
        if (_laporan!.buktiPelanggaran != null &&
            _laporan!.buktiPelanggaran!.isNotEmpty) ...[
          SizedBox(height: 20),
          Text(
            'Bukti Pelanggaran:',
            style: TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.w600,
              color: _textColor,
            ),
          ),
          SizedBox(height: 12),
          Container(
            decoration: BoxDecoration(
              color: _backgroundColor,
              borderRadius: BorderRadius.circular(8),
              border: Border.all(color: _borderColor),
            ),
            child: ListView.separated(
              shrinkWrap: true,
              physics: NeverScrollableScrollPhysics(),
              itemCount: _laporan!.buktiPelanggaran!.length,
              separatorBuilder: (context, index) =>
                  Divider(height: 1, thickness: 1, color: _borderColor),
              itemBuilder: (context, index) {
                return Padding(
                  padding: const EdgeInsets.all(12),
                  child: Row(
                    children: [
                      Container(
                        padding: EdgeInsets.all(6),
                        decoration: BoxDecoration(
                          color: _primaryColor.withOpacity(0.1),
                          shape: BoxShape.circle,
                        ),
                        child: Icon(
                          Icons.check,
                          size: 14,
                          color: _primaryColor,
                        ),
                      ),
                      SizedBox(width: 12),
                      Expanded(
                        child: Text(
                          _laporan!.buktiPelanggaran![index],
                          style: TextStyle(fontSize: 14, color: _textColor),
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
    );
  }

  Widget _buildTerlaporSection() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: _laporan!.terlapor!.asMap().entries.map((entry) {
        final index = entry.key;
        final terlapor = entry.value;

        return Container(
          margin: EdgeInsets.only(bottom: 16),
          decoration: BoxDecoration(
            color: _backgroundColor,
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: _borderColor),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Header
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
                  children: [
                    Icon(Icons.person_outline, color: _primaryColor, size: 16),
                    SizedBox(width: 8),
                    Text(
                      'Terlapor ${index + 1}',
                      style: TextStyle(
                        fontWeight: FontWeight.w600,
                        color: _primaryColor,
                      ),
                    ),
                  ],
                ),
              ),

              // Content
              Padding(
                padding: const EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    _buildInfoRow('Nama Lengkap', terlapor.namaLengkap ?? '-'),
                    SizedBox(height: 12),
                    _buildInfoRow('Email', terlapor.email ?? '-'),
                    SizedBox(height: 12),
                    _buildInfoRow(
                        'Nomor Telepon', terlapor.nomorTelepon ?? '-'),
                    SizedBox(height: 12),
                    _buildInfoRow('Status', terlapor.statusWarga ?? '-'),
                    SizedBox(height: 12),
                    _buildInfoRow(
                        'Jenis Kelamin', terlapor.jenisKelamin ?? '-'),
                  ],
                ),
              ),
            ],
          ),
        );
      }).toList(),
    );
  }

  Widget _buildSaksiSection() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: _laporan!.saksi!.asMap().entries.map((entry) {
        final index = entry.key;
        final saksi = entry.value;

        return Container(
          margin: EdgeInsets.only(bottom: 16),
          decoration: BoxDecoration(
            color: _backgroundColor,
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: _borderColor),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Header
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
                  children: [
                    Icon(Icons.people_alt_outlined,
                        color: _primaryColor, size: 16),
                    SizedBox(width: 8),
                    Text(
                      'Saksi ${index + 1}',
                      style: TextStyle(
                        fontWeight: FontWeight.w600,
                        color: _primaryColor,
                      ),
                    ),
                  ],
                ),
              ),

              // Content
              Padding(
                padding: const EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    _buildInfoRow('Nama Lengkap', saksi.namaLengkap ?? '-'),
                    SizedBox(height: 12),
                    _buildInfoRow('Email', saksi.email ?? '-'),
                    SizedBox(height: 12),
                    _buildInfoRow('Nomor Telepon', saksi.nomorTelepon ?? '-'),
                  ],
                ),
              ),
            ],
          ),
        );
      }).toList(),
    );
  }

  Widget _buildImageSection() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _laporan!.imagePath!.isEmpty
            ? Text('Tidak ada gambar yang dilampirkan',
                style: TextStyle(color: _lightTextColor))
            : GridView.builder(
                shrinkWrap: true,
                physics: NeverScrollableScrollPhysics(),
                gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
                  crossAxisCount: 2,
                  crossAxisSpacing: 16,
                  mainAxisSpacing: 16,
                  childAspectRatio: 1,
                ),
                itemCount: _laporan!.imagePath!.length,
                itemBuilder: (context, index) {
                  final String fileName = _laporan!.imagePath![index];
                  final String baseUrl =
                      //'http://pelaporan-d3ti.my.id/Backend-Port/backend/engine/public/storage/laporankekerasan/';
                      'https://v3422040.mhs.d3tiuns.com/Backend-Port/backend/engine/public/storage/laporankekerasan/';
                  final String imageUrl = '$baseUrl$fileName';

                  return GestureDetector(
                    onTap: () {
                      // Show full-screen image view when tapped
                      Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder: (context) => Scaffold(
                            backgroundColor: Colors.black,
                            appBar: AppBar(
                              title: Text(
                                'Gambar Lampiran ${index + 1}',
                                style: TextStyle(color: Colors.white),
                              ),
                              backgroundColor: Colors.black,
                              iconTheme: IconThemeData(color: Colors.white),
                              elevation: 0,
                            ),
                            body: Center(
                              child: InteractiveViewer(
                                minScale: 0.5,
                                maxScale: 4.0,
                                child: Image.network(
                                  imageUrl,
                                  fit: BoxFit.contain,
                                  loadingBuilder: (context, child, progress) {
                                    if (progress == null) return child;
                                    return Center(
                                        child: CircularProgressIndicator(
                                            color: Colors.white));
                                  },
                                  errorBuilder: (context, error, stackTrace) {
                                    return Center(
                                      child: Column(
                                        mainAxisAlignment:
                                            MainAxisAlignment.center,
                                        children: [
                                          Icon(Icons.broken_image,
                                              size: 60, color: Colors.white70),
                                          SizedBox(height: 16),
                                          Text(
                                            'Tidak dapat memuat gambar',
                                            style:
                                                TextStyle(color: Colors.white),
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
                      );
                    },
                    child: Container(
                      decoration: BoxDecoration(
                        color: _cardColor,
                        borderRadius: BorderRadius.circular(12),
                        boxShadow: [
                          BoxShadow(
                            color: _shadowColor,
                            blurRadius: 8,
                            offset: Offset(0, 3),
                          ),
                        ],
                      ),
                      child: ClipRRect(
                        borderRadius: BorderRadius.circular(12),
                        child: Stack(
                          fit: StackFit.expand,
                          children: [
                            // Image
                            Image.network(
                              imageUrl,
                              fit: BoxFit.cover,
                              loadingBuilder: (context, child, progress) {
                                if (progress == null) return child;
                                return Center(
                                  child: CircularProgressIndicator(
                                    value: progress.expectedTotalBytes != null
                                        ? progress.cumulativeBytesLoaded /
                                            progress.expectedTotalBytes!
                                        : null,
                                    valueColor: AlwaysStoppedAnimation<Color>(
                                        _primaryColor),
                                  ),
                                );
                              },
                              errorBuilder: (context, error, stackTrace) {
                                return Center(
                                  child: Column(
                                    mainAxisAlignment: MainAxisAlignment.center,
                                    children: [
                                      Icon(Icons.broken_image,
                                          size: 40, color: Colors.grey),
                                      SizedBox(height: 8),
                                      Text(
                                        'Gambar tidak\ntersedia',
                                        style: TextStyle(
                                          fontSize: 12,
                                          color: Colors.grey[700],
                                        ),
                                        textAlign: TextAlign.center,
                                      ),
                                    ],
                                  ),
                                );
                              },
                            ),

                            // Zoom hint overlay
                            Positioned(
                              right: 8,
                              bottom: 8,
                              child: Container(
                                padding: EdgeInsets.symmetric(
                                    horizontal: 8, vertical: 4),
                                decoration: BoxDecoration(
                                  color: Colors.black.withOpacity(0.7),
                                  borderRadius: BorderRadius.circular(12),
                                ),
                                child: Row(
                                  mainAxisSize: MainAxisSize.min,
                                  children: [
                                    Icon(Icons.zoom_in,
                                        color: Colors.white, size: 14),
                                    SizedBox(width: 4),
                                    Text(
                                      'Perbesar',
                                      style: TextStyle(
                                        color: Colors.white,
                                        fontSize: 12,
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            ),

                            // File indicator
                            Positioned(
                              left: 8,
                              top: 8,
                              child: Container(
                                padding: EdgeInsets.symmetric(
                                    horizontal: 8, vertical: 4),
                                decoration: BoxDecoration(
                                  color: _primaryColor,
                                  borderRadius: BorderRadius.circular(12),
                                ),
                                child: Text(
                                  'Lampiran ${index + 1}',
                                  style: TextStyle(
                                    color: Colors.white,
                                    fontSize: 12,
                                    fontWeight: FontWeight.w500,
                                  ),
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  );
                },
              ),
      ],
    );
  }

  Widget _buildInfoRow(String label, String value) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        SizedBox(
          width: 120,
          child: Text(
            label,
            style: TextStyle(
              fontSize: 14,
              color: _lightTextColor,
            ),
          ),
        ),
        SizedBox(width: 12),
        Expanded(
          child: Text(
            value,
            style: TextStyle(
              fontSize: 15,
              fontWeight: FontWeight.w500,
              color: _textColor,
            ),
          ),
        ),
      ],
    );
  }
}
