import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:pelaporan_d3ti/components/sidebar.dart';
import 'package:pelaporan_d3ti/mahasiswa/pelaporan/detail_lapor_kejadian.dart';
import 'package:pelaporan_d3ti/services/api_service.dart';
import 'package:pelaporan_d3ti/models/laporan.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'dart:async';
import 'dart:math' as Math;

class LaporKejadianPage extends StatefulWidget {
  const LaporKejadianPage({Key? key}) : super(key: key);

  @override
  _LaporKejadianPageState createState() => _LaporKejadianPageState();
}

class _LaporKejadianPageState extends State<LaporKejadianPage> {
  // API service instance
  final ApiService _apiService = ApiService();

  // Data state
  List<Laporan> _laporan = [];
  List<Laporan> _userLaporan = []; // This will store only the user's reports
  Map<int, String> _categories = {};
  bool _loading = true;
  String? _error;

  // Current user info
  String? _currentUserName;
  String? _currentUserNim;

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

  // Theme colors
  final Color _primaryColor = Color(0xFF00A2EA);
  final Color _secondaryColor = Color(0xFFF78052);
  final Color _accentColor = Colors.indigoAccent;
  final Color _backgroundColor = Colors.grey.shade50;
  final Color _cardColor = Colors.white;
  final Color _textColor = Color(0xFF2D3748);
  final Color _subtleTextColor = Color(0xFF718096);
  final Color _borderColor = Color(0xFFE2E8F0);

  // Status colors
  final Map<String, Color> _statusColors = {
    'Belum Diverifikasi': Color(0xFF718096),
    'Diproses': Color(0xFF3182CE),
    'Ditolak': Color(0xFFE53E3E),
    'Selesai': Color(0xFF38A169),
  };

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

      // Get the user name and NIM
      String? userName = prefs.getString('user_name');
      String? userNim = prefs.getString('user_nim');
      String? userEmail = prefs.getString('user_email');

      print(
          'Retrieved from SharedPreferences - Name: $userName, NIM: $userNim, Email: $userEmail');

      if ((userName == null || userName.isEmpty) &&
          (userNim == null || userNim.isEmpty)) {
        // No user info in SharedPreferences, use hardcoded values for testing
        userName = "miftahul01D"; // Match this to a nama_pelapor in your API
        userNim = "miftahul01D"; // Match this to a ni_pelapor in your API
        print('No user in SharedPreferences, using hardcoded: $userName');
      }

      setState(() {
        _currentUserName = userName;
        _currentUserNim = userNim;
      });

