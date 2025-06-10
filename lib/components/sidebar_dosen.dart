import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:pelaporan_d3ti/services/token_manager.dart';
import 'package:pelaporan_d3ti/services/api_service.dart';
import 'dart:convert';
import 'package:http/http.dart' as http;

class SidebarDosen extends StatefulWidget {
  const SidebarDosen({Key? key}) : super(key: key);

  @override
  _SidebarDosenState createState() => _SidebarDosenState();
}

class _SidebarDosenState extends State<SidebarDosen> {
  final ApiService _apiService = ApiService();
  String _userName = "Dosen";
  String? _userEmail;
  String? _userRole;
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _loadUserData();
  }

  Future<void> _loadUserData() async {
    setState(() {
      _isLoading = true;
    });

    try {
      // First check if we have cached user data
      final prefs = await SharedPreferences.getInstance();
      final userData = prefs.getString('user_data');

      // Get user name and NIP from shared preferences
      final String? currentUserName = prefs.getString('user_name');
      String? currentUserNip = prefs.getString('user_nip');

      if (currentUserName != null && currentUserName.isNotEmpty) {
        _userName = currentUserName;
      }

      if (userData != null) {
        try {
          final data = json.decode(userData);
          setState(() {
            _userEmail = data['email'] ?? prefs.getString('user_email');
            _userRole = data['role'] ?? prefs.getString('user_role');
            // Extract NIP if available in cached data
            if (data['nip'] != null) {
              currentUserNip = data['nip'];
              prefs.setString('user_nip', currentUserNip!);
            }
          });
        } catch (e) {
          print("Error parsing user data: $e");
        }
      } else {
        // Try to get user info from API if no cached data
        final token = await TokenManager.getToken();

        if (token != null && token.isNotEmpty) {
          try {
            final headers = {
              'Content-Type': 'application/json',
              'Authorization': 'Bearer $token'
            };

            // This would be your user profile endpoint
            final response = await http.get(
              Uri.parse('${_apiService.baseUrl}/user/profile'),
              headers: headers,
            );

            if (response.statusCode == 200) {
              final responseData = json.decode(response.body);

              // Check if data is nested under 'data' and then 'user'
              final userData = responseData['data'] != null &&
                      responseData['data']['user'] != null
                  ? responseData['data']['user']
                  : responseData;

              setState(() {
                _userName = userData['name'] ??
                    userData['username'] ??
                    currentUserName ??
                    "Dosen";
                _userEmail = userData['email'];
                _userRole = userData['role'];

                // Extract and save NIP
                if (userData['nip'] != null) {
                  currentUserNip = userData['nip'];
                  prefs.setString('user_nip', currentUserNip!);
                }

                // Save to preferences for future use
                prefs.setString('user_name', _userName);
                if (_userEmail != null)
                  prefs.setString('user_email', _userEmail!);
                if (_userRole != null) prefs.setString('user_role', _userRole!);
                prefs.setString('user_data', json.encode(userData));
              });
            }
          } catch (e) {
            print('Error fetching user profile: $e');
          }
        }
      }

      // Now display NIP in the user info section if available
      if (currentUserNip != null && currentUserNip!.isNotEmpty) {
        setState(() {
          _userEmail = "NIP: $currentUserNip" +
              (_userEmail != null ? " | $_userEmail" : "");
        });
      }
    } catch (e) {
      print('Error loading user data: $e');
    } finally {
      setState(() {
        _isLoading = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Drawer(
      child: Container(
        decoration: BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: [
              Colors.indigo[800]!,
              Colors.indigo[700]!,
              Colors.indigo[600]!,
            ],
          ),
        ),
        child: Column(
          children: [
            // App Title Section
            Container(
              padding: EdgeInsets.only(top: 50, bottom: 20),
              width: double.infinity,
              color: Colors.indigo[900],
              child: Column(
                children: [
                  // App logo or icon
                  Container(
                    height: 70,
                    width: 70,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      color: Colors.white,
                      boxShadow: [
                        BoxShadow(
                          color: Colors.black.withOpacity(0.2),
                          blurRadius: 8,
                          offset: Offset(0, 4),
                        ),
                      ],
                    ),
                    child: Center(
                      child: Image.asset(
                        'assets/images/d3ti_logo.png',
                        width: 50,
                        height: 50,
                        fit: BoxFit.contain,
                      ),
                    ),
                  ),
                  SizedBox(height: 15),
                  // App title text
                  Text(
                    "Pelaporan D3TI UNS",
                    style: TextStyle(
                      fontSize: 20,
                      fontWeight: FontWeight.bold,
                      color: Colors.white,
                      letterSpacing: 1.2,
                    ),
                  ),
                ],
              ),
            ),

            // User info section
            Container(
              padding: EdgeInsets.symmetric(vertical: 20, horizontal: 15),
              width: double.infinity,
              color: Colors.indigo.withOpacity(0.8),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      CircleAvatar(
                        backgroundColor: Colors.white,
                        radius: 25,
                        child: Icon(
                          Icons.person,
                          size: 30,
                          color: Colors.indigo[800],
                        ),
                      ),
                      SizedBox(width: 15),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              _isLoading ? "Loading..." : _userName,
                              style: TextStyle(
                                fontSize: 16,
                                fontWeight: FontWeight.bold,
                                color: Colors.white,
                              ),
                              overflow: TextOverflow.ellipsis,
                            ),
                            SizedBox(height: 3),
                            Text(
                              _userEmail ??
                                  (_userRole != null ? "Role: $_userRole" : ""),
                              style: TextStyle(
                                color: Colors.white.withOpacity(0.9),
                                fontSize: 12,
                              ),
                              overflow: TextOverflow.ellipsis,
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),

            // Menu items
            Expanded(
              child: Container(
                color: Colors.white,
                child: ListView(
                  padding: EdgeInsets.zero,
                  children: [
                    _buildMenuItem(
                      icon: Icons.dashboard,
                      title: 'Dashboard',
                      onTap: () {
                        Navigator.pushReplacementNamed(context, '/dosen-home');
                      },
                      gradientColors: [
                        Colors.indigo[400]!,
                        Colors.indigo[600]!
                      ],
                    ),
                    _buildMenuItem(
                      icon: Icons.assignment,
                      title: 'Kelola Laporan',
                      onTap: () {
                        Navigator.pushNamed(context, '/manage-reports');
                      },
                      gradientColors: [Colors.amber[600]!, Colors.amber[800]!],
                    ),
                    _buildMenuItem(
                      icon: Icons.people,
                      title: 'Data Mahasiswa',
                      onTap: () {
                        Navigator.pushNamed(context, '/manage-students');
                      },
                      gradientColors: [Colors.teal[400]!, Colors.teal[600]!],
                    ),
                    _buildMenuItem(
                      icon: Icons.analytics,
                      title: 'Statistik Laporan',
                      onTap: () {
                        Navigator.pushNamed(context, '/report-statistics');
                      },
                      gradientColors: [
                        Colors.purple[400]!,
                        Colors.purple[600]!
                      ],
                    ),
                    Divider(thickness: 1),
                    _buildMenuItem(
                      icon: Icons.settings,
                      title: 'Pengaturan',
                      onTap: () {
                        Navigator.pushNamed(context, '/settings');
                      },
                      gradientColors: [
                        Colors.blueGrey[400]!,
                        Colors.blueGrey[600]!
                      ],
                    ),
                    _buildMenuItem(
                      icon: Icons.logout,
                      title: 'Logout',
                      onTap: () async {
                        try {
                          await TokenManager.clearToken();
                          Navigator.pushReplacementNamed(context, '/login');
                        } catch (e) {
                          print('Error during logout: $e');
                          ScaffoldMessenger.of(context).showSnackBar(
                            SnackBar(content: Text('Error during logout: $e')),
                          );
                        }
                      },
                      gradientColors: [Colors.grey[400]!, Colors.grey[700]!],
                    ),
                  ],
                ),
              ),
            ),

            // Footer with version info
            Container(
              width: double.infinity,
              color: Colors.indigo[900],
              padding: EdgeInsets.symmetric(vertical: 10),
              child: Text(
                'v1.0.0',
                style: TextStyle(color: Colors.white.withOpacity(0.6)),
                textAlign: TextAlign.center,
              ),
            ),
          ],
        ),
      ),
    );
  }

  // Custom menu item widget with gradient background
  Widget _buildMenuItem({
    required IconData icon,
    required String title,
    required Function() onTap,
    required List<Color> gradientColors,
  }) {
    return Container(
      margin: EdgeInsets.symmetric(horizontal: 10, vertical: 5),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(10),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.1),
            blurRadius: 4,
            offset: Offset(0, 2),
          ),
        ],
      ),
      child: Material(
        borderRadius: BorderRadius.circular(10),
        color: Colors.transparent,
        child: InkWell(
          borderRadius: BorderRadius.circular(10),
          onTap: onTap,
          child: Container(
            padding: EdgeInsets.symmetric(vertical: 12, horizontal: 16),
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(10),
              gradient: LinearGradient(
                begin: Alignment.centerLeft,
                end: Alignment.centerRight,
                colors: gradientColors,
              ),
            ),
            child: Row(
              children: [
                Container(
                  padding: EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: Colors.white.withOpacity(0.3),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Icon(
                    icon,
                    color: Colors.white,
                    size: 22,
                  ),
                ),
                SizedBox(width: 15),
                Text(
                  title,
                  style: TextStyle(
                    color: Colors.white,
                    fontWeight: FontWeight.bold,
                    fontSize: 14,
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
