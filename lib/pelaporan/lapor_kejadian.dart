import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:pelaporan_d3ti/pelaporan/detail_lapor_kejadian.dart';
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
    _categories = {
      1: 'Kerusakan Fasilitas',
      2: 'Kehilangan Barang',
      3: 'Kecelakaan',
      4: 'Lainnya'
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
          fieldA = a.id; // Changed from laporanId to id
          fieldB = b.id; // Changed from laporanId to id
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
        return Colors.grey;
      case 'Diproses':
        return Colors.orange;
      case 'Ditolak':
        return Colors.red;
      case 'Selesai':
        return Colors.green;
      default:
        return Colors.grey;
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
      appBar: AppBar(
        title: Text('Pelaporan Kejadian'),
        actions: [
          IconButton(
            icon: Icon(Icons.refresh),
            onPressed: _fetchData,
          ),
        ],
      ),
      body: _loading
          ? Center(child: CircularProgressIndicator())
          : _error != null && _laporan.isEmpty
              ? _buildErrorWidget()
              : _buildMainContent(),
    );
  }

  Widget _buildErrorWidget() {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.error_outline, color: Colors.red, size: 48),
            SizedBox(height: 16),
            Text(
              'Terjadi kesalahan:',
              style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
            ),
            SizedBox(height: 8),
            Text(_error ?? 'Unknown error'),
            SizedBox(height: 16),
            ElevatedButton(
              onPressed: _fetchData,
              child: Text('Coba Lagi'),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildMainContent() {
    return SingleChildScrollView(
      child: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            if (_error != null)
              Padding(
                padding: const EdgeInsets.only(bottom: 16.0),
                child: Container(
                  width: double.infinity,
                  padding: EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: Colors.yellow.shade100,
                    border: Border.all(color: Colors.yellow.shade700),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Row(
                    children: [
                      Icon(Icons.warning, color: Colors.yellow.shade800),
                      SizedBox(width: 12),
                      Expanded(child: Text(_error!)),
                    ],
                  ),
                ),
              ),
            _buildHeader(),
            SizedBox(height: 16),
            _buildDashboardCards(),
            SizedBox(height: 16),
            _buildSearchAndAddSection(),
            SizedBox(height: 16),
            _buildFiltersSection(),
            SizedBox(height: 16),
            _buildDataTable(),
            SizedBox(height: 16),
            if (_filteredLaporan.isNotEmpty) _buildPagination(),
          ],
        ),
      ),
    );
  }

  Widget _buildHeader() {
    return Card(
      elevation: 2,
      child: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Pelaporan Kejadian',
              style: TextStyle(
                fontSize: 24,
                fontWeight: FontWeight.bold,
              ),
            ),
            SizedBox(height: 8),
            Text(
              'Sistem pencatatan dan manajemen laporan kejadian yang terjadi di D3 TI SV UNS. Gunakan halaman ini untuk mengirim, memantau, dan mengelola laporan kejadian.',
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

  Widget _buildDashboardCards() {
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
              icon: Icons.pending, // Using pending instead of hourglass_half
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
        // For larger screens, use a row
        return Row(
          children: [
            Expanded(
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
                icon: Icons.pending, // Using pending instead of hourglass_half
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
                prefixIcon: Icon(Icons.search),
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(8),
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
                  Navigator.pushNamed(context, '/addlaporkejadian');
                },
                icon: Icon(Icons.add),
                label: Text('Tambah Laporan'),
                style: ElevatedButton.styleFrom(
                  padding: EdgeInsets.symmetric(vertical: 16),
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
                  prefixIcon: Icon(Icons.search),
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(8),
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
                Navigator.pushNamed(context, '/addlaporkejadian');
              },
              icon: Icon(Icons.add),
              label: Text('Tambah Laporan'),
              style: ElevatedButton.styleFrom(
                padding: EdgeInsets.symmetric(horizontal: 16, vertical: 16),
              ),
            ),
          ],
        );
      }
    });
  }

  Widget _buildFiltersSection() {
    return Card(
      elevation: 1,
      child: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Filter berdasarkan:',
              style: TextStyle(
                fontWeight: FontWeight.bold,
              ),
            ),
            SizedBox(height: 16),
            LayoutBuilder(builder: (context, constraints) {
              if (constraints.maxWidth < 600) {
                // For smaller screens, stack widgets vertically
                return Column(
                  children: [
                    _buildCategoryDropdown(),
                    SizedBox(height: 12),
                    _buildStatusDropdown(),
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
            }),
            SizedBox(height: 16),
            ElevatedButton.icon(
              onPressed: _resetFilters,
              icon: Icon(Icons.refresh),
              label: Text('Reset Filter'),
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.grey[200],
                foregroundColor: Colors.black87,
              ),
            ),
          ],
        ),
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

    return DropdownButtonFormField<String>(
      decoration: InputDecoration(
        labelText: 'Kategori',
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(8),
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
    );
  }

  Widget _buildStatusDropdown() {
    return DropdownButtonFormField<String>(
      decoration: InputDecoration(
        labelText: 'Status',
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(8),
        ),
      ),
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
    );
  }

  Widget _buildStartDatePicker() {
    return TextFormField(
      decoration: InputDecoration(
        labelText: 'Tanggal Mulai',
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(8),
        ),
        suffixIcon: Icon(Icons.calendar_today),
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
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(8),
        ),
        suffixIcon: Icon(Icons.calendar_today),
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
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(24.0),
          child: Column(
            children: [
              Icon(Icons.search_off, size: 48, color: Colors.grey[400]),
              SizedBox(height: 16),
              Text(
                _searchQuery.isNotEmpty ||
                        _filters.values
                            .any((v) => v != null && v.toString().isNotEmpty)
                    ? 'Tidak ada hasil yang ditemukan'
                    : 'Belum ada laporan yang dibuat',
                style: TextStyle(fontSize: 16, color: Colors.grey),
                textAlign: TextAlign.center,
              ),
            ],
          ),
        ),
      );
    }

    // Always use table view regardless of screen size
    return Card(
      elevation: 2,
      child: SingleChildScrollView(
        scrollDirection: Axis.horizontal,
        child: DataTable(
          columns: [
            DataColumn(label: Text('No')),
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

            return DataRow(
              cells: [
                DataCell(Text(((_currentPage - 1) * _itemsPerPage + index + 1)
                    .toString())),
                DataCell(Text(laporan.nomorLaporan ?? '-')),
                DataCell(Text(_formatDate(laporan.createdAt))),
                DataCell(Text(laporan.judul ?? '-')),
                DataCell(Text(
                    _categories[laporan.categoryId] ?? 'Tidak ada kategori')),
                DataCell(Text(laporan.namaPelapor ?? '-')),
                DataCell(
                  Container(
                    padding: EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                    decoration: BoxDecoration(
                      color: _getStatusColor(formattedStatus).withOpacity(0.1),
                      borderRadius: BorderRadius.circular(16),
                    ),
                    child: Text(
                      formattedStatus,
                      style: TextStyle(
                        color: _getStatusColor(formattedStatus),
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),
                ),
                // Di dalam DataCell untuk tombol "Lihat"
                DataCell(
                  IconButton(
                    icon: Icon(Icons.visibility, color: Colors.blue),
                    onPressed: () {
                      // Check if laporan.id is not null before navigating
                      if (laporan.id != null) {
                        Navigator.push(
                          context,
                          MaterialPageRoute(
                            builder: (context) => DetailLaporanPage(
                              laporan:
                                  laporan, // Pass the entire laporan object
                              id: laporan
                                  .id!, // Use the non-null assertion operator to convert int? to int
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
    );
  }

  Widget _buildPagination() {
    final totalPages = (_filteredLaporan.length / _itemsPerPage).ceil();

    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Text(
          'Menampilkan ${(_currentPage - 1) * _itemsPerPage + 1}-${_currentPage * _itemsPerPage > _filteredLaporan.length ? _filteredLaporan.length : _currentPage * _itemsPerPage} dari ${_filteredLaporan.length} laporan',
          style: TextStyle(
            color: Colors.grey[600],
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
              color: _currentPage > 1 ? Colors.blue : Colors.grey,
            ),
            Text('$_currentPage / $totalPages'),
            IconButton(
              onPressed: _currentPage < totalPages
                  ? () {
                      setState(() {
                        _currentPage++;
                      });
                    }
                  : null,
              icon: Icon(Icons.chevron_right),
              color: _currentPage < totalPages ? Colors.blue : Colors.grey,
            ),
          ],
        ),
      ],
    );
  }
}
