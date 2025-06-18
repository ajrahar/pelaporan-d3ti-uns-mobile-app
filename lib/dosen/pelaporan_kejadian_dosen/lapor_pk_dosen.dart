import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:pelaporan_d3ti/components/sidebar_dosen.dart'; // Import for teacher sidebar
import 'package:pelaporan_d3ti/dosen/pelaporan_kejadian_dosen/detail_lapor_pk_dosen.dart';
import 'package:pelaporan_d3ti/services/api_service.dart';
import 'package:pelaporan_d3ti/models/laporan.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'dart:async';
import 'dart:math' as Math;

class LaporKejadianDosenPage extends StatefulWidget {
  const LaporKejadianDosenPage({Key? key}) : super(key: key);

  @override
  _LaporKejadianDosenPageState createState() => _LaporKejadianDosenPageState();
}

class _LaporKejadianDosenPageState extends State<LaporKejadianDosenPage> {
  // API service instance
  final ApiService _apiService = ApiService();

  // Data state
  List<Laporan> _laporan = [];
  List<Laporan> _dosenLaporan = []; // This will store only the dosen's reports
  Map<int, String> _categories = {};
  bool _loading = true;
  String? _error;

  // Current user info
  String? _currentUserName;
  String? _currentUserNip;

  // Stats for cards
  int _totalLaporan = 0;
  int _dalamProses = 0;
  int _selesai = 0;

  // Search and filters
  final TextEditingController _searchController = TextEditingController();
  String _searchQuery = '';
  Map<String, dynamic> _filters = {
    'category_id': '',
    'status': '',
    'startDate': null,
    'endDate': null
  };

  // Sorting
  String _sortField = 'created_at';
  bool _sortAscending = false;

  // Pagination
  int _currentPage = 1;
  int _itemsPerPage = 10;

  @override
  void initState() {
    super.initState();
    // First, get the current user info
    _getCurrentUserInfo().then((_) {
      // Then fetch data
      _fetchData();
    });
  }

  // Get current user information from SharedPreferences
  Future<void> _getCurrentUserInfo() async {
    try {
      final prefs = await SharedPreferences.getInstance();

      // Get the user name and NIP
      String? userName = prefs.getString('user_name');
      String? userNip = prefs.getString('user_nip');
      String? userEmail = prefs.getString('user_email');

      print(
          'Retrieved from SharedPreferences - Name: $userName, NIP: $userNip, Email: $userEmail');

      if ((userName == null || userName.isEmpty) &&
          (userNip == null || userNip.isEmpty)) {
        // No user info in SharedPreferences, use hardcoded values for testing
        userName = "dosenD3TI"; // Match this to a nama_pelapor in your API
        userNip = "19900101"; // Match this to a ni_pelapor in your API
        print('No user in SharedPreferences, using hardcoded: $userName');
      }

      setState(() {
        _currentUserName = userName;
        _currentUserNip = userNip;
      });

      print('Current user set to: $_currentUserName (NIP: $_currentUserNip)');
    } catch (e) {
      print('Error getting current user info: $e');
      // Set hardcoded values as fallback
      setState(() {
        _currentUserName = "dosenD3TI";
        _currentUserNip = "19900101";
      });
      print('Set fallback user after error: $_currentUserName');
    }
  }

  // Filter laporan to show only current user's reports
  void _filterDosenLaporan() {
    if (_currentUserName == null && _currentUserNip == null) {
      setState(() {
        _dosenLaporan = [];
        _totalLaporan = 0;
        _dalamProses = 0;
        _selesai = 0;
      });
      print("No user info available. Not showing any reports.");
      return;
    }

    print(
        "Filtering reports for dosen: $_currentUserName (NIP: $_currentUserNip)");
    print("Total reports before filtering: ${_laporan.length}");

    // Show the first few reports for debugging
    for (var i = 0; i < Math.min(3, _laporan.length); i++) {
      final report = _laporan[i];
      print(
          "Report ${i + 1}: ID: ${report.id}, nama_pelapor: ${report.namaPelapor}, ni_pelapor: ${report.niPelapor}");
    }

    // Filter based on the API's actual field structure
    List<Laporan> filtered = [];

    // First try to match by ni_pelapor (NIP)
    if (_currentUserNip != null && _currentUserNip!.isNotEmpty) {
      filtered = _laporan
          .where((report) =>
              report.niPelapor != null &&
              report.niPelapor!.toLowerCase() == _currentUserNip!.toLowerCase())
          .toList();

      print("Filtered by ni_pelapor: found ${filtered.length} matches");
    }

    // If no matches by nip, try by name
    if (filtered.isEmpty &&
        _currentUserName != null &&
        _currentUserName!.isNotEmpty) {
      filtered = _laporan
          .where((report) =>
              report.namaPelapor != null &&
              report.namaPelapor!.toLowerCase() ==
                  _currentUserName!.toLowerCase())
          .toList();

      print("Filtered by nama_pelapor: found ${filtered.length} matches");
    }

    // If still no matches, try alternative fields or partial matches
    if (filtered.isEmpty) {
      print("No exact matches found, trying partial matches...");

      // Try partial NIP match
      if (_currentUserNip != null && _currentUserNip!.isNotEmpty) {
        filtered = _laporan
            .where((report) =>
                report.niPelapor != null &&
                report.niPelapor!
                    .toLowerCase()
                    .endsWith(_currentUserNip!.toLowerCase()))
            .toList();

        print("Partial ni_pelapor match: found ${filtered.length} matches");
      }

      // Try partial name match
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

        print("Partial nama_pelapor match: found ${filtered.length} matches");
      }
    }

