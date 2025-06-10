import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:pelaporan_d3ti/services/api_service.dart';
import 'package:pelaporan_d3ti/services/token_manager.dart';
import 'package:pelaporan_d3ti/components/sidebar.dart';
import 'package:intl/intl.dart';
import 'package:pelaporan_d3ti/models/laporan.dart';

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

  @override
  void initState() {
    super.initState();
    _loadUserData();
    _fetchReports();
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
        },
        child: SingleChildScrollView(
          physics: const AlwaysScrollableScrollPhysics(),
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              _buildWelcomeCard(),
              const SizedBox(height: 24),
              _buildDashboardStats(),
              const SizedBox(height: 24),
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

    // Use similar layout to lapor_kejadian.dart for stats cards
    return LayoutBuilder(builder: (context, constraints) {
      // For small screens, stack cards vertically
      if (constraints.maxWidth < 600) {
        return Column(
          children: [
            _buildStatCard(
              icon: Icons.description,
              iconColor: Colors.blue,
              title: 'Total Laporan',
              count: _totalLaporan,
              fullWidth: true,
            ),
            SizedBox(height: 12),
            _buildStatCard(
              icon: Icons.hourglass_empty,
              iconColor: Colors.grey,
              title: 'Belum Diverifikasi',
              count: _belumDiverifikasi,
              fullWidth: true,
            ),
            SizedBox(height: 12),
            _buildStatCard(
              icon: Icons.pending_actions,
              iconColor: Colors.orange,
              title: 'Dalam Proses',
              count: _dalamProses,
              fullWidth: true,
            ),
            SizedBox(height: 12),
            _buildStatCard(
              icon: Icons.check_circle,
              iconColor: Colors.green,
              title: 'Selesai',
              count: _selesai,
              fullWidth: true,
            ),
          ],
        );
      } else {
        // For larger screens, use rows
        return Column(
          children: [
            Row(
              children: [
                Expanded(
                  flex: 2,
                  child: _buildStatCard(
                    icon: Icons.description,
                    iconColor: Colors.blue,
                    title: 'Total Laporan',
                    count: _totalLaporan,
                  ),
                ),
                SizedBox(width: 12),
                Expanded(
                  child: _buildStatCard(
                    icon: Icons.hourglass_empty,
                    iconColor: Colors.grey,
                    title: 'Belum Diverifikasi',
                    count: _belumDiverifikasi,
                  ),
                ),
              ],
            ),
            SizedBox(height: 12),
            Row(
              children: [
                Expanded(
                  child: _buildStatCard(
                    icon: Icons.pending_actions,
                    iconColor: Colors.orange,
                    title: 'Dalam Proses',
                    count: _dalamProses,
                  ),
                ),
                SizedBox(width: 12),
                Expanded(
                  child: _buildStatCard(
                    icon: Icons.check_circle,
                    iconColor: Colors.green,
                    title: 'Selesai',
                    count: _selesai,
                  ),
                ),
                SizedBox(width: 12),
                Expanded(
                  child: _buildStatCard(
                    icon: Icons.cancel,
                    iconColor: Colors.red,
                    title: 'Ditolak',
                    count: _ditolak,
                  ),
                ),
              ],
            ),
          ],
        );
      }
    });
  }

  // Copied and adapted from lapor_kejadian.dart
  Widget _buildStatCard({
    required IconData icon,
    required Color iconColor,
    required String title,
    required int count,
    bool fullWidth = false,
  }) {
    return Card(
      elevation: 2,
      child: Padding(
        padding: const EdgeInsets.all(16.0),
        child: fullWidth
            ? Row(
                children: [
                  Container(
                    padding: EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: iconColor.withOpacity(0.1),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Icon(
                      icon,
                      color: iconColor,
                      size: 24,
                    ),
                  ),
                  SizedBox(width: 16),
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        title,
                        style: TextStyle(
                          fontSize: 14,
                          color: Colors.grey[600],
                        ),
                      ),
                      SizedBox(height: 4),
                      Text(
                        count.toString(),
                        style: TextStyle(
                          fontSize: 20,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ],
                  )
                ],
              )
            : Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Container(
                    padding: EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: iconColor.withOpacity(0.1),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Icon(
                      icon,
                      color: iconColor,
                      size: 24,
                    ),
                  ),
                  SizedBox(height: 16),
                  Text(
                    title,
                    style: TextStyle(
                      fontSize: 14,
                      color: Colors.grey[600],
                    ),
                  ),
                  SizedBox(height: 4),
                  Text(
                    count.toString(),
                    style: TextStyle(
                      fontSize: 20,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ],
              ),
      ),
    );
  }

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
              'Aktivitas Terbaru',
              style: Theme.of(context).textTheme.titleLarge,
            ),
            const SizedBox(height: 16),
            _isLoadingReports
                ? Center(child: CircularProgressIndicator())
                : _userLaporan.isNotEmpty
                    ? Column(
                        children: _userLaporan
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
            const SizedBox(height: 16),
            Center(
              child: ElevatedButton(
                onPressed: () {
                  Navigator.pushNamed(context, '/reports');
                },
                child: const Text('Lihat Semua Laporan'),
              ),
            ),
          ],
        ),
      ),
    );
  }

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

    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8.0),
      child: InkWell(
        onTap: () {
          if (report.id != null) {
            Navigator.pushNamed(
              context,
              '/reports',
              // You could pass arguments here to show the specific report
            );
          }
        },
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
                    ),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                  SizedBox(height: 4),
                  Text(
                    'Laporan #${report.id} · ${report.createdAt != null ? DateFormat('dd MMM yyyy').format(report.createdAt!) : 'No date'}',
                    style: TextStyle(
                      fontSize: 12,
                      color: Colors.grey[600],
                    ),
                  ),
                  SizedBox(height: 4),
                  Container(
                    padding: EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                    decoration: BoxDecoration(
                      color: statusColor.withOpacity(0.1),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Text(
                      statusText,
                      style: TextStyle(
                        fontSize: 11,
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
    );
  }
}
