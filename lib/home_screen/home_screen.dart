import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:pelaporan_d3ti/services/api_service.dart';
import 'package:pelaporan_d3ti/services/token_manager.dart';
import 'package:pelaporan_d3ti/components/sidebar.dart';
import 'package:intl/intl.dart';
import 'package:pelaporan_d3ti/models/laporan.dart';
import 'package:pelaporan_d3ti/models/laporan_kekerasan.dart'; // Make sure this import exists

class HomeScreen extends StatefulWidget {
  const HomeScreen({Key? key}) : super(key: key);

  @override
  _HomeScreenState createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
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

  // Dashboard statistics (similar to lapor_kejadian.dart)
  int _totalLaporan = 0;
  int _dalamProses = 0;
  int _selesai = 0;
  int _belumDiverifikasi = 0;
  int _ditolak = 0;

  // Report data
  List<Laporan> _laporan = [];
  List<Laporan> _userLaporan = [];
  String? _currentUserNim;
  String? _currentUserName;

  // Add these variables to your _HomeScreenState class
  List<LaporanKekerasan> _laporanKekerasan = [];
  List<LaporanKekerasan> _userLaporanKekerasan = [];
  int _totalLaporanKekerasan = 0;
  bool _isLoadingKekerasanReports = true;

  @override
  void initState() {
    super.initState();
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

      // Get the user name and NIM, similar to lapor_kejadian.dart
      _currentUserName = prefs.getString('user_name');
      _currentUserNim = prefs.getString('user_nim');

      if (_currentUserName == null || _currentUserName!.isEmpty) {
        _currentUserName = "User";
      }

      if (userData != null) {
        // Use cached data
        Map<String, dynamic> data = {};
        try {
          data = Map<String, dynamic>.from(DateTime.fromMillisecondsSinceEpoch(
                      0)
                  .toUtc()
                  .isAtSameMomentAs(
                    DateTime.fromMillisecondsSinceEpoch(1),
                  )
              ? {} // This line will never execute, it's to avoid linter warning
              : await prefs.getString('user_data') != null
                  ? (await prefs.getString('user_data') as Map<String, dynamic>)
                  : {});
        } catch (e) {
          // If we can't parse, we'll just use empty map
          print("Error parsing user data: $e");
        }

        setState(() {
          _userName = _currentUserName ?? "User";
          _userEmail = data['email'] ?? prefs.getString('user_email');
          _userRole = data['role'] ?? prefs.getString('user_role');
          _isLoadingUser = false;
        });
      } else {
        setState(() {
          _userName = _currentUserName ?? "User";
          _userEmail = prefs.getString('user_email');
          _userRole = prefs.getString('user_role');
          _isLoadingUser = false;
        });
      }
    } catch (e) {
      print('Error loading user data: $e');
      setState(() {
        _userName = "User";
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
      // Fetch reports from API using ApiService
      final laporanResponse = await _apiService.getLaporan();

      if (laporanResponse.isNotEmpty) {
        _laporan = laporanResponse;
        _filterUserLaporan();
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

  // Add a new method to fetch kekerasan reports
  Future<void> _fetchKekerasanReports() async {
    setState(() {
      _isLoadingKekerasanReports = true;
    });

    try {
      // Fetch reports from API using ApiService
      final laporanResponse = await _apiService.getLaporanKekerasan();

      if (laporanResponse.isNotEmpty) {
        _laporanKekerasan = laporanResponse;
        _filterUserLaporanKekerasan();
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

  // Filter laporan to show only current user's reports - copied from lapor_kejadian.dart
  void _filterUserLaporan() {
    if (_currentUserName == null && _currentUserNim == null) {
      setState(() {
        _userLaporan = [];
        _calculateStats(
            _laporan); // Calculate stats from all reports if no user filter
      });
      print("No user info available. Using all reports for stats.");
      return;
    }

    print(
        "Filtering reports for user: $_currentUserName (NIM: $_currentUserNim)");

    // Filter based on the API's actual field structure
    List<Laporan> filtered = [];

    // First try to match by ni_pelapor (NIM)
    if (_currentUserNim != null && _currentUserNim!.isNotEmpty) {
      filtered = _laporan
          .where((report) =>
              report.niPelapor != null &&
              report.niPelapor!.toLowerCase() == _currentUserNim!.toLowerCase())
          .toList();
    }

    // If no matches by nim, try by name
    if (filtered.isEmpty &&
        _currentUserName != null &&
        _currentUserName!.isNotEmpty) {
      filtered = _laporan
          .where((report) =>
              report.namaPelapor != null &&
              report.namaPelapor!.toLowerCase() ==
                  _currentUserName!.toLowerCase())
          .toList();
    }

    // If still no matches, try partial matches as fallback
    if (filtered.isEmpty) {
      // Try partial NIM match
      if (_currentUserNim != null && _currentUserNim!.isNotEmpty) {
        filtered = _laporan
            .where((report) =>
                report.niPelapor != null &&
                report.niPelapor!
                    .toLowerCase()
                    .contains(_currentUserNim!.toLowerCase()))
            .toList();
      }

      // Try partial name match if still empty
      if (filtered.isEmpty &&
          _currentUserName != null &&
          _currentUserName!.isNotEmpty) {
        filtered = _laporan
            .where((report) =>
                report.namaPelapor != null &&
                report.namaPelapor!
                    .toLowerCase()
                    .contains(_currentUserName!.toLowerCase()))
            .toList();
      }
    }

    setState(() {
      _userLaporan = filtered;
      _calculateStats(filtered); // Calculate stats from filtered reports
    });

    print(
        'Filtered ${_laporan.length} reports down to ${_userLaporan.length} for user $_currentUserName');
  }

  // Filter kekerasan reports to show only current user's
  void _filterUserLaporanKekerasan() {
    if (_currentUserName == null && _currentUserNim == null) {
      setState(() {
        _userLaporanKekerasan = [];
        _totalLaporanKekerasan = 0;
      });
      return;
    }

    // Filter by nim_pelapor or nama_pelapor
    List<LaporanKekerasan> filtered = [];

    // First try to match by NIM
    if (_currentUserNim != null && _currentUserNim!.isNotEmpty) {
      filtered = _laporanKekerasan
          .where((report) =>
              report.nimPelapor != null &&
              report.nimPelapor!.toLowerCase() ==
                  _currentUserNim!.toLowerCase())
          .toList();
    }

    // If no matches by nim, try by name
    if (filtered.isEmpty &&
        _currentUserName != null &&
        _currentUserName!.isNotEmpty) {
      filtered = _laporanKekerasan
          .where((report) =>
              report.namaPelapor != null &&
              report.namaPelapor!.toLowerCase() ==
                  _currentUserName!.toLowerCase())
          .toList();
    }

    setState(() {
      _userLaporanKekerasan = filtered;
      _totalLaporanKekerasan = filtered.length;
    });
  }

  // Calculate statistics from reports - similar to lapor_kejadian.dart
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

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      key: _scaffoldKey,
      appBar: AppBar(
        title: const Text('Dashboard'),
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
      drawer: Sidebar(),
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

              // Urgent report button moved here, before statistics
              _buildUrgentReportButton(),
              const SizedBox(height: 24),

              // Sexual harassment report button added here
              _buildSexualHarassmentReportButton(),
              const SizedBox(height: 24),

              // Statistics section
              _buildDashboardStats(),
              const SizedBox(height: 24),

              // Recent activity section
              _buildRecentActivity(),
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
                  backgroundColor: Colors.blue,
                  child: Icon(Icons.person, color: Colors.white, size: 30),
                ),
                const SizedBox(width: 16),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        _isLoadingUser ? "Loading..." : "Welcome, $_userName",
                        style: Theme.of(context).textTheme.titleLarge?.copyWith(
                              fontWeight: FontWeight.bold,
                            ),
                      ),
                      Text(
                        _userRole != null
                            ? "Role: $_userRole"
                            : "Selamat datang di dashboard pelaporan",
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
              'Today is ${DateFormat('EEEE, dd MMMM yyyy').format(DateTime.now())}',
              style: TextStyle(color: Colors.grey[700]),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildDashboardStats() {
    if (_isLoadingReports || _isLoadingKekerasanReports) {
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
        // Add the kekerasan sexual report stat card
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
                            'Total Laporan: $_totalLaporanKekerasan',
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
        SizedBox(height: 16),
        Padding(
          padding: const EdgeInsets.only(left: 4.0, bottom: 16.0),
          child: Text(
            'Statistik Laporan Kejadian',
            style: TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.bold,
            ),
          ),
        ),
        // 2x2 Grid for statistics cards
        GridView.count(
          crossAxisCount: 2,
          crossAxisSpacing: 12.0,
          mainAxisSpacing: 12.0,
          shrinkWrap: true,
          physics: NeverScrollableScrollPhysics(),
          children: [
            _buildStatCard(
              icon: Icons.description,
              iconColor: Colors.blue,
              title: 'Total Laporan',
              count: _totalLaporan,
            ),
            _buildStatCard(
              icon: Icons.hourglass_empty,
              iconColor: Colors.grey,
              title: 'Belum Diverifikasi',
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
          ],
        ),
      ],
    );
  }

  // Updated stat card with square aspect ratio
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

  // Updated to sort activities by date (most recent first)
  Widget _buildRecentActivity() {
    return Card(
      elevation: 4,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Aktivitas Terbaru Pelaporan Kejadian',
              style: Theme.of(context).textTheme.titleLarge,
            ),
            const SizedBox(height: 16),
            _isLoadingReports
                ? Center(child: CircularProgressIndicator())
                : _userLaporan.isNotEmpty
                    ? Column(
                        children: _getSortedRecentActivities()
                            .take(3) // Only show 3 most recent reports
                            .map((report) => _buildActivityItem(report))
                            .toList(),
                      )
                    : Center(
                        child: Padding(
                          padding: const EdgeInsets.symmetric(vertical: 24.0),
                          child: Text(
                            'Belum ada aktivitas',
                            style: TextStyle(color: Colors.grey),
                          ),
                        ),
                      ),
            const SizedBox(height: 24),

            // Only "View All Reports" button remains here
            SizedBox(
              width: double.infinity,
              child: ElevatedButton(
                onPressed: () {
                  Navigator.pushNamed(context, '/reports');
                },
                style: ElevatedButton.styleFrom(
                  padding: const EdgeInsets.symmetric(vertical: 12),
                  backgroundColor:
                      Colors.blue, // Set the button background to blue
                  foregroundColor: Colors.white, // Set the text color to white
                  elevation: 2, // Slight elevation for depth
                ),
                child: const Text(
                  'Lihat Semua Laporan',
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

  // Helper method to sort reports by date
  List<Laporan> _getSortedRecentActivities() {
    // Make a copy of the list to avoid modifying the original
    final sortedReports = List<Laporan>.from(_userLaporan);

    // Sort by created_at date, most recent first
    sortedReports.sort((a, b) {
      if (a.createdAt == null) return 1; // Null dates go to the end
      if (b.createdAt == null) return -1;
      return b.createdAt!.compareTo(a.createdAt!); // Descending order
    });

    return sortedReports;
  }

  // Updated activity item with improved date display
  Widget _buildActivityItem(Laporan report) {
    // Format status for display
    String statusText = 'Belum Diverifikasi';
    Color statusColor = Colors.grey;

    if (report.status != null) {
      switch (report.status!.toLowerCase()) {
        case 'verified':
          statusText = 'Diproses';
          statusColor = Colors.orange;
          break;
        case 'finished':
          statusText = 'Selesai';
          statusColor = Colors.green;
          break;
        case 'rejected':
          statusText = 'Ditolak';
          statusColor = Colors.red;
          break;
        default:
          statusText = 'Belum Diverifikasi';
          statusColor = Colors.grey;
      }
    }

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
            Navigator.pushNamed(
              context,
              '/reports',
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
                  color: Colors.blue.withOpacity(0.1),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Icon(
                  Icons.article,
                  color: Colors.blue,
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
                    SizedBox(height: 8),
                    Container(
                      padding: EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                      decoration: BoxDecoration(
                        color: statusColor.withOpacity(0.1),
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: Text(
                        statusText,
                        style: TextStyle(
                          fontSize: 12,
                          color: statusColor,
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

  // Create a new method for the urgent report button
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
                  Navigator.pushNamed(context, '/addlaporkejadianmendesak');
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
                  Navigator.pushNamed(context, '/addlaporks');
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
}
