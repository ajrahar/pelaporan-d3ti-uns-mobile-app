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

  // Limitation tracking
  int _userPendingReportsCount = 0;
  int _kekerasanReportsTodayCount = 0;
  bool _canSubmitRegularReport = true;
  bool _canSubmitKekerasanReport = true;

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

        // Count how many kekerasan reports were made today
        final today = DateTime.now();
        final startOfDay = DateTime(today.year, today.month, today.day);

        int kekerasanReportsToday = 0;
        for (var report in laporanResponse) {
          if (report.createdAt != null &&
              report.createdAt!.isAfter(startOfDay) &&
              report.namaPelapor == _currentUserName) {
            kekerasanReportsToday++;
          }
        }

        setState(() {
          _laporanKekerasan = laporanResponse;
          _totalLaporanKekerasan = laporanResponse.length;
          _kekerasanReportsTodayCount = kekerasanReportsToday;
          _canSubmitKekerasanReport = kekerasanReportsToday < 5;
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

    // Count unverified reports by this user
    int pendingReportsCount = 0;
    for (var report in filteredReports) {
      if (report.status == 'unverified') {
        pendingReportsCount++;
      }
    }

    setState(() {
      _userMatchingReports = filteredReports;
      _countMatchingReports = filteredReports.length;
      _userPendingReportsCount = pendingReportsCount;

      // Check if the user can submit new reports (limit to 3 pending reports)
      _canSubmitRegularReport = pendingReportsCount < 3;

      // Update the statistics based on the filtered reports for the current user
      _calculateStats(_userMatchingReports);
    });

    print(
        'Filtered ${_laporan.length} reports down to ${_userMatchingReports.length} for user $_currentUserName');
    print(
        'User has $_userPendingReportsCount pending reports - can submit new report: $_canSubmitRegularReport');
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      key: _scaffoldKey,
      backgroundColor: Colors.grey[50],
      appBar: AppBar(
        backgroundColor: Colors.white,
        elevation: 1,
        title: Text(
          'Dashboard Dosen',
          style: TextStyle(
            color: Colors.grey[800],
            fontWeight: FontWeight.w600,
          ),
        ),
        leading: IconButton(
          icon: Icon(Icons.menu, color: Colors.grey[800]),
          onPressed: () {
            _scaffoldKey.currentState?.openDrawer();
          },
        ),
        actions: [
          IconButton(
            icon: Icon(Icons.refresh, color: Colors.grey[800]),
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
              const SizedBox(height: 16),
              _canSubmitRegularReport
                  ? Container()
                  : _buildLimitWarning(
                      "Anda telah memiliki 3 laporan yang belum diverifikasi"),
              const SizedBox(height: 24),

              _buildSexualHarassmentReportButton(),
              const SizedBox(height: 16),
              _canSubmitKekerasanReport
                  ? Container()
                  : _buildLimitWarning(
                      "Anda telah mencapai batas 5 laporan kekerasan seksual hari ini"),
              const SizedBox(height: 24),

              // Statistics section
              _buildDashboardStats(),
              const SizedBox(height: 24),

              // Recent reports to verify/handle
              _buildPendingVerificationSection(),
              const SizedBox(height: 24),

              // Kekerasan sexual reports section
              _buildKekerasanReportsSection(),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildLimitWarning(String message) {
    return Container(
      padding: EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      decoration: BoxDecoration(
        color: Colors.red[50],
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: Colors.red[200]!),
      ),
      child: Row(
        children: [
          Icon(Icons.warning_amber_rounded, color: Colors.red[400], size: 18),
          SizedBox(width: 8),
          Expanded(
            child: Text(
              message,
              style: TextStyle(
                color: Colors.red[700],
                fontSize: 12,
                fontWeight: FontWeight.w500,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildWelcomeCard() {
    return Card(
      elevation: 0,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(16),
        side: BorderSide(color: Colors.grey.shade200),
      ),
      child: Padding(
        padding: const EdgeInsets.all(20.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Container(
                  width: 56,
                  height: 56,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    color: Colors.blue[50],
                    border: Border.all(color: Colors.blue.shade100, width: 2),
                  ),
                  child: Icon(
                    Icons.school_rounded,
                    color: Colors.blue[700],
                    size: 28,
                  ),
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
                        style: TextStyle(
                          fontSize: 20,
                          fontWeight: FontWeight.bold,
                          color: Colors.grey[800],
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        _userRole != null
                            ? "Role: $_userRole"
                            : "Dashboard Pelaporan D3TI UNS",
                        style: TextStyle(
                          fontSize: 14,
                          color: Colors.grey[600],
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
            const SizedBox(height: 20),
            Container(
              padding: EdgeInsets.symmetric(horizontal: 14, vertical: 10),
              decoration: BoxDecoration(
                color: Colors.grey[100],
                borderRadius: BorderRadius.circular(10),
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(Icons.calendar_today_rounded,
                      size: 18, color: Colors.grey[700]),
                  const SizedBox(width: 8),
                  Text(
                    DateFormat('EEEE, dd MMMM yyyy', 'id_ID')
                        .format(DateTime.now()),
                    style: TextStyle(
                      color: Colors.grey[700],
                      fontWeight: FontWeight.w500,
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

  Widget _buildUrgentReportButton() {
    return Card(
      elevation: 0,
      color: Colors.white,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(16),
        side: BorderSide(
            color: _canSubmitRegularReport
                ? Colors.purple.shade200
                : Colors.grey.shade300,
            width: 1),
      ),
      child: Padding(
        padding: const EdgeInsets.all(20.0),
        child: Column(
          children: [
            Row(
              children: [
                Container(
                  padding: EdgeInsets.all(10),
                  decoration: BoxDecoration(
                    color: _canSubmitRegularReport
                        ? Colors.purple.shade50
                        : Colors.grey.shade100,
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: Icon(
                    Icons.warning_rounded,
                    color:
                        _canSubmitRegularReport ? Colors.purple : Colors.grey,
                    size: 24,
                  ),
                ),
                SizedBox(width: 16),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Terjadi Kejadian Darurat dan Mendesak?',
                        style: TextStyle(
                          fontWeight: FontWeight.bold,
                          fontSize: 16,
                          color: _canSubmitRegularReport
                              ? Colors.grey[800]
                              : Colors.grey,
                        ),
                      ),
                      SizedBox(height: 6),
                      Text(
                        'Segera laporkan kejadian darurat dan mendesak yang membutuhkan penanganan cepat',
                        style: TextStyle(
                          fontSize: 13,
                          color: _canSubmitRegularReport
                              ? Colors.grey[700]
                              : Colors.grey,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
            SizedBox(height: 20),
            SizedBox(
              width: double.infinity,
              child: ElevatedButton(
                onPressed: _canSubmitRegularReport
                    ? () {
                        Navigator.pushNamed(
                            context, '/addlaporpkmendesakdosen');
                      }
                    : null,
                style: ElevatedButton.styleFrom(
                  padding: const EdgeInsets.symmetric(vertical: 14),
                  backgroundColor: Colors.purple,
                  foregroundColor: Colors.white,
                  elevation: _canSubmitRegularReport ? 0 : 0,
                  disabledBackgroundColor: Colors.grey[300],
                  disabledForegroundColor: Colors.grey[500],
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(10),
                  ),
                ),
                child: Text(
                  'Tambah Laporan Mendesak',
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

  // Create a method for the sexual harassment report button
  Widget _buildSexualHarassmentReportButton() {
    return Card(
      elevation: 0,
      color: Colors.white,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(16),
        side: BorderSide(
            color: _canSubmitKekerasanReport
                ? Colors.red.shade200
                : Colors.grey.shade300,
            width: 1),
      ),
      child: Padding(
        padding: const EdgeInsets.all(20.0),
        child: Column(
          children: [
            Row(
              children: [
                Container(
                  padding: EdgeInsets.all(10),
                  decoration: BoxDecoration(
                    color: _canSubmitKekerasanReport
                        ? Colors.red.shade50
                        : Colors.grey.shade100,
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: Icon(
                    Icons.privacy_tip_rounded,
                    color: _canSubmitKekerasanReport ? Colors.red : Colors.grey,
                    size: 24,
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
                          fontWeight: FontWeight.bold,
                          fontSize: 16,
                          color: _canSubmitKekerasanReport
                              ? Colors.grey[800]
                              : Colors.grey,
                        ),
                      ),
                      SizedBox(height: 6),
                      Text(
                        'Laporkan dengan aman dan privasi terjaga. Semua laporan ditangani dengan kerahasiaan penuh',
                        style: TextStyle(
                          fontSize: 13,
                          color: _canSubmitKekerasanReport
                              ? Colors.grey[700]
                              : Colors.grey,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
            SizedBox(height: 20),
            SizedBox(
              width: double.infinity,
              child: ElevatedButton(
                onPressed: _canSubmitKekerasanReport
                    ? () {
                        Navigator.pushNamed(context, '/addlaporksdosen');
                      }
                    : null,
                style: ElevatedButton.styleFrom(
                  padding: const EdgeInsets.symmetric(vertical: 14),
                  backgroundColor: Colors.red,
                  foregroundColor: Colors.white,
                  elevation: _canSubmitKekerasanReport ? 0 : 0,
                  disabledBackgroundColor: Colors.grey[300],
                  disabledForegroundColor: Colors.grey[500],
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(10),
                  ),
                ),
                child: Text(
                  'Laporkan Kekerasan Seksual',
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

  Widget _buildDashboardStats() {
    if (_isLoadingReports) {
      return Center(
        child: CircularProgressIndicator(
          valueColor: AlwaysStoppedAnimation<Color>(Colors.blue),
          strokeWidth: 3,
        ),
      );
    }

    if (_error != null) {
      return Card(
        elevation: 0,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(16),
          side: BorderSide(color: Colors.red.shade200),
        ),
        child: Padding(
          padding: const EdgeInsets.all(20.0),
          child: Column(
            children: [
              Icon(Icons.error_outline, color: Colors.red, size: 48),
              SizedBox(height: 16),
              Text(_error!, textAlign: TextAlign.center),
              SizedBox(height: 20),
              ElevatedButton(
                onPressed: _fetchReports,
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.blue,
                  foregroundColor: Colors.white,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(8),
                  ),
                  padding: EdgeInsets.symmetric(horizontal: 24, vertical: 12),
                ),
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
              color: Colors.grey[800],
            ),
          ),
        ),
        // Overview card
        Card(
          elevation: 0,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(16),
            side: BorderSide(color: Colors.grey.shade200),
          ),
          child: Container(
            padding: EdgeInsets.all(20.0),
            width: double.infinity,
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
                        Icons.assessment_rounded,
                        color: Colors.blue[700],
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
                              fontWeight: FontWeight.w600,
                              color: Colors.grey[700],
                            ),
                          ),
                          SizedBox(height: 8),
                          Text(
                            '$_totalLaporan Laporan',
                            style: TextStyle(
                              fontSize: 22,
                              fontWeight: FontWeight.bold,
                              color: Colors.blue[700],
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
              icon: Icons.hourglass_empty_rounded,
              iconColor: Colors.amber[700]!,
              title: 'Perlu Verifikasi',
              count: _belumDiverifikasi,
            ),
            _buildStatCard(
              icon: Icons.pending_actions_rounded,
              iconColor: Colors.orange[700]!,
              title: 'Dalam Proses',
              count: _dalamProses,
            ),
            _buildStatCard(
              icon: Icons.check_circle_outline_rounded,
              iconColor: Colors.green[700]!,
              title: 'Selesai',
              count: _selesai,
            ),
            _buildStatCard(
              icon: Icons.cancel_outlined,
              iconColor: Colors.red[700]!,
              title: 'Ditolak',
              count: _ditolak,
            ),
          ],
        ),
        SizedBox(height: 16),
        // Kekerasan sexual reports stat card
        Card(
          elevation: 0,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(16),
            side: BorderSide(color: Colors.red.shade200),
          ),
          color: Colors.red[50],
          child: Container(
            padding: EdgeInsets.all(20.0),
            width: double.infinity,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Container(
                      padding: EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        color: Colors.white,
                        borderRadius: BorderRadius.circular(12),
                        boxShadow: [
                          BoxShadow(
                            color: Colors.red.withOpacity(0.2),
                            blurRadius: 4,
                            spreadRadius: 0,
                            offset: Offset(0, 2),
                          ),
                        ],
                      ),
                      child: Icon(
                        Icons.privacy_tip_rounded,
                        color: Colors.red[700],
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
                              color: Colors.red[900],
                            ),
                          ),
                          SizedBox(height: 8),
                          Row(
                            children: [
                              Text(
                                'Total: $_totalLaporanKekerasan',
                                style: TextStyle(
                                  fontSize: 18,
                                  fontWeight: FontWeight.bold,
                                  color: Colors.red[700],
                                ),
                              ),
                              SizedBox(width: 16),
                              Container(
                                padding: EdgeInsets.symmetric(
                                    horizontal: 8, vertical: 3),
                                decoration: BoxDecoration(
                                  color: Colors.white,
                                  borderRadius: BorderRadius.circular(12),
                                  border: Border.all(color: Colors.red[200]!),
                                ),
                                child: Text(
                                  'Hari ini: $_kekerasanReportsTodayCount/5',
                                  style: TextStyle(
                                    fontSize: 12,
                                    fontWeight: FontWeight.w600,
                                    color: Colors.red[700],
                                  ),
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
      elevation: 0,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(16),
        side: BorderSide(color: Colors.grey.shade200),
      ),
      child: Container(
        padding: EdgeInsets.all(16.0),
        child: Column(
          mainAxisAlignment:
              MainAxisAlignment.start, // Changed from center to start
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
            Spacer(), // This creates flexible space
            Text(
              count.toString(),
              style: TextStyle(
                fontSize: 32,
                fontWeight: FontWeight.bold,
                color: Colors.grey[800],
              ),
            ),
            SizedBox(height: 8),
            Text(
              title,
              style: TextStyle(
                fontSize: 14,
                fontWeight: FontWeight.w500,
                color: Colors.grey[600],
              ),
              textAlign: TextAlign.center,
            ),
            SizedBox(height: 12), // Added extra space at the bottom
          ],
        ),
      ),
    );
  }

  Widget _buildPendingVerificationSection() {
    // Filter reports to only show those created by the current user
    final userReports = _userMatchingReports.take(3).toList();

    return Card(
      elevation: 0,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(16),
        side: BorderSide(color: Colors.grey.shade200),
      ),
      child: Padding(
        padding: const EdgeInsets.all(20.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(
                  Icons.assignment_rounded,
                  color: Colors.blue[700],
                  size: 24,
                ),
                SizedBox(width: 12),
                Text(
                  'Laporan Kejadian',
                  style: TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                    color: Colors.grey[800],
                  ),
                ),
              ],
            ),
            const SizedBox(height: 20),
            _isLoadingReports
                ? Center(
                    child: CircularProgressIndicator(
                    valueColor: AlwaysStoppedAnimation<Color>(Colors.blue),
                  ))
                : userReports.isNotEmpty
                    ? Column(
                        children: userReports
                            .map((report) => _buildReportItem(report))
                            .toList(),
                      )
                    : Center(
                        child: Padding(
                          padding: const EdgeInsets.symmetric(vertical: 30.0),
                          child: Column(
                            children: [
                              Icon(
                                Icons.folder_open_rounded,
                                size: 48,
                                color: Colors.grey[400],
                              ),
                              SizedBox(height: 16),
                              Text(
                                'Belum ada laporan yang Anda buat',
                                style: TextStyle(
                                  color: Colors.grey[600],
                                  fontWeight: FontWeight.w500,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
            const SizedBox(height: 20),
            SizedBox(
              width: double.infinity,
              child: ElevatedButton.icon(
                onPressed: () {
                  Navigator.pushNamed(context, '/laporpkdosen');
                },
                icon: Icon(Icons.visibility_rounded, size: 18),
                label: Text(
                  'Lihat Semua Laporan Anda',
                  style: TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                style: ElevatedButton.styleFrom(
                  padding: const EdgeInsets.symmetric(vertical: 14),
                  backgroundColor: Colors.blue[700],
                  foregroundColor: Colors.white,
                  elevation: 0,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(10),
                  ),
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

    // Determine status color and text
    Color statusColor;
    String statusText;
    IconData statusIcon;

    switch (report.status) {
      case 'unverified':
        statusColor = Colors.amber[700]!;
        statusText = 'Perlu Verifikasi';
        statusIcon = Icons.hourglass_empty_rounded;
        break;
      case 'verified':
        statusColor = Colors.orange[700]!;
        statusText = 'Dalam Proses';
        statusIcon = Icons.pending_actions_rounded;
        break;
      case 'finished':
        statusColor = Colors.green[700]!;
        statusText = 'Selesai';
        statusIcon = Icons.check_circle_outline_rounded;
        break;
      case 'rejected':
        statusColor = Colors.red[700]!;
        statusText = 'Ditolak';
        statusIcon = Icons.cancel_outlined;
        break;
      default:
        statusColor = Colors.grey[700]!;
        statusText = 'Status Tidak Diketahui';
        statusIcon = Icons.help_outline_rounded;
    }

    return Padding(
      padding: const EdgeInsets.only(bottom: 12.0),
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
        borderRadius: BorderRadius.circular(12),
        child: Container(
          padding: EdgeInsets.all(16),
          decoration: BoxDecoration(
            border: Border.all(color: Colors.grey.shade200),
            borderRadius: BorderRadius.circular(12),
            color: Colors.white,
          ),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Container(
                width: 44,
                height: 44,
                decoration: BoxDecoration(
                  color: statusColor.withOpacity(0.1),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Icon(
                  statusIcon,
                  color: statusColor,
                  size: 24,
                ),
              ),
              SizedBox(width: 16),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      report.judul ?? 'No Title',
                      style: TextStyle(
                        fontWeight: FontWeight.bold,
                        fontSize: 15,
                        color: Colors.grey[800],
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                    SizedBox(height: 6),
                    Row(
                      children: [
                        Icon(Icons.access_time_rounded,
                            size: 14, color: Colors.grey[600]),
                        SizedBox(width: 4),
                        Text(
                          formattedDate,
                          style: TextStyle(
                            fontSize: 13,
                            color: Colors.grey[600],
                          ),
                        ),
                      ],
                    ),
                    SizedBox(height: 8),
                    Container(
                      padding:
                          EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                      decoration: BoxDecoration(
                        color: statusColor.withOpacity(0.1),
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(color: statusColor.withOpacity(0.3)),
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
                  ],
                ),
              ),
              Icon(
                Icons.arrow_forward_ios_rounded,
                size: 16,
                color: Colors.grey[400],
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildKekerasanReportsSection() {
    return Card(
      elevation: 0,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(16),
        side: BorderSide(color: Colors.red.shade200),
      ),
      color: Colors.white,
      child: Padding(
        padding: const EdgeInsets.all(20.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Container(
                  padding: EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: Colors.red[50],
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: Icon(Icons.privacy_tip_rounded,
                      color: Colors.red[700], size: 22),
                ),
                SizedBox(width: 12),
                Expanded(
                  child: Text(
                    'Laporan Kekerasan Seksual',
                    style: TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                      color: Colors.red[900],
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 20),
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
                          padding: const EdgeInsets.symmetric(vertical: 30.0),
                          child: Column(
                            children: [
                              Icon(
                                Icons.folder_open_rounded,
                                size: 48,
                                color: Colors.red[200],
                              ),
                              SizedBox(height: 16),
                              Text(
                                'Tidak ada laporan kekerasan seksual',
                                style: TextStyle(
                                  color: Colors.red[400],
                                  fontWeight: FontWeight.w500,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
            const SizedBox(height: 20),
            SizedBox(
              width: double.infinity,
              child: ElevatedButton.icon(
                onPressed: () {
                  Navigator.pushNamed(context, '/laporksdosen');
                },
                icon: Icon(Icons.visibility_rounded, size: 18),
                label: Text(
                  'Lihat Semua Laporan Kekerasan Seksual',
                  style: TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                style: ElevatedButton.styleFrom(
                  padding: const EdgeInsets.symmetric(vertical: 14),
                  backgroundColor: Colors.red[700],
                  foregroundColor: Colors.white,
                  elevation: 0,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(10),
                  ),
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
      padding: const EdgeInsets.only(bottom: 12.0),
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
        borderRadius: BorderRadius.circular(12),
        child: Container(
          padding: EdgeInsets.all(16),
          decoration: BoxDecoration(
            border: Border.all(color: Colors.red.shade100),
            borderRadius: BorderRadius.circular(12),
            color: Colors.white,
          ),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Container(
                width: 44,
                height: 44,
                decoration: BoxDecoration(
                  color: Colors.red.withOpacity(0.1),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Icon(
                  Icons.privacy_tip_rounded,
                  color: Colors.red[700],
                  size: 24,
                ),
              ),
              SizedBox(width: 16),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      report.judul ?? 'Laporan Kekerasan Seksual',
                      style: TextStyle(
                        fontWeight: FontWeight.bold,
                        fontSize: 15,
                        color: Colors.grey[800],
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                    SizedBox(height: 6),
                    Row(
                      children: [
                        Icon(Icons.access_time_rounded,
                            size: 14, color: Colors.grey[600]),
                        SizedBox(width: 4),
                        Text(
                          formattedDate,
                          style: TextStyle(
                            fontSize: 13,
                            color: Colors.grey[600],
                          ),
                        ),
                      ],
                    ),
                    SizedBox(height: 8),
                    Container(
                      padding:
                          EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                      decoration: BoxDecoration(
                        color: Colors.red.withOpacity(0.1),
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(color: Colors.red.withOpacity(0.3)),
                      ),
                      child: Text(
                        "Perlu Penanganan",
                        style: TextStyle(
                          fontSize: 12,
                          color: Colors.red[700],
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
              Icon(
                Icons.arrow_forward_ios_rounded,
                size: 16,
                color: Colors.grey[400],
              ),
            ],
          ),
        ),
      ),
    );
  }
}