    // If still no matches, show a sample for debugging
    if (filtered.isEmpty) {
      print(
          "WARNING: No matching reports found for dosen $_currentUserName (NIP: $_currentUserNip)");
      print("Check the user info against what's in your API data");

      // For testing, show specific reports or a subset
      filtered = _laporan.take(5).toList(); // Show first 5 reports as fallback
      print("Showing first ${filtered.length} reports as fallback.");
    }

    setState(() {
      _dosenLaporan = filtered;
      _totalLaporan = _dosenLaporan.length;
      _dalamProses =
          _dosenLaporan.where((item) => item.status == 'verified').length;
      _selesai =
          _dosenLaporan.where((item) => item.status == 'finished').length;

      // Add debug info to show in the UI
      _error = filtered.isEmpty
          ? "No reports found for dosen $_currentUserName. Showing sample data instead."
          : null;
    });

    print(
        'Filtered ${_laporan.length} reports down to ${_dosenLaporan.length} for dosen $_currentUserName');
  }

  // Dummy data for testing when API is not available
  void _loadDummyData() {
    // Filter to only show current user's reports
    _filterDosenLaporan();

    setState(() {
      _loading = false;
    });
  }

  Future<void> _fetchData() async {
    setState(() {
      _loading = true;
      _error = null;
    });

    try {
      // Attempt to fetch real data from API
      try {
        // Fetch categories
        print("Attempting to fetch categories from API...");
        final categoriesResponse = await _apiService.getCategories();
        print(
            "Categories API response received: ${categoriesResponse.length} items");

        if (categoriesResponse.isNotEmpty) {
          _categories = categoriesResponse;
          print("Categories loaded successfully");
        }

        // Fetch laporan
        print("Attempting to fetch laporan from API...");
        final laporanResponse = await _apiService.getLaporan();
        print("Laporan API response received: ${laporanResponse.length} items");

        if (laporanResponse.isNotEmpty) {
          _laporan = laporanResponse;

          // Print unique users in the response for debugging
          Set<String> uniqueUsers = Set<String>();
          _laporan.forEach((report) {
            // Only add non-null name values
            if (report.namaPelapor != null) {
              uniqueUsers.add(report.namaPelapor!);
            }
          });

          print("Unique users in API response: ${uniqueUsers.join(', ')}");

          // Print unique ni_pelapor values
          Set<String> uniqueNips = Set<String>();
          _laporan.forEach((report) {
            if (report.niPelapor != null && report.niPelapor!.isNotEmpty) {
              uniqueNips.add(report.niPelapor!);
            }
          });

          print("Unique ni_pelapor values: ${uniqueNips.join(', ')}");

          // Filter to only show current user's reports
          _filterDosenLaporan();
        }

        setState(() {
          _loading = false;
        });
        print("Data loaded from API successfully");
      } catch (e, stackTrace) {
        print("API ERROR DETAILS: $e");
        print("STACK TRACE: $stackTrace");

        // If API fails, load dummy data
        print("Loading dummy data instead");
        _loadDummyData();
      }
    } catch (e) {
      setState(() {
        _error = "Tidak dapat terhubung ke server. Menggunakan data sementara.";
        _loading = false;
      });
      // Load dummy data as fallback
      _loadDummyData();
    }
  }

  // Get filtered and sorted data
  List<Laporan> get _filteredLaporan {
    // Start with dosen's laporan instead of all laporan
    List<Laporan> result = [..._dosenLaporan];

    // Apply search filter
    if (_searchQuery.isNotEmpty) {
      final query = _searchQuery.toLowerCase();
      result = result
          .where((item) =>
              (item.judul?.toLowerCase().contains(query) ?? false) ||
              (item.nomorLaporan?.toLowerCase().contains(query) ?? false) ||
              (item.namaPelapor?.toLowerCase().contains(query) ?? false))
          .toList();
    }

    // Apply status filter
    if (_filters['status'] != null &&
        _filters['status'].toString().isNotEmpty) {
      final statusMap = {
        'Belum Diverifikasi': 'unverified',
        'Diproses': 'verified',
        'Ditolak': 'rejected',
        'Selesai': 'finished'
      };

      final statusValue = statusMap[_filters['status']];
      if (statusValue != null) {
        result = result.where((item) => item.status == statusValue).toList();
      }
    }

    // Apply category filter
    if (_filters['category_id'] != null &&
        _filters['category_id'].toString().isNotEmpty) {
      final categoryId = int.tryParse(_filters['category_id'].toString());
      if (categoryId != null) {
        result = result.where((item) => item.categoryId == categoryId).toList();
      }
    }

    // Apply date range filter
    if (_filters['startDate'] != null || _filters['endDate'] != null) {
      result = result.where((item) {
        if (item.createdAt == null) {
          return true; // Skip items with no date
        }

        if (_filters['startDate'] != null) {
          final startDate = _filters['startDate'] as DateTime;
          if (item.createdAt!.isBefore(startDate)) {
            return false;
          }
        }

        if (_filters['endDate'] != null) {
          final endDate = _filters['endDate'] as DateTime;
          final endOfDay =
              DateTime(endDate.year, endDate.month, endDate.day, 23, 59, 59);
          if (item.createdAt!.isAfter(endOfDay)) {
            return false;
          }
        }

        return true;
      }).toList();
    }

    // Apply sorting
    result.sort((a, b) {
      dynamic fieldA, fieldB;

      switch (_sortField) {
        case 'nomor_laporan':
          fieldA = a.nomorLaporan;
          fieldB = b.nomorLaporan;
          break;
        case 'created_at':
          fieldA = a.createdAt;
          fieldB = b.createdAt;
          break;
        case 'judul':
          fieldA = a.judul;
          fieldB = b.judul;
          break;
        case 'status':
          fieldA = a.status;
          fieldB = b.status;
          break;
        default:
          fieldA = a.id;
          fieldB = b.id;
      }

      int comparison = _compareValues(fieldA, fieldB);
      return _sortAscending ? comparison : -comparison;
    });

    return result;
  }

  // Compare values for sorting
  int _compareValues(dynamic a, dynamic b) {
    if (a == b) return 0;
    if (a == null) return -1;
    if (b == null) return 1;
    return a.compareTo(b);
  }

  // Get paginated data
  List<Laporan> get _paginatedLaporan {
    if (_filteredLaporan.isEmpty) return [];

    final start = (_currentPage - 1) * _itemsPerPage;
    if (start >= _filteredLaporan.length) {
      return [];
    }

    final end = start + _itemsPerPage;
    return _filteredLaporan.sublist(
        start, end > _filteredLaporan.length ? _filteredLaporan.length : end);
  }

  // Format status for display
  String _formatStatus(String status) {
    switch (status.toLowerCase()) {
      case 'verified':
        return 'Diproses';
      case 'unverified':
        return 'Belum Diverifikasi';
      case 'rejected':
        return 'Ditolak';
      case 'finished':
        return 'Selesai';
      default:
        return status;
    }
  }

  // Get status color
  Color _getStatusColor(String status) {
    switch (status) {
      case 'Belum Diverifikasi':
        return Colors.grey.shade700;
      case 'Diproses':
        return Colors.orange.shade700;
      case 'Ditolak':
        return Colors.red.shade700;
      case 'Selesai':
        return Colors.green.shade700;
      default:
        return Colors.grey.shade700;
    }
  }

  // Format date for display
  String _formatDate(DateTime? date) {
    if (date == null) {
      return '-';
    }
    final DateFormat formatter = DateFormat('dd MMM yyyy');
    return formatter.format(date);
  }

  // Reset filters
  void _resetFilters() {
    setState(() {
      _filters = {
        'category_id': '',
        'status': '',
        'startDate': null,
        'endDate': null
      };
      _searchQuery = '';
      _searchController.clear();
      _currentPage = 1;
    });
  }

  // Toggle sort direction
  void _sortBy(String field) {
    setState(() {
      if (_sortField == field) {
        _sortAscending = !_sortAscending;
      } else {
        _sortField = field;
        _sortAscending = true;
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      appBar: AppBar(
        backgroundColor: Colors.white,
        elevation: 0,
        title: Text(
          'Pelaporan Kejadian',
          style: TextStyle(
            color: Colors.grey.shade800,
            fontWeight: FontWeight.w600,
          ),
        ),
        iconTheme: IconThemeData(color: Colors.grey.shade800),
        actions: [
          IconButton(
            icon: Icon(Icons.refresh),
            onPressed: _fetchData,
            color: Colors.blue,
          ),
        ],
        bottom: PreferredSize(
          preferredSize: Size.fromHeight(1.0),
          child: Container(
            color: Colors.grey.shade200,
            height: 1.0,
          ),
        ),
      ),
      drawer: SidebarDosen(),
      body: _loading
          ? Center(
              child: CircularProgressIndicator(
                valueColor: AlwaysStoppedAnimation<Color>(Colors.blue),
              ),
            )
          : _error != null && _laporan.isEmpty
              ? _buildErrorWidget()
              : _buildMainContent(),
    );
  }

  Widget _buildErrorWidget() {
    return Center(
      child: Container(
        margin: EdgeInsets.all(24),
        padding: EdgeInsets.all(24),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: Colors.red.shade200),
          boxShadow: [
            BoxShadow(
              color: Colors.grey.shade100,
              blurRadius: 10,
              offset: Offset(0, 4),
            ),
          ],
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.center,
          children: [
            Container(
              padding: EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: Colors.red.shade50,
                shape: BoxShape.circle,
                border: Border.all(color: Colors.red.shade100),
              ),
              child: Icon(
                Icons.error_outline,
                color: Colors.red,
                size: 36,
              ),
            ),
            SizedBox(height: 24),
            Text(
              'Terjadi kesalahan:',
              style: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.w600,
                color: Colors.grey.shade800,
              ),
            ),
            SizedBox(height: 12),
            Text(
              _error ?? 'Unknown error',
              textAlign: TextAlign.center,
              style: TextStyle(
                color: Colors.grey.shade600,
                fontSize: 15,
              ),
            ),
            SizedBox(height: 24),
            ElevatedButton(
              onPressed: _fetchData,
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.blue,
                foregroundColor: Colors.white,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(8),
                ),
                elevation: 0,
                padding: EdgeInsets.symmetric(horizontal: 24, vertical: 12),
              ),
              child: Text(
                'Coba Lagi',
                style: TextStyle(
                  fontWeight: FontWeight.w500,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildMainContent() {
    return SingleChildScrollView(
      child: Container(
        color: Colors.white,
        child: Padding(
          padding: const EdgeInsets.all(16.0),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              if (_error != null)
                Container(
                  width: double.infinity,
                  margin: EdgeInsets.only(bottom: 16.0),
                  padding: EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(color: Colors.yellow.shade700),
                  ),
                  child: Row(
                    children: [
                      Container(
                        padding: EdgeInsets.all(8),
                        decoration: BoxDecoration(
                          color: Colors.yellow.shade50,
                          shape: BoxShape.circle,
                        ),
                        child: Icon(
                          Icons.warning_amber_rounded,
                          color: Colors.yellow.shade800,
                          size: 24,
                        ),
                      ),
                      SizedBox(width: 16),
                      Expanded(
                        child: Text(
                          _error!,
                          style: TextStyle(
                            fontSize: 14,
                            color: Colors.grey.shade800,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              _buildHeader(),
              SizedBox(height: 24),
              _buildDashboardCards(),
              SizedBox(height: 24),
              _buildSearchAndAddSection(),
              SizedBox(height: 24),
              _buildFiltersSection(),
              SizedBox(height: 24),
              _buildDataTable(),
              SizedBox(height: 16),
              if (_filteredLaporan.isNotEmpty) _buildPagination(),
              SizedBox(height: 32), // Bottom padding
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildHeader() {
    return Container(
      width: double.infinity,
      padding: EdgeInsets.all(24),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: Colors.grey.shade200),
        boxShadow: [
          BoxShadow(
            color: Colors.grey.shade50,
            blurRadius: 10,
            offset: Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Pelaporan Kejadian',
            style: TextStyle(
              fontSize: 24,
              fontWeight: FontWeight.bold,
              color: Colors.grey.shade800,
              letterSpacing: 0.5,
            ),
          ),
          SizedBox(height: 12),
          Text(
            'Sistem pencatatan dan manajemen laporan kejadian oleh dosen di D3 TI SV UNS. Gunakan halaman ini untuk mengirim, memantau, dan mengelola laporan kejadian.',
            style: TextStyle(
              fontSize: 14,
              height: 1.5,
              color: Colors.grey.shade600,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildDashboardCards() {
    return LayoutBuilder(builder: (context, constraints) {
      // For small screens, stack cards vertically
      if (constraints.maxWidth < 600) {
        return Column(
          children: [
            _buildStatCard(
              icon: Icons.description_outlined,
              iconColor: Colors.blue,
              title: 'Total Laporan',
              count: _totalLaporan,
              fullWidth: true,
            ),
            SizedBox(height: 16),
            _buildStatCard(
              icon: Icons.pending_actions_outlined,
              iconColor: Colors.orange,
              title: 'Dalam Proses',
              count: _dalamProses,
              fullWidth: true,
            ),
            SizedBox(height: 16),
            _buildStatCard(
              icon: Icons.check_circle_outline,
              iconColor: Colors.green,
              title: 'Selesai',
              count: _selesai,
              fullWidth: true,
            ),
          ],
        );
      } else {
        // For larger screens, use a row
        return Row(
          children: [
            Expanded(
              child: _buildStatCard(
                icon: Icons.description_outlined,
                iconColor: Colors.blue,
                title: 'Total Laporan',
                count: _totalLaporan,
              ),
            ),
            SizedBox(width: 16),
            Expanded(
              child: _buildStatCard(
                icon: Icons.pending_actions_outlined,
                iconColor: Colors.orange,
                title: 'Dalam Proses',
                count: _dalamProses,
              ),
            ),
            SizedBox(width: 16),
            Expanded(
              child: _buildStatCard(
                icon: Icons.check_circle_outline,
                iconColor: Colors.green,
                title: 'Selesai',
                count: _selesai,
              ),
            ),
          ],
        );
      }
    });
  }

  Widget _buildStatCard({
    required IconData icon,
    required Color iconColor,
    required String title,
    required int count,
    bool fullWidth = false,
  }) {
    return Container(
      padding: EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: iconColor.withOpacity(0.3)),
      ),
      child: fullWidth
          ? Row(
              children: [
                Container(
                  padding: EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(color: iconColor),
                  ),
                  child: Icon(
                    icon,
                    color: iconColor,
                    size: 24,
                  ),
                ),
                SizedBox(width: 20),
                Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      title,
                      style: TextStyle(
                        fontSize: 14,
                        fontWeight: FontWeight.w500,
                        color: Colors.grey[600],
                      ),
                    ),
                    SizedBox(height: 6),
                    Text(
                      count.toString(),
                      style: TextStyle(
                        fontSize: 24,
                        fontWeight: FontWeight.bold,
                        color: Colors.grey.shade800,
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
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(color: iconColor),
                  ),
                  child: Icon(
                    icon,
                    color: iconColor,
                    size: 24,
                  ),
                ),
                SizedBox(height: 20),
                Text(
                  title,
                  style: TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.w500,
                    color: Colors.grey[600],
                  ),
                ),
                SizedBox(height: 6),
                Text(
                  count.toString(),
                  style: TextStyle(
                    fontSize: 28,
                    fontWeight: FontWeight.bold,
                    color: Colors.grey.shade800,
                  ),
                ),
              ],
            ),
    );
  }

  Widget _buildSearchAndAddSection() {
    return LayoutBuilder(builder: (context, constraints) {
      if (constraints.maxWidth < 600) {
        // For smaller screens, stack widgets vertically
        return Column(
          children: [
            TextField(
              controller: _searchController,
              decoration: InputDecoration(
                labelText: 'Cari laporan...',
                labelStyle: TextStyle(color: Colors.grey.shade600),
                prefixIcon: Icon(Icons.search, color: Colors.grey.shade600),
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                  borderSide: BorderSide(color: Colors.grey.shade300),
                ),
                enabledBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                  borderSide: BorderSide(color: Colors.grey.shade300),
                ),
                focusedBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                  borderSide: BorderSide(color: Colors.blue),
                ),
                contentPadding:
                    EdgeInsets.symmetric(vertical: 16, horizontal: 16),
                filled: true,
                fillColor: Colors.white,
              ),
              style: TextStyle(fontSize: 15, color: Colors.grey.shade800),
              onChanged: (value) {
                setState(() {
                  _searchQuery = value;
                  _currentPage = 1;
                });
              },
            ),
            SizedBox(height: 16),
            SizedBox(
              width: double.infinity,
              child: ElevatedButton.icon(
                onPressed: () {
                  Navigator.pushNamed(context, '/addlaporpkdosen');
                },
                icon: Icon(Icons.add, color: Colors.white),
                label: Text(
                  'Tambah Laporan',
                  style: TextStyle(
                    fontWeight: FontWeight.w600,
                    fontSize: 15,
                    letterSpacing: 0.3,
                    color: Colors.white,
                  ),
                ),
                style: ElevatedButton.styleFrom(
                  padding: EdgeInsets.symmetric(vertical: 16),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                  elevation: 0,
                  backgroundColor: Colors.blue,
                ),
              ),
            ),
          ],
        );
      } else {
        // For larger screens, use a row
        return Row(
          children: [
            Expanded(
              child: TextField(
                controller: _searchController,
                decoration: InputDecoration(
                  labelText: 'Cari laporan...',
                  labelStyle: TextStyle(color: Colors.grey.shade600),
                  prefixIcon: Icon(Icons.search, color: Colors.grey.shade600),
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                    borderSide: BorderSide(color: Colors.grey.shade300),
                  ),
                  enabledBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                    borderSide: BorderSide(color: Colors.grey.shade300),
                  ),
                  focusedBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                    borderSide: BorderSide(color: Colors.blue),
                  ),
                  contentPadding:
                      EdgeInsets.symmetric(vertical: 16, horizontal: 16),
                  filled: true,
                  fillColor: Colors.white,
                ),
                style: TextStyle(fontSize: 15, color: Colors.grey.shade800),
                onChanged: (value) {
                  setState(() {
                    _searchQuery = value;
                    _currentPage = 1;
                  });
                },
              ),
            ),
            SizedBox(width: 16),
            ElevatedButton.icon(
              onPressed: () {
                Navigator.pushNamed(context, '/addlaporpkdosen');
              },
              icon: Icon(Icons.add),
              label: Text(
                'Tambah Laporan',
                style: TextStyle(
                  fontWeight: FontWeight.w600,
                  fontSize: 15,
                  letterSpacing: 0.3,
                ),
              ),
              style: ElevatedButton.styleFrom(
                padding: EdgeInsets.symmetric(horizontal: 24, vertical: 16),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
                elevation: 0,
                backgroundColor: Colors.blue,
              ),
            ),
          ],
        );
      }
    });
  }

  Widget _buildFiltersSection() {
    return Container(
      padding: EdgeInsets.all(24),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: Colors.grey.shade200),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(Icons.filter_list, color: Colors.grey.shade800, size: 20),
              SizedBox(width: 8),
              Text(
                'Filter berdasarkan:',
                style: TextStyle(
                  fontWeight: FontWeight.w600,
                  fontSize: 16,
                  color: Colors.grey.shade800,
                ),
              ),
            ],
          ),
          SizedBox(height: 20),
          LayoutBuilder(builder: (context, constraints) {
            if (constraints.maxWidth < 600) {
              // For smaller screens, stack widgets vertically
              return Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  _buildCategoryDropdown(),
                  SizedBox(height: 16),
                  _buildStatusDropdown(),
                  SizedBox(height: 16),
                  _buildStartDatePicker(),
                  SizedBox(height: 16),
                  _buildEndDatePicker(),
                  SizedBox(height: 20),
                  Row(
                    children: [
                      Expanded(
                        child: ElevatedButton.icon(
                          onPressed: _resetFilters,
                          icon: Icon(Icons.restart_alt),
                          label: Text('Reset Filter'),
                          style: ElevatedButton.styleFrom(
                            backgroundColor: Colors.white,
                            foregroundColor: Colors.grey.shade700,
                            elevation: 0,
                            side: BorderSide(color: Colors.grey.shade300),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(12),
                            ),
                            padding: EdgeInsets.symmetric(vertical: 16),
                          ),
                        ),
                      ),
                    ],
                  ),
                ],
              );
            } else {
              // For larger screens, use rows
              return Column(
                children: [
                  Row(
                    children: [
                      Expanded(child: _buildCategoryDropdown()),
                      SizedBox(width: 16),
                      Expanded(child: _buildStatusDropdown()),
                    ],
                  ),
                  SizedBox(height: 16),
                  Row(
                    children: [
                      Expanded(child: _buildStartDatePicker()),
                      SizedBox(width: 16),
                      Expanded(child: _buildEndDatePicker()),
                    ],
                  ),
                  SizedBox(height: 20),
                  Row(
                    children: [
                      ElevatedButton.icon(
                        onPressed: _resetFilters,
                        icon: Icon(Icons.restart_alt),
                        label: Text('Reset Filter'),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: Colors.white,
                          foregroundColor: Colors.grey.shade700,
                          elevation: 0,
                          side: BorderSide(color: Colors.grey.shade300),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(12),
                          ),
                          padding: EdgeInsets.symmetric(
                              horizontal: 20, vertical: 16),
                        ),
                      ),
                    ],
                  ),
                ],
              );
            }
          }),
        ],
      ),
    );
  }

  Widget _buildCategoryDropdown() {
    // Create a map to deduplicate categories by name
    final Map<String, int> uniqueCategories = {};

    // For each category, keep only one entry per unique category name
    _categories.forEach((id, name) {
      // Skip categories starting with "Kekerasan"
      if (!name.toLowerCase().startsWith("kekerasan")) {
        // Only add this category if we haven't seen this name yet
        if (!uniqueCategories.containsKey(name)) {
          uniqueCategories[name] = id;
        }
      }
    });

    return DropdownButtonFormField<String>(
      decoration: InputDecoration(
        labelText: 'Kategori',
        labelStyle: TextStyle(color: Colors.grey.shade600),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: BorderSide(color: Colors.grey.shade300),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: BorderSide(color: Colors.grey.shade300),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: BorderSide(color: Colors.blue),
        ),
        contentPadding: EdgeInsets.symmetric(vertical: 16, horizontal: 16),
        filled: true,
        fillColor: Colors.white,
      ),
      style: TextStyle(fontSize: 15, color: Colors.grey.shade800),
      value: _filters['category_id'].toString().isEmpty
          ? null
          : _filters['category_id'].toString(),
      items: [
        DropdownMenuItem(
          value: '',
          child: Text('Semua'),
        ),
        // Map the unique categories to DropdownMenuItems
        ...uniqueCategories.entries.map((entry) {
          return DropdownMenuItem(
            value: entry.value.toString(),
            child: Text(entry.key),
          );
        }).toList(),
      ],
      onChanged: (value) {
        setState(() {
          _filters['category_id'] = value;
          _currentPage = 1;
        });
      },
      icon: Icon(Icons.arrow_drop_down, color: Colors.grey.shade600),
      isExpanded: true,
      hint:
          Text('Pilih Kategori', style: TextStyle(color: Colors.grey.shade500)),
      dropdownColor: Colors.white,
    );
  }

  Widget _buildStatusDropdown() {
    return DropdownButtonFormField<String>(
      decoration: InputDecoration(
        labelText: 'Status',
        labelStyle: TextStyle(color: Colors.grey.shade600),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: BorderSide(color: Colors.grey.shade300),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: BorderSide(color: Colors.grey.shade300),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: BorderSide(color: Colors.blue),
        ),
        contentPadding: EdgeInsets.symmetric(vertical: 16, horizontal: 16),
        filled: true,
        fillColor: Colors.white,
      ),
      style: TextStyle(fontSize: 15, color: Colors.grey.shade800),
      value: _filters['status'].toString().isEmpty ? null : _filters['status'],
      items: [
        DropdownMenuItem(
          value: '',
          child: Text('Semua'),
        ),
        DropdownMenuItem(
          value: 'Belum Diverifikasi',
          child: Text('Belum Diverifikasi'),
        ),
        DropdownMenuItem(
          value: 'Diproses',
          child: Text('Diproses'),
        ),
        DropdownMenuItem(
          value: 'Ditolak',
          child: Text('Ditolak'),
        ),
        DropdownMenuItem(
          value: 'Selesai',
          child: Text('Selesai'),
        ),
      ],
      onChanged: (value) {
        setState(() {
          _filters['status'] = value;
          _currentPage = 1;
        });
      },
      icon: Icon(Icons.arrow_drop_down, color: Colors.grey.shade600),
      isExpanded: true,
      hint: Text('Pilih Status', style: TextStyle(color: Colors.grey.shade500)),
      dropdownColor: Colors.white,
    );
  }

  Widget _buildStartDatePicker() {
    return TextFormField(
      decoration: InputDecoration(
        labelText: 'Tanggal Mulai',
        labelStyle: TextStyle(color: Colors.grey.shade600),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: BorderSide(color: Colors.grey.shade300),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: BorderSide(color: Colors.grey.shade300),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: BorderSide(color: Colors.blue),
        ),
        contentPadding: EdgeInsets.symmetric(vertical: 16, horizontal: 16),
        filled: true,
        fillColor: Colors.white,
        suffixIcon:
            Icon(Icons.calendar_today, color: Colors.grey.shade600, size: 20),
      ),
      style: TextStyle(fontSize: 15, color: Colors.grey.shade800),
      readOnly: true,
      controller: TextEditingController(
        text: _filters['startDate'] != null
            ? DateFormat('dd MMM yyyy')
                .format(_filters['startDate'] as DateTime)
            : '',
      ),
      onTap: () async {
        final DateTime? picked = await showDatePicker(
          context: context,
          initialDate: _filters['startDate'] ?? DateTime.now(),
          firstDate: DateTime(2020),
          lastDate: DateTime(2030),
          builder: (context, child) {
            return Theme(
              data: Theme.of(context).copyWith(
                colorScheme: ColorScheme.light(
                  primary: Colors.blue,
                  onPrimary: Colors.white,
                  surface: Colors.white,
                  onSurface: Colors.grey.shade800,
                ),
                dialogBackgroundColor: Colors.white,
              ),
              child: child!,
            );
          },
        );
        if (picked != null) {
          setState(() {
            _filters['startDate'] = picked;
            _currentPage = 1;
          });
        }
      },
    );
  }

  Widget _buildEndDatePicker() {
    return TextFormField(
      decoration: InputDecoration(
        labelText: 'Tanggal Akhir',
        labelStyle: TextStyle(color: Colors.grey.shade600),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: BorderSide(color: Colors.grey.shade300),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: BorderSide(color: Colors.grey.shade300),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: BorderSide(color: Colors.blue),
        ),
        contentPadding: EdgeInsets.symmetric(vertical: 16, horizontal: 16),
        filled: true,
        fillColor: Colors.white,
        suffixIcon:
            Icon(Icons.calendar_today, color: Colors.grey.shade600, size: 20),
      ),
      style: TextStyle(fontSize: 15, color: Colors.grey.shade800),
      readOnly: true,
      controller: TextEditingController(
        text: _filters['endDate'] != null
            ? DateFormat('dd MMM yyyy').format(_filters['endDate'] as DateTime)
            : '',
      ),
      onTap: () async {
        final DateTime? picked = await showDatePicker(
          context: context,
          initialDate: _filters['endDate'] ?? DateTime.now(),
          firstDate: DateTime(2020),
          lastDate: DateTime(2030),
          builder: (context, child) {
            return Theme(
              data: Theme.of(context).copyWith(
                colorScheme: ColorScheme.light(
                  primary: Colors.blue,
                  onPrimary: Colors.white,
                  surface: Colors.white,
                  onSurface: Colors.grey.shade800,
                ),
                dialogBackgroundColor: Colors.white,
              ),
              child: child!,
            );
          },
        );
        if (picked != null) {
          setState(() {
            _filters['endDate'] = picked;
            _currentPage = 1;
          });
        }
      },
    );
  }

  Widget _buildDataTable() {
    if (_filteredLaporan.isEmpty) {
      return Container(
        padding: EdgeInsets.all(32),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: Colors.grey.shade200),
        ),
        child: Column(
          children: [
            Container(
              padding: EdgeInsets.all(20),
              decoration: BoxDecoration(
                color: Colors.grey.shade50,
                shape: BoxShape.circle,
                border: Border.all(color: Colors.grey.shade200),
              ),
              child: Icon(
                _searchQuery.isNotEmpty ||
                        _filters.values
                            .any((v) => v != null && v.toString().isNotEmpty)
                    ? Icons.search_off_rounded
                    : Icons.note_add_outlined,
                size: 40,
                color: Colors.grey.shade400,
              ),
            ),
            SizedBox(height: 24),
            Text(
              _searchQuery.isNotEmpty ||
                      _filters.values
                          .any((v) => v != null && v.toString().isNotEmpty)
                  ? 'Tidak ada hasil yang ditemukan'
                  : 'Belum ada laporan yang dibuat',
              style: TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.w500,
                color: Colors.grey.shade600,
              ),
              textAlign: TextAlign.center,
            ),
            SizedBox(height: 8),
            Text(
              _searchQuery.isNotEmpty ||
                      _filters.values
                          .any((v) => v != null && v.toString().isNotEmpty)
                  ? 'Coba ubah kriteria pencarian atau reset filter'
                  : 'Klik tombol "Tambah Laporan" untuk membuat laporan baru',
              style: TextStyle(
                fontSize: 14,
                color: Colors.grey.shade500,
              ),
              textAlign: TextAlign.center,
            ),
          ],
        ),
      );
    }

    // Always use table view regardless of screen size
    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: Colors.grey.shade200),
        boxShadow: [
          BoxShadow(
            color: Colors.grey.shade50,
            blurRadius: 5,
            offset: Offset(0, 2),
          ),
        ],
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(16),
        child: SingleChildScrollView(
          scrollDirection: Axis.horizontal,
          child: DataTable(
            headingRowColor: MaterialStateProperty.all(Colors.grey.shade50),
            dataRowColor: MaterialStateProperty.all(Colors.white),
            headingTextStyle: TextStyle(
              color: Colors.grey.shade800,
              fontWeight: FontWeight.w600,
              fontSize: 14,
            ),
            dataTextStyle: TextStyle(
              color: Colors.grey.shade700,
              fontSize: 14,
            ),
            horizontalMargin: 24,
            columnSpacing: 16,
            dividerThickness: 0.5,
            columns: [
              DataColumn(
                label: Container(
                  padding: EdgeInsets.symmetric(vertical: 8),
                  child: Text('No'),
                ),
              ),
              DataColumn(
                label: GestureDetector(
                  onTap: () => _sortBy('nomor_laporan'),
                  child: Row(
                    children: [
                      Text('Nomor Laporan'),
                      SizedBox(width: 4),
                      Icon(
                        _sortField == 'nomor_laporan'
                            ? (_sortAscending
                                ? Icons.arrow_upward
                                : Icons.arrow_downward)
                            : Icons.unfold_more,
                        size: 16,
                        color: _sortField == 'nomor_laporan'
                            ? Colors.blue
                            : Colors.grey.shade600,
                      ),
                    ],
                  ),
                ),
              ),
              DataColumn(
                label: GestureDetector(
                  onTap: () => _sortBy('created_at'),
                  child: Row(
                    children: [
                      Text('Tanggal'),
                      SizedBox(width: 4),
                      Icon(
                        _sortField == 'created_at'
                            ? (_sortAscending
                                ? Icons.arrow_upward
                                : Icons.arrow_downward)
                            : Icons.unfold_more,
                        size: 16,
                        color: _sortField == 'created_at'
                            ? Colors.blue
                            : Colors.grey.shade600,
                      ),
                    ],
                  ),
                ),
              ),
              DataColumn(
                label: GestureDetector(
                  onTap: () => _sortBy('judul'),
                  child: Row(
                    children: [
                      Text('Judul'),
                      SizedBox(width: 4),
                      Icon(
                        _sortField == 'judul'
                            ? (_sortAscending
                                ? Icons.arrow_upward
                                : Icons.arrow_downward)
                            : Icons.unfold_more,
                        size: 16,
                        color: _sortField == 'judul'
                            ? Colors.blue
                            : Colors.grey.shade600,
                      ),
                    ],
                  ),
                ),
              ),
              DataColumn(label: Text('Kategori')),
              DataColumn(label: Text('Pelapor')),
              DataColumn(
                label: GestureDetector(
                  onTap: () => _sortBy('status'),
                  child: Row(
                    children: [
                      Text('Status'),
                      SizedBox(width: 4),
                      Icon(
                        _sortField == 'status'
                            ? (_sortAscending
                                ? Icons.arrow_upward
                                : Icons.arrow_downward)
                            : Icons.unfold_more,
                        size: 16,
                        color: _sortField == 'status'
                            ? Colors.blue
                            : Colors.grey.shade600,
                      ),
                    ],
                  ),
                ),
              ),
              DataColumn(label: Text('Aksi')),
            ],
            rows: _paginatedLaporan.asMap().entries.map((entry) {
              final index = entry.key;
              final laporan = entry.value;
              final formattedStatus =
                  _formatStatus(laporan.status ?? 'unverified');
              final statusColor = _getStatusColor(formattedStatus);

              return DataRow(
                cells: [
                  DataCell(
                    Container(
                      padding: EdgeInsets.symmetric(vertical: 16),
                      child: Text(
                        ((_currentPage - 1) * _itemsPerPage + index + 1)
                            .toString(),
                      ),
                    ),
                  ),
                  DataCell(Text(laporan.nomorLaporan ?? '-')),
                  DataCell(Text(_formatDate(laporan.createdAt))),
                  DataCell(Text(laporan.judul ?? '-')),
                  DataCell(Text(
                      _categories[laporan.categoryId] ?? 'Tidak ada kategori')),
                  DataCell(Text(laporan.namaPelapor ?? '-')),
                  DataCell(
                    Container(
                      padding:
                          EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                      decoration: BoxDecoration(
                        color: Colors.white,
                        borderRadius: BorderRadius.circular(20),
                        border: Border.all(color: statusColor),
                      ),
                      child: Text(
                        formattedStatus,
                        style: TextStyle(
                          color: statusColor,
                          fontWeight: FontWeight.w600,
                          fontSize: 12,
                        ),
                      ),
                    ),
                  ),
                  DataCell(
                    IconButton(
                      icon: Icon(Icons.visibility_outlined),
                      color: Colors.blue,
                      tooltip: 'Lihat Detail',
                      onPressed: () {
                        // Check if laporan.id is not null before navigating
                        if (laporan.id != null) {
                          Navigator.push(
                            context,
                            MaterialPageRoute(
                              builder: (context) => DetailLaporanPKDosen(
                                laporan: laporan,
                                id: laporan.id!,
                              ),
                            ),
                          );
                        } else {
                          // Handle the null id case
                          ScaffoldMessenger.of(context).showSnackBar(
                            SnackBar(
                              content: Text(
                                  'Tidak dapat melihat detail, ID laporan tidak valid'),
                              backgroundColor: Colors.red,
                            ),
                          );
                        }
                      },
                    ),
                  ),
                ],
              );
            }).toList(),
          ),
        ),
      ),
    );
  }

  Widget _buildPagination() {
    final totalPages = (_filteredLaporan.length / _itemsPerPage).ceil();

    return Padding(
      padding: const EdgeInsets.only(top: 8.0),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(
            'Menampilkan ${(_currentPage - 1) * _itemsPerPage + 1}-${_currentPage * _itemsPerPage > _filteredLaporan.length ? _filteredLaporan.length : _currentPage * _itemsPerPage} dari ${_filteredLaporan.length} laporan',
            style: TextStyle(
              color: Colors.grey.shade600,
              fontSize: 13,
            ),
          ),
          Row(
            children: [
              IconButton(
                onPressed: _currentPage > 1
                    ? () {
                        setState(() {
                          _currentPage--;
                        });
                      }
                    : null,
                icon: Icon(Icons.chevron_left),
                color: _currentPage > 1 ? Colors.blue : Colors.grey.shade400,
                tooltip: 'Halaman sebelumnya',
              ),
              Container(
                padding: EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(20),
                  border: Border.all(color: Colors.grey.shade300),
                ),
                child: Text(
                  '$_currentPage / $totalPages',
                  style: TextStyle(
                    fontWeight: FontWeight.w600,
                    color: Colors.grey.shade800,
                  ),
                ),
              ),
              IconButton(
                onPressed: _currentPage < totalPages
                    ? () {
                        setState(() {
                          _currentPage++;
                        });
                      }
                    : null,
                icon: Icon(Icons.chevron_right),
                color: _currentPage < totalPages
                    ? Colors.blue
                    : Colors.grey.shade400,
                tooltip: 'Halaman berikutnya',
              ),
            ],
          ),
        ],
      ),
    );
  }
}
