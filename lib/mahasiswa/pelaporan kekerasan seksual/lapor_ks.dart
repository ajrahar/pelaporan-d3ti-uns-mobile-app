import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:pelaporan_d3ti/components/sidebar.dart'; // Update the import to match your file structure
import 'package:pelaporan_d3ti/mahasiswa/pelaporan%20kekerasan%20seksual/detail_lapor_ks.dart';
import 'package:pelaporan_d3ti/services/api_service.dart';
import 'package:pelaporan_d3ti/models/laporan_kekerasan.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'dart:async';
import 'dart:math' as Math;

class LaporKekerasanPage extends StatefulWidget {
  const LaporKekerasanPage({Key? key}) : super(key: key);

  @override
  _LaporKekerasanPageState createState() => _LaporKekerasanPageState();
}

class _LaporKekerasanPageState extends State<LaporKekerasanPage> {
  // API service instance
  final ApiService _apiService = ApiService();

  // Theme colors for elegant white design
  final Color _primaryColor = Color(0xFF00457C); // Deep blue
  final Color _accentColor = Color(0xFFF44336); // Red accent
  final Color _backgroundColor = Color(0xFFF9FAFC); // Light background
  final Color _cardColor = Colors.white; // Card color
  final Color _textColor = Color(0xFF2D3748); // Dark text
  final Color _lightTextColor = Color(0xFF718096); // Light text
  final Color _borderColor = Color(0xFFE2E8F0); // Border color
  final Color _shadowColor = Color(0x0A000000); // Soft shadow

  // Dynamic user info and time
  String _currentDateTime = '';
  String _currentUserName = '';
  Timer? _timeTimer;

  // Data state
  List<LaporanKekerasan> _laporan = [];
  List<LaporanKekerasan> _userLaporan =
      []; // This will store only the user's reports
  Map<int, String> _categories = {};
  bool _loading = true;
  String? _error;

  // Current user info
  String? _currentUserNim;

  // Stats for cards
  int _totalLaporan = 0;

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

    // Initialize date/time and set up timer to update it
    _updateCurrentTime();
    _timeTimer = Timer.periodic(Duration(seconds: 1), (timer) {
      _updateCurrentTime();
    });

