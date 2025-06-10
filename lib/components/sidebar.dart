import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:pelaporan_d3ti/services/token_manager.dart';
import 'package:pelaporan_d3ti/services/api_service.dart';
import 'dart:convert';
import 'package:http/http.dart' as http;

class Sidebar extends StatefulWidget {
  const Sidebar({Key? key}) : super(key: key);

  @override
  _SidebarState createState() => _SidebarState();
}

class _SidebarState extends State<Sidebar> {
  final ApiService _apiService = ApiService();
  String _userName = "User";
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

      // Get user name and NIM from shared preferences
      final String? currentUserName = prefs.getString('user_name');
      String? currentUserNim = prefs.getString('user_nim');

      if (currentUserName != null && currentUserName.isNotEmpty) {
        _userName = currentUserName;
      }

      if (userData != null) {
        try {
          final data = json.decode(userData);
          setState(() {
            _userEmail = data['email'] ?? prefs.getString('user_email');
            _userRole = data['role'] ?? prefs.getString('user_role');
            // Extract NIM if available in cached data
            if (data['nim'] != null) {
              currentUserNim = data['nim'];
              prefs.setString('user_nim', currentUserNim!);
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
                    "User";
                _userEmail = userData['email'];
                _userRole = userData['role'];

                // Extract and save NIM
                if (userData['nim'] != null) {
                  currentUserNim = userData['nim'];
                  prefs.setString('user_nim', currentUserNim!);
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

      // Now display NIM in the user info section if available
      if (currentUserNim != null && currentUserNim!.isNotEmpty) {
        setState(() {
          _userEmail = "NIM: $currentUserNim" +
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
              Colors.blue[800]!,
              Colors.blue[700]!,
              Colors.blue[600]!,
            ],
          ),
        ),
        child: Column(
          children: [
            // App Title Section
            Container(
              padding: EdgeInsets.only(top: 50, bottom: 20),
              width: double.infinity,
              color: Colors.blue[900],
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
              color: Colors.blue.withOpacity(0.8),
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
                          color: Colors.blue[800],
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
                        Navigator.pushReplacementNamed(context, '/home');
                      },
                      gradientColors: [Colors.blue[400]!, Colors.blue[600]!],
                    ),
                    _buildMenuItem(
                      icon: Icons.report_outlined,
                      title: 'Laporan Kejadian',
                      onTap: () {
                        Navigator.pushNamed(context, '/reports');
                      },
                      gradientColors: [Colors.green[400]!, Colors.green[600]!],
                    ),
                    _buildMenuItem(
                      icon: Icons.privacy_tip_outlined,
                      title: 'Laporan Kekerasan Seksual',
                      onTap: () {
                        Navigator.pushNamed(context, '/violence-reports');
                      },
                      gradientColors: [Colors.red[400]!, Colors.red[600]!],
                    ),
                    Divider(thickness: 1),
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
              color: Colors.blue[900],
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
