import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:pelaporan_d3ti/services/api_service.dart';
import 'package:pelaporan_d3ti/services/token_manager.dart';
import 'package:pelaporan_d3ti/components/sidebar_dosen.dart'; // Assuming you have a sidebar for dosen
import 'package:intl/intl.dart';
import 'package:intl/date_symbol_data_local.dart';
import 'package:pelaporan_d3ti/models/laporan.dart';
import 'package:pelaporan_d3ti/models/laporan_kekerasan.dart';

class HomeScreenDosen extends StatefulWidget {
  const HomeScreenDosen({Key? key}) : super(key: key);

  @override
  _HomeScreenDosenState createState() => _HomeScreenDosenState();
}

class _HomeScreenDosenState extends State<HomeScreenDosen> {
  final ApiService _apiService = ApiService();
  final GlobalKey<ScaffoldState> _scaffoldKey = GlobalKey<ScaffoldState>();

  // User info
  String _userName = "";
  String? _userEmail;
  String? _userRole;
  bool _isLoadingUser = true;

  // Loading states
  bool _isLoadingReports = true;
  String? _error;

  // Dashboard statistics
  int _totalLaporan = 0;
  int _dalamProses = 0;
  int _selesai = 0;
  int _belumDiverifikasi = 0;
  int _ditolak = 0;

  // Report data
  List<Laporan> _laporan = [];
  String? _currentUserNip;
  String? _currentUserName;
  List<Laporan> _userMatchingReports = [];
  int _countMatchingReports = 0;

  // Kekerasan reports
  List<LaporanKekerasan> _laporanKekerasan = [];
  int _totalLaporanKekerasan = 0;
  bool _isLoadingKekerasanReports = true;

  @override
  void initState() {
    super.initState();
    initializeDateFormatting('id_ID', null);
    _loadUserData();
    _fetchReports();
    _fetchKekerasanReports();
  }

  Future<void> _loadUserData() async {
    setState(() {
      _isLoadingUser = true;
    });

    try {
      // First check if we have cached user data
      final prefs = await SharedPreferences.getInstance();
      final userData = prefs.getString('user_data');

      // Get the user name and NIP for dosen
      _currentUserName = prefs.getString('user_name');
      _currentUserNip = prefs.getString('user_nip');

      if (_currentUserName == null || _currentUserName!.isEmpty) {
        _currentUserName = "Dosen";
      }

      if (userData != null) {
        // Use cached data
        Map<String, dynamic> data = {};
        try {
          data = Map<String, dynamic>.from(
              await prefs.getString('user_data') != null
                  ? (await prefs.getString('user_data') as Map<String, dynamic>)
                  : {});
        } catch (e) {
          print("Error parsing user data: $e");
        }

        setState(() {
          _userName = _currentUserName ?? "Dosen";
          _userEmail = data['email'] ?? prefs.getString('user_email');
          _userRole = data['role'] ?? prefs.getString('user_role');
          _isLoadingUser = false;
        });
      } else {
        setState(() {
          _userName = _currentUserName ?? "Dosen";
          _userEmail = prefs.getString('user_email');
          _userRole = prefs.getString('user_role');
          _isLoadingUser = false;
        });
      }
    } catch (e) {
      print('Error loading user data: $e');
      setState(() {
        _userName = "Dosen";
        _isLoadingUser = false;
      });
    }
  }

  Future<void> _fetchReports() async {
    setState(() {
      _isLoadingReports = true;
      _error = null;
    });
    try {
      // Fetch all reports
      final laporanResponse = await _apiService.getLaporan();
      if (laporanResponse.isNotEmpty) {
        // Debug: Print dates before sorting
        print(
            'Before sorting - first item date: ${laporanResponse.first.createdAt}');

        // Sort the reports in descending order (newest first)
        laporanResponse.sort((a, b) {
          // Safely handle null dates by providing a fallback
          DateTime dateA =
              a.createdAt ?? DateTime.fromMillisecondsSinceEpoch(0);
          DateTime dateB =
              b.createdAt ?? DateTime.fromMillisecondsSinceEpoch(0);
          // For descending order: compare B to A (newer dates first)
          return dateB.compareTo(dateA);
        });

        // Debug: Print dates after sorting
        print(
            'After sorting - first item date: ${laporanResponse.first.createdAt}');

        setState(() {
          _laporan = laporanResponse;
        });

        // Filter reports for the current user and update statistics
        _filterUserReports();
      }

      setState(() {
        _isLoadingReports = false;
      });
    } catch (e) {
      setState(() {
        _error = "Gagal memuat data: $e";
        _isLoadingReports = false;
      });
      print('Error fetching reports: $e');
    }
  }

