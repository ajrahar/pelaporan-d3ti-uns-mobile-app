import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:pelaporan_d3ti/shared/services/token_manager.dart';
import "package:pelaporan_d3ti/shared/services/api_service.dart";
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
  String? _userNik;
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

      // Get user name, NIP and NIK from shared preferences
      final String? currentUserName = prefs.getString('user_name');
      String? currentUserNip = prefs.getString('user_nip');
      _userNik = prefs.getString('user_nik'); // Get NIK from preferences

      if (currentUserName != null && currentUserName.isNotEmpty) {
        _userName = currentUserName;
      }

      if (userData != null) {
        try {
          final data = json.decode(userData);
          setState(() {
            _userEmail = data['email'] ?? prefs.getString('user_email');
            _userRole = data['role'] ?? prefs.getString('user_role');

            // Look for NIK in cached data
            if (data['nik'] != null) {
              _userNik = data['nik'];
              prefs.setString('user_nik', _userNik!);
            }

            // Extract NIP if available in cached data
            if (data['nip'] != null) {
              currentUserNip = data['nip'];
              prefs.setString('user_nip', currentUserNip!);
            }
          });
        } catch (e) {
          print("Error parsing user data: $e");
        }
      }

      // Always try to refresh data from API regardless of cache
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

          print("API Response Status: ${response.statusCode}");
          if (response.statusCode == 200) {
            final responseData = json.decode(response.body);
            print("API Response Body: ${response.body}");

            // Extract NIK directly from the response first
            if (responseData['data'] != null &&
                responseData['data']['dosen'] != null &&
                responseData['data']['dosen']['nik'] != null) {
              setState(() {
                _userNik = responseData['data']['dosen']['nik'];
                // Save NIK to preferences
                prefs.setString('user_nik', _userNik!);
              });
              print("NIK extracted: $_userNik");
            }

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
      backgroundColor: Colors.white,
      elevation: 2,
      child: Column(
        children: [
          // App Title Section with logo
          Container(
            padding: const EdgeInsets.only(top: 50, bottom: 20),
            width: double.infinity,
            decoration: BoxDecoration(
              color: Colors.white,
              boxShadow: [
                BoxShadow(
                  color: Colors.grey.withOpacity(0.1),
                  spreadRadius: 1,
                  blurRadius: 5,
                  offset: const Offset(0, 3),
                ),
              ],
            ),
            child: Column(
              children: [
                // App logo
                Container(
                  height: 80,
                  width: 80,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    color: Colors.white,
                    boxShadow: [
                      BoxShadow(
                        color: Colors.black.withOpacity(0.1),
                        blurRadius: 10,
                        offset: const Offset(0, 4),
                      ),
                    ],
                    border: Border.all(
                      color: Colors.grey.withOpacity(0.2),
                      width: 2,
                    ),
                  ),
                  child: Center(
                    child: Image.asset(
                      'assets/images/d3ti_logo.png',
                      width: 60,
                      height: 60,
                      fit: BoxFit.contain,
                    ),
                  ),
                ),
                const SizedBox(height: 15),
                // App title text
                Text(
                  "Pelaporan D3TI",
                  style: TextStyle(
                    fontSize: 20,
                    fontWeight: FontWeight.w600,
                    color: Colors.blue[800],
                    letterSpacing: 0.5,
                  ),
                ),
                Text(
                  "Sekolah Vokasi",
                  style: TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.w600,
                    color: Colors.grey[800],
                    letterSpacing: 0.5,
                  ),
                ),
                Text(
                  "Universitas Sebelas Maret",
                  style: TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.w600,
                    color: Colors.grey[800],
                    letterSpacing: 0.5,
                  ),
                ),
              ],
            ),
          ),

          // User info section with elegant design
          Container(
            padding: const EdgeInsets.symmetric(vertical: 20, horizontal: 15),
            width: double.infinity,
            decoration: BoxDecoration(
              color: Colors.grey[50],
              border: Border(
                bottom: BorderSide(
                  color: Colors.grey.withOpacity(0.2),
                  width: 1,
                ),
              ),
            ),
            child: Row(
              children: [
                Container(
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    color: Colors.white,
                    boxShadow: [
                      BoxShadow(
                        color: Colors.grey.withOpacity(0.2),
                        spreadRadius: 1,
                        blurRadius: 5,
                      ),
                    ],
                  ),
                  child: CircleAvatar(
                    backgroundColor: Colors.white,
                    radius: 25,
                    child: Icon(
                      Icons.person,
                      size: 30,
                      color: Colors.grey[700],
                    ),
                  ),
                ),
                const SizedBox(width: 15),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        _isLoading ? "Loading..." : _userName,
                        style: TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.w600,
                          color: Colors.grey[800],
                        ),
                        overflow: TextOverflow.ellipsis,
                      ),
                      const SizedBox(height: 3),
                      Text(
                        _isLoading ? "Loading..." : _userNik ?? "NIK: -",
                        style: TextStyle(
                          color: Colors.grey[600],
                          fontSize: 12,
                        ),
                      ),
                      Text(
                        _userEmail ??
                            (_userRole != null ? "Role: $_userRole" : ""),
                        style: TextStyle(
                          color: Colors.grey[600],
                          fontSize: 12,
                        ),
                        overflow: TextOverflow.ellipsis,
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),

          // Menu items - Vertical layout
          Expanded(
            child: Container(
              color: Colors.white,
              child: ListView(
                padding:
                    const EdgeInsets.symmetric(vertical: 10, horizontal: 15),
                children: [
                  _buildMenuItem(
                    icon: Icons.dashboard_outlined,
                    title: 'Dashboard',
                    onTap: () {
                      Navigator.pushReplacementNamed(context, '/homedosen');
                    },
                    iconColor: Colors.blue[700]!,
                  ),
                  const SizedBox(height: 12),
                  _buildMenuItem(
                    icon: Icons.assignment_outlined,
                    title: 'Laporan Kejadian',
                    onTap: () {
                      Navigator.pushNamed(context, '/laporpkdosen');
                    },
                    iconColor: Colors.amber[700]!,
                  ),
                  const SizedBox(height: 12),
                  _buildMenuItem(
                    icon: Icons.people_outlined,
                    title: 'Laporan\nKekerasan Seksual', // Split into two lines
                    onTap: () {
                      Navigator.pushNamed(context, '/laporksdosen');
                    },
                    iconColor: Colors.red[700]!,
                  ),
                  const SizedBox(height: 12),
                  const Divider(
                    thickness: 1,
                    color: Color(0xFFEEEEEE),
                    height: 24,
                  ),
                  _buildMenuItem(
                    icon: Icons.logout,
                    title: 'Logout',
                    onTap: () async {
                      try {
                        await TokenManager.clearToken();
                        Navigator.pushReplacementNamed(context, '/logindosen');
                      } catch (e) {
                        print('Error during logout: $e');
                        ScaffoldMessenger.of(context).showSnackBar(
                          SnackBar(content: Text('Error during logout: $e')),
                        );
                      }
                    },
                    iconColor: Colors.grey[700]!,
                  ),
                ],
              ),
            ),
          ),

          // Footer with version info
          Container(
            width: double.infinity,
            padding: const EdgeInsets.symmetric(vertical: 10),
            decoration: BoxDecoration(
              color: Colors.white,
              boxShadow: [
                BoxShadow(
                  color: Colors.grey.withOpacity(0.1),
                  spreadRadius: 0,
                  blurRadius: 5,
                  offset: const Offset(0, -3),
                ),
              ],
            ),
            child: Text(
              'v1.0.0',
              style: TextStyle(
                color: Colors.grey[600],
                fontSize: 12,
                fontWeight: FontWeight.w500,
              ),
              textAlign: TextAlign.center,
            ),
          ),
        ],
      ),
    );
  }

  // Vertical menu item with elegant design
  Widget _buildMenuItem({
    required IconData icon,
    required String title,
    required Function() onTap,
    required Color iconColor,
  }) {
    return Container(
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(10),
        boxShadow: [
          BoxShadow(
            color: Colors.grey.withOpacity(0.1),
            blurRadius: 4,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Material(
        borderRadius: BorderRadius.circular(10),
        color: Colors.white,
        child: InkWell(
          borderRadius: BorderRadius.circular(10),
          onTap: onTap,
          child: Padding(
            padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 16),
            child: Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: iconColor.withOpacity(0.1),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Icon(
                    icon,
                    color: iconColor,
                    size: 22,
                  ),
                ),
                const SizedBox(width: 15),
                Expanded(
                  child: Text(
                    title,
                    style: TextStyle(
                      color: Colors.grey[800],
                      fontWeight: FontWeight.w500,
                      fontSize: 14,
                    ),
                    maxLines: 2, // Allow up to 2 lines of text
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
