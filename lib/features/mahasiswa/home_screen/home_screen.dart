import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import "package:pelaporan_d3ti/shared/services/api_service.dart";
import 'package:pelaporan_d3ti/shared/services/token_manager.dart';
import 'package:pelaporan_d3ti/shared/widgets/sidebar.dart';
import 'package:intl/intl.dart';
import "package:pelaporan_d3ti/shared/data/models/laporan.dart";
import 'package:pelaporan_d3ti/shared/data/models/laporan_kekerasan.dart';

class HomeScreen extends StatefulWidget {
  const HomeScreen({Key? key}) : super(key: key);

  @override
  _HomeScreenState createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  final ApiService _apiService = ApiService();
  final GlobalKey<ScaffoldState> _scaffoldKey = GlobalKey<ScaffoldState>();

  // Theme colors
  final Color _primaryColor = Colors.indigo.shade600;
  final Color _accentColor = Colors.indigoAccent;
  final Color _lightAccent = Colors.indigo.shade50;
  final Color _darkGrey = Colors.grey.shade800;
  final Color _mediumGrey = Colors.grey.shade500;
  final Color _lightGrey = Colors.grey.shade200;

  // Secondary colors
  final Color _urgentColor = Colors.deepPurple;
  final Color _urgentLightColor = Colors.deepPurple.shade50;
  final Color _dangerColor = Colors.red.shade700;
  final Color _dangerLightColor = Colors.red.shade50;

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
  List<Laporan> _userLaporan = [];
  String? _currentUserNim;
  String? _currentUserName;

  // Kekerasan reports
  List<LaporanKekerasan> _laporanKekerasan = [];
  List<LaporanKekerasan> _userLaporanKekerasan = [];
  int _totalLaporanKekerasan = 0;
  bool _isLoadingKekerasanReports = true;

  // Limitation variables
  bool _canSubmitRegularReport = true;
  bool _canSubmitUrgentReport = true;
  bool _canSubmitSexualHarassmentReport = true;
  int _sexualHarassmentReportsToday = 0;

  // Key for storing daily report count in SharedPreferences
  static const String _lastReportDateKey = 'last_report_date';
  static const String _dailyReportCountKey = 'daily_report_count';

  @override
  void initState() {
    super.initState();
    _loadUserData();
    _fetchReports();
    _fetchKekerasanReports();
    _checkDailyReportLimit();
  }

  Future<void> _checkDailyReportLimit() async {
    final prefs = await SharedPreferences.getInstance();
    final lastReportDate = prefs.getString(_lastReportDateKey) ?? '';
    final today = DateFormat('yyyy-MM-dd').format(DateTime.now());

    // Reset counter if it's a new day
    if (lastReportDate != today) {
      await prefs.setString(_lastReportDateKey, today);
      await prefs.setInt(_dailyReportCountKey, 0);
      _sexualHarassmentReportsToday = 0;
    } else {
      _sexualHarassmentReportsToday = prefs.getInt(_dailyReportCountKey) ?? 0;
    }

    setState(() {
      _canSubmitSexualHarassmentReport = _sexualHarassmentReportsToday < 5;
    });
  }

  Future<void> _loadUserData() async {
    setState(() {
      _isLoadingUser = true;
    });

    try {
      // First check if we have cached user data
      final prefs = await SharedPreferences.getInstance();
      final userData = prefs.getString('user_data');

      // Get the user name and NIM
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
                  ? json.decode(await prefs.getString('user_data') ?? '{}')
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

      // Check if user has too many unverified reports
      int unverifiedCount =
          _userLaporan.where((report) => report.status == 'unverified').length;
      _canSubmitRegularReport = unverifiedCount < 3;
      _canSubmitUrgentReport = unverifiedCount < 3;
    });

