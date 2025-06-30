import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:pelaporan_d3ti/models/laporan_kekerasan.dart';
import 'package:pelaporan_d3ti/services/api_service.dart';
import 'package:pelaporan_d3ti/components/sidebar_dosen.dart';
import 'package:intl/date_symbol_data_local.dart';

class DetailLaporanKekerasanDosenPage extends StatefulWidget {
  final LaporanKekerasan? laporan;
  final int id;

  const DetailLaporanKekerasanDosenPage({
    Key? key,
    this.laporan,
    required this.id,
  }) : super(key: key);

  @override
  _DetailLaporanKekerasanDosenPageState createState() =>
      _DetailLaporanKekerasanDosenPageState();
}

class _DetailLaporanKekerasanDosenPageState
    extends State<DetailLaporanKekerasanDosenPage> {
  final ApiService _apiService = ApiService();
  bool _loading = true;
  String? _error;
  LaporanKekerasan? _laporan;
  Map<int, String> _categories = {};
  bool _dateFormatInitialized = false;

  @override
  void initState() {
    super.initState();
    _initializeDateFormatting();
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
        _error = 'Error fetching data: $e';
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
      backgroundColor: Colors.white,
      appBar: AppBar(
        title: Text(
          'Detail Laporan Kekerasan',
          style: TextStyle(
            color: Colors.grey.shade800,
            fontWeight: FontWeight.w600,
          ),
        ),
        backgroundColor: Colors.white,
        elevation: 0,
        iconTheme: IconThemeData(color: Colors.grey.shade800),
        leading: IconButton(
          icon: Icon(Icons.arrow_back),
          onPressed: () => Navigator.of(context).pop(),
        ),
        actions: [
          IconButton(
            icon: Icon(Icons.refresh, color: Colors.red.shade700),
            onPressed: _fetchData,
            tooltip: 'Refresh data',
          ),
        ],
        bottom: PreferredSize(
          preferredSize: Size.fromHeight(1),
          child: Container(
            height: 1,
            color: Colors.grey.shade200,
          ),
        ),
      ),
      drawer: SidebarDosen(),
      body: _loading
          ? _buildLoadingView()
          : _error != null
              ? _buildErrorView()
              : _laporan == null
                  ? _buildNotFoundView()
                  : _buildDetailContent(),
    );
  }

  Widget _buildLoadingView() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          CircularProgressIndicator(
            valueColor: AlwaysStoppedAnimation<Color>(Colors.red),
            strokeWidth: 3,
          ),
          SizedBox(height: 20),
          Text(
            'Memuat data...',
            style: TextStyle(
              color: Colors.grey.shade700,
              fontSize: 16,
              fontWeight: FontWeight.w500,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildErrorView() {
    return Center(
      child: Container(
        width: double.infinity,
        margin: EdgeInsets.all(20),
        padding: EdgeInsets.all(24),
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
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              padding: EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: Colors.red.shade50,
                shape: BoxShape.circle,
              ),
              child: Icon(
                Icons.error_outline,
                size: 48,
                color: Colors.red,
              ),
            ),
            SizedBox(height: 24),
            Text(
              'Terjadi Kesalahan',
              style: TextStyle(
                fontSize: 20,
                fontWeight: FontWeight.bold,
                color: Colors.grey.shade800,
              ),
            ),
            SizedBox(height: 12),
            Text(
              _error ?? 'Terjadi kesalahan saat memuat data',
              textAlign: TextAlign.center,
              style: TextStyle(
                fontSize: 16,
                color: Colors.grey.shade600,
              ),
            ),
            SizedBox(height: 24),
            Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                ElevatedButton(
                  onPressed: _fetchData,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.red,
                    foregroundColor: Colors.white,
                    elevation: 0,
                    padding: EdgeInsets.symmetric(horizontal: 24, vertical: 12),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(8),
                    ),
                  ),
                  child: Text('Coba Lagi'),
                ),
                SizedBox(width: 16),
                OutlinedButton.icon(
                  onPressed: () => Navigator.of(context).pop(),
                  icon: Icon(Icons.arrow_back),
                  label: Text('Kembali ke Daftar'),
                  style: OutlinedButton.styleFrom(
                    foregroundColor: Colors.grey.shade700,
                    padding: EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                    side: BorderSide(color: Colors.grey.shade300),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(8),
                    ),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildNotFoundView() {
    return Center(
      child: Container(
        width: double.infinity,
        margin: EdgeInsets.all(20),
        padding: EdgeInsets.all(24),
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
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              padding: EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: Colors.grey.shade100,
                shape: BoxShape.circle,
              ),
              child: Icon(
                Icons.search_off_rounded,
                size: 48,
                color: Colors.grey.shade400,
              ),
            ),
            SizedBox(height: 24),
            Text(
              'Data Tidak Ditemukan',
              style: TextStyle(
                fontSize: 20,
                fontWeight: FontWeight.bold,
                color: Colors.grey.shade800,
              ),
            ),
            SizedBox(height: 12),
            Text(
              'Laporan dengan ID yang diminta tidak dapat ditemukan',
              textAlign: TextAlign.center,
              style: TextStyle(
                fontSize: 16,
                color: Colors.grey.shade600,
              ),
            ),
            SizedBox(height: 24),
            OutlinedButton.icon(
              onPressed: () => Navigator.of(context).pop(),
              icon: Icon(Icons.arrow_back),
              label: Text('Kembali ke Daftar'),
              style: OutlinedButton.styleFrom(
                foregroundColor: Colors.grey.shade700,
                padding: EdgeInsets.symmetric(horizontal: 20, vertical: 12),
                side: BorderSide(color: Colors.grey.shade300),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(8),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildDetailContent() {
    return SingleChildScrollView(
      physics: BouncingScrollPhysics(),
      child: Padding(
        padding: EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _buildHeaderSection(),
            SizedBox(height: 24),
            _buildDetailCard(
              title: 'Informasi Laporan',
              icon: Icons.info_outline,
              content: _buildLaporanInfo(),
            ),
            SizedBox(height: 24),
            _buildDetailCard(
              title: 'Deskripsi Kejadian',
              icon: Icons.description_outlined,
              content: _buildDeskripsiSection(),
            ),
            if (_laporan!.terlapor != null &&
                _laporan!.terlapor!.isNotEmpty) ...[
              SizedBox(height: 24),
              _buildDetailCard(
                title: 'Informasi Terlapor',
                icon: Icons.person_outline,
                content: _buildTerlaporSection(),
                headerColor: Colors.orange.shade700,
              ),
            ],
            if (_laporan!.saksi != null && _laporan!.saksi!.isNotEmpty) ...[
              SizedBox(height: 24),
              _buildDetailCard(
                title: 'Informasi Saksi',
                icon: Icons.people_outline,
                content: _buildSaksiSection(),
                headerColor: Colors.green.shade700,
              ),
            ],
            if (_laporan!.imagePath != null &&
                _laporan!.imagePath!.isNotEmpty) ...[
              SizedBox(height: 24),
              _buildDetailCard(
                title: 'Lampiran Bukti',
                icon: Icons.image_outlined,
                content: _buildImageSection(),
                headerColor: Colors.blue.shade700,
              ),
            ],
            SizedBox(height: 40),
            _buildBackToListButton(),
            SizedBox(height: 40),
          ],
        ),
      ),
    );
  }

  Widget _buildHeaderSection() {
    return Container(
      width: double.infinity,
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.03),
            blurRadius: 15,
            spreadRadius: 0,
            offset: Offset(0, 4),
          ),
        ],
      ),
      padding: EdgeInsets.all(20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Container(
                padding: EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: Colors.red.shade50,
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Icon(
                  Icons.privacy_tip_outlined,
                  color: Colors.red,
                  size: 24,
                ),
              ),
              SizedBox(width: 16),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Container(
                      padding:
                          EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                      decoration: BoxDecoration(
                        color: Colors.red.shade50,
                        borderRadius: BorderRadius.circular(20),
                        border: Border.all(color: Colors.red.shade100),
                      ),
                      child: Text(
                        _categories[_laporan!.categoryId] ??
                            'Kekerasan Seksual',
                        style: TextStyle(
                          color: Colors.red.shade700,
                          fontWeight: FontWeight.w600,
                          fontSize: 13,
                        ),
                      ),
                    ),
                    SizedBox(height: 12),
                    Text(
                      _laporan!.judul ?? 'Tidak ada judul',
                      style: TextStyle(
                        fontSize: 20,
                        fontWeight: FontWeight.bold,
                        color: Colors.grey.shade800,
                      ),
                    ),
                    SizedBox(height: 12),
                    Container(
                      padding: EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        color: Colors.grey.shade50,
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(color: Colors.grey.shade200),
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          _buildInfoItem(
                            icon: Icons.numbers_outlined,
                            label: 'Nomor Laporan',
                            value: _laporan!.nomorLaporanKekerasan ?? "-",
                          ),
                          SizedBox(height: 8),
                          _buildInfoItem(
                            icon: Icons.calendar_today_outlined,
                            label: 'Tanggal Laporan',
                            value: _formatDate(_laporan!.createdAt),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildDetailCard({
    required String title,
    required Widget content,
    required IconData icon,
    Color? headerColor,
  }) {
    return Container(
      width: double.infinity,
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.03),
            blurRadius: 15,
            spreadRadius: 0,
            offset: Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        children: [
          // Section header
          Container(
            padding: EdgeInsets.all(20),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.only(
                topLeft: Radius.circular(16),
                topRight: Radius.circular(16),
              ),
            ),
            child: Row(
              children: [
                Container(
                  padding: EdgeInsets.all(10),
                  decoration: BoxDecoration(
                    color: (headerColor ?? Colors.red).withOpacity(0.1),
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: Icon(
                    icon,
                    color: headerColor ?? Colors.red,
                    size: 20,
                  ),
                ),
                SizedBox(width: 16),
                Expanded(
                  child: Text(
                    title,
                    style: TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.w600,
                      color: headerColor ?? Colors.red,
                    ),
                  ),
                ),
              ],
            ),
          ),

          // Subtle divider
          Divider(height: 1, thickness: 1, color: Colors.grey.shade100),

          // Content section
          Padding(
            padding: EdgeInsets.all(20),
            child: content,
          ),
        ],
      ),
    );
  }

  Widget _buildLaporanInfo() {
    return Container(
      padding: EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.grey.shade50,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.grey.shade100),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _buildInfoRow(
            icon: Icons.person_outline,
            label: 'Nama Pelapor',
            value: _laporan!.namaPelapor ?? '-',
          ),
          SizedBox(height: 16),
          _buildInfoRow(
            icon: Icons.badge_outlined,
            label: 'NIM Pelapor',
            value: _laporan!.nimPelapor ?? '-',
          ),
          SizedBox(height: 16),
          _buildInfoRow(
            icon: Icons.phone_outlined,
            label: 'Nomor Telepon',
            value: _laporan!.nomorTelepon ?? '-',
          ),
          SizedBox(height: 16),
          _buildInfoRow(
            icon: Icons.event_outlined,
            label: 'Tanggal Kejadian',
            value: _formatDate(_laporan!.tanggalKejadian),
          ),
        ],
      ),
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
            color: Colors.grey.shade50,
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: Colors.grey.shade100),
          ),
          child: Text(
            _laporan!.deskripsi ?? 'Tidak ada deskripsi',
            style: TextStyle(
              fontSize: 15,
              color: Colors.grey.shade800,
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
              color: Colors.red,
            ),
          ),
          SizedBox(height: 12),
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: _laporan!.buktiPelanggaran!.map((bukti) {
              return Container(
                margin: EdgeInsets.only(bottom: 8),
                padding: EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(10),
                  border: Border.all(color: Colors.green.shade100),
                ),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Container(
                      padding: EdgeInsets.all(6),
                      decoration: BoxDecoration(
                        color: Colors.green.shade50,
                        shape: BoxShape.circle,
                      ),
                      child: Icon(
                        Icons.check,
                        size: 14,
                        color: Colors.green,
                      ),
                    ),
                    SizedBox(width: 12),
                    Expanded(
                      child: Text(
                        bukti,
                        style: TextStyle(
                          color: Colors.grey.shade800,
                          height: 1.4,
                        ),
                      ),
                    ),
                  ],
                ),
              );
            }).toList(),
          ),
        ],
      ],
    );
  }

  Widget _buildTerlaporSection() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: _laporan!.terlapor!.asMap().entries.map((entry) {
        final int index = entry.key;
        final terlapor = entry.value;

        return Container(
          width: double.infinity,
          margin: EdgeInsets.only(
              bottom: index < _laporan!.terlapor!.length - 1 ? 16 : 0),
          padding: EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: Colors.grey.shade50,
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: Colors.orange.shade100),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Container(
                padding: EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                decoration: BoxDecoration(
                  color: Colors.orange.shade50,
                  borderRadius: BorderRadius.circular(20),
                ),
                child: Text(
                  'Terlapor ${index + 1}',
                  style: TextStyle(
                    color: Colors.orange.shade700,
                    fontWeight: FontWeight.w600,
                    fontSize: 13,
                  ),
                ),
              ),
              SizedBox(height: 16),
              _buildInfoRow(
                icon: Icons.person_outline,
                label: 'Nama',
                value: terlapor.namaLengkap ?? '-',
              ),
              SizedBox(height: 12),
              _buildInfoRow(
                icon: Icons.email_outlined,
                label: 'Email',
                value: terlapor.email ?? '-',
              ),
              SizedBox(height: 12),
              _buildInfoRow(
                icon: Icons.phone_outlined,
                label: 'Nomor Telepon',
                value: terlapor.nomorTelepon ?? '-',
              ),
              SizedBox(height: 12),
              _buildInfoRow(
                icon: Icons.badge_outlined,
                label: 'Status',
                value: terlapor.statusWarga ?? '-',
              ),
              SizedBox(height: 12),
              _buildInfoRow(
                icon: Icons.person_outlined,
                label: 'Jenis Kelamin',
                value: terlapor.jenisKelamin ?? '-',
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
        final int index = entry.key;
        final saksi = entry.value;

        return Container(
          width: double.infinity,
          margin: EdgeInsets.only(
              bottom: index < _laporan!.saksi!.length - 1 ? 16 : 0),
          padding: EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: Colors.grey.shade50,
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: Colors.green.shade100),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Container(
                padding: EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                decoration: BoxDecoration(
                  color: Colors.green.shade50,
                  borderRadius: BorderRadius.circular(20),
                ),
                child: Text(
                  'Saksi ${index + 1}',
                  style: TextStyle(
                    color: Colors.green.shade700,
                    fontWeight: FontWeight.w600,
                    fontSize: 13,
                  ),
                ),
              ),
              SizedBox(height: 16),
              _buildInfoRow(
                icon: Icons.person_outline,
                label: 'Nama',
                value: saksi.namaLengkap ?? '-',
              ),
              SizedBox(height: 12),
              _buildInfoRow(
                icon: Icons.email_outlined,
                label: 'Email',
                value: saksi.email ?? '-',
              ),
              SizedBox(height: 12),
              _buildInfoRow(
                icon: Icons.phone_outlined,
                label: 'Nomor Telepon',
                value: saksi.nomorTelepon ?? '-',
              ),
            ],
          ),
        );
      }).toList(),
    );
  }

  Widget _buildImageSection() {
    if (_laporan!.imagePath == null || _laporan!.imagePath!.isEmpty) {
      return Container(
        padding: EdgeInsets.all(20),
        decoration: BoxDecoration(
          color: Colors.grey.shade50,
          borderRadius: BorderRadius.circular(12),
        ),
        child: Center(
          child: Column(
            children: [
              Icon(Icons.image_not_supported_outlined,
                  size: 48, color: Colors.grey.shade400),
              SizedBox(height: 16),
              Text(
                'Tidak ada gambar yang dilampirkan',
                style: TextStyle(color: Colors.grey.shade600),
              ),
            ],
          ),
        ),
      );
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: _laporan!.imagePath!.asMap().entries.map((entry) {
        final int index = entry.key;
        final String fileName = entry.value;

        // Construct full image URL
        final String baseUrl =
            //'http://pelaporan-d3ti.my.id/Backend-Port/backend/engine/public/storage/laporankekerasan/';
            'https://v3422040.mhs.d3tiuns.com/Backend-Port/backend/engine/public/storage/laporankekerasan/';
        final String imageUrl = '$baseUrl$fileName';

        return Container(
          width: double.infinity,
          margin: EdgeInsets.only(
              bottom: index < _laporan!.imagePath!.length - 1 ? 20 : 0),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Image label
              Container(
                margin: EdgeInsets.only(bottom: 12),
                padding: EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                decoration: BoxDecoration(
                  color: Colors.blue.shade50,
                  borderRadius: BorderRadius.circular(20),
                ),
                child: Text(
                  'Lampiran ${index + 1}',
                  style: TextStyle(
                    color: Colors.blue.shade700,
                    fontWeight: FontWeight.w600,
                    fontSize: 13,
                  ),
                ),
              ),

              // Image container
              Container(
                width: double.infinity,
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(12),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withOpacity(0.05),
                      blurRadius: 10,
                      spreadRadius: 0,
                      offset: Offset(0, 4),
                    ),
                  ],
                ),
                child: ClipRRect(
                  borderRadius: BorderRadius.circular(12),
                  child: Stack(
                    children: [
                      // Image with fixed height preview
                      _buildImagePreview(imageUrl, fileName),

                      // Zoom overlay icon
                      Positioned(
                        top: 12,
                        right: 12,
                        child: GestureDetector(
                          onTap: () => _openFullScreenImage(imageUrl, index),
                          child: Container(
                            padding: EdgeInsets.all(8),
                            decoration: BoxDecoration(
                              color: Colors.black.withOpacity(0.6),
                              borderRadius: BorderRadius.circular(8),
                            ),
                            child: Icon(
                              Icons.zoom_in,
                              color: Colors.white,
                              size: 20,
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
      }).toList(),
    );
  }

  Widget _buildImagePreview(String imageUrl, String fileName) {
    return GestureDetector(
      onTap: () => _openFullScreenImage(imageUrl, 0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Image container with fixed height
          Container(
            height: 200,
            width: double.infinity,
            child: Image.network(
              imageUrl,
              fit: BoxFit.cover,
              loadingBuilder: (context, child, progress) {
                if (progress == null) return child;
                return Container(
                  color: Colors.grey.shade100,
                  child: Center(
                    child: CircularProgressIndicator(
                      valueColor: AlwaysStoppedAnimation<Color>(Colors.blue),
                      value: progress.expectedTotalBytes != null
                          ? progress.cumulativeBytesLoaded /
                              progress.expectedTotalBytes!
                          : null,
                    ),
                  ),
                );
              },
              errorBuilder: (context, error, stackTrace) {
                return Container(
                  height: 200,
                  color: Colors.grey.shade100,
                  child: Center(
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(
                          Icons.broken_image_outlined,
                          size: 40,
                          color: Colors.grey.shade400,
                        ),
                        SizedBox(height: 12),
                        Text(
                          'Gagal memuat gambar',
                          style: TextStyle(
                            color: Colors.grey.shade600,
                          ),
                        ),
                      ],
                    ),
                  ),
                );
              },
            ),
          ),

          // Image details footer
          Container(
            width: double.infinity,
            padding: EdgeInsets.symmetric(horizontal: 16, vertical: 12),
            decoration: BoxDecoration(
              color: Colors.grey.shade50,
              border: Border(
                top: BorderSide(color: Colors.grey.shade100),
              ),
            ),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Expanded(
                  child: Text(
                    fileName,
                    style: TextStyle(
                      fontSize: 13,
                      color: Colors.grey.shade600,
                    ),
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
                Text(
                  'Ketuk untuk memperbesar',
                  style: TextStyle(
                    fontSize: 13,
                    color: Colors.blue,
                    fontWeight: FontWeight.w500,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  void _openFullScreenImage(String imageUrl, int index) {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => Scaffold(
          backgroundColor: Colors.black,
          appBar: AppBar(
            title: Text(
              'Lampiran ${index + 1}',
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
                      valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
                      value: progress.expectedTotalBytes != null
                          ? progress.cumulativeBytesLoaded /
                              progress.expectedTotalBytes!
                          : null,
                    ),
                  );
                },
                errorBuilder: (context, error, stackTrace) {
                  return Center(
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(Icons.broken_image_outlined,
                            size: 64, color: Colors.white60),
                        SizedBox(height: 20),
                        Text(
                          'Tidak dapat memuat gambar',
                          style: TextStyle(color: Colors.white),
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
  }

  Widget _buildInfoItem(
      {required IconData icon, required String label, required String value}) {
    return Row(
      children: [
        Container(
          padding: EdgeInsets.all(8),
          decoration: BoxDecoration(
            color: Colors.grey.shade100,
            borderRadius: BorderRadius.circular(8),
          ),
          child: Icon(
            icon,
            size: 16,
            color: Colors.grey.shade600,
          ),
        ),
        SizedBox(width: 12),
        Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              label,
              style: TextStyle(
                fontSize: 12,
                color: Colors.grey.shade500,
              ),
            ),
            SizedBox(height: 2),
            Text(
              value,
              style: TextStyle(
                fontSize: 14,
                color: Colors.grey.shade800,
                fontWeight: FontWeight.w500,
              ),
            ),
          ],
        ),
      ],
    );
  }

  Widget _buildInfoRow(
      {required IconData icon, required String label, required String value}) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Container(
          padding: EdgeInsets.all(8),
          decoration: BoxDecoration(
            color: Colors.grey.shade100,
            borderRadius: BorderRadius.circular(8),
          ),
          child: Icon(
            icon,
            size: 18,
            color: Colors.grey.shade600,
          ),
        ),
        SizedBox(width: 16),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                label,
                style: TextStyle(
                  fontSize: 13,
                  color: Colors.grey.shade500,
                ),
              ),
              SizedBox(height: 4),
              Text(
                value,
                style: TextStyle(
                  fontSize: 15,
                  color: Colors.grey.shade800,
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildBackToListButton() {
    return Center(
      child: OutlinedButton.icon(
        onPressed: () => Navigator.of(context).pop(),
        icon: Icon(Icons.arrow_back),
        label: Text('Kembali ke Daftar Laporan'),
        style: OutlinedButton.styleFrom(
          foregroundColor: Colors.grey.shade700,
          padding: EdgeInsets.symmetric(horizontal: 20, vertical: 12),
          side: BorderSide(color: Colors.grey.shade300),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(10),
          ),
        ),
      ),
    );
  }
}
