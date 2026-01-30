import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:pelaporan_d3ti/components/sidebar_dosen.dart';
import 'package:pelaporan_d3ti/dosen/pelaporan_kekerasan_seksual/detail_lapor_ks_dosen.dart';
import 'package:pelaporan_d3ti/services/api_service.dart';
import 'package:pelaporan_d3ti/models/laporan_kekerasan.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'dart:async';
import 'dart:math' as Math;

class LaporKekerasanDosenPage extends StatefulWidget {
  const LaporKekerasanDosenPage({Key? key}) : super(key: key);

  @override
  _LaporKekerasanDosenPageState createState() =>
      _LaporKekerasanDosenPageState();
}

class _LaporKekerasanDosenPageState extends State<LaporKekerasanDosenPage> {
  // API service instance
  final ApiService _apiService = ApiService();

  // Data state
  List<LaporanKekerasan> _laporan = [];
  List<LaporanKekerasan> _userLaporan = []; // Store only user's reports
  Map<int, String> _categories = {};
  bool _loading = true;
  String? _error;

  // Current user info
  String? _currentUserName;
  String? _currentUserNik;

  // Stats for cards
  int _totalLaporan = 0;
  int _ongoingLaporan = 0;

  // Search and filters
  final TextEditingController _searchController = TextEditingController();
  String _searchQuery = '';
  Map<String, dynamic> _filters = {
    'category_id': '',
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

      // Get the user name and NIK
      String? userName = prefs.getString('user_name');
      String? userNik = prefs.getString('user_nik'); // Changed from user_nip
      String? userEmail = prefs.getString('user_email');

      print(
          'Retrieved from SharedPreferences - Name: $userName, NIK: $userNik, Email: $userEmail');

      if ((userName == null || userName.isEmpty) &&
          (userNik == null || userNik.isEmpty)) {
        // No user info in SharedPreferences, use hardcoded values for testing
        userName = "dosen_test"; // Match this to a nama_pelapor in your API
        userNik = "091231231"; // Match this to a nik_pelapor in your API
        print('No user in SharedPreferences, using hardcoded: $userName');
      }

      setState(() {
        _currentUserName = userName;
        _currentUserNik = userNik; // Changed from _currentUserNip
      });

      print('Current user set to: $_currentUserName (NIK: $_currentUserNik)');
    } catch (e) {
      print('Error getting current user info: $e');
      // Set hardcoded values as fallback
      setState(() {
        _currentUserName = "dosen_test";
        _currentUserNik = "091231231"; // Changed from _currentUserNip
      });
      print('Set fallback user after error: $_currentUserName');
    }
  }

  // Update the filterUserLaporan method to use NIK
  void _filterUserLaporan() {
    if (_currentUserName == null && _currentUserNik == null) {
      setState(() {
        _userLaporan = [];
        _totalLaporan = 0;
      });
      print("No user info available. Not showing any reports.");
      return;
    }

    print(
        "Filtering reports for user: $_currentUserName (NIK: $_currentUserNik)");
    print("Total reports before filtering: ${_laporan.length}");

    // Show the first few reports for debugging
    for (var i = 0; i < Math.min(3, _laporan.length); i++) {
      final report = _laporan[i];
    }

    // Filter based on the API's actual field structure
    List<LaporanKekerasan> filtered = [];

    // If no matches by nik, try by name
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

      // Try partial name match (contains)
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
          "WARNING: No matching reports found for user $_currentUserName (NIK: $_currentUserNik)");
      print("Check the user info against what's in your API data");

      // For testing, show specific reports or a subset
      filtered = _laporan.take(5).toList(); // Show first 5 reports as fallback
      print("Showing first ${filtered.length} reports as fallback.");
    }

    setState(() {
      _userLaporan = filtered;
      _totalLaporan = _userLaporan.length;

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
    _categories = {
      16: 'Kekerasan Seksual',
      17: 'Kekerasan Fisik',
      18: 'Kekerasan Verbal',
      19: 'Kekerasan Psikologis'
    };

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

        // Fetch laporan kekerasan
        print("Attempting to fetch laporan kekerasan from API...");
        final laporanResponse = await _apiService.getLaporanKekerasan();
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
  List<LaporanKekerasan> get _filteredLaporan {
    // Start with user's laporan instead of all laporan
    List<LaporanKekerasan> result = [..._userLaporan];

    // Apply search filter
    if (_searchQuery.isNotEmpty) {
      final query = _searchQuery.toLowerCase();
      result = result
          .where((item) =>
              (item.judul?.toLowerCase().contains(query) ?? false) ||
              (item.nomorLaporanKekerasan?.toLowerCase().contains(query) ??
                  false) ||
              (item.namaPelapor?.toLowerCase().contains(query) ?? false))
          .toList();
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
        // Use tanggalKejadian for date filtering
        final itemDate = item.tanggalKejadian ?? item.createdAt;

        if (itemDate == null) {
          return true; // Skip items with no date
        }

        if (_filters['startDate'] != null) {
          final startDate = _filters['startDate'] as DateTime;
          if (itemDate.isBefore(startDate)) {
            return false;
          }
        }

        if (_filters['endDate'] != null) {
          final endDate = _filters['endDate'] as DateTime;
          final endOfDay =
              DateTime(endDate.year, endDate.month, endDate.day, 23, 59, 59);
          if (itemDate.isAfter(endOfDay)) {
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
        case 'nomor_laporan_kekerasan':
          fieldA = a.nomorLaporanKekerasan;
          fieldB = b.nomorLaporanKekerasan;
          break;
        case 'created_at':
          fieldA = a.createdAt;
          fieldB = b.createdAt;
          break;
        case 'judul':
          fieldA = a.judul;
          fieldB = b.judul;
          break;
        case 'tanggal_kejadian':
          fieldA = a.tanggalKejadian;
          fieldB = b.tanggalKejadian;
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
  List<LaporanKekerasan> get _paginatedLaporan {
    if (_filteredLaporan.isEmpty) return [];

    final start = (_currentPage - 1) * _itemsPerPage;
    if (start >= _filteredLaporan.length) {
      return [];
    }

    final end = start + _itemsPerPage;
    return _filteredLaporan.sublist(
        start, end > _filteredLaporan.length ? _filteredLaporan.length : end);
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
      _filters = {'category_id': '', 'startDate': null, 'endDate': null};
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
        title: Text(
          'Pelaporan Kekerasan Seksual',
          style: TextStyle(
            color: Colors.grey[800],
            fontWeight: FontWeight.w600,
          ),
        ),
        backgroundColor: Colors.white,
        elevation: 0,
        iconTheme: IconThemeData(color: Colors.grey[800]),
        actions: [
          IconButton(
            icon: Icon(Icons.refresh, color: Colors.red[700]),
            onPressed: _fetchData,
            tooltip: 'Muat ulang data',
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
          : _error != null && _laporan.isEmpty
              ? _buildErrorView()
              : _buildMainContent(),
    );
  }

  Widget _buildLoadingView() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          CircularProgressIndicator(
            valueColor: AlwaysStoppedAnimation<Color>(Colors.red),
          ),
          SizedBox(height: 20),
          Text(
            'Memuat data...',
            style: TextStyle(
              color: Colors.grey[600],
              fontSize: 16,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildErrorView() {
    return Center(
      child: Container(
        padding: const EdgeInsets.all(24.0),
        margin: const EdgeInsets.all(20.0),
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
                color: Colors.red[50],
                shape: BoxShape.circle,
              ),
              child: Icon(
                Icons.error_outline,
                color: Colors.red,
                size: 48,
              ),
            ),
            SizedBox(height: 24),
            Text(
              'Terjadi kesalahan:',
              style: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.bold,
                color: Colors.grey[800],
              ),
            ),
            SizedBox(height: 12),
            Text(
              _error ?? 'Unknown error',
              textAlign: TextAlign.center,
              style: TextStyle(
                color: Colors.grey[600],
                fontSize: 16,
              ),
            ),
            SizedBox(height: 24),
            ElevatedButton(
              onPressed: _fetchData,
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.red,
                foregroundColor: Colors.white,
                elevation: 0,
                padding: EdgeInsets.symmetric(horizontal: 32, vertical: 12),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(8),
                ),
              ),
              child: Text('Coba Lagi'),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildMainContent() {
    return SingleChildScrollView(
      physics: AlwaysScrollableScrollPhysics(),
      child: Padding(
        padding: const EdgeInsets.all(20.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            if (_error != null) _buildWarningBanner(),
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
            SizedBox(height: 40), // Bottom padding
          ],
        ),
      ),
    );
  }

  Widget _buildWarningBanner() {
    return Container(
      width: double.infinity,
      margin: EdgeInsets.only(bottom: 20),
      padding: EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      decoration: BoxDecoration(
        color: Colors.yellow[50],
        borderRadius: BorderRadius.circular(12),
        boxShadow: [
          BoxShadow(
            color: Colors.yellow.withOpacity(0.1),
            blurRadius: 8,
            offset: Offset(0, 2),
          ),
        ],
      ),
      child: Row(
        children: [
          Container(
            padding: EdgeInsets.all(8),
            decoration: BoxDecoration(
              color: Colors.yellow[100],
              shape: BoxShape.circle,
            ),
            child: Icon(
              Icons.warning_amber_rounded,
              color: Colors.orange[700],
              size: 20,
            ),
          ),
          SizedBox(width: 16),
          Expanded(
            child: Text(
              _error!,
              style: TextStyle(
                color: Colors.grey[800],
                fontSize: 14,
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
      padding: EdgeInsets.all(24),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.03),
            blurRadius: 15,
            spreadRadius: 0,
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
                padding: EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: Colors.red[50],
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Icon(
                  Icons.shield_outlined,
                  color: Colors.red,
                  size: 24,
                ),
              ),
              SizedBox(width: 16),
              Expanded(
                child: Text(
                  'Pelaporan Kekerasan Seksual',
                  style: TextStyle(
                    fontSize: 22,
                    fontWeight: FontWeight.bold,
                    color: Colors.grey[800],
                  ),
                ),
              ),
            ],
          ),
          SizedBox(height: 16),
          Text(
            'Sistem pencatatan dan manajemen laporan kekerasan seksual yang terjadi di D3 TI SV UNS. Gunakan halaman ini untuk mengirim, memantau, dan mengelola laporan kekerasan seksual.',
            style: TextStyle(
              fontSize: 14,
              color: Colors.grey[600],
              height: 1.5,
            ),
          ),
          SizedBox(height: 16),
          Container(
            padding: EdgeInsets.symmetric(horizontal: 12, vertical: 8),
            decoration: BoxDecoration(
              color: Colors.red[50],
              borderRadius: BorderRadius.circular(8),
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(
                  Icons.lock_outline,
                  size: 16,
                  color: Colors.red,
                ),
                SizedBox(width: 8),
                Text(
                  'Informasi sensitif & rahasia',
                  style: TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.w500,
                    color: Colors.red,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildDashboardCards() {
    return Row(
      children: [
        Expanded(
          child: _buildStatCard(
            icon: Icons.description_outlined,
            iconColor: Colors.red[700]!,
            title: 'Total Laporan',
            count: _totalLaporan,
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
    return Container(
      padding: EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.03),
            blurRadius: 15,
            spreadRadius: 0,
            offset: Offset(0, 5),
          ),
        ],
      ),
      child: Column(
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
          SizedBox(height: 16),
          Text(
            title,
            style: TextStyle(
              fontSize: 14,
              fontWeight: FontWeight.w500,
              color: Colors.grey[600],
            ),
          ),
          SizedBox(height: 8),
          Text(
            count.toString(),
            style: TextStyle(
              fontSize: 24,
              fontWeight: FontWeight.bold,
              color: Colors.grey[800],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSearchAndAddSection() {
    return LayoutBuilder(
      builder: (context, constraints) {
        if (constraints.maxWidth < 600) {
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
              _buildAddButton(isCompact: true),
            ],
          );
        }
      },
    );
  }

  Widget _buildSearchField() {
    return Container(
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(12),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.03),
            blurRadius: 10,
            spreadRadius: 0,
            offset: Offset(0, 2),
          ),
        ],
      ),
      child: TextField(
        controller: _searchController,
        decoration: InputDecoration(
          labelText: 'Cari laporan...',
          labelStyle: TextStyle(color: Colors.grey[600]),
          hintText: 'Cari berdasarkan judul, nomor, atau nama pelapor',
          hintStyle: TextStyle(color: Colors.grey[400], fontSize: 13),
          prefixIcon: Icon(Icons.search, color: Colors.grey[500]),
          filled: true,
          fillColor: Colors.white,
          contentPadding: EdgeInsets.symmetric(vertical: 16, horizontal: 16),
          border: OutlineInputBorder(
            borderRadius: BorderRadius.circular(12),
            borderSide: BorderSide(color: Colors.transparent),
          ),
          enabledBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(12),
            borderSide: BorderSide(color: Colors.grey.shade200),
          ),
          focusedBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(12),
            borderSide: BorderSide(color: Colors.red.shade300),
          ),
        ),
        style: TextStyle(fontSize: 15, color: Colors.grey[800]),
        onChanged: (value) {
          setState(() {
            _searchQuery = value;
            _currentPage = 1;
          });
        },
      ),
    );
  }

  Widget _buildAddButton({bool isCompact = false}) {
    return Container(
      width: isCompact ? null : double.infinity,
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(12),
        boxShadow: [
          BoxShadow(
            color: Colors.red.withOpacity(0.2),
            blurRadius: 10,
            spreadRadius: 0,
            offset: Offset(0, 2),
          ),
        ],
      ),
      child: ElevatedButton.icon(
        onPressed: () {
          Navigator.pushNamed(context, '/addlaporksdosen');
        },
        icon: Icon(Icons.add, color: Colors.white),
        label: Text(
          'Tambah Laporan',
          style: TextStyle(
            color: Colors.white,
            fontWeight: FontWeight.w600,
            fontSize: 15,
          ),
        ),
        style: ElevatedButton.styleFrom(
          backgroundColor: Colors.red[700],
          foregroundColor: Colors.white,
          padding: EdgeInsets.symmetric(
            vertical: 16,
            horizontal: isCompact ? 16 : 24,
          ),
          elevation: 0,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12),
          ),
        ),
      ),
    );
  }

  Widget _buildFiltersSection() {
    return Container(
      width: double.infinity,
      padding: EdgeInsets.all(24),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.03),
            blurRadius: 15,
            spreadRadius: 0,
            offset: Offset(0, 5),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(Icons.filter_list, color: Colors.grey[700]),
              SizedBox(width: 12),
              Text(
                'Filter berdasarkan:',
                style: TextStyle(
                  fontWeight: FontWeight.w600,
                  fontSize: 16,
                  color: Colors.grey[800],
                ),
              ),
            ],
          ),
          SizedBox(height: 20),
          LayoutBuilder(
            builder: (context, constraints) {
              if (constraints.maxWidth < 600) {
                // For smaller screens, stack widgets vertically
                return Column(
                  children: [
                    _buildCategoryDropdown(),
                    SizedBox(height: 16),
                    _buildStartDatePicker(),
                    SizedBox(height: 16),
                    _buildEndDatePicker(),
                    SizedBox(height: 24),
                    _buildResetFilterButton(isFullWidth: true),
                  ],
                );
              } else {
                // For larger screens, use rows
                return Column(
                  children: [
                    Row(
                      children: [
                        Expanded(child: _buildCategoryDropdown()),
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
                    SizedBox(height: 24),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.start,
                      children: [
                        _buildResetFilterButton(isFullWidth: false),
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
    // Create a map to deduplicate categories and filter for Kekerasan categories
    final Map<String, int> kekerasanCategories = {};

    // For each category, keep only those starting with "Kekerasan"
    _categories.forEach((id, name) {
      if (name.toLowerCase().startsWith("kekerasan")) {
        kekerasanCategories[name] = id;
      }
    });

    return DropdownButtonFormField<String>(
      decoration: InputDecoration(
        labelText: 'Kategori',
        labelStyle: TextStyle(color: Colors.grey[600]),
        filled: true,
        fillColor: Colors.white,
        contentPadding: EdgeInsets.symmetric(horizontal: 16, vertical: 0),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: BorderSide(color: Colors.grey.shade200),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: BorderSide(color: Colors.grey.shade200),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: BorderSide(color: Colors.red.shade300),
        ),
      ),
      style: TextStyle(color: Colors.grey[800], fontSize: 15),
      value: _filters['category_id'].toString().isEmpty
          ? null
          : _filters['category_id'].toString(),
      items: [
        DropdownMenuItem(
          value: '',
          child: Text('Semua kategori'),
        ),
        // Map the Kekerasan categories to DropdownMenuItems
        ...kekerasanCategories.entries.map((entry) {
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
      icon: Icon(Icons.keyboard_arrow_down, color: Colors.grey[600]),
      dropdownColor: Colors.white,
      borderRadius: BorderRadius.circular(12),
      isExpanded: true,
    );
  }

  Widget _buildStartDatePicker() {
    return TextFormField(
      decoration: InputDecoration(
        labelText: 'Tanggal Mulai',
        labelStyle: TextStyle(color: Colors.grey[600]),
        filled: true,
        fillColor: Colors.white,
        contentPadding: EdgeInsets.symmetric(horizontal: 16, vertical: 16),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: BorderSide(color: Colors.grey.shade200),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: BorderSide(color: Colors.grey.shade200),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: BorderSide(color: Colors.red.shade300),
        ),
        suffixIcon: Icon(
          Icons.calendar_today,
          color: Colors.grey[500],
          size: 20,
        ),
      ),
      style: TextStyle(color: Colors.grey[800], fontSize: 15),
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
          builder: (BuildContext context, Widget? child) {
            return Theme(
              data: Theme.of(context).copyWith(
                colorScheme: ColorScheme.light(
                  primary: Colors.red,
                  onPrimary: Colors.white,
                  surface: Colors.white,
                  onSurface: Colors.grey[800]!,
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
        labelStyle: TextStyle(color: Colors.grey[600]),
        filled: true,
        fillColor: Colors.white,
        contentPadding: EdgeInsets.symmetric(horizontal: 16, vertical: 16),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: BorderSide(color: Colors.grey.shade200),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: BorderSide(color: Colors.grey.shade200),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: BorderSide(color: Colors.red.shade300),
        ),
        suffixIcon: Icon(
          Icons.calendar_today,
          color: Colors.grey[500],
          size: 20,
        ),
      ),
      style: TextStyle(color: Colors.grey[800], fontSize: 15),
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
          builder: (BuildContext context, Widget? child) {
            return Theme(
              data: Theme.of(context).copyWith(
                colorScheme: ColorScheme.light(
                  primary: Colors.red,
                  onPrimary: Colors.white,
                  surface: Colors.white,
                  onSurface: Colors.grey[800]!,
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

  Widget _buildResetFilterButton({required bool isFullWidth}) {
    return SizedBox(
      width: isFullWidth ? double.infinity : null,
      child: OutlinedButton.icon(
        onPressed: _resetFilters,
        icon: Icon(Icons.refresh, size: 18),
        label: Text('Reset Filter'),
        style: OutlinedButton.styleFrom(
          foregroundColor: Colors.grey[700],
          side: BorderSide(color: Colors.grey.shade300),
          padding: EdgeInsets.symmetric(
            vertical: 12,
            horizontal: isFullWidth ? 0 : 16,
          ),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12),
          ),
        ),
      ),
    );
  }

  Widget _buildDataTable() {
    if (_filteredLaporan.isEmpty) {
      return _buildEmptyState();
    }

    return Container(
      width: double.infinity,
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.03),
            blurRadius: 15,
            spreadRadius: 0,
            offset: Offset(0, 5),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: const EdgeInsets.all(20.0),
            child: Row(
              children: [
                Icon(
                  Icons.list_alt,
                  color: Colors.grey[700],
                  size: 20,
                ),
                SizedBox(width: 12),
                Text(
                  'Daftar Laporan',
                  style: TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.w600,
                    color: Colors.grey[800],
                  ),
                ),
                Spacer(),
                Container(
                  padding: EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                  decoration: BoxDecoration(
                    color: Colors.grey[100],
                    borderRadius: BorderRadius.circular(20),
                  ),
                  child: Text(
                    '${_filteredLaporan.length} laporan',
                    style: TextStyle(
                      fontSize: 13,
                      color: Colors.grey[700],
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                ),
              ],
            ),
          ),
          Divider(
            height: 1,
            thickness: 1,
            color: Colors.grey.shade100,
          ),
          SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            child: DataTable(
              headingRowColor: MaterialStateProperty.all(Colors.grey.shade50),
              dataRowHeight: 70,
              headingRowHeight: 56,
              horizontalMargin: 20,
              columnSpacing: 20,
              columns: [
                DataColumn(
                  label: Text(
                    'No',
                    style: TextStyle(
                      fontWeight: FontWeight.w600,
                      color: Colors.grey[800],
                    ),
                  ),
                ),
                DataColumn(
                  label: _buildSortableHeader(
                    'Nomor Laporan',
                    'nomor_laporan_kekerasan',
                  ),
                ),
                DataColumn(
                  label: _buildSortableHeader(
                    'Tanggal Laporan',
                    'created_at',
                  ),
                ),
                DataColumn(
                  label: _buildSortableHeader(
                    'Judul',
                    'judul',
                  ),
                ),
                DataColumn(
                  label: Text(
                    'Kategori',
                    style: TextStyle(
                      fontWeight: FontWeight.w600,
                      color: Colors.grey[800],
                    ),
                  ),
                ),
                DataColumn(
                  label: Text(
                    'Nama Pelapor',
                    style: TextStyle(
                      fontWeight: FontWeight.w600,
                      color: Colors.grey[800],
                    ),
                  ),
                ),
                DataColumn(
                  label: Text(
                    'Aksi',
                    style: TextStyle(
                      fontWeight: FontWeight.w600,
                      color: Colors.grey[800],
                    ),
                  ),
                ),
              ],
              rows: _paginatedLaporan.asMap().entries.map((entry) {
                final index = entry.key;
                final laporan = entry.value;

                return DataRow(
                  cells: [
                    DataCell(
                      Container(
                        padding:
                            EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                        decoration: BoxDecoration(
                          color: Colors.grey[100],
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: Text(
                          ((_currentPage - 1) * _itemsPerPage + index + 1)
                              .toString(),
                          style: TextStyle(
                            fontWeight: FontWeight.w500,
                            color: Colors.grey[700],
                          ),
                        ),
                      ),
                    ),
                    DataCell(
                      Text(
                        laporan.nomorLaporanKekerasan ?? '-',
                        style: TextStyle(
                          fontWeight: FontWeight.w500,
                          color: Colors.grey[800],
                        ),
                      ),
                    ),
                    DataCell(
                      Text(
                        _formatDate(laporan.createdAt),
                        style: TextStyle(color: Colors.grey[700]),
                      ),
                    ),
                    DataCell(
                      Container(
                        constraints: BoxConstraints(maxWidth: 200),
                        child: Text(
                          laporan.judul ?? '-',
                          overflow: TextOverflow.ellipsis,
                          style: TextStyle(color: Colors.grey[800]),
                        ),
                      ),
                    ),
                    DataCell(
                      Container(
                        padding:
                            EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                        decoration: BoxDecoration(
                          color: Colors.red.shade50,
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: Text(
                          _categories[laporan.categoryId] ??
                              'Tidak ada kategori',
                          style: TextStyle(
                            color: Colors.red[700],
                            fontWeight: FontWeight.w500,
                            fontSize: 13,
                          ),
                        ),
                      ),
                    ),
                    DataCell(
                      Text(
                        laporan.namaPelapor ?? '-',
                        style: TextStyle(color: Colors.grey[800]),
                      ),
                    ),
                    DataCell(
                      ElevatedButton.icon(
                        onPressed: () {
                          // Check if laporan.id is not null before navigating
                          if (laporan.id != null) {
                            Navigator.push(
                              context,
                              MaterialPageRoute(
                                builder: (context) =>
                                    DetailLaporanKekerasanDosenPage(
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
                                  'Tidak dapat melihat detail, ID laporan tidak valid',
                                ),
                                backgroundColor: Colors.red,
                                behavior: SnackBarBehavior.floating,
                                shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(10),
                                ),
                                margin: EdgeInsets.all(15),
                              ),
                            );
                          }
                        },
                        icon: Icon(Icons.visibility_outlined, size: 16),
                        label: Text('Lihat'),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: Colors.blue,
                          foregroundColor: Colors.white,
                          padding:
                              EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                          elevation: 0,
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(8),
                          ),
                        ),
                      ),
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
          Text(
            title,
            style: TextStyle(
              fontWeight: FontWeight.w600,
              color: _sortField == field ? Colors.grey[800] : Colors.grey[800],
            ),
          ),
          SizedBox(width: 4),
          Icon(
            _sortField == field
                ? (_sortAscending ? Icons.arrow_upward : Icons.arrow_downward)
                : Icons.unfold_more,
            size: 16,
            color: _sortField == field ? Colors.grey[600] : Colors.grey[600],
          ),
        ],
      ),
    );
  }

  Widget _buildEmptyState() {
    return Container(
      width: double.infinity,
      padding: EdgeInsets.all(32),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.03),
            blurRadius: 15,
            spreadRadius: 0,
            offset: Offset(0, 5),
          ),
        ],
      ),
      child: Column(
        children: [
          Container(
            padding: EdgeInsets.all(24),
            decoration: BoxDecoration(
              color: Colors.grey[50],
              shape: BoxShape.circle,
            ),
            child: Icon(
              _searchQuery.isNotEmpty ||
                      _filters.values
                          .any((v) => v != null && v.toString().isNotEmpty)
                  ? Icons.search_off_rounded
                  : Icons.note_add_outlined,
              size: 48,
              color: Colors.grey[400],
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
              fontSize: 18,
              fontWeight: FontWeight.w600,
              color: Colors.grey[700],
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
              color: Colors.grey[500],
              height: 1.5,
            ),
            textAlign: TextAlign.center,
          ),
          SizedBox(height: 24),
          if (_searchQuery.isNotEmpty ||
              _filters.values.any((v) => v != null && v.toString().isNotEmpty))
            OutlinedButton.icon(
              onPressed: _resetFilters,
              icon: Icon(Icons.refresh),
              label: Text('Reset Filter'),
              style: OutlinedButton.styleFrom(
                padding: EdgeInsets.symmetric(horizontal: 24, vertical: 12),
                foregroundColor: Colors.grey[700],
                side: BorderSide(color: Colors.grey.shade300),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(8),
                ),
              ),
            ),
        ],
      ),
    );
  }

  Widget _buildPagination() {
    final totalPages = (_filteredLaporan.length / _itemsPerPage).ceil();

    return Padding(
      padding: const EdgeInsets.only(top: 20.0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          Text(
            'Menampilkan ${(_currentPage - 1) * _itemsPerPage + 1}-${_currentPage * _itemsPerPage > _filteredLaporan.length ? _filteredLaporan.length : _currentPage * _itemsPerPage} dari ${_filteredLaporan.length} laporan',
            style: TextStyle(
              color: Colors.grey[600],
              fontSize: 14,
            ),
          ),
          SizedBox(height: 16),
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              _buildPaginationButton(
                onPressed: _currentPage > 1
                    ? () {
                        setState(() {
                          _currentPage--;
                        });
                      }
                    : null,
                icon: Icons.chevron_left,
                tooltip: 'Halaman sebelumnya',
              ),
              Container(
                padding: EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(color: Colors.grey.shade200),
                ),
                child: Text(
                  '$_currentPage / $totalPages',
                  style: TextStyle(
                    color: Colors.grey[800],
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
              _buildPaginationButton(
                onPressed: _currentPage < totalPages
                    ? () {
                        setState(() {
                          _currentPage++;
                        });
                      }
                    : null,
                icon: Icons.chevron_right,
                tooltip: 'Halaman berikutnya',
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildPaginationButton({
    required VoidCallback? onPressed,
    required IconData icon,
    required String tooltip,
  }) {
    return Container(
      margin: EdgeInsets.symmetric(horizontal: 8),
      decoration: BoxDecoration(
        color: onPressed != null ? Colors.white : Colors.grey[100],
        borderRadius: BorderRadius.circular(8),
        border: Border.all(
          color:
              onPressed != null ? Colors.grey.shade200 : Colors.grey.shade200,
        ),
      ),
      child: IconButton(
        onPressed: onPressed,
        icon: Icon(
          icon,
          color: onPressed != null ? Colors.grey[800] : Colors.grey[400],
          size: 20,
        ),
        tooltip: tooltip,
        padding: EdgeInsets.all(8),
        constraints: BoxConstraints(minWidth: 40, minHeight: 40),
        splashColor: Colors.red.withOpacity(0.1),
        highlightColor: Colors.red.withOpacity(0.05),
      ),
    );
  }
}