    print(
        'Filtered ${_laporan.length} reports down to ${_userLaporan.length} for user $_currentUserName');
  }

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

  // Method to increment sexual harassment reports counter
  Future<void> _incrementSexualHarassmentReportCount() async {
    final prefs = await SharedPreferences.getInstance();
    final today = DateFormat('yyyy-MM-dd').format(DateTime.now());

    // Check if it's a new day
    final lastReportDate = prefs.getString(_lastReportDateKey) ?? '';
    if (lastReportDate != today) {
      await prefs.setString(_lastReportDateKey, today);
      await prefs.setInt(_dailyReportCountKey, 1);
    } else {
      // Increment the counter
      int currentCount = prefs.getInt(_dailyReportCountKey) ?? 0;
      await prefs.setInt(_dailyReportCountKey, currentCount + 1);
    }

    // Check if limit reached
    _checkDailyReportLimit();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      key: _scaffoldKey,
      backgroundColor: Colors.grey.shade50,
      appBar: _buildAppBar(),
      drawer: Sidebar(),
      body: _buildBody(),
    );
  }

  PreferredSizeWidget _buildAppBar() {
    return AppBar(
      elevation: 0,
      backgroundColor: Colors.white,
      foregroundColor: _primaryColor,
      title: Text(
        'Dashboard',
        style: TextStyle(
          color: _darkGrey,
          fontWeight: FontWeight.w600,
          letterSpacing: 0.5,
        ),
      ),
      leading: IconButton(
        icon: Icon(Icons.menu, color: _darkGrey),
        onPressed: () {
          _scaffoldKey.currentState?.openDrawer();
        },
      ),
      actions: [
        IconButton(
          icon: Icon(Icons.refresh, color: _primaryColor),
          onPressed: () {
            _fetchReports();
            _loadUserData();
            _fetchKekerasanReports();
            _checkDailyReportLimit();
          },
        ),
      ],
    );
  }

  Widget _buildBody() {
    return SafeArea(
      child: RefreshIndicator(
        onRefresh: () async {
          await _loadUserData();
          await _fetchReports();
          await _fetchKekerasanReports();
          await _checkDailyReportLimit();
        },
        color: _primaryColor,
        child: SingleChildScrollView(
          physics: const AlwaysScrollableScrollPhysics(),
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 20),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                _buildWelcomeCard(),
                const SizedBox(height: 24),

                // Urgent report button
                _buildUrgentReportButton(),
                const SizedBox(height: 20),

                // Sexual harassment report button
                _buildSexualHarassmentReportButton(),
                const SizedBox(height: 24),

                // Statistics section
                _buildDashboardStats(),
                const SizedBox(height: 24),

                // Recent regular activity section
                _buildRecentActivity(),
                const SizedBox(height: 24),

                // Recent sexual harassment activity section
                _buildRecentKekerasanActivity(),

                // Add padding at the bottom for better scrolling
                const SizedBox(height: 16),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildWelcomeCard() {
    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.04),
            blurRadius: 12,
            offset: Offset(0, 4),
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
                  padding: EdgeInsets.all(3),
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    gradient: LinearGradient(
                      begin: Alignment.topLeft,
                      end: Alignment.bottomRight,
                      colors: [_primaryColor, _accentColor],
                    ),
                  ),
                  child: CircleAvatar(
                    radius: 24,
                    backgroundColor: Colors.white,
                    child: Icon(Icons.person, color: _primaryColor, size: 26),
                  ),
                ),
                const SizedBox(width: 16),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        _isLoadingUser ? "Loading..." : "Welcome, $_userName",
                        style: TextStyle(
                          fontSize: 20,
                          fontWeight: FontWeight.w600,
                          color: _darkGrey,
                          letterSpacing: 0.3,
                        ),
                      ),
                      SizedBox(height: 4),
                      Text(
                        _userRole != null
                            ? "Role: $_userRole"
                            : "Selamat datang di dashboard pelaporan",
                        style: TextStyle(
                          fontSize: 14,
                          color: _mediumGrey,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
            const SizedBox(height: 16),
            Container(
              padding: EdgeInsets.symmetric(horizontal: 12, vertical: 6),
              decoration: BoxDecoration(
                color: _lightAccent.withOpacity(0.3),
                borderRadius: BorderRadius.circular(20),
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(
                    Icons.calendar_today,
                    size: 14,
                    color: _primaryColor,
                  ),
                  SizedBox(width: 6),
                  Text(
                    DateFormat('EEEE, dd MMMM yyyy').format(DateTime.now()),
                    style: TextStyle(
                      color: _primaryColor,
                      fontWeight: FontWeight.w500,
                      fontSize: 13,
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

  Widget _buildDashboardStats() {
    if (_isLoadingReports || _isLoadingKekerasanReports) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(40.0),
          child: CircularProgressIndicator(
            color: _primaryColor,
            strokeWidth: 3,
          ),
        ),
      );
    }

    if (_error != null) {
      return Container(
        padding: const EdgeInsets.all(20.0),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(16),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(0.04),
              blurRadius: 12,
              offset: Offset(0, 4),
            ),
          ],
        ),
        child: Column(
          children: [
            Icon(
              Icons.error_outline,
              color: Colors.red.shade400,
              size: 48,
            ),
            SizedBox(height: 16),
            Text(
              _error!,
              textAlign: TextAlign.center,
              style: TextStyle(
                color: _darkGrey,
                fontSize: 15,
              ),
            ),
            SizedBox(height: 20),
            ElevatedButton.icon(
              onPressed: _fetchReports,
              icon: Icon(Icons.refresh),
              label: Text('Coba Lagi'),
              style: ElevatedButton.styleFrom(
                backgroundColor: _primaryColor,
                foregroundColor: Colors.white,
                padding: EdgeInsets.symmetric(horizontal: 24, vertical: 12),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(8),
                ),
                elevation: 0,
              ),
            ),
          ],
        ),
      );
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.only(left: 4.0, bottom: 12.0),
          child: Text(
            'Statistik Laporan',
            style: TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.w600,
              color: _darkGrey,
              letterSpacing: 0.3,
            ),
          ),
        ),
        // Add the kekerasan sexual report stat card
        _buildKekerasanStatsCard(),
        SizedBox(height: 20),
        Padding(
          padding: const EdgeInsets.only(left: 4.0, bottom: 12.0),
          child: Text(
            'Statistik Laporan Kejadian',
            style: TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.w600,
              color: _darkGrey,
              letterSpacing: 0.3,
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
          padding: EdgeInsets.only(
              bottom: 24.0), // Added padding at the bottom to prevent overflow
          children: [
            _buildStatCard(
              icon: Icons.description_outlined,
              iconColor: _primaryColor,
              title: 'Total Laporan',
              count: _totalLaporan,
            ),
            _buildStatCard(
              icon: Icons.hourglass_empty_outlined,
              iconColor: Colors.grey.shade600,
              title: 'Belum Diverifikasi',
              count: _belumDiverifikasi,
            ),
            _buildStatCard(
              icon: Icons.pending_actions_outlined,
              iconColor: Colors.amber.shade700,
              title: 'Dalam Proses',
              count: _dalamProses,
            ),
            _buildStatCard(
              icon: Icons.check_circle_outline,
              iconColor: Colors.green.shade600,
              title: 'Selesai',
              count: _selesai,
            ),
          ],
        ),
        // Additional spacing at the bottom of the entire section
        SizedBox(height: 16),
      ],
    );
  }

  Widget _buildKekerasanStatsCard() {
    return Container(
      padding: EdgeInsets.all(20.0),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.04),
            blurRadius: 12,
            offset: Offset(0, 4),
          ),
        ],
        border: Border.all(
          color: _dangerColor.withOpacity(0.1),
          width: 1,
        ),
      ),
      width: double.infinity,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                padding: EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: _dangerLightColor,
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Icon(
                  Icons.privacy_tip_outlined,
                  color: _dangerColor,
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
                        fontWeight: FontWeight.w600,
                        color: _darkGrey,
                      ),
                    ),
                    SizedBox(height: 6),
                    Row(
                      children: [
                        Text(
                          'Total Laporan:',
                          style: TextStyle(
                            fontSize: 14,
                            color: _mediumGrey,
                          ),
                        ),
                        SizedBox(width: 6),
                        Text(
                          '$_totalLaporanKekerasan',
                          style: TextStyle(
                            fontSize: 18,
                            fontWeight: FontWeight.w600,
                            color: _dangerColor,
                          ),
                        ),
                      ],
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

  // Updated stat card with elegant design
  Widget _buildStatCard({
    required IconData icon,
    required Color iconColor,
    required String title,
    required int count,
  }) {
    return Container(
      padding: EdgeInsets.all(20.0),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.04),
            blurRadius: 12,
            offset: Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            padding: EdgeInsets.all(10),
            decoration: BoxDecoration(
              color: iconColor.withOpacity(0.1),
              borderRadius: BorderRadius.circular(12),
            ),
            child: Icon(
              icon,
              color: iconColor,
              size: 24,
            ),
          ),
          Spacer(),
          Text(
            count.toString(),
            style: TextStyle(
              fontSize: 28,
              fontWeight: FontWeight.w600,
              color: _darkGrey,
            ),
          ),
          SizedBox(height: 4),
          Text(
            title,
            style: TextStyle(
              fontSize: 14,
              color: _mediumGrey,
              fontWeight: FontWeight.w500,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildRecentActivity() {
    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.04),
            blurRadius: 12,
            offset: Offset(0, 4),
          ),
        ],
      ),
      child: Padding(
        padding: const EdgeInsets.all(20.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Aktivitas Terbaru Pelaporan Kejadian',
              style: TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.w600,
                color: _darkGrey,
                letterSpacing: 0.3,
              ),
            ),
            const SizedBox(height: 16),
            _isLoadingReports
                ? Center(
                    child: Padding(
                      padding: const EdgeInsets.symmetric(vertical: 30.0),
                      child: CircularProgressIndicator(
                        color: _primaryColor,
                        strokeWidth: 3,
                      ),
                    ),
                  )
                : _userLaporan.isNotEmpty
                    ? Column(
                        children: _getSortedRecentActivities()
                            .take(3) // Only show 3 most recent reports
                            .map((report) => _buildActivityItem(report))
                            .toList(),
                      )
                    : Center(
                        child: Padding(
                          padding: const EdgeInsets.symmetric(vertical: 30.0),
                          child: Column(
                            children: [
                              Icon(
                                Icons.folder_outlined,
                                size: 48,
                                color: Colors.grey.shade300,
                              ),
                              SizedBox(height: 16),
                              Text(
                                'Belum ada aktivitas',
                                style: TextStyle(
                                  color: _mediumGrey,
                                  fontSize: 15,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
            const SizedBox(height: 24),

            // Add report button with limitation
            _buildAddReportButton(),

            const SizedBox(height: 12),

            // View All Reports button
            SizedBox(
              width: double.infinity,
              child: OutlinedButton(
                onPressed: () {
                  Navigator.pushNamed(context, '/reports');
                },
                style: OutlinedButton.styleFrom(
                  padding: const EdgeInsets.symmetric(vertical: 14),
                  foregroundColor: _primaryColor,
                  side: BorderSide(color: _primaryColor),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                ),
                child: Text(
                  'Lihat Semua Laporan',
                  style: TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.w600,
                    letterSpacing: 0.3,
                  ),
                ),
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
          statusColor = Colors.amber.shade700;
          break;
        case 'finished':
          statusText = 'Selesai';
          statusColor = Colors.green.shade600;
          break;
        case 'rejected':
          statusText = 'Ditolak';
          statusColor = Colors.red.shade600;
          break;
        default:
          statusText = 'Belum Diverifikasi';
          statusColor = Colors.grey.shade600;
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

    return Container(
      margin: EdgeInsets.only(bottom: 12),
      child: InkWell(
        onTap: () {
          if (report.id != null) {
            Navigator.pushNamed(
              context,
              '/reports',
            );
          }
        },
        borderRadius: BorderRadius.circular(12),
        child: Ink(
          decoration: BoxDecoration(
            color: Colors.grey.shade50,
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: Colors.grey.shade200),
          ),
          padding: EdgeInsets.all(14),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Container(
                width: 44,
                height: 44,
                decoration: BoxDecoration(
                  color: _primaryColor.withOpacity(0.1),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Icon(
                  Icons.description_outlined,
                  color: _primaryColor,
                  size: 24,
                ),
              ),
              SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // Title
                    Text(
                      report.judul ?? 'No Title',
                      style: TextStyle(
                        fontWeight: FontWeight.w600,
                        color: _darkGrey,
                        fontSize: 15,
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                    SizedBox(height: 6),

                    // Status - now between title and time
                    Container(
                      margin: EdgeInsets.only(bottom: 6),
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
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ),

                    // Time
                    Row(
                      children: [
                        Icon(
                          Icons.access_time,
                          size: 12,
                          color: _mediumGrey,
                        ),
                        SizedBox(width: 4),
                        Text(
                          formattedDate,
                          style: TextStyle(
                            fontSize: 12,
                            color: _mediumGrey,
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
              Icon(
                Icons.chevron_right,
                size: 16,
                color: _mediumGrey,
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildAddReportButton() {
    return SizedBox(
      width: double.infinity,
      child: ElevatedButton.icon(
        onPressed: _canSubmitRegularReport
            ? () {
                Navigator.pushNamed(context, '/addlaporkejadian');
              }
            : null,
        icon: Icon(Icons.add),
        label: Text(
          _canSubmitRegularReport
              ? 'Tambah Laporan Kejadian'
              : 'Batas Laporan Tercapai (Maks. 3 belum diverifikasi)',
          style: TextStyle(
            fontSize: 14,
            fontWeight: FontWeight.w600,
            letterSpacing: 0.3,
          ),
        ),
        style: ElevatedButton.styleFrom(
          padding: const EdgeInsets.symmetric(vertical: 14),
          backgroundColor:
              _canSubmitRegularReport ? _primaryColor : Colors.grey.shade300,
          foregroundColor:
              _canSubmitRegularReport ? Colors.white : Colors.grey.shade600,
          elevation: _canSubmitRegularReport ? 0 : 0,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12),
          ),
        ),
      ),
    );
  }

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

  // Create a method for the urgent report button
  Widget _buildUrgentReportButton() {
    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.04),
            blurRadius: 12,
            offset: Offset(0, 4),
          ),
        ],
        border: Border.all(color: _urgentColor.withOpacity(0.2), width: 1),
      ),
      padding: EdgeInsets.all(20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                padding: EdgeInsets.all(10),
                decoration: BoxDecoration(
                  color: _urgentLightColor,
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Icon(
                  Icons.warning_rounded,
                  color: _urgentColor,
                  size: 28,
                ),
              ),
              SizedBox(width: 16),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Kejadian Darurat dan Mendesak',
                      style: TextStyle(
                        fontWeight: FontWeight.w600,
                        fontSize: 16,
                        color: _darkGrey,
                      ),
                    ),
                    SizedBox(height: 6),
                    Text(
                      'Segera laporkan kejadian darurat dan mendesak yang membutuhkan penanganan cepat',
                      style: TextStyle(
                        fontSize: 13,
                        color: _mediumGrey,
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
            child: ElevatedButton.icon(
              onPressed: _canSubmitUrgentReport
                  ? () {
                      Navigator.pushNamed(context, '/addlaporkejadianmendesak');
                    }
                  : null,
              icon: Icon(Icons.warning_amber),
              label: Text(
                _canSubmitUrgentReport
                    ? 'Tambah Laporan Mendesak'
                    : 'Batas Laporan Tercapai (Maks. 3 belum diverifikasi)',
                style: TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.w600,
                  letterSpacing: 0.3,
                ),
              ),
              style: ElevatedButton.styleFrom(
                padding: const EdgeInsets.symmetric(vertical: 14),
                backgroundColor: _canSubmitUrgentReport
                    ? _urgentColor
                    : Colors.grey.shade300,
                foregroundColor: _canSubmitUrgentReport
                    ? Colors.white
                    : Colors.grey.shade600,
                elevation: 0,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  // Create a method for the sexual harassment report button
  Widget _buildSexualHarassmentReportButton() {
    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.04),
            blurRadius: 12,
            offset: Offset(0, 4),
          ),
        ],
        border: Border.all(color: _dangerColor.withOpacity(0.2), width: 1),
      ),
      padding: EdgeInsets.all(20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                padding: EdgeInsets.all(10),
                decoration: BoxDecoration(
                  color: _dangerLightColor,
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Icon(
                  Icons.privacy_tip_outlined,
                  color: _dangerColor,
                  size: 28,
                ),
              ),
              SizedBox(width: 16),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Melaporkan Kasus Kekerasan Seksual',
                      style: TextStyle(
                        fontWeight: FontWeight.w600,
                        fontSize: 16,
                        color: _darkGrey,
                      ),
                    ),
                    SizedBox(height: 6),
                    Text(
                      'Laporkan dengan aman dan privasi terjaga. Semua laporan ditangani dengan kerahasiaan penuh',
                      style: TextStyle(
                        fontSize: 13,
                        color: _mediumGrey,
                      ),
                    ),
                    SizedBox(height: 8),
                    // Show the daily report count limitation
                    Container(
                      padding:
                          EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                      decoration: BoxDecoration(
                        color: !_canSubmitSexualHarassmentReport
                            ? _dangerLightColor
                            : Colors.grey.shade50,
                        borderRadius: BorderRadius.circular(10),
                        border: Border.all(
                          color: !_canSubmitSexualHarassmentReport
                              ? _dangerColor.withOpacity(0.3)
                              : Colors.grey.shade300,
                          width: 1,
                        ),
                      ),
                      child: !_canSubmitSexualHarassmentReport
                          ? Text(
                              'Anda telah mencapai batas harian (5 laporan/hari)',
                              style: TextStyle(
                                fontSize: 12,
                                color: _dangerColor,
                                fontWeight: FontWeight.w600,
                              ),
                            )
                          : Text(
                              'Sisa laporan hari ini: ${5 - _sexualHarassmentReportsToday}/5',
                              style: TextStyle(
                                fontSize: 12,
                                color: _mediumGrey,
                              ),
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
            child: ElevatedButton.icon(
              onPressed: _canSubmitSexualHarassmentReport
                  ? () async {
                      // Navigate to the form page
                      final result =
                          await Navigator.pushNamed(context, '/addlaporks');

                      // If the report was submitted successfully, increment the counter
                      if (result == true) {
                        await _incrementSexualHarassmentReportCount();
                        // Refresh reports
                        _fetchKekerasanReports();
                      }
                    }
                  : null,
              icon: Icon(Icons.privacy_tip),
              label: Text(
                _canSubmitSexualHarassmentReport
                    ? 'Laporkan Kekerasan Seksual'
                    : 'Batas Laporan Harian Tercapai',
                style: TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.w600,
                  letterSpacing: 0.3,
                ),
              ),
              style: ElevatedButton.styleFrom(
                padding: const EdgeInsets.symmetric(vertical: 14),
                backgroundColor: _canSubmitSexualHarassmentReport
                    ? _dangerColor
                    : Colors.grey.shade300,
                foregroundColor: _canSubmitSexualHarassmentReport
                    ? Colors.white
                    : Colors.grey.shade600,
                elevation: 0,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  // Recent activity section for sexual harassment reports
  Widget _buildRecentKekerasanActivity() {
    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.04),
            blurRadius: 12,
            offset: Offset(0, 4),
          ),
        ],
        border: Border.all(color: _dangerColor.withOpacity(0.1), width: 1),
      ),
      padding: EdgeInsets.all(20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              Container(
                padding: EdgeInsets.all(10),
                decoration: BoxDecoration(
                  color: _dangerLightColor,
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Icon(
                  Icons.privacy_tip_outlined,
                  color: _dangerColor,
                  size: 24,
                ),
              ),
              SizedBox(width: 14),
              Expanded(
                child: Text(
                  'Aktivitas Terbaru Pelaporan Kekerasan Seksual',
                  style: TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.w600,
                    color: _darkGrey,
                    letterSpacing: 0.3,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          _isLoadingKekerasanReports
              ? Center(
                  child: Padding(
                    padding: const EdgeInsets.symmetric(vertical: 30.0),
                    child: CircularProgressIndicator(
                      color: _dangerColor,
                      strokeWidth: 3,
                    ),
                  ),
                )
              : _userLaporanKekerasan.isNotEmpty
                  ? Column(
                      children: _getSortedRecentKekerasanActivities()
                          .take(3) // Only show 3 most recent reports
                          .map((report) => _buildKekerasanActivityItem(report))
                          .toList(),
                    )
                  : Center(
                      child: Padding(
                        padding: const EdgeInsets.symmetric(vertical: 30.0),
                        child: Column(
                          children: [
                            Icon(
                              Icons.folder_outlined,
                              size: 48,
                              color: Colors.grey.shade300,
                            ),
                            SizedBox(height: 16),
                            Text(
                              'Tidak ada laporan kekerasan seksual',
                              style: TextStyle(
                                color: _mediumGrey,
                                fontSize: 15,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
          const SizedBox(height: 20),
          // Button to view all reports
          SizedBox(
            width: double.infinity,
            child: OutlinedButton(
              onPressed: () {
                Navigator.pushNamed(context, '/violence-reports');
              },
              style: OutlinedButton.styleFrom(
                padding: const EdgeInsets.symmetric(vertical: 14),
                foregroundColor: _dangerColor,
                side: BorderSide(color: _dangerColor),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
              ),
              child: const Text(
                'Lihat Semua Laporan Kekerasan Seksual',
                style: TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.w600,
                  letterSpacing: 0.3,
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  // Helper method to sort sexual harassment reports by date
  List<LaporanKekerasan> _getSortedRecentKekerasanActivities() {
    // Make a copy of the list to avoid modifying the original
    final sortedReports = List<LaporanKekerasan>.from(_userLaporanKekerasan);

    // Sort by created_at date, most recent first
    sortedReports.sort((a, b) {
      if (a.createdAt == null) return 1; // Null dates go to the end
      if (b.createdAt == null) return -1;
      return b.createdAt!.compareTo(a.createdAt!); // Descending order
    });

    return sortedReports;
  }

  // Item for displaying sexual harassment report in the activity list
  Widget _buildKekerasanActivityItem(LaporanKekerasan report) {
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

    return Container(
      margin: EdgeInsets.only(bottom: 12),
      child: InkWell(
        onTap: () {
          if (report.id != null) {
            Navigator.pushNamed(
              context,
              '/violence-reports',
            );
          }
        },
        borderRadius: BorderRadius.circular(12),
        child: Ink(
          decoration: BoxDecoration(
            color: Colors.grey.shade50,
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: Colors.grey.shade200),
          ),
          padding: EdgeInsets.all(14),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Container(
                width: 44,
                height: 44,
                decoration: BoxDecoration(
                  color: _dangerLightColor,
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Icon(
                  Icons.privacy_tip_outlined,
                  color: _dangerColor,
                  size: 24,
                ),
              ),
              SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      report.judul ?? 'Laporan Kekerasan Seksual',
                      style: TextStyle(
                        fontWeight: FontWeight.w600,
                        color: _darkGrey,
                        fontSize: 15,
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                    SizedBox(height: 6),
                    Row(
                      children: [
                        Icon(
                          Icons.access_time,
                          size: 12,
                          color: _mediumGrey,
                        ),
                        SizedBox(width: 4),
                        Text(
                          formattedDate,
                          style: TextStyle(
                            fontSize: 12,
                            color: _mediumGrey,
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
              Icon(
                Icons.chevron_right,
                size: 16,
                color: _mediumGrey,
              ),
            ],
          ),
        ),
      ),
    );
  }
}
