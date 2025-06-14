import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:pelaporan_d3ti/models/laporan_kekerasan.dart';
import 'package:pelaporan_d3ti/services/api_service.dart';
import 'package:pelaporan_d3ti/components/sidebar.dart';
import 'package:intl/date_symbol_data_local.dart';

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
      appBar: AppBar(
        title: Text('Detail Laporan Kekerasan'),
        backgroundColor: Color(0xFF00A2EA),
        leading: IconButton(
          icon: Icon(Icons.arrow_back),
          onPressed: () => Navigator.of(context).pop(),
        ),
        actions: [
          // Optional action buttons can be added here
          IconButton(
            icon: Icon(Icons.refresh),
            onPressed: _fetchData,
            tooltip: 'Refresh data',
          ),
        ],
      ),
      drawer: Sidebar(),
      body: _loading
          ? Center(child: CircularProgressIndicator())
          : _error != null
              ? _buildErrorWidget()
              : _laporan == null
                  ? Center(child: Text('Data tidak ditemukan'))
                  : _buildDetailContent(),
      floatingActionButton: FloatingActionButton(
        onPressed: () {
          Navigator.of(context).pop();
        },
        backgroundColor: Color(0xFF00A2EA),
        child: Icon(Icons.arrow_back),
        tooltip: 'Kembali',
      ),
      floatingActionButtonLocation: FloatingActionButtonLocation.endFloat,
    );
  }

  Widget _buildErrorWidget() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(Icons.error_outline, size: 48, color: Colors.red),
          SizedBox(height: 16),
          Text(_error ?? 'Terjadi kesalahan'),
          SizedBox(height: 16),
          ElevatedButton(
            onPressed: _fetchData,
            child: Text('Coba Lagi'),
          ),
          SizedBox(height: 24),
          ElevatedButton.icon(
            onPressed: () => Navigator.of(context).pop(),
            icon: Icon(Icons.arrow_back),
            label: Text('Kembali ke Daftar'),
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.grey[300],
              foregroundColor: Colors.black87,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildDetailContent() {
    return Stack(
      children: [
        SingleChildScrollView(
          padding: EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Back button at the top of the content
              _buildBackButton(),
              SizedBox(height: 8),

              _buildHeaderCard(),
              SizedBox(height: 16),
              _buildInfoCard('Informasi Laporan', _buildLaporanInfo()),
              SizedBox(height: 16),
              _buildInfoCard('Deskripsi Kejadian', _buildDeskripsiSection()),
              SizedBox(height: 16),
              if (_laporan!.terlapor != null && _laporan!.terlapor!.isNotEmpty)
                _buildInfoCard('Informasi Terlapor', _buildTerlaporSection()),
              SizedBox(height: 16),
              if (_laporan!.saksi != null && _laporan!.saksi!.isNotEmpty)
                _buildInfoCard('Informasi Saksi', _buildSaksiSection()),
              if (_laporan!.imagePath != null &&
                  _laporan!.imagePath!.isNotEmpty) ...[
                SizedBox(height: 16),
                _buildInfoCard('Lampiran Gambar', _buildImageSection()),
              ],
              SizedBox(
                  height: 80), // Space at bottom for floating action button
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildBackButton() {
    return ElevatedButton.icon(
      onPressed: () => Navigator.of(context).pop(),
      icon: Icon(Icons.arrow_back),
      label: Text('Kembali ke Daftar Laporan'),
      style: ElevatedButton.styleFrom(
        backgroundColor: Color(0xFF00A2EA).withOpacity(0.1),
        foregroundColor: Color(0xFF00A2EA),
        elevation: 0,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(8),
          side: BorderSide(color: Color(0xFF00A2EA).withOpacity(0.2)),
        ),
      ),
    );
  }

  Widget _buildHeaderCard() {
    return Card(
      elevation: 3,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: Padding(
        padding: EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Title first (full width)
            Text(
              _laporan!.judul ?? 'Tidak ada judul',
              style: TextStyle(
                fontSize: 20,
                fontWeight: FontWeight.bold,
              ),
            ),

            // Small spacing after title
            SizedBox(height: 8),

            // Category badge below the title
            Container(
              padding: EdgeInsets.symmetric(horizontal: 12, vertical: 6),
              decoration: BoxDecoration(
                color: Colors.red.withOpacity(0.1),
                borderRadius: BorderRadius.circular(16),
              ),
              child: Text(
                _categories[_laporan!.categoryId] ?? 'Kekerasan Seksual',
                style: TextStyle(
                  color: Colors.red,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ),

            // Other report information
            SizedBox(height: 12),
            Text(
              'Nomor Laporan: ${_laporan!.nomorLaporanKekerasan ?? "-"}',
              style: TextStyle(
                fontSize: 14,
                color: Colors.grey[600],
              ),
            ),
            SizedBox(height: 6),
            Text(
              'Tanggal Laporan Masuk: ${_formatDate(_laporan!.createdAt)}',
              style: TextStyle(
                fontSize: 14,
                color: Colors.grey[600],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildInfoCard(String title, Widget content) {
    return Card(
      elevation: 2,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: Padding(
        padding: EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              title,
              style: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.bold,
                color: Color(0xFF00A2EA),
              ),
            ),
            SizedBox(height: 16),
            content,
          ],
        ),
      ),
    );
  }

  Widget _buildLaporanInfo() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _buildInfoRow('Nama Pelapor', _laporan!.namaPelapor ?? '-'),
        SizedBox(height: 8),
        _buildInfoRow('NIM Pelapor', _laporan!.nimPelapor ?? '-'),
        SizedBox(height: 8),
        _buildInfoRow('Nomor Telepon', _laporan!.nomorTelepon ?? '-'),
        SizedBox(height: 8),
        _buildInfoRow(
            'Tanggal Kejadian', _formatDate(_laporan!.tanggalKejadian)),
      ],
    );
  }

  Widget _buildDeskripsiSection() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          _laporan!.deskripsi ?? 'Tidak ada deskripsi',
          style: TextStyle(fontSize: 16),
        ),
        if (_laporan!.buktiPelanggaran != null &&
            _laporan!.buktiPelanggaran!.isNotEmpty) ...[
          SizedBox(height: 16),
          Text(
            'Bukti Pelanggaran:',
            style: TextStyle(
              fontWeight: FontWeight.bold,
              color: Color(0xFF00A2EA),
            ),
          ),
          SizedBox(height: 8),
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: _laporan!.buktiPelanggaran!
                .map((bukti) => Padding(
                      padding: const EdgeInsets.only(bottom: 6),
                      child: Row(
                        children: [
                          Icon(Icons.check_circle,
                              size: 16, color: Colors.green),
                          SizedBox(width: 8),
                          Expanded(child: Text(bukti)),
                        ],
                      ),
                    ))
                .toList(),
          ),
        ],
      ],
    );
  }

  Widget _buildTerlaporSection() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: _laporan!.terlapor!.map((terlapor) {
        return Card(
          color: Colors.grey[50],
          margin: EdgeInsets.only(bottom: 12),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
          child: Padding(
            padding: EdgeInsets.all(12),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                _buildInfoRow('Nama', terlapor.namaLengkap ?? '-'),
                SizedBox(height: 8),
                _buildInfoRow('Email', terlapor.email ?? '-'),
                SizedBox(height: 8),
                _buildInfoRow('Nomor Telepon', terlapor.nomorTelepon ?? '-'),
                SizedBox(height: 8),
                _buildInfoRow('Status', terlapor.statusWarga ?? '-'),
                SizedBox(height: 8),
                _buildInfoRow('Jenis Kelamin', terlapor.jenisKelamin ?? '-'),
              ],
            ),
          ),
        );
      }).toList(),
    );
  }

  Widget _buildSaksiSection() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: _laporan!.saksi!.map((saksi) {
        return Card(
          color: Colors.grey[50],
          margin: EdgeInsets.only(bottom: 12),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
          child: Padding(
            padding: EdgeInsets.all(12),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                _buildInfoRow('Nama', saksi.namaLengkap ?? '-'),
                SizedBox(height: 8),
                _buildInfoRow('Email', saksi.email ?? '-'),
                SizedBox(height: 8),
                _buildInfoRow('Nomor Telepon', saksi.nomorTelepon ?? '-'),
              ],
            ),
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
            ? Text('Tidak ada gambar yang dilampirkan')
            : Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: _laporan!.imagePath!.asMap().entries.map((entry) {
                  final int index = entry.key;
                  final String fileName = entry.value;

                  // Update the base URL to the production URL
                  final String baseUrl =
                      'https://v3422040.mhs.d3tiuns.com/Backend-Port/backend/engine/public/storage/laporankekerasan/';
                  final String imageUrl = '$baseUrl$fileName';

                  return Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      if (index > 0) SizedBox(height: 16),

                      // Image label
                      Padding(
                        padding: const EdgeInsets.only(bottom: 8.0),
                        child: Text(
                          'Lampiran ${index + 1}',
                          style: TextStyle(fontWeight: FontWeight.bold),
                        ),
                      ),

                      // Image display with error handling
                      ClipRRect(
                        borderRadius: BorderRadius.circular(8),
                        child: Container(
                          decoration: BoxDecoration(
                            border: Border.all(color: Colors.grey.shade300),
                            borderRadius: BorderRadius.circular(8),
                          ),
                          child: InkWell(
                            onTap: () {
                              // Show full-screen image view when tapped
                              Navigator.push(
                                context,
                                MaterialPageRoute(
                                  builder: (context) => Scaffold(
                                    appBar: AppBar(
                                      title:
                                          Text('Gambar Lampiran ${index + 1}'),
                                      backgroundColor: Color(0xFF00A2EA),
                                    ),
                                    body: Center(
                                      child: InteractiveViewer(
                                        minScale: 0.5,
                                        maxScale: 4.0,
                                        child: Image.network(
                                          imageUrl,
                                          fit: BoxFit.contain,
                                          loadingBuilder:
                                              (context, child, progress) {
                                            if (progress == null) return child;
                                            return Center(
                                                child:
                                                    CircularProgressIndicator());
                                          },
                                          errorBuilder:
                                              (context, error, stackTrace) {
                                            print(
                                                "Full image error: $error for URL: $imageUrl");
                                            return Center(
                                              child: Column(
                                                mainAxisAlignment:
                                                    MainAxisAlignment.center,
                                                children: [
                                                  Icon(Icons.broken_image,
                                                      size: 50,
                                                      color: Colors.grey),
                                                  SizedBox(height: 16),
                                                  Text(
                                                    'Tidak dapat memuat gambar',
                                                    style: TextStyle(
                                                        color:
                                                            Colors.grey[700]),
                                                  ),
                                                  SizedBox(height: 8),
                                                  Text(
                                                    fileName,
                                                    style: TextStyle(
                                                        fontSize: 12,
                                                        color: Colors.grey),
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
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                // Fixed height container for the image
                                Container(
                                  height: 180, // Fixed height for all images
                                  width: double.infinity,
                                  child: Stack(
                                    alignment: Alignment.center,
                                    children: [
                                      // Thumbnail image with consistent size
                                      Image.network(
                                        imageUrl,
                                        fit: BoxFit.cover,
                                        height: 180,
                                        width: double.infinity,
                                        loadingBuilder:
                                            (context, child, progress) {
                                          if (progress == null) return child;
                                          return Center(
                                            child: CircularProgressIndicator(
                                              value: progress
                                                          .expectedTotalBytes !=
                                                      null
                                                  ? progress
                                                          .cumulativeBytesLoaded /
                                                      progress
                                                          .expectedTotalBytes!
                                                  : null,
                                            ),
                                          );
                                        },
                                        errorBuilder:
                                            (context, error, stackTrace) {
                                          print(
                                              "Thumbnail error: $error for URL: $imageUrl");
                                          return Center(
                                            child: Column(
                                              mainAxisAlignment:
                                                  MainAxisAlignment.center,
                                              children: [
                                                Icon(Icons.image_not_supported,
                                                    size: 40,
                                                    color: Colors.grey),
                                                SizedBox(height: 8),
                                                Text(
                                                  'File: $fileName',
                                                  style:
                                                      TextStyle(fontSize: 12),
                                                ),
                                              ],
                                            ),
                                          );
                                        },
                                      ),

                                      // Overlay to indicate image is clickable
                                      Positioned(
                                        right: 8,
                                        bottom: 8,
                                        child: Container(
                                          padding: EdgeInsets.symmetric(
                                              horizontal: 8, vertical: 4),
                                          decoration: BoxDecoration(
                                            color: Colors.black54,
                                            borderRadius:
                                                BorderRadius.circular(12),
                                          ),
                                          child: Row(
                                            mainAxisSize: MainAxisSize.min,
                                            children: [
                                              Icon(
                                                Icons.zoom_in,
                                                color: Colors.white,
                                                size: 16,
                                              ),
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
                                    ],
                                  ),
                                ),

                                // File name footer
                                Container(
                                  padding: EdgeInsets.all(8),
                                  width: double.infinity,
                                  decoration: BoxDecoration(
                                    color: Colors.grey[200],
                                  ),
                                  child: Row(
                                    mainAxisAlignment:
                                        MainAxisAlignment.spaceBetween,
                                    children: [
                                      Expanded(
                                        child: Text(
                                          fileName,
                                          style: TextStyle(fontSize: 12),
                                          overflow: TextOverflow.ellipsis,
                                        ),
                                      ),
                                      Text(
                                        'Klik untuk memperbesar',
                                        style: TextStyle(
                                          fontSize: 11,
                                          color: Colors.grey[700],
                                          fontStyle: FontStyle.italic,
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ),
                      ),
                    ],
                  );
                }).toList(),
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
              fontWeight: FontWeight.bold,
              color: Colors.grey[700],
            ),
          ),
        ),
        SizedBox(width: 8),
        Expanded(
          child: Text(
            value,
            style: TextStyle(
              fontSize: 15,
            ),
          ),
        ),
      ],
    );
  }
}