    // Get current user info
    _getCurrentUserInfo().then((_) {
      // Then fetch data
      _fetchData();
    });
  }

  @override
  void dispose() {
    _timeTimer?.cancel();
    super.dispose();
  }

  // Update current date/time - Indonesian time (UTC+7)
  void _updateCurrentTime() {
    final now = DateTime.now().toUtc();
    final jakartaTime = now.add(Duration(hours: 7)); // UTC+7 for WIB
    final formattedTime = DateFormat('yyyy-MM-dd HH:mm:ss').format(jakartaTime);

    if (_currentDateTime != formattedTime) {
      setState(() {
        _currentDateTime = formattedTime;
      });
    }
  }

  // Get current user information from SharedPreferences
  Future<void> _getCurrentUserInfo() async {
    try {
      final prefs = await SharedPreferences.getInstance();

      // Get the user name and NIM
      String? userName = prefs.getString('user_name');
      String? userNim = prefs.getString('user_nim');

      if ((userName == null || userName.isEmpty)) {
        userName = "Pengguna"; // Default if no user name found
      }

      setState(() {
        _currentUserName = userName!;
        _currentUserNim = userNim;
      });
    } catch (e) {
      print('Error getting current user info: $e');
      // Set default values as fallback
      setState(() {
        _currentUserName = "Pengguna";
        _currentUserNim = "";
      });
    }
  }

  // Filter laporan to show only current user's reports
  void _filterUserLaporan() {
    if (_currentUserName.isEmpty &&
        (_currentUserNim == null || _currentUserNim!.isEmpty)) {
      setState(() {
        _userLaporan = [];
        _totalLaporan = 0;
      });
      print("No user info available. Not showing any reports.");
      return;
    }

    // Filter based on the API's actual field structure
    List<LaporanKekerasan> filtered = [];

    // First try to match by nim_pelapor
    if (_currentUserNim != null && _currentUserNim!.isNotEmpty) {
      filtered = _laporan
          .where((report) =>
              report.nimPelapor != null &&
              report.nimPelapor!.toLowerCase() ==
                  _currentUserNim!.toLowerCase())
          .toList();
    }

    // If no matches by nim, try by name
    if (filtered.isEmpty && _currentUserName.isNotEmpty) {
      filtered = _laporan
          .where((report) =>
              report.namaPelapor != null &&
              report.namaPelapor!.toLowerCase() ==
                  _currentUserName.toLowerCase())
          .toList();
    }

    // If still no matches, try alternative fields or partial matches
    if (filtered.isEmpty) {
      // Try partial NIM match (ending with)
      if (_currentUserNim != null && _currentUserNim!.isNotEmpty) {
        filtered = _laporan
            .where((report) =>
                report.nimPelapor != null &&
                report.nimPelapor!
                    .toLowerCase()
                    .endsWith(_currentUserNim!.toLowerCase()))
            .toList();
      }

      // Try partial name match (contains)
      if (filtered.isEmpty && _currentUserName.isNotEmpty) {
        filtered = _laporan
            .where((report) =>
                report.namaPelapor != null &&
                report.namaPelapor!
                    .toLowerCase()
                    .contains(_currentUserName.toLowerCase()))
            .toList();
      }
    }

    // If still no matches, show a sample for debugging
    if (filtered.isEmpty) {
      // For testing, show specific reports or a subset
      filtered = _laporan.take(5).toList(); // Show first 5 reports as fallback
    }

    setState(() {
      _userLaporan = filtered;
      _totalLaporan = _userLaporan.length;
      _error = filtered.isEmpty
          ? "No reports found for user $_currentUserName. Showing sample data instead."
          : null;
    });
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
        final categoriesResponse = await _apiService.getCategories();
        if (categoriesResponse.isNotEmpty) {
          _categories = categoriesResponse;
        }

        // Fetch laporan kekerasan
        final laporanResponse = await _apiService.getLaporanKekerasan();
        if (laporanResponse.isNotEmpty) {
          _laporan = laporanResponse;
          // Filter to only show current user's reports
          _filterUserLaporan();
        }

        setState(() {
          _loading = false;
        });
      } catch (e, stackTrace) {
        print("API ERROR DETAILS: $e");
        print("STACK TRACE: $stackTrace");

        // If API fails, load dummy data
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
      backgroundColor: _backgroundColor,
      appBar: AppBar(
        elevation: 0,
        backgroundColor: _cardColor,
        title: Text(
          'Pelaporan Kekerasan Seksual',
          style: TextStyle(color: _textColor, fontWeight: FontWeight.w600),
        ),
        iconTheme: IconThemeData(color: _textColor),
        actions: [
          IconButton(
            icon: Icon(Icons.refresh, color: _primaryColor),
            onPressed: _fetchData,
          ),
        ],
      ),
      // Use your existing Sidebar without parameters
      drawer: Sidebar(),
      body: _loading
          ? Center(
              child: CircularProgressIndicator(
                valueColor: AlwaysStoppedAnimation<Color>(_primaryColor),
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
        padding: const EdgeInsets.all(24),
        width: double.infinity,
        constraints: BoxConstraints(maxWidth: 600),
        decoration: BoxDecoration(
          color: _cardColor,
          borderRadius: BorderRadius.circular(16),
          boxShadow: [
            BoxShadow(
              color: _shadowColor,
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
                color: _accentColor.withOpacity(0.1),
                shape: BoxShape.circle,
              ),
              child: Icon(Icons.error_outline, color: _accentColor, size: 48),
            ),
            SizedBox(height: 24),
            Text(
              'Terjadi kesalahan:',
              style: TextStyle(
                  fontSize: 22, fontWeight: FontWeight.bold, color: _textColor),
            ),
            SizedBox(height: 12),
            Text(
              _error ?? 'Unknown error',
              textAlign: TextAlign.center,
              style: TextStyle(fontSize: 16, color: _lightTextColor),
            ),
            SizedBox(height: 24),
            ElevatedButton.icon(
              onPressed: _fetchData,
              icon: Icon(Icons.refresh),
              label: Text('Coba Lagi',
                  style: TextStyle(fontWeight: FontWeight.w600)),
              style: ElevatedButton.styleFrom(
                backgroundColor: _primaryColor,
                foregroundColor: Colors.white,
                padding: EdgeInsets.symmetric(horizontal: 32, vertical: 16),
                elevation: 0,
                shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(8)),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildMainContent() {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(20.0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          if (_error != null)
            Container(
              width: double.infinity,
              margin: EdgeInsets.only(bottom: 20),
              padding: EdgeInsets.symmetric(vertical: 12, horizontal: 16),
              decoration: BoxDecoration(
                color: Colors.yellow.shade50,
                border: Border.all(color: Colors.yellow.shade400),
                borderRadius: BorderRadius.circular(8),
              ),
              child: Row(
                children: [
                  Icon(Icons.info_outline, color: Colors.amber.shade700),
                  SizedBox(width: 12),
                  Expanded(
                    child: Text(
                      _error!,
                      style: TextStyle(color: Colors.amber.shade900),
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
          SizedBox(height: 24),
          if (_filteredLaporan.isNotEmpty) _buildPagination(),
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
            color: _shadowColor,
            blurRadius: 15,
            offset: Offset(0, 5),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Pelaporan Kekerasan Seksual',
            style: TextStyle(
              fontSize: 24,
              fontWeight: FontWeight.bold,
              color: _textColor,
            ),
          ),
          SizedBox(height: 12),
          Text(
            'Sistem pencatatan dan manajemen laporan kekerasan seksual yang terjadi di D3 TI SV UNS. Gunakan halaman ini untuk mengirim, memantau, dan mengelola laporan kekerasan seksual.',
            style: TextStyle(
              fontSize: 15,
              height: 1.5,
              color: _lightTextColor,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildDashboardCards() {
    return Container(
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        color: _cardColor,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: _shadowColor,
            blurRadius: 15,
            offset: Offset(0, 5),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Statistik',
            style: TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.bold,
              color: _textColor,
            ),
          ),
          SizedBox(height: 16),
          Row(
            children: [
              _buildStatCard(
                icon: Icons.description,
                iconColor: _accentColor,
                title: 'Total Laporan',
                count: _totalLaporan,
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildStatCard({
    required IconData icon,
    required Color iconColor,
    required String title,
    required int count,
  }) {
    return Expanded(
      child: Container(
        padding: const EdgeInsets.all(20),
        decoration: BoxDecoration(
          color: iconColor.withOpacity(0.05),
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: iconColor.withOpacity(0.1)),
        ),
        child: Row(
          children: [
            Container(
              padding: EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: iconColor.withOpacity(0.1),
                shape: BoxShape.circle,
              ),
              child: Icon(icon, color: iconColor, size: 24),
            ),
            SizedBox(width: 16),
            Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.w500,
                    color: _lightTextColor,
                  ),
                ),
                SizedBox(height: 6),
                Text(
                  count.toString(),
                  style: TextStyle(
                    fontSize: 22,
                    fontWeight: FontWeight.bold,
                    color: _textColor,
                  ),
                ),
              ],
            ),
          ],
        ),
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
                hintText: 'Cari laporan...',
                prefixIcon: Icon(Icons.search, color: _primaryColor),
                filled: true,
                fillColor: _cardColor,
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(8),
                  borderSide: BorderSide(color: _borderColor),
                ),
                enabledBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(8),
                  borderSide: BorderSide(color: _borderColor),
                ),
                focusedBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(8),
                  borderSide: BorderSide(color: _primaryColor),
                ),
              ),
              onChanged: (value) {
                setState(() {
                  _searchQuery = value;
                  _currentPage = 1;
                });
              },
            ),
            SizedBox(height: 12),
            SizedBox(
              width: double.infinity,
              child: ElevatedButton.icon(
                onPressed: () {
                  Navigator.pushNamed(context, '/addlaporks');
                },
                icon: Icon(Icons.add, color: Colors.white),
                label: Text(
                  'Tambah Laporan',
                  style: TextStyle(
                    color: Colors.white,
                    fontWeight: FontWeight.w600,
                    fontSize: 16,
                  ),
                ),
                style: ElevatedButton.styleFrom(
                  backgroundColor: _accentColor,
                  foregroundColor: Colors.white,
                  padding: EdgeInsets.symmetric(vertical: 16),
                  elevation: 0,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(8),
                  ),
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
                  hintText: 'Cari laporan...',
                  prefixIcon: Icon(Icons.search, color: _primaryColor),
                  filled: true,
                  fillColor: _cardColor,
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(8),
                    borderSide: BorderSide(color: _borderColor),
                  ),
                  enabledBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(8),
                    borderSide: BorderSide(color: _borderColor),
                  ),
                  focusedBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(8),
                    borderSide: BorderSide(color: _primaryColor),
                  ),
                ),
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
                Navigator.pushNamed(context, '/addlaporks');
              },
              icon: Icon(Icons.add),
              label: Text(
                'Tambah Laporan',
                style: TextStyle(fontWeight: FontWeight.w600),
              ),
              style: ElevatedButton.styleFrom(
                backgroundColor: _accentColor,
                foregroundColor: Colors.white,
                padding: EdgeInsets.symmetric(horizontal: 20, vertical: 16),
                elevation: 0,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(8),
                ),
              ),
            ),
          ],
        );
      }
    });
  }

  Widget _buildFiltersSection() {
    return Container(
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        color: _cardColor,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: _shadowColor,
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
              Icon(Icons.filter_list, color: _primaryColor, size: 18),
              SizedBox(width: 8),
              Text(
                'Filter berdasarkan:',
                style: TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.w600,
                  color: _textColor,
                ),
              ),
            ],
          ),
          SizedBox(height: 20),
          LayoutBuilder(builder: (context, constraints) {
            if (constraints.maxWidth < 600) {
              // For smaller screens, stack widgets vertically
              return Column(
                children: [
                  _buildCategoryDropdown(),
                  SizedBox(height: 12),
                  _buildStartDatePicker(),
                  SizedBox(height: 12),
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
          }),
          SizedBox(height: 20),
          TextButton.icon(
            onPressed: _resetFilters,
            icon: Icon(Icons.refresh, size: 18),
            label: Text('Reset Filter'),
            style: TextButton.styleFrom(
              foregroundColor: _primaryColor,
              padding: EdgeInsets.symmetric(vertical: 12, horizontal: 16),
            ),
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
        labelStyle: TextStyle(color: _lightTextColor),
        filled: true,
        fillColor: _cardColor,
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(8),
          borderSide: BorderSide(color: _borderColor),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(8),
          borderSide: BorderSide(color: _borderColor),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(8),
          borderSide: BorderSide(color: _primaryColor),
        ),
      ),
      value: _filters['category_id'].toString().isEmpty
          ? null
          : _filters['category_id'].toString(),
      items: [
        DropdownMenuItem(
          value: '',
          child: Text('Semua'),
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
      icon: Icon(Icons.arrow_drop_down, color: _primaryColor),
      isExpanded: true,
      dropdownColor: _cardColor,
    );
  }

  Widget _buildStartDatePicker() {
    return TextFormField(
      decoration: InputDecoration(
        labelText: 'Tanggal Mulai',
        labelStyle: TextStyle(color: _lightTextColor),
        filled: true,
        fillColor: _cardColor,
        suffixIcon: Icon(Icons.calendar_today, color: _primaryColor, size: 18),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(8),
          borderSide: BorderSide(color: _borderColor),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(8),
          borderSide: BorderSide(color: _borderColor),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(8),
          borderSide: BorderSide(color: _primaryColor),
        ),
      ),
      readOnly: true,
      controller: TextEditingController(
        text: _filters['startDate'] != null
            ? DateFormat('yyyy-MM-dd').format(_filters['startDate'] as DateTime)
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
              data: ThemeData.light().copyWith(
                primaryColor: _primaryColor,
                colorScheme: ColorScheme.light(primary: _primaryColor),
                buttonTheme:
                    ButtonThemeData(textTheme: ButtonTextTheme.primary),
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
        labelStyle: TextStyle(color: _lightTextColor),
        filled: true,
        fillColor: _cardColor,
        suffixIcon: Icon(Icons.calendar_today, color: _primaryColor, size: 18),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(8),
          borderSide: BorderSide(color: _borderColor),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(8),
          borderSide: BorderSide(color: _borderColor),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(8),
          borderSide: BorderSide(color: _primaryColor),
        ),
      ),
      readOnly: true,
      controller: TextEditingController(
        text: _filters['endDate'] != null
            ? DateFormat('yyyy-MM-dd').format(_filters['endDate'] as DateTime)
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
              data: ThemeData.light().copyWith(
                primaryColor: _primaryColor,
                colorScheme: ColorScheme.light(primary: _primaryColor),
                buttonTheme:
                    ButtonThemeData(textTheme: ButtonTextTheme.primary),
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
        padding: EdgeInsets.all(40),
        width: double.infinity,
        decoration: BoxDecoration(
          color: _cardColor,
          borderRadius: BorderRadius.circular(16),
          boxShadow: [
            BoxShadow(
              color: _shadowColor,
              blurRadius: 15,
              offset: Offset(0, 5),
            ),
          ],
        ),
        child: Column(
          children: [
            Icon(
              _searchQuery.isNotEmpty ||
                      _filters.values
                          .any((v) => v != null && v.toString().isNotEmpty)
                  ? Icons.search_off
                  : Icons.note_add,
              size: 64,
              color: Colors.grey[300],
            ),
            SizedBox(height: 16),
            Text(
              _searchQuery.isNotEmpty ||
                      _filters.values
                          .any((v) => v != null && v.toString().isNotEmpty)
                  ? 'Tidak ada hasil yang ditemukan'
                  : 'Belum ada laporan yang dibuat',
              style: TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.w500,
                  color: _lightTextColor),
              textAlign: TextAlign.center,
            ),
            SizedBox(height: 8),
            Text(
              _searchQuery.isNotEmpty ||
                      _filters.values
                          .any((v) => v != null && v.toString().isNotEmpty)
                  ? 'Coba mengubah filter atau kata kunci pencarian'
                  : 'Klik tombol "Tambah Laporan" untuk membuat laporan baru',
              style: TextStyle(fontSize: 14, color: _lightTextColor),
              textAlign: TextAlign.center,
            ),
          ],
        ),
      );
    }

    return Container(
      decoration: BoxDecoration(
        color: _cardColor,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: _shadowColor,
            blurRadius: 15,
            offset: Offset(0, 5),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: EdgeInsets.all(20),
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
            child: DataTable(
              headingRowColor: MaterialStateProperty.resolveWith<Color>(
                  (states) => _backgroundColor),
              dataRowColor: MaterialStateProperty.resolveWith<Color>(
                  (states) => _cardColor),
              columnSpacing: 24,
              horizontalMargin: 20,
              headingTextStyle: TextStyle(
                color: _textColor,
                fontWeight: FontWeight.w600,
                fontSize: 14,
              ),
              columns: [
                DataColumn(label: Text('No')),
                DataColumn(
                  label: _buildSortableHeader(
                      'Nomor Laporan', 'nomor_laporan_kekerasan'),
                ),
                DataColumn(
                  label: _buildSortableHeader('Tanggal Laporan', 'created_at'),
                ),
                DataColumn(
                  label: _buildSortableHeader('Judul', 'judul'),
                ),
                DataColumn(label: Text('Kategori')),
                DataColumn(label: Text('Nama Pelapor')),
                DataColumn(label: Text('Aksi')),
              ],
              rows: _paginatedLaporan.asMap().entries.map((entry) {
                final index = entry.key;
                final laporan = entry.value;

                return DataRow(
                  cells: [
                    DataCell(Text(
                      ((_currentPage - 1) * _itemsPerPage + index + 1)
                          .toString(),
                      style: TextStyle(color: _textColor),
                    )),
                    DataCell(Text(
                      laporan.nomorLaporanKekerasan ?? '-',
                      style: TextStyle(color: _textColor),
                    )),
                    DataCell(Text(
                      _formatDate(laporan.createdAt),
                      style: TextStyle(color: _textColor),
                    )),
                    DataCell(Text(
                      laporan.judul ?? '-',
                      style: TextStyle(color: _textColor),
                    )),
                    DataCell(Text(
                      _categories[laporan.categoryId] ?? 'Tidak ada kategori',
                      style: TextStyle(color: _textColor),
                    )),
                    DataCell(Text(
                      laporan.namaPelapor ?? '-',
                      style: TextStyle(color: _textColor),
                    )),
                    DataCell(
                      ElevatedButton.icon(
                        onPressed: () {
                          if (laporan.id != null) {
                            Navigator.push(
                              context,
                              MaterialPageRoute(
                                builder: (context) =>
                                    DetailLaporanKekerasanPage(
                                  laporan: laporan,
                                  id: laporan.id!,
                                ),
                              ),
                            );
                          } else {
                            ScaffoldMessenger.of(context).showSnackBar(
                              SnackBar(
                                content: Text('ID laporan tidak valid'),
                                backgroundColor: _accentColor,
                              ),
                            );
                          }
                        },
                        icon: Icon(Icons.visibility, size: 16),
                        label: Text('Lihat'),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: _primaryColor,
                          foregroundColor: Colors.white,
                          elevation: 0,
                          padding:
                              EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                          textStyle: TextStyle(fontSize: 12),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(6),
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

  Widget _buildSortableHeader(String text, String field) {
    final isSorted = _sortField == field;

    return InkWell(
      onTap: () => _sortBy(field),
      child: Row(
        children: [
          Text(text),
          SizedBox(width: 4),
          Icon(
            isSorted
                ? (_sortAscending ? Icons.arrow_upward : Icons.arrow_downward)
                : Icons.swap_vert,
            size: 16,
            color: isSorted ? _primaryColor : Colors.grey,
          ),
        ],
      ),
    );
  }

  Widget _buildPagination() {
    final totalPages = (_filteredLaporan.length / _itemsPerPage).ceil();

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: _cardColor,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: _shadowColor,
            blurRadius: 15,
            offset: Offset(0, 5),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Information text
          Text(
            'Menampilkan ${(_currentPage - 1) * _itemsPerPage + 1}-${_currentPage * _itemsPerPage > _filteredLaporan.length ? _filteredLaporan.length : _currentPage * _itemsPerPage} dari ${_filteredLaporan.length} laporan',
            style: TextStyle(
              color: _lightTextColor,
              fontSize: 14,
            ),
          ),

          SizedBox(height: 16),

          // Pagination controls - centered
          Center(
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                ElevatedButton(
                  onPressed: _currentPage > 1
                      ? () {
                          setState(() {
                            _currentPage--;
                          });
                        }
                      : null,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: _cardColor,
                    foregroundColor: _primaryColor,
                    elevation: 0,
                    padding: EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                    shape: CircleBorder(),
                    side: BorderSide(color: _borderColor),
                  ),
                  child: Icon(Icons.chevron_left, size: 20),
                ),
                Container(
                  margin: EdgeInsets.symmetric(horizontal: 16),
                  padding: EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                  decoration: BoxDecoration(
                    color: _primaryColor.withOpacity(0.1),
                    borderRadius: BorderRadius.circular(20),
                  ),
                  child: Text(
                    '$_currentPage / $totalPages',
                    style: TextStyle(
                      fontWeight: FontWeight.w600,
                      color: _primaryColor,
                    ),
                  ),
                ),
                ElevatedButton(
                  onPressed: _currentPage < totalPages
                      ? () {
                          setState(() {
                            _currentPage++;
                          });
                        }
                      : null,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: _cardColor,
                    foregroundColor: _primaryColor,
                    elevation: 0,
                    padding: EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                    shape: CircleBorder(),
                    side: BorderSide(color: _borderColor),
                  ),
                  child: Icon(Icons.chevron_right, size: 20),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
