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

  // Define elegant theme colors
  final Color _primaryColor = Colors.indigo.shade600;
  final Color _accentColor = Colors.indigoAccent;
  final Color _lightAccent = Colors.indigo.shade50;
  final Color _darkGrey = Colors.grey.shade800;
  final Color _mediumGrey = Colors.grey.shade500;
  final Color _lightGrey = Colors.grey.shade200;

  // Track current active route
  String _currentRoute = '';

  @override
  void initState() {
    super.initState();
    _loadUserData();
    // Determine current route from Navigator
    WidgetsBinding.instance.addPostFrameCallback((_) {
      final route = ModalRoute.of(context)?.settings.name ?? '/';
      setState(() {
        _currentRoute = route;
      });
    });
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
    // Determine if we should use compact layout based on screen width
    final screenWidth = MediaQuery.of(context).size.width;
    final isCompact = screenWidth < 768;

    return Drawer(
      elevation: 0,
      backgroundColor: Colors.white,
      child: Column(
        children: [
          // Header with app logo and title
          _buildHeader(isCompact),

          // User profile section
          _buildUserProfile(isCompact),

          // Divider
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 20.0),
            child: Divider(color: _lightGrey, thickness: 1.5),
          ),
          SizedBox(height: 8),

          // Menu items - always vertical
          Expanded(
            child: _buildVerticalMenu(isCompact),
          ),

          // Footer with version
          _buildFooter(),
        ],
      ),
    );
  }

  Widget _buildHeader(bool isCompact) {
    return Container(
      padding: EdgeInsets.only(
          top: isCompact ? 40 : 50, bottom: isCompact ? 16 : 20),
      width: double.infinity,
      color: Colors.white,
      child: Column(
        children: [
          // App logo with elegant shadow
          Container(
            height: isCompact ? 60 : 70,
            width: isCompact ? 60 : 70,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: Colors.white,
              boxShadow: [
                BoxShadow(
                  color: _primaryColor.withOpacity(0.2),
                  blurRadius: 12,
                  offset: Offset(0, 5),
                ),
              ],
            ),
            child: Center(
              child: Image.asset(
                'assets/images/d3ti_logo.png',
                width: isCompact ? 44 : 50,
                height: isCompact ? 44 : 50,
                fit: BoxFit.contain,
              ),
            ),
          ),
          SizedBox(height: isCompact ? 14 : 18),
          // App title with elegant typography
          Text(
            "Pelaporan D3TI",
            style: TextStyle(
              fontSize: isCompact ? 20 : 22,
              fontWeight: FontWeight.w600,
              color: _primaryColor,
              letterSpacing: 0.5,
            ),
          ),
          Text(
            "Sekolah Vokasi",
            style: TextStyle(
              fontSize: isCompact ? 12 : 14,
              color: _mediumGrey,
              letterSpacing: 0.3,
            ),
          ),
          Text(
            "Universitas Sebelas Maret",
            style: TextStyle(
              fontSize: isCompact ? 12 : 14,
              color: _mediumGrey,
              letterSpacing: 0.3,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildUserProfile(bool isCompact) {
    return Container(
      margin:
          EdgeInsets.symmetric(horizontal: 16, vertical: isCompact ? 10 : 16),
      padding: EdgeInsets.all(isCompact ? 12 : 16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.05),
            blurRadius: 10,
            offset: Offset(0, 4),
          ),
        ],
      ),
      child: Row(
        children: [
          // User avatar with subtle gradient border
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
              backgroundColor: Colors.white,
              radius: isCompact ? 18 : 22,
              child: Icon(
                Icons.person,
                size: isCompact ? 22 : 26,
                color: _primaryColor,
              ),
            ),
          ),
          SizedBox(width: 15),
          // User info
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  _isLoading ? "Loading..." : _userName,
                  style: TextStyle(
                    fontSize: isCompact ? 14 : 16,
                    fontWeight: FontWeight.w600,
                    color: _darkGrey,
                  ),
                  overflow: TextOverflow.ellipsis,
                ),
                SizedBox(height: 4),
                Text(
                  _userEmail ?? (_userRole != null ? "Role: $_userRole" : ""),
                  style: TextStyle(
                    color: _mediumGrey,
                    fontSize: isCompact ? 10 : 12,
                  ),
                  overflow: TextOverflow.ellipsis,
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  // Vertical menu layout for all screen sizes
  Widget _buildVerticalMenu(bool isCompact) {
    return ListView(
      padding: EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      children: [
        _buildMenuHeader("MAIN MENU"),
        _buildMenuItem(
          icon: Icons.dashboard_outlined,
          title: 'Dashboard',
          onTap: () => _navigateTo(context, '/home'),
          isActive: _isActivePage('/home'),
          isCompact: isCompact,
        ),
        _buildMenuHeader("REPORTS"),
        _buildMenuItem(
          icon: Icons.report_outlined,
          title: 'Laporan Kejadian',
          onTap: () => _navigateTo(context, '/reports'),
          isActive: _isActivePage('/reports'),
          iconColor: Colors.green.shade600,
          isCompact: isCompact,
        ),
        _buildMenuItem(
          icon: Icons.privacy_tip_outlined,
          title: 'Laporan Kekerasan Seksual',
          onTap: () => _navigateTo(context, '/violence-reports'),
          isActive: _isActivePage('/violence-reports'),
          iconColor: Colors.red.shade600,
          isCompact: isCompact,
        ),
        SizedBox(height: 16),
        _buildMenuHeader("ACCOUNT"),
        _buildMenuItem(
          icon: Icons.logout_outlined,
          title: 'Logout',
          onTap: _performLogout,
          isDanger: true,
          isCompact: isCompact,
        ),
      ],
    );
  }

  Widget _buildMenuHeader(String title) {
    return Padding(
      padding: const EdgeInsets.only(left: 8.0, top: 16.0, bottom: 8.0),
      child: Text(
        title,
        style: TextStyle(
          fontSize: 12,
          fontWeight: FontWeight.w600,
          color: _mediumGrey,
          letterSpacing: 1.2,
        ),
      ),
    );
  }

  // Standard menu item with responsive sizing
  Widget _buildMenuItem({
    required IconData icon,
    required String title,
    required Function() onTap,
    bool isActive = false,
    bool isDanger = false,
    Color? iconColor,
    required bool isCompact,
  }) {
    // Define colors based on state and type
    Color bgColor = isActive ? _lightAccent : Colors.transparent;
    Color textIconColor = isDanger
        ? Colors.red.shade400
        : (isActive ? _primaryColor : (iconColor ?? _darkGrey));

    return Container(
      margin: EdgeInsets.symmetric(vertical: 4),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(10),
      ),
      child: Material(
        color: Colors.transparent,
        borderRadius: BorderRadius.circular(10),
        child: InkWell(
          borderRadius: BorderRadius.circular(10),
          onTap: onTap,
          splashColor: _lightAccent,
          highlightColor: _lightAccent.withOpacity(0.5),
          hoverColor: _lightAccent.withOpacity(0.3),
          child: Ink(
            decoration: BoxDecoration(
              color: bgColor,
              borderRadius: BorderRadius.circular(10),
              border: isActive
                  ? Border.all(color: textIconColor.withOpacity(0.3), width: 1)
                  : null,
            ),
            padding: EdgeInsets.symmetric(
                horizontal: 16, vertical: isCompact ? 10 : 12),
            child: Row(
              children: [
                Container(
                  padding: EdgeInsets.all(isCompact ? 6 : 8),
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(8),
                    boxShadow: [
                      BoxShadow(
                        color: textIconColor.withOpacity(0.1),
                        blurRadius: 6,
                        offset: Offset(0, 2),
                      ),
                    ],
                  ),
                  child: Icon(
                    icon,
                    color: textIconColor,
                    size: isCompact ? 16 : 18,
                  ),
                ),
                SizedBox(width: 16),
                Expanded(
                  child: Text(
                    title,
                    style: TextStyle(
                      color: textIconColor,
                      fontWeight: isActive ? FontWeight.w600 : FontWeight.w500,
                      fontSize: isCompact ? 13 : 14,
                    ),
                  ),
                ),
                if (isActive) ...[
                  Container(
                    width: 6,
                    height: 6,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      color: textIconColor,
                    ),
                  ),
                ],
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildFooter() {
    return Container(
      width: double.infinity,
      padding: EdgeInsets.symmetric(vertical: 16),
      child: Column(
        children: [
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 20.0),
            child: Divider(color: _lightGrey, thickness: 1.5),
          ),
          SizedBox(height: 16),
          Text(
            'v1.0.0',
            style: TextStyle(
              color: _mediumGrey,
              fontSize: 12,
            ),
            textAlign: TextAlign.center,
          ),
          SizedBox(height: 4),
          Text(
            '© 2025 D3TI UNS',
            style: TextStyle(
              color: _darkGrey,
              fontSize: 12,
              fontWeight: FontWeight.w500,
            ),
            textAlign: TextAlign.center,
          ),
          SizedBox(height: 16),
        ],
      ),
    );
  }

  // Helper method to navigate and update current route
  void _navigateTo(BuildContext context, String route) {
    Navigator.pushReplacementNamed(context, route);
    setState(() {
      _currentRoute = route;
    });
  }

  // Helper method to check if a page is active
  bool _isActivePage(String route) {
    return _currentRoute == route ||
        (_currentRoute.isEmpty && route == '/home'); // Default to home if empty
  }

  // Logout helper method
  Future<void> _performLogout() async {
    try {
      await TokenManager.clearToken();
      Navigator.pushReplacementNamed(context, '/login');
    } catch (e) {
      print('Error during logout: $e');
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Error during logout: $e')),
      );
    }
  }
}