  Future<void> _fetchKekerasanReports() async {
    setState(() {
      _isLoadingKekerasanReports = true;
    });

    try {
      // Fetch kekerasan reports
      final laporanResponse = await _apiService.getLaporanKekerasan();

      if (laporanResponse.isNotEmpty) {
        // Debug: Print dates before sorting
        print(
            'Before sorting kekerasan - first item date: ${laporanResponse.first.createdAt}');

        // Sort the reports in descending order (newest first)
        laporanResponse.sort((a, b) {
          // Safely handle null dates by providing a fallback
          DateTime dateA =
              a.createdAt ?? DateTime.fromMillisecondsSinceEpoch(0);
          DateTime dateB =
              b.createdAt ?? DateTime.fromMillisecondsSinceEpoch(0);
          // For descending order: compare B to A (newer dates first)
          return dateB.compareTo(dateA);
        });

        // Debug: Print dates after sorting
        print(
            'After sorting kekerasan - first item date: ${laporanResponse.first.createdAt}');

        setState(() {
          _laporanKekerasan = laporanResponse;
          _totalLaporanKekerasan = laporanResponse.length;
        });
      }

      setState(() {
        _isLoadingKekerasanReports = false;
      });
    } catch (e) {
      setState(() {
        _isLoadingKekerasanReports = false;
      });
      print('Error fetching kekerasan reports: $e');
    }
  }

  // Calculate statistics from reports
  void _calculateStats(List<Laporan> reports) {
    int pending = 0;
    int processed = 0;
    int completed = 0;
    int rejected = 0;

    for (var report in reports) {
      if (report.status == 'unverified') {
        pending++;
      } else if (report.status == 'verified') {
        processed++;
      } else if (report.status == 'finished') {
        completed++;
      } else if (report.status == 'rejected') {
        rejected++;
      }
    }

    setState(() {
      _totalLaporan = reports.length;
      _belumDiverifikasi = pending;
      _dalamProses = processed;
      _selesai = completed;
      _ditolak = rejected;
    });
  }

  // In _HomeScreenDosenState class, update or add this method:

  void _filterUserReports() {
    if (_currentUserName == null && _currentUserNip == null) {
      setState(() {
        _userMatchingReports = [];
        _countMatchingReports = 0;
      });
      print("No user info available. Not filtering reports.");
      return;
    }

    print(
        "Filtering reports for dosen: $_currentUserName (NIP: $_currentUserNip)");

    // Filter based on the current logged-in user's information
    List<Laporan> filteredReports = _laporan.where((report) {
      bool matchesByNip = false;
      bool matchesByName = false;

      if (_currentUserNip != null &&
          _currentUserNip!.isNotEmpty &&
          report.niPelapor != null) {
        matchesByNip =
            report.niPelapor!.toLowerCase() == _currentUserNip!.toLowerCase();
      }

      if (_currentUserName != null &&
          _currentUserName!.isNotEmpty &&
          report.namaPelapor != null) {
        matchesByName = report.namaPelapor!.toLowerCase() ==
            _currentUserName!.toLowerCase();
      }

      return matchesByNip || matchesByName;
    }).toList();

    setState(() {
      _userMatchingReports = filteredReports;
      _countMatchingReports = filteredReports.length;

      // Update the statistics based on the filtered reports for the current user
      _calculateStats(_userMatchingReports);
    });

    print(
        'Filtered ${_laporan.length} reports down to ${_userMatchingReports.length} for user $_currentUserName');
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      key: _scaffoldKey,
      appBar: AppBar(
        title: const Text('Dashboard Dosen'),
        leading: IconButton(
          icon: const Icon(Icons.menu),
          onPressed: () {
            _scaffoldKey.currentState?.openDrawer();
          },
        ),
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh),
            onPressed: () {
              _fetchReports();
              _loadUserData();
              _fetchKekerasanReports();
            },
          ),
        ],
      ),
      drawer: SidebarDosen(), // Use the dosen sidebar
      body: _buildBody(),
    );
  }

  Widget _buildBody() {
    return SafeArea(
      child: RefreshIndicator(
        onRefresh: () async {
          await _loadUserData();
          await _fetchReports();
          await _fetchKekerasanReports();
        },
        child: SingleChildScrollView(
          physics: const AlwaysScrollableScrollPhysics(),
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              _buildWelcomeCard(),
              const SizedBox(height: 24),

              _buildUrgentReportButton(),
              const SizedBox(height: 24),

              _buildSexualHarassmentReportButton(),
              const SizedBox(height: 24),

              // Statistics section
              _buildDashboardStats(),
              const SizedBox(height: 24),

              // Recent reports to verify/handle
              _buildPendingVerificationSection(),
              const SizedBox(height: 24),

              // Kekerasan sexual reports section (if professor has access)
              _buildKekerasanReportsSection(),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildWelcomeCard() {
    return Card(
      elevation: 4,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
      ),
      child: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                const CircleAvatar(
                  radius: 24,
                  backgroundColor: Colors.indigo,
                  child: Icon(Icons.school, color: Colors.white, size: 30),
                ),
                const SizedBox(width: 16),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        _isLoadingUser
                            ? "Loading..."
                            : "Selamat datang, $_userName",
                        style: Theme.of(context).textTheme.titleLarge?.copyWith(
                              fontWeight: FontWeight.bold,
                            ),
                      ),
                      Text(
                        _userRole != null
                            ? "Role: $_userRole"
                            : "Dashboard Pelaporan D3TI UNS",
                        style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                              color: Colors.grey[600],
                            ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
            const SizedBox(height: 16),
            Text(
              'Hari ini: ${DateFormat('EEEE, dd MMMM yyyy', 'id_ID').format(DateTime.now())}',
              style: TextStyle(color: Colors.grey[700]),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildUrgentReportButton() {
    return Card(
      elevation: 4,
      color: Colors.purple.shade50,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
        side: BorderSide(color: Colors.purple.shade200, width: 1),
      ),
      child: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          children: [
            Row(
              children: [
                Icon(
                  Icons.warning_rounded,
                  color: Colors.purple,
                  size: 30,
                ),
                SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Terjadi Kejadian Darurat dan Mendesak?',
                        style: TextStyle(
                          fontWeight: FontWeight.bold,
                          fontSize: 16,
                        ),
                      ),
                      SizedBox(height: 4),
                      Text(
                        'Segera laporkan kejadian darurat dan mendesak yang membutuhkan penanganan cepat',
                        style: TextStyle(
                          fontSize: 13,
                          color: Colors.grey[700],
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
            SizedBox(height: 16),
            SizedBox(
              width: double.infinity,
              child: ElevatedButton(
                onPressed: () {
                  Navigator.pushNamed(context, '/addlaporpkmendesakdosen');
                },
                style: ElevatedButton.styleFrom(
                  padding: const EdgeInsets.symmetric(vertical: 12),
                  backgroundColor: Colors.purple,
                  foregroundColor: Colors.white,
                  elevation: 3,
                ),
                child: const Text(
                  'Tambah Laporan Mendesak',
                  style: TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.bold,
                    letterSpacing: 0.3,
                  ),
                  textAlign: TextAlign.center,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  // Create a method for the sexual harassment report button
  Widget _buildSexualHarassmentReportButton() {
    return Card(
      elevation: 4,
      color: Colors.red.shade50,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
        side: BorderSide(color: Colors.red.shade200, width: 1),
      ),
      child: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          children: [
            Row(
              children: [
                Icon(
                  Icons.privacy_tip_rounded,
                  color: Colors.red,
                  size: 30,
                ),
                SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Melaporkan Kasus Kekerasan Seksual',
                        style: TextStyle(
                          fontWeight: FontWeight.bold,
                          fontSize: 16,
                        ),
                      ),
                      SizedBox(height: 4),
                      Text(
                        'Laporkan dengan aman dan privasi terjaga. Semua laporan ditangani dengan kerahasiaan penuh',
                        style: TextStyle(
                          fontSize: 13,
                          color: Colors.grey[700],
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
            SizedBox(height: 16),
            SizedBox(
              width: double.infinity,
              child: ElevatedButton(
                onPressed: () {
                  Navigator.pushNamed(context, '/addlaporksdosen');
                },
                style: ElevatedButton.styleFrom(
                  padding: const EdgeInsets.symmetric(vertical: 12),
                  backgroundColor: Colors.red,
                  foregroundColor: Colors.white,
                  elevation: 3,
                ),
                child: const Text(
                  'Laporkan Kekerasan Seksual',
                  style: TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.bold,
                    letterSpacing: 0.3,
                  ),
                  textAlign: TextAlign.center,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildDashboardStats() {
    if (_isLoadingReports) {
      return Center(
        child: CircularProgressIndicator(),
      );
    }

    if (_error != null) {
      return Card(
        elevation: 2,
        child: Padding(
          padding: const EdgeInsets.all(16.0),
          child: Column(
            children: [
              Icon(Icons.error_outline, color: Colors.red, size: 48),
              SizedBox(height: 16),
              Text(_error!, textAlign: TextAlign.center),
              SizedBox(height: 16),
              ElevatedButton(
                onPressed: _fetchReports,
                child: Text('Coba Lagi'),
              ),
            ],
          ),
        ),
      );
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.only(left: 4.0, bottom: 16.0),
          child: Text(
            'Statistik Laporan',
            style: TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.bold,
            ),
          ),
        ),
        // Overview card
        Card(
          elevation: 3,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(16),
          ),
          child: Container(
            padding: EdgeInsets.all(16.0),
            width: double.infinity,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Container(
                      padding: EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        color: Colors.indigo.withOpacity(0.1),
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: Icon(
                        Icons.assignment,
                        color: Colors.indigo,
                        size: 28,
                      ),
                    ),
                    SizedBox(width: 16),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'Total Semua Laporan',
                            style: TextStyle(
                              fontSize: 16,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                          SizedBox(height: 8),
                          Text(
                            '$_totalLaporan Laporan',
                            style: TextStyle(
                              fontSize: 18,
                              fontWeight: FontWeight.bold,
                              color: Colors.indigo,
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
        ),
        SizedBox(height: 16),
        // 2x2 Grid for statistics cards
        GridView.count(
          crossAxisCount: 2,
          crossAxisSpacing: 12.0,
          mainAxisSpacing: 12.0,
          shrinkWrap: true,
          physics: NeverScrollableScrollPhysics(),
          children: [
            _buildStatCard(
              icon: Icons.hourglass_empty,
              iconColor: Colors.amber,
              title: 'Perlu Verifikasi',
              count: _belumDiverifikasi,
            ),
            _buildStatCard(
              icon: Icons.pending_actions,
              iconColor: Colors.orange,
              title: 'Dalam Proses',
              count: _dalamProses,
            ),
            _buildStatCard(
              icon: Icons.check_circle,
              iconColor: Colors.green,
              title: 'Selesai',
              count: _selesai,
            ),
            _buildStatCard(
              icon: Icons.cancel,
              iconColor: Colors.red,
              title: 'Ditolak',
              count: _ditolak,
            ),
          ],
        ),
        SizedBox(height: 16),
        // Kekerasan sexual reports stat card
        Card(
          elevation: 3,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(16),
          ),
          child: Container(
            padding: EdgeInsets.all(16.0),
            width: double.infinity,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Container(
                      padding: EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        color: Colors.red.withOpacity(0.1),
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: Icon(
                        Icons.privacy_tip_rounded,
                        color: Colors.red,
                        size: 28,
                      ),
                    ),
                    SizedBox(width: 16),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'Laporan Kekerasan Seksual',
                            style: TextStyle(
                              fontSize: 16,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                          SizedBox(height: 8),
                          Text(
                            'Total: $_totalLaporanKekerasan',
                            style: TextStyle(
                              fontSize: 18,
                              fontWeight: FontWeight.bold,
                              color: Colors.red,
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
        ),
      ],
    );
  }

  Widget _buildStatCard({
    required IconData icon,
    required Color iconColor,
    required String title,
    required int count,
  }) {
    return Card(
      elevation: 3,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(16),
      ),
      child: Container(
        padding: EdgeInsets.all(16.0),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          crossAxisAlignment: CrossAxisAlignment.center,
          children: [
            Container(
              padding: EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: iconColor.withOpacity(0.1),
                borderRadius: BorderRadius.circular(12),
              ),
              child: Icon(
                icon,
                color: iconColor,
                size: 28,
              ),
            ),
            Spacer(),
            Text(
              count.toString(),
              style: TextStyle(
                fontSize: 28,
                fontWeight: FontWeight.bold,
              ),
            ),
            SizedBox(height: 8),
            Text(
              title,
              style: TextStyle(
                fontSize: 14,
                color: Colors.grey[700],
              ),
              textAlign: TextAlign.center,
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildPendingVerificationSection() {
    // Filter reports to only show those created by the current user
    final userReports = _userMatchingReports.take(3).toList();

    return Card(
      elevation: 4,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Laporan Kejadian',
              style: Theme.of(context).textTheme.titleLarge,
            ),
            const SizedBox(height: 16),
            _isLoadingReports
                ? Center(child: CircularProgressIndicator())
                : userReports.isNotEmpty
                    ? Column(
                        children: userReports
                            .map((report) => _buildReportItem(report))
                            .toList(),
                      )
                    : Center(
                        child: Padding(
                          padding: const EdgeInsets.symmetric(vertical: 24.0),
                          child: Column(
                            children: [
                              Icon(
                                Icons.info_outline,
                                size: 48,
                                color: Colors.blue,
                              ),
                              SizedBox(height: 12),
                              Text(
                                'Belum ada laporan yang Anda buat',
                                style: TextStyle(color: Colors.grey),
                              ),
                            ],
                          ),
                        ),
                      ),
            const SizedBox(height: 24),
            SizedBox(
              width: double.infinity,
              child: ElevatedButton(
                onPressed: () {
                  Navigator.pushNamed(context, '/my-reports');
                },
                style: ElevatedButton.styleFrom(
                  padding: const EdgeInsets.symmetric(vertical: 12),
                  backgroundColor: Colors.blue,
                  foregroundColor: Colors.white,
                  elevation: 2,
                ),
                child: const Text(
                  'Lihat Semua Laporan Anda',
                  style: TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.bold,
                    letterSpacing: 0.3,
                  ),
                  textAlign: TextAlign.center,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildReportItem(Laporan report) {
    // Format the date relative to current time
    String formattedDate = 'No date';
    if (report.createdAt != null) {
      final now = DateTime.now();
      final difference = now.difference(report.createdAt!);

      if (difference.inDays == 0) {
        if (difference.inHours == 0) {
          formattedDate = '${difference.inMinutes} menit yang lalu';
        } else {
          formattedDate = '${difference.inHours} jam yang lalu';
        }
      } else if (difference.inDays < 7) {
        formattedDate = '${difference.inDays} hari yang lalu';
      } else {
        formattedDate = DateFormat('dd MMM yyyy').format(report.createdAt!);
      }
    }

    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8.0),
      child: InkWell(
        onTap: () {
          if (report.id != null) {
            // Navigate to report detail page
            Navigator.pushNamed(
              context,
              '/report-detail',
              arguments: report.id,
            );
          }
        },
        borderRadius: BorderRadius.circular(8),
        child: Container(
          padding: EdgeInsets.all(12),
          decoration: BoxDecoration(
            border: Border.all(color: Colors.grey.shade200),
            borderRadius: BorderRadius.circular(8),
          ),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Container(
                width: 42,
                height: 42,
                decoration: BoxDecoration(
                  color: Colors.amber.withOpacity(0.1),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Icon(
                  Icons.hourglass_empty,
                  color: Colors.amber,
                  size: 24,
                ),
              ),
              SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      report.judul ?? 'No Title',
                      style: TextStyle(
                        fontWeight: FontWeight.bold,
                        fontSize: 15,
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                    SizedBox(height: 4),
                    Row(
                      children: [
                        Icon(Icons.access_time,
                            size: 12, color: Colors.grey[600]),
                        SizedBox(width: 4),
                        Text(
                          formattedDate,
                          style: TextStyle(
                            fontSize: 12,
                            color: Colors.grey[600],
                          ),
                        ),
                      ],
                    ),
                    SizedBox(height: 4),
                    Text(
                      'Pelapor: ${report.namaPelapor ?? 'Unknown'}',
                      style: TextStyle(
                        fontSize: 12,
                        color: Colors.grey[700],
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                    SizedBox(height: 8),
                    Container(
                      padding: EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                      decoration: BoxDecoration(
                        color: Colors.amber.withOpacity(0.1),
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: Text(
                        'Perlu Verifikasi',
                        style: TextStyle(
                          fontSize: 12,
                          color: Colors.amber[800],
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
              Icon(
                Icons.arrow_forward_ios,
                size: 14,
                color: Colors.grey,
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildKekerasanReportsSection() {
    return Card(
      elevation: 4,
      color: Colors.red[50],
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Container(
                  padding: EdgeInsets.only(top: 4),
                  child: Icon(Icons.privacy_tip_outlined,
                      color: Colors.red, size: 24),
                ),
                SizedBox(width: 8),
                Expanded(
                  child: Text(
                    'Laporan Kekerasan Seksual',
                    style: TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                      color: Colors.red[800],
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 16),
            _isLoadingKekerasanReports
                ? Center(child: CircularProgressIndicator(color: Colors.red))
                : _laporanKekerasan.isNotEmpty
                    ? Column(
                        children: _laporanKekerasan
                            .take(3)
                            .map((report) => _buildKekerasanReportItem(report))
                            .toList(),
                      )
                    : Center(
                        child: Padding(
                          padding: const EdgeInsets.symmetric(vertical: 24.0),
                          child: Column(
                            children: [
                              Icon(
                                Icons.folder_open,
                                size: 48,
                                color: Colors.red[300],
                              ),
                              SizedBox(height: 12),
                              Text(
                                'Tidak ada laporan kekerasan seksual',
                                style: TextStyle(
                                  color: Colors.red[400],
                                  fontStyle: FontStyle.italic,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
            const SizedBox(height: 16),
            SizedBox(
              width: double.infinity,
              child: ElevatedButton(
                onPressed: () {
                  Navigator.pushNamed(context, '/violence-reports');
                },
                style: ElevatedButton.styleFrom(
                  padding: const EdgeInsets.symmetric(vertical: 12),
                  backgroundColor: Colors.red,
                  foregroundColor: Colors.white,
                  elevation: 2,
                ),
                child: const Text(
                  'Lihat Semua Laporan Kekerasan Seksual',
                  style: TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.bold,
                    letterSpacing: 0.3,
                  ),
                  textAlign: TextAlign.center,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildKekerasanReportItem(LaporanKekerasan report) {
    // Format the date relative to current time
    String formattedDate = 'No date';
    if (report.createdAt != null) {
      final now = DateTime.now();
      final difference = now.difference(report.createdAt!);

      if (difference.inDays == 0) {
        if (difference.inHours == 0) {
          formattedDate = '${difference.inMinutes} menit yang lalu';
        } else {
          formattedDate = '${difference.inHours} jam yang lalu';
        }
      } else if (difference.inDays < 7) {
        formattedDate = '${difference.inDays} hari yang lalu';
      } else {
        formattedDate = DateFormat('dd MMM yyyy').format(report.createdAt!);
      }
    }

    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8.0),
      child: InkWell(
        onTap: () {
          if (report.id != null) {
            // Navigate to kekerasan report detail
            Navigator.pushNamed(
              context,
              '/ks-report-detail',
              arguments: report.id,
            );
          }
        },
        borderRadius: BorderRadius.circular(8),
        child: Container(
          padding: EdgeInsets.all(12),
          decoration: BoxDecoration(
            color: Colors.white,
            border: Border.all(color: Colors.red.shade200),
            borderRadius: BorderRadius.circular(8),
          ),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Container(
                width: 42,
                height: 42,
                decoration: BoxDecoration(
                  color: Colors.red.withOpacity(0.1),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Icon(
                  Icons.privacy_tip,
                  color: Colors.red,
                  size: 24,
                ),
              ),
              SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      report.judul ?? 'Laporan Kekerasan Seksual',
                      style: TextStyle(
                        fontWeight: FontWeight.bold,
                        fontSize: 15,
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                    SizedBox(height: 4),
                    Row(
                      children: [
                        Icon(Icons.access_time,
                            size: 12, color: Colors.grey[600]),
                        SizedBox(width: 4),
                        Text(
                          formattedDate,
                          style: TextStyle(
                            fontSize: 12,
                            color: Colors.grey[600],
                          ),
                        ),
                      ],
                    ),
                    SizedBox(height: 8),
                    Container(
                      padding: EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                      decoration: BoxDecoration(
                        color: Colors.red.withOpacity(0.1),
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: Text(
                        "Perlu Penanganan",
                        style: TextStyle(
                          fontSize: 12,
                          color: Colors.red,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
              Icon(
                Icons.arrow_forward_ios,
                size: 14,
                color: Colors.grey,
              ),
            ],
          ),
        ),
      ),
    );
  }
}