      print('Current user set to: $_currentUserName (NIM: $_currentUserNim)');
    } catch (e) {
      print('Error getting current user info: $e');
      // Set hardcoded values as fallback
      setState(() {
        _currentUserName = "miftahul01D";
        _currentUserNim = "miftahul01D";
      });
      print('Set fallback user after error: $_currentUserName');
    }
  }

  // Filter laporan to show only current user's reports
  void _filterUserLaporan() {
    if (_currentUserName == null && _currentUserNim == null) {
      setState(() {
        _userLaporan = [];
        _totalLaporan = 0;
        _dalamProses = 0;
        _selesai = 0;
      });
      print("No user info available. Not showing any reports.");
      return;
    }

    print(
        "Filtering reports for user: $_currentUserName (NIM: $_currentUserNim)");
    print("Total reports before filtering: ${_laporan.length}");

    // Show the first few reports for debugging
    for (var i = 0; i < Math.min(3, _laporan.length); i++) {
      final report = _laporan[i];
      print(
          "Report ${i + 1}: ID: ${report.id}, nama_pelapor: ${report.namaPelapor}, ni_pelapor: ${report.niPelapor}");
    }

    // Filter based on the API's actual field structure
    List<Laporan> filtered = [];

    // First try to match by ni_pelapor
    if (_currentUserNim != null && _currentUserNim!.isNotEmpty) {
      filtered = _laporan
          .where((report) =>
              report.niPelapor != null &&
              report.niPelapor!.toLowerCase() == _currentUserNim!.toLowerCase())
          .toList();

      print("Filtered by ni_pelapor: found ${filtered.length} matches");
    }

    // If no matches by nim, try by name
    if (filtered.isEmpty &&
        _currentUserName != null &&
        _currentUserName!.isNotEmpty) {
      filtered = _laporan
          .where((report) =>
              report.namaPelapor != null && // Add null check
              report.namaPelapor!.toLowerCase() == // Use null assertion
                  _currentUserName!.toLowerCase())
          .toList();

      print("Filtered by nama_pelapor: found ${filtered.length} matches");
    }

    // If still no matches, try alternative fields or partial matches
    if (filtered.isEmpty) {
      print("No exact matches found, trying partial matches...");

      // Try partial NIM match (ending with)
      if (_currentUserNim != null && _currentUserNim!.isNotEmpty) {
        filtered = _laporan
            .where((report) =>
                report.niPelapor != null &&
                report.niPelapor!
                    .toLowerCase()
                    .endsWith(_currentUserNim!.toLowerCase()))
            .toList();

        print("Partial ni_pelapor match: found ${filtered.length} matches");
      }

      // Try partial name match (contains)
      if (filtered.isEmpty &&
          _currentUserName != null &&
          _currentUserName!.isNotEmpty) {
        filtered = _laporan
            .where((report) =>
                report.namaPelapor != null && // Add null check
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
          "WARNING: No matching reports found for user $_currentUserName (NIM: $_currentUserNim)");
      print("Check the user info against what's in your API data");

      // For testing, show specific reports or a subset
      filtered = _laporan.take(5).toList(); // Show first 5 reports as fallback
      print("Showing first ${filtered.length} reports as fallback.");
    }

    setState(() {
      _userLaporan = filtered;
      _totalLaporan = _userLaporan.length;
      _dalamProses =
          _userLaporan.where((item) => item.status == 'verified').length;
      _selesai = _userLaporan.where((item) => item.status == 'finished').length;

      // Add debug info to show in the UI
      _error = filtered.isEmpty
          ? "No reports found for user $_currentUserName. Showing sample data instead."
          : null;
    });

    print(
        'Filtered ${_laporan.length} reports down to ${_userLaporan.length} for user $_currentUserName');
  }

  // Dummy data for testing when API is not available
  void _loadDummyData() {
    // Filter to only show current user's reports
    _filterUserLaporan();

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
          Set<String> uniqueNims = Set<String>();
          _laporan.forEach((report) {
            if (report.niPelapor != null && report.niPelapor!.isNotEmpty) {
              uniqueNims.add(report.niPelapor!);
            }
          });

          print("Unique ni_pelapor values: ${uniqueNims.join(', ')}");

          // Filter to only show current user's reports
          _filterUserLaporan();
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
    // Start with user's laporan instead of all laporan
    List<Laporan> result = [..._userLaporan];

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
    return _statusColors[status] ?? _statusColors['Belum Diverifikasi']!;
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
      appBar: AppBar(
        elevation: 0,
        backgroundColor: Colors.white,
        title: Text(
          'Pelaporan Kejadian',
          style: TextStyle(
            color: _textColor,
            fontWeight: FontWeight.w600,
            fontSize: 18,
            letterSpacing: 0.2,
          ),
        ),
        iconTheme: IconThemeData(color: _primaryColor),
        actions: [
          IconButton(
            icon: Icon(Icons.refresh, color: _primaryColor),
            onPressed: _fetchData,
            tooltip: 'Refresh Data',
          ),
        ],
      ),
      drawer: Sidebar(),
      backgroundColor: _backgroundColor,
      body: _loading
          ? Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  CircularProgressIndicator(color: _primaryColor),
                  SizedBox(height: 16),
                  Text(
                    'Memuat data...',
                    style: TextStyle(
                      color: _subtleTextColor,
                      fontSize: 16,
                    ),
                  ),
                ],
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
        width: double.infinity,
        margin: const EdgeInsets.all(24.0),
        padding: const EdgeInsets.all(24.0),
        decoration: BoxDecoration(
          color: _cardColor,
          borderRadius: BorderRadius.circular(16),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(0.05),
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
                color: Colors.red.shade50,
                shape: BoxShape.circle,
              ),
              child: Icon(Icons.error_outline,
                  color: Colors.red.shade400, size: 56),
            ),
            SizedBox(height: 24),
            Text(
              'Terjadi kesalahan:',
              style: TextStyle(
                fontSize: 20,
                fontWeight: FontWeight.w600,
                color: _textColor,
              ),
            ),
            SizedBox(height: 12),
            Text(
              _error ?? 'Unknown error',
              style: TextStyle(
                fontSize: 16,
                color: _subtleTextColor,
                height: 1.5,
              ),
              textAlign: TextAlign.center,
            ),
            SizedBox(height: 28),
            ElevatedButton(
              onPressed: _fetchData,
              style: ElevatedButton.styleFrom(
                foregroundColor: Colors.white,
                backgroundColor: _primaryColor,
                padding: EdgeInsets.symmetric(horizontal: 32, vertical: 16),
                elevation: 0,
                shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(8)),
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(Icons.refresh, size: 20),
                  SizedBox(width: 8),
                  Text(
                    'Coba Lagi',
                    style: TextStyle(
                      fontSize: 16,
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

  Widget _buildMainContent() {
    return SingleChildScrollView(
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          if (_error != null) _buildWarningBanner(),
          _buildHeader(),
          SizedBox(height: 20),
          _buildDashboardCards(),
          SizedBox(height: 24),
          _buildFiltersSection(),
          SizedBox(height: 24),
          _buildSearchAndAddSection(),
          SizedBox(height: 24),
          _buildDataTable(),
          SizedBox(height: 24),
          if (_filteredLaporan.isNotEmpty) _buildPagination(),
          SizedBox(height: 40),
        ],
      ),
    );
  }

  Widget _buildWarningBanner() {
    return Container(
      width: double.infinity,
      margin: EdgeInsets.only(bottom: 20),
      padding: EdgeInsets.symmetric(horizontal: 18, vertical: 14),
      decoration: BoxDecoration(
        color: Colors.amber.shade50,
        border: Border.all(color: Colors.amber.shade200),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Row(
        children: [
          Icon(Icons.warning_amber_rounded,
              color: Colors.amber.shade700, size: 24),
          SizedBox(width: 16),
          Expanded(
            child: Text(
              _error!,
              style: TextStyle(
                fontSize: 15,
                color: Colors.amber.shade900,
                height: 1.5,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildHeader() {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        color: _cardColor,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.04),
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
              Container(
                padding: EdgeInsets.all(10),
                decoration: BoxDecoration(
                  color: _primaryColor.withOpacity(0.1),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Icon(
                  Icons.assignment_outlined,
                  color: _primaryColor,
                  size: 28,
                ),
              ),
              SizedBox(width: 16),
              Text(
                'Pelaporan Kejadian',
                style: TextStyle(
                  fontSize: 24,
                  fontWeight: FontWeight.bold,
                  color: _textColor,
                  letterSpacing: 0.2,
                ),
              ),
            ],
          ),
          SizedBox(height: 16),
          Text(
            'Sistem pencatatan dan manajemen laporan kejadian yang terjadi di D3 TI SV UNS. Gunakan halaman ini untuk mengirim, memantau, dan mengelola laporan kejadian.',
            style: TextStyle(
              fontSize: 15,
              color: _subtleTextColor,
              height: 1.5,
              letterSpacing: 0.1,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildDashboardCards() {
    return LayoutBuilder(builder: (context, constraints) {
      // For small screens, stack cards vertically
      if (constraints.maxWidth < 800) {
        return Column(
          children: [
            _buildStatCard(
              icon: Icons.description_outlined,
              iconColor: _primaryColor,
              title: 'Total Laporan',
              count: _totalLaporan,
              fullWidth: true,
            ),
            SizedBox(height: 16),
            _buildStatCard(
              icon: Icons.pending_actions_outlined,
              iconColor: _statusColors['Diproses']!,
              title: 'Dalam Proses',
              count: _dalamProses,
              fullWidth: true,
            ),
            SizedBox(height: 16),
            _buildStatCard(
              icon: Icons.check_circle_outline,
              iconColor: _statusColors['Selesai']!,
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
                iconColor: _primaryColor,
                title: 'Total Laporan',
                count: _totalLaporan,
              ),
            ),
            SizedBox(width: 16),
            Expanded(
              child: _buildStatCard(
                icon: Icons.pending_actions_outlined,
                iconColor: _statusColors['Diproses']!,
                title: 'Dalam Proses',
                count: _dalamProses,
              ),
            ),
            SizedBox(width: 16),
            Expanded(
              child: _buildStatCard(
                icon: Icons.check_circle_outline,
                iconColor: _statusColors['Selesai']!,
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
        color: _cardColor,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.04),
            blurRadius: 12,
            offset: Offset(0, 4),
          ),
        ],
      ),
      child: fullWidth
          ? Row(
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
                    size: 24,
                  ),
                ),
                SizedBox(width: 20),
                Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      count.toString(),
                      style: TextStyle(
                        fontSize: 28,
                        fontWeight: FontWeight.bold,
                        color: _textColor,
                      ),
                    ),
                    SizedBox(height: 4),
                    Text(
                      title,
                      style: TextStyle(
                        fontSize: 15,
                        color: _subtleTextColor,
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
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Icon(
                    icon,
                    color: iconColor,
                    size: 24,
                  ),
                ),
                SizedBox(height: 20),
                Text(
                  count.toString(),
                  style: TextStyle(
                    fontSize: 28,
                    fontWeight: FontWeight.bold,
                    color: _textColor,
                  ),
                ),
                SizedBox(height: 4),
                Text(
                  title,
                  style: TextStyle(
                    fontSize: 15,
                    color: _subtleTextColor,
                  ),
                ),
              ],
            ),
    );
  }

  Widget _buildSearchAndAddSection() {
    return LayoutBuilder(builder: (context, constraints) {
      if (constraints.maxWidth < 800) {
        // For smaller screens, stack widgets vertically
        return Column(
          children: [
            _buildSearchField(),
            SizedBox(height: 16),
            _buildAddButton(),
          ],
        );
      } else {
        // For larger screens, use a row
        return Row(
          children: [
            Expanded(child: _buildSearchField()),
            SizedBox(width: 16),
            _buildAddButton(),
          ],
        );
      }
    });
  }

  Widget _buildSearchField() {
    return Container(
      decoration: BoxDecoration(
        color: _cardColor,
        borderRadius: BorderRadius.circular(12),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.03),
            blurRadius: 8,
            offset: Offset(0, 2),
          ),
        ],
      ),
      child: TextField(
        controller: _searchController,
        decoration: InputDecoration(
          hintText: 'Cari laporan...',
          hintStyle: TextStyle(color: Colors.grey[400], fontSize: 15),
          prefixIcon: Icon(Icons.search, color: _primaryColor, size: 20),
          border: OutlineInputBorder(
            borderRadius: BorderRadius.circular(12),
            borderSide: BorderSide.none,
          ),
          enabledBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(12),
            borderSide: BorderSide.none,
          ),
          focusedBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(12),
            borderSide: BorderSide(color: _primaryColor, width: 1),
          ),
          contentPadding: EdgeInsets.symmetric(vertical: 16),
          filled: true,
          fillColor: _cardColor,
        ),
        onChanged: (value) {
          setState(() {
            _searchQuery = value;
            _currentPage = 1;
          });
        },
      ),
    );
  }

  Widget _buildAddButton() {
    return Container(
      height: 56,
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(12),
        boxShadow: [
          BoxShadow(
            color: _primaryColor.withOpacity(0.2),
            blurRadius: 8,
            offset: Offset(0, 3),
          ),
        ],
      ),
      child: ElevatedButton.icon(
        onPressed: () {
          Navigator.pushNamed(context, '/addlaporkejadian');
        },
        icon: Icon(Icons.add_circle_outline, size: 20),
        label: Text(
          'Tambah Laporan',
          style: TextStyle(
            fontSize: 15,
            fontWeight: FontWeight.w600,
            letterSpacing: 0.3,
          ),
        ),
        style: ElevatedButton.styleFrom(
          foregroundColor: Colors.white,
          backgroundColor: _primaryColor,
          padding: EdgeInsets.symmetric(horizontal: 20, vertical: 16),
          elevation: 0,
          shape:
              RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        ),
      ),
    );
  }

  Widget _buildFiltersSection() {
    return Container(
      padding: EdgeInsets.all(24),
      decoration: BoxDecoration(
        color: _cardColor,
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
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                'Filter Pencarian',
                style: TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.w600,
                  color: _textColor,
                ),
              ),
              TextButton.icon(
                onPressed: _resetFilters,
                icon: Icon(Icons.refresh, size: 18),
                label: Text('Reset Filter'),
                style: TextButton.styleFrom(
                  foregroundColor: _primaryColor,
                ),
              ),
            ],
          ),
          SizedBox(height: 20),
          LayoutBuilder(
            builder: (context, constraints) {
              if (constraints.maxWidth < 800) {
                // For smaller screens, stack filters vertically
                return Column(
                  children: [
                    _buildCategoryDropdown(),
                    SizedBox(height: 16),
                    _buildStatusDropdown(),
                    SizedBox(height: 16),
                    _buildStartDatePicker(),
                    SizedBox(height: 16),
                    _buildEndDatePicker(),
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
                  ],
                );
              }
            },
          ),
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
        // Only add this category if we haven't seen this name yet,
        // or if we want to replace the previous entry with this one
        if (!uniqueCategories.containsKey(name)) {
          uniqueCategories[name] = id;
        }
      }
    });

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Kategori',
          style: TextStyle(
            fontSize: 14,
            fontWeight: FontWeight.w500,
            color: _textColor,
          ),
        ),
        SizedBox(height: 8),
        Container(
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(12),
            color: _cardColor,
            border: Border.all(color: _borderColor),
          ),
          child: DropdownButtonFormField<String>(
            decoration: InputDecoration(
              contentPadding:
                  EdgeInsets.symmetric(horizontal: 16, vertical: 12),
              border: InputBorder.none,
              hintText: 'Pilih Kategori',
              hintStyle: TextStyle(color: Colors.grey[400]),
            ),
            icon: Icon(Icons.keyboard_arrow_down, color: _subtleTextColor),
            value: _filters['category_id'].toString().isEmpty
                ? null
                : _filters['category_id'].toString(),
            items: [
              DropdownMenuItem(
                value: '',
                child: Text('Semua Kategori'),
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
            dropdownColor: _cardColor,
            style: TextStyle(
              fontSize: 15,
              color: _textColor,
            ),
            isExpanded: true,
          ),
        ),
      ],
    );
  }

  Widget _buildStatusDropdown() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Status',
          style: TextStyle(
            fontSize: 14,
            fontWeight: FontWeight.w500,
            color: _textColor,
          ),
        ),
        SizedBox(height: 8),
        Container(
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(12),
            color: _cardColor,
            border: Border.all(color: _borderColor),
          ),
          child: DropdownButtonFormField<String>(
            decoration: InputDecoration(
              contentPadding:
                  EdgeInsets.symmetric(horizontal: 16, vertical: 12),
              border: InputBorder.none,
              hintText: 'Pilih Status',
              hintStyle: TextStyle(color: Colors.grey[400]),
            ),
            icon: Icon(Icons.keyboard_arrow_down, color: _subtleTextColor),
            value: _filters['status'].toString().isEmpty
                ? null
                : _filters['status'],
            items: [
              DropdownMenuItem(
                value: '',
                child: Text('Semua Status'),
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
            dropdownColor: _cardColor,
            style: TextStyle(
              fontSize: 15,
              color: _textColor,
            ),
            isExpanded: true,
          ),
        ),
      ],
    );
  }

  Widget _buildStartDatePicker() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Tanggal Mulai',
          style: TextStyle(
            fontSize: 14,
            fontWeight: FontWeight.w500,
            color: _textColor,
          ),
        ),
        SizedBox(height: 8),
        Container(
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(12),
            color: _cardColor,
            border: Border.all(color: _borderColor),
          ),
          child: TextFormField(
            decoration: InputDecoration(
              contentPadding:
                  EdgeInsets.symmetric(horizontal: 16, vertical: 14),
              border: InputBorder.none,
              hintText: 'Pilih Tanggal Mulai',
              hintStyle: TextStyle(color: Colors.grey[400]),
              suffixIcon:
                  Icon(Icons.calendar_today, color: _primaryColor, size: 20),
            ),
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
                        primary: _primaryColor,
                      ),
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
          ),
        ),
      ],
    );
  }

  Widget _buildEndDatePicker() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Tanggal Akhir',
          style: TextStyle(
            fontSize: 14,
            fontWeight: FontWeight.w500,
            color: _textColor,
          ),
        ),
        SizedBox(height: 8),
        Container(
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(12),
            color: _cardColor,
            border: Border.all(color: _borderColor),
          ),
          child: TextFormField(
            decoration: InputDecoration(
              contentPadding:
                  EdgeInsets.symmetric(horizontal: 16, vertical: 14),
              border: InputBorder.none,
              hintText: 'Pilih Tanggal Akhir',
              hintStyle: TextStyle(color: Colors.grey[400]),
              suffixIcon:
                  Icon(Icons.calendar_today, color: _primaryColor, size: 20),
            ),
            readOnly: true,
            controller: TextEditingController(
              text: _filters['endDate'] != null
                  ? DateFormat('dd MMM yyyy')
                      .format(_filters['endDate'] as DateTime)
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
                        primary: _primaryColor,
                      ),
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
          ),
        ),
      ],
    );
  }

  Widget _buildDataTable() {
    if (_filteredLaporan.isEmpty) {
      return Container(
        padding: EdgeInsets.all(40),
        decoration: BoxDecoration(
          color: _cardColor,
          borderRadius: BorderRadius.circular(16),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(0.04),
              blurRadius: 12,
              offset: Offset(0, 4),
            ),
          ],
        ),
        child: Center(
          child: Column(
            children: [
              Icon(
                _searchQuery.isNotEmpty ||
                        _filters.values
                            .any((v) => v != null && v.toString().isNotEmpty)
                    ? Icons.search_off_outlined
                    : Icons.assignment_outlined,
                size: 64,
                color: Colors.grey.shade300,
              ),
              SizedBox(height: 24),
              Text(
                _searchQuery.isNotEmpty ||
                        _filters.values
                            .any((v) => v != null && v.toString().isNotEmpty)
                    ? 'Tidak ada hasil yang ditemukan'
                    : 'Belum ada laporan yang dibuat',
                style: TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.w500,
                  color: _subtleTextColor,
                ),
                textAlign: TextAlign.center,
              ),
              SizedBox(height: 8),
              Text(
                _searchQuery.isNotEmpty ||
                        _filters.values
                            .any((v) => v != null && v.toString().isNotEmpty)
                    ? 'Coba ubah filter pencarian Anda'
                    : 'Klik tombol "Tambah Laporan" untuk membuat laporan baru',
                style: TextStyle(
                  fontSize: 15,
                  color: Colors.grey.shade500,
                ),
                textAlign: TextAlign.center,
              ),
            ],
          ),
        ),
      );
    }

    return Container(
      decoration: BoxDecoration(
        color: _cardColor,
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
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: const EdgeInsets.all(20.0),
            child: Text(
              'Daftar Laporan',
              style: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.w600,
                color: _textColor,
              ),
            ),
          ),
          Divider(height: 1, thickness: 1, color: _borderColor),
          SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            padding: EdgeInsets.symmetric(vertical: 8),
            child: DataTable(
              headingTextStyle: TextStyle(
                color: _textColor,
                fontWeight: FontWeight.w600,
                fontSize: 14,
              ),
              dataTextStyle: TextStyle(
                color: _textColor,
                fontSize: 14,
              ),
              headingRowColor: MaterialStateProperty.all(Colors.grey.shade50),
              horizontalMargin: 20,
              columnSpacing: 20,
              columns: [
                DataColumn(label: Text('No')),
                DataColumn(
                  label: _buildSortableHeader('Nomor Laporan', 'nomor_laporan'),
                ),
                DataColumn(
                  label: _buildSortableHeader('Tanggal', 'created_at'),
                ),
                DataColumn(
                  label: _buildSortableHeader('Judul', 'judul'),
                ),
                DataColumn(label: Text('Kategori')),
                DataColumn(label: Text('Pelapor')),
                DataColumn(
                  label: _buildSortableHeader('Status', 'status'),
                ),
                DataColumn(label: Text('Aksi')),
              ],
              rows: _paginatedLaporan.asMap().entries.map((entry) {
                final index = entry.key;
                final laporan = entry.value;
                final formattedStatus =
                    _formatStatus(laporan.status ?? 'unverified');

                return DataRow(
                  cells: [
                    DataCell(Text(
                        ((_currentPage - 1) * _itemsPerPage + index + 1)
                            .toString())),
                    DataCell(Text(laporan.nomorLaporan ?? '-')),
                    DataCell(Text(_formatDate(laporan.createdAt))),
                    DataCell(
                      ConstrainedBox(
                        constraints: BoxConstraints(maxWidth: 200),
                        child: Text(
                          laporan.judul ?? '-',
                          overflow: TextOverflow.ellipsis,
                          maxLines: 1,
                        ),
                      ),
                    ),
                    DataCell(Text(_categories[laporan.categoryId] ??
                        'Tidak ada kategori')),
                    DataCell(Text(laporan.namaPelapor ?? '-')),
                    DataCell(
                      _buildStatusBadge(formattedStatus),
                    ),
                    DataCell(
                      _buildViewButton(laporan),
                    ),
                  ],
                );
              }).toList(),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSortableHeader(String title, String field) {
    return GestureDetector(
      onTap: () => _sortBy(field),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(title),
          SizedBox(width: 4),
          Icon(
            _sortField == field
                ? (_sortAscending ? Icons.arrow_upward : Icons.arrow_downward)
                : Icons.swap_vert,
            size: 16,
            color: _sortField == field ? _primaryColor : Colors.grey.shade400,
          ),
        ],
      ),
    );
  }

  Widget _buildStatusBadge(String status) {
    final Color statusColor = _getStatusColor(status);

    return Container(
      padding: EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(
        color: statusColor.withOpacity(0.1),
        borderRadius: BorderRadius.circular(30),
        border: Border.all(
          color: statusColor.withOpacity(0.3),
          width: 1,
        ),
      ),
      child: Text(
        status,
        style: TextStyle(
          fontSize: 13,
          fontWeight: FontWeight.w500,
          color: statusColor,
        ),
      ),
    );
  }

  Widget _buildViewButton(Laporan laporan) {
    return TextButton.icon(
      onPressed: () {
        if (laporan.id != null) {
          Navigator.push(
            context,
            MaterialPageRoute(
              builder: (context) => DetailLaporanPage(
                laporan: laporan,
                id: laporan.id!,
              ),
            ),
          );
        } else {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content:
                  Text('Tidak dapat melihat detail, ID laporan tidak valid'),
              backgroundColor: Colors.red.shade400,
              behavior: SnackBarBehavior.floating,
              shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(8)),
              margin: EdgeInsets.all(16),
            ),
          );
        }
      },
      icon: Icon(Icons.visibility_outlined, size: 16),
      label: Text('Lihat'),
      style: TextButton.styleFrom(
        foregroundColor: _primaryColor,
        backgroundColor: _primaryColor.withOpacity(0.1),
        padding: EdgeInsets.symmetric(horizontal: 12, vertical: 8),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
      ),
    );
  }

  Widget _buildPagination() {
    // Safely calculate total pages with a guard against division by zero
    final int totalPages = _itemsPerPage > 0
        ? (_filteredLaporan.length / _itemsPerPage).ceil()
        : 1;

    // Ensure current page is within bounds
    int safeCurrentPage = _currentPage;
    if (safeCurrentPage < 1) safeCurrentPage = 1;
    if (safeCurrentPage > totalPages) safeCurrentPage = totalPages;

    // Safely calculate start and end indexes
    int startIndex = (safeCurrentPage - 1) * _itemsPerPage + 1;
    int endIndex = safeCurrentPage * _itemsPerPage;

    // Ensure end index doesn't exceed total items
    if (endIndex > _filteredLaporan.length) {
      endIndex = _filteredLaporan.length;
    }

    // If no items, adjust start index to avoid "showing 1-0 of 0" text
    if (_filteredLaporan.isEmpty) {
      startIndex = 0;
      endIndex = 0;
    }

    return Container(
      padding: EdgeInsets.symmetric(horizontal: 20, vertical: 16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.03),
            blurRadius: 10,
            offset: Offset(0, 2),
          ),
        ],
      ),
      child: Column(
        // Changed to Column to stack elements vertically
        children: [
          // Info text at the top
          Center(
            child: Text(
              'Menampilkan $startIndex-$endIndex dari ${_filteredLaporan.length} laporan',
              style: TextStyle(
                color: _subtleTextColor,
                fontSize: 14,
              ),
            ),
          ),
          SizedBox(height: 16), // Add spacing between text and buttons

          // Pagination buttons in the center bottom
          Row(
            mainAxisAlignment: MainAxisAlignment.center, // Center the buttons
            children: [
              // Previous page button
              Container(
                height: 40,
                width: 40,
                decoration: BoxDecoration(
                  color:
                      safeCurrentPage > 1 ? Colors.white : Colors.grey.shade100,
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(
                    color: safeCurrentPage > 1
                        ? _primaryColor.withOpacity(0.3)
                        : Colors.grey.shade300,
                  ),
                ),
                child: IconButton(
                  onPressed: safeCurrentPage > 1
                      ? () {
                          setState(() {
                            _currentPage = safeCurrentPage - 1;
                          });
                        }
                      : null,
                  icon: Icon(Icons.chevron_left, size: 20),
                  color: safeCurrentPage > 1
                      ? _primaryColor
                      : Colors.grey.shade400,
                  padding: EdgeInsets.zero,
                  splashRadius: 20,
                  tooltip: 'Halaman Sebelumnya',
                ),
              ),

              // Page number indicator
              Container(
                margin: EdgeInsets.symmetric(horizontal: 16),
                padding: EdgeInsets.symmetric(horizontal: 20, vertical: 8),
                decoration: BoxDecoration(
                  color: _primaryColor,
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Text(
                  '$safeCurrentPage / $totalPages',
                  style: TextStyle(
                    color: Colors.white,
                    fontWeight: FontWeight.w600,
                    fontSize: 14,
                  ),
                ),
              ),

              // Next page button
              Container(
                height: 40,
                width: 40,
                decoration: BoxDecoration(
                  color: safeCurrentPage < totalPages
                      ? Colors.white
                      : Colors.grey.shade100,
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(
                    color: safeCurrentPage < totalPages
                        ? _primaryColor.withOpacity(0.3)
                        : Colors.grey.shade300,
                  ),
                ),
                child: IconButton(
                  onPressed: safeCurrentPage < totalPages
                      ? () {
                          setState(() {
                            _currentPage = safeCurrentPage + 1;
                          });
                        }
                      : null,
                  icon: Icon(Icons.chevron_right, size: 20),
                  color: safeCurrentPage < totalPages
                      ? _primaryColor
                      : Colors.grey.shade400,
                  padding: EdgeInsets.zero,
                  splashRadius: 20,
                  tooltip: 'Halaman Berikutnya',
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildPaginationButton({
    required IconData icon,
    required Function()? onPressed,
  }) {
    final bool isEnabled = onPressed != null;

    return Container(
      decoration: BoxDecoration(
        color: isEnabled ? _accentColor : Colors.grey.shade100,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(
          color:
              isEnabled ? _primaryColor.withOpacity(0.3) : Colors.grey.shade300,
        ),
      ),
      child: IconButton(
        onPressed: onPressed,
        icon: Icon(icon, size: 20),
        color: isEnabled ? _primaryColor : Colors.grey.shade400,
        splashRadius: 24,
        tooltip: isEnabled
            ? (icon == Icons.chevron_left
                ? 'Halaman Sebelumnya'
                : 'Halaman Berikutnya')
            : null,
      ),
    );
  }
}
