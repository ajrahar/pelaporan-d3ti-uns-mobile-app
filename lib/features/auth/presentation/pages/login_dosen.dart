import 'package:flutter/material.dart';
import 'package:pelaporan_d3ti/features/dosen/home/home_screen_dosen.dart';
import "package:pelaporan_d3ti/features/mahasiswa/home_screen/home_screen.dart";
import 'package:http/http.dart' as http;
import "package:pelaporan_d3ti/shared/services/api_service.dart";
import 'dart:convert';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:pelaporan_d3ti/shared/services/token_manager.dart';
import 'dart:math' as Math;

class LoginDosenPage extends StatefulWidget {
  @override
  _LoginDosenPageState createState() => _LoginDosenPageState();
}

class _LoginDosenPageState extends State<LoginDosenPage> {
  // Controllers
  final TextEditingController _emailController = TextEditingController();
  final TextEditingController _passwordController = TextEditingController();

  // States
  bool _rememberMe = false;
  bool _isPasswordVisible = false;
  String? _emailError;
  String? _passwordError;
  bool _isLoading = false;
  bool _prefsInitialized = false;

  // Theme colors
  final Color _primaryColor = Color(0xFF00A2EA);
  final Color _secondaryColor = Color(0xFFF78052);
  final Color _darkTextColor = Color(0xFF2D3748);
  final Color _lightTextColor = Color(0xFF718096);
  final Color _dangerColor = Color(0xFFE53E3E);
  final Color _borderColor = Color(0xFFE2E8F0);
  final Color _backgroundColor = Colors.white;

  @override
  void initState() {
    super.initState();
    // Use a delayed call to avoid PlatformException
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _loadSavedCredentials();
    });
  }

  // Safely get value from SharedPreferences
  Future<T> _safeGetPrefs<T>(String key, T defaultValue,
      Future<T?> Function(SharedPreferences, String) getter) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final value = await getter(prefs, key);
      return value ?? defaultValue;
    } catch (e) {
      print('Error reading preferences: $e');
      return defaultValue;
    }
  }

  // Safely set value in SharedPreferences
  Future<bool> _safeSetPrefs<T>(String key, T value,
      Future<bool> Function(SharedPreferences, String, T) setter) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      return await setter(prefs, key, value);
    } catch (e) {
      print('Error saving preferences: $e');
      return false;
    }
  }

  Future<void> _loadSavedCredentials() async {
    try {
      final prefs = await SharedPreferences.getInstance();

      // Get remember me value for dosen
      final rememberValue = prefs.getBool('remember_me_dosen');

      // Only if we have a valid value
      if (rememberValue != null) {
        setState(() {
          _rememberMe = rememberValue;

          // If remember me is true, load saved email and password
          if (_rememberMe) {
            final savedEmail = prefs.getString('saved_email_dosen');
            final savedPassword = prefs.getString('saved_password_dosen');

            if (savedEmail != null && savedEmail.isNotEmpty) {
              _emailController.text = savedEmail;
            }

            if (savedPassword != null && savedPassword.isNotEmpty) {
              _passwordController.text = savedPassword;
            }
          }

          _prefsInitialized = true;
        });
      } else {
        setState(() {
          _prefsInitialized = true;
        });
      }
    } catch (e) {
      print('Failed to load preferences: $e');
      setState(() {
        _prefsInitialized = true; // Mark as initialized even if it failed
      });
    }
  }

  Future<void> _saveRememberMeState(bool value) async {
    try {
      final prefs = await SharedPreferences.getInstance();

      // Save remember me state for dosen
      await prefs.setBool('remember_me_dosen', value);

      // If remember me is checked and we have credentials, save them
      if (value &&
          _emailController.text.isNotEmpty &&
          _passwordController.text.isNotEmpty) {
        await prefs.setString('saved_email_dosen', _emailController.text);
        await prefs.setString('saved_password_dosen', _passwordController.text);
      }
      // If remember me is unchecked, clear saved credentials
      else if (!value) {
        await prefs.remove('saved_email_dosen');
        await prefs.remove('saved_password_dosen');
      }
    } catch (e) {
      print('Failed to save remember me state: $e');
    }
  }

  Future<void> _saveCredentialsOnSuccessfulLogin() async {
    try {
      final prefs = await SharedPreferences.getInstance();

      // Only save if remember me is checked
      if (_rememberMe) {
        await prefs.setString('saved_email_dosen', _emailController.text);
        await prefs.setString('saved_password_dosen', _passwordController.text);
        await prefs.setBool('remember_me_dosen', true);
      }
    } catch (e) {
      print('Failed to save credentials: $e');
    }
  }

  bool _validateInputs() {
    setState(() {
      // Validasi email
      if (_emailController.text.isEmpty) {
        _emailError = 'Email tidak boleh kosong';
      } else {
        _emailError = null;
      }

      // Validasi password
      if (_passwordController.text.isEmpty) {
        _passwordError = 'Password tidak boleh kosong';
      } else {
        _passwordError = null;
      }
    });

    return _emailError == null && _passwordError == null;
  }

  Future<void> _handleLogin() async {
    if (!_validateInputs()) {
      return;
    }

    setState(() {
      _isLoading = true;
    });

    // Use the new API URL
    // final url = Uri.parse('http://pelaporan-d3ti.my.id/api/login/dosen');
    final url = Uri.parse('https://v3422040.mhs.d3tiuns.com/api/login/dosen');

    try {
      // Create form data
      final formData = {
        'email': _emailController.text,
        'password': _passwordController.text,
      };

      // Add headers similar to Postman
      final headers = {
        'Content-Type': 'application/x-www-form-urlencoded',
        'Accept': 'application/json',
        'User-Agent': 'Mozilla/5.0 Flutter App',
      };

      print("Attempting login with email: ${_emailController.text}");

      // Send POST request
      final response = await http
          .post(
            url,
            headers: headers,
            body: formData,
          )
          .timeout(Duration(seconds: 30));

      setState(() {
        _isLoading = false;
      });

      print("Login response status: ${response.statusCode}");
      print(
          "Login response: ${response.body.substring(0, Math.min(500, response.body.length))}");

      if (response.statusCode == 200 || response.statusCode == 201) {
        // Parse the JSON response
        final jsonResponse = jsonDecode(response.body);

        if (jsonResponse['status'] == true) {
          // Extract user data and token - the key is 'dosen' not 'user'
          final dosenData = jsonResponse['data']['dosen'];
          final token = jsonResponse['data']['token'];

          print('Login successful! Token received');

          // Save token using our TokenManager
          await TokenManager.setToken(token);

          // Save credentials if remember me is checked
          await _saveCredentialsOnSuccessfulLogin();

          // Save dosen data using safer methods
          await _safeSetPrefs('user_id', dosenData['id'],
              (prefs, key, value) => prefs.setInt(key, value));
          await _safeSetPrefs('user_name', dosenData['name'],
              (prefs, key, value) => prefs.setString(key, value));
          await _safeSetPrefs('user_email', dosenData['email'],
              (prefs, key, value) => prefs.setString(key, value));
          await _safeSetPrefs('user_nik', dosenData['nik'],
              (prefs, key, value) => prefs.setString(key, value));
          await _safeSetPrefs('user_no_telp', dosenData['no_telp'],
              (prefs, key, value) => prefs.setString(key, value));

          // Save jabatan information
          final jabatanSekarang = jsonResponse['data']['jabatan_sekarang'];
          if (jabatanSekarang != null) {
            await _safeSetPrefs('jabatan_id', jabatanSekarang['id'],
                (prefs, key, value) => prefs.setInt(key, value));
            await _safeSetPrefs('jabatan_name', jabatanSekarang['name'],
                (prefs, key, value) => prefs.setString(key, value));
          }

          await _safeSetPrefs('is_logged_in', true,
              (prefs, key, value) => prefs.setBool(key, value));
          await _safeSetPrefs('is_dosen', true,
              (prefs, key, value) => prefs.setBool(key, value));

          // Navigate to home screen
          Navigator.pushReplacement(
            context,
            MaterialPageRoute(builder: (context) => HomeScreenDosen()),
          );
        } else {
          _showLoginError(jsonResponse['message'] ?? 'Login failed.');
        }
      } else {
        _showLoginError('Login failed with status: ${response.statusCode}');
      }
    } catch (e) {
      print('Login error: $e');
      setState(() {
        _isLoading = false;
      });
      _showLoginError(
          'Error connecting to server: ${e.toString().split('\n')[0]}');
    }
  }

  void _showLoginError(String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Row(
          children: [
            Icon(Icons.error_outline, color: Colors.white, size: 24),
            SizedBox(width: 16),
            Expanded(child: Text(message)),
          ],
        ),
        backgroundColor: _dangerColor,
        behavior: SnackBarBehavior.floating,
        margin: EdgeInsets.all(16),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        duration: Duration(seconds: 4),
        action: SnackBarAction(
          label: 'OK',
          textColor: Colors.white,
          onPressed: () {
            ScaffoldMessenger.of(context).hideCurrentSnackBar();
          },
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final Size size = MediaQuery.of(context).size;
    final bool isLargeScreen = size.width > 800;

    return Scaffold(
      backgroundColor: _backgroundColor,
      body: SingleChildScrollView(
        child: ConstrainedBox(
          constraints: BoxConstraints(minHeight: size.height),
          child: Row(
            children: [
              if (isLargeScreen)
                // Left side - Image Area (for large screens)
                Expanded(
                  flex: 5,
                  child: Container(
                    decoration: BoxDecoration(
                      image: DecorationImage(
                        image: AssetImage('assets/images/d3ti_background.png'),
                        fit: BoxFit.cover,
                      ),
                    ),
                    child: Container(
                      decoration: BoxDecoration(
                        gradient: LinearGradient(
                          begin: Alignment.topRight,
                          end: Alignment.bottomLeft,
                          colors: [
                            _primaryColor.withOpacity(0.8),
                            _primaryColor.withOpacity(0.6),
                          ],
                        ),
                      ),
                      child: Center(
                        child: Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Container(
                              padding: EdgeInsets.all(20),
                              decoration: BoxDecoration(
                                shape: BoxShape.circle,
                                color: Colors.white,
                              ),
                              child: Image.asset(
                                'assets/images/d3ti_logo.png',
                                width: 100,
                                height: 100,
                              ),
                            ),
                            SizedBox(height: 24),
                            Text(
                              'Portal Dosen',
                              style: TextStyle(
                                color: Colors.white,
                                fontSize: 32,
                                fontWeight: FontWeight.bold,
                                letterSpacing: 1.2,
                              ),
                            ),
                            Text(
                              'D3 Teknik Informatika',
                              style: TextStyle(
                                color: Colors.white,
                                fontSize: 24,
                                fontWeight: FontWeight.w500,
                                letterSpacing: 1.0,
                              ),
                            ),
                            SizedBox(height: 8),
                            Text(
                              'Universitas Sebelas Maret',
                              style: TextStyle(
                                color: Colors.white.withOpacity(0.9),
                                fontSize: 18,
                                letterSpacing: 0.5,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),
                ),

              // Right side - Login Form
              Expanded(
                flex: isLargeScreen ? 5 : 10,
                child: Container(
                  padding: EdgeInsets.all(isLargeScreen ? 48.0 : 24.0),
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    crossAxisAlignment: CrossAxisAlignment.center,
                    children: [
                      // D3TI Logo (for small screens)
                      if (!isLargeScreen) ...[
                        Container(
                          padding: EdgeInsets.all(16),
                          decoration: BoxDecoration(
                            color: Colors.white,
                            shape: BoxShape.circle,
                            boxShadow: [
                              BoxShadow(
                                color: Colors.grey.shade200,
                                blurRadius: 10,
                                spreadRadius: 5,
                              ),
                            ],
                          ),
                          child: Image.asset(
                            'assets/images/d3ti_logo.png',
                            width: 80,
                            height: 80,
                          ),
                        ),
                        SizedBox(height: 24),
                      ],

                      // Welcome text
                      Text(
                        'Welcome to Pelaporan',
                        style: TextStyle(
                          fontSize: 24,
                          fontWeight: FontWeight.w600,
                          color: _darkTextColor,
                          letterSpacing: 0.5,
                        ),
                      ),
                      SizedBox(height: 8),

                      // D3TI Text with color
                      RichText(
                        text: TextSpan(
                          style: TextStyle(
                            fontSize: 26,
                            fontWeight: FontWeight.bold,
                            letterSpacing: 1,
                          ),
                          children: [
                            TextSpan(
                              text: 'D',
                              style: TextStyle(color: _primaryColor),
                            ),
                            TextSpan(
                              text: '3',
                              style: TextStyle(color: _secondaryColor),
                            ),
                            TextSpan(
                              text: 'TI',
                              style: TextStyle(color: _primaryColor),
                            ),
                          ],
                        ),
                      ),
                      SizedBox(height: 12),

                      // Login text
                      Text(
                        'Login Dosen',
                        style: TextStyle(
                          fontSize: 16,
                          color: _lightTextColor,
                          letterSpacing: 0.3,
                        ),
                      ),
                      SizedBox(height: 32),

                      // User Type Selector (Mahasiswa/Dosen)
                      Container(
                        width: 280,
                        height: 54,
                        decoration: BoxDecoration(
                          color: Colors.grey.shade100,
                          borderRadius: BorderRadius.circular(30),
                        ),
                        child: Row(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            // Mahasiswa button
                            Expanded(
                              child: Container(
                                margin: EdgeInsets.all(4),
                                child: ElevatedButton(
                                  onPressed: () {
                                    Navigator.pushNamed(context, '/login');
                                  },
                                  style: ElevatedButton.styleFrom(
                                    foregroundColor: _lightTextColor,
                                    backgroundColor: Colors.transparent,
                                    elevation: 0,
                                    padding: EdgeInsets.zero,
                                    shape: RoundedRectangleBorder(
                                      borderRadius: BorderRadius.circular(25),
                                    ),
                                  ),
                                  child: Text(
                                    'Mahasiswa',
                                    style: TextStyle(
                                      fontWeight: FontWeight.w500,
                                      fontSize: 14,
                                    ),
                                  ),
                                ),
                              ),
                            ),

                            // Dosen button
                            Expanded(
                              child: Container(
                                margin: EdgeInsets.all(4),
                                child: ElevatedButton(
                                  onPressed: () {},
                                  style: ElevatedButton.styleFrom(
                                    foregroundColor: Colors.white,
                                    backgroundColor: _primaryColor,
                                    elevation: 0,
                                    padding: EdgeInsets.zero,
                                    shape: RoundedRectangleBorder(
                                      borderRadius: BorderRadius.circular(25),
                                    ),
                                  ),
                                  child: Text(
                                    'Dosen',
                                    style: TextStyle(
                                      fontWeight: FontWeight.w600,
                                      fontSize: 14,
                                    ),
                                  ),
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                      SizedBox(height: 32),

                      // Email Field
                      Container(
                        decoration: BoxDecoration(
                          boxShadow: [
                            BoxShadow(
                              color: _emailError != null
                                  ? _dangerColor.withOpacity(0.1)
                                  : Colors.grey.withOpacity(0.05),
                              blurRadius: 10,
                              offset: Offset(0, 4),
                            ),
                          ],
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: TextFormField(
                          controller: _emailController,
                          decoration: InputDecoration(
                            labelText: 'Email',
                            labelStyle: TextStyle(
                              color: _emailError != null
                                  ? _dangerColor
                                  : _lightTextColor,
                              fontSize: 15,
                            ),
                            hintText: 'dosen@staff.uns.ac.id',
                            hintStyle: TextStyle(
                              color: Colors.grey[400],
                              fontSize: 14,
                            ),
                            prefixIcon: Icon(
                              Icons.email_outlined,
                              color: _emailError != null
                                  ? _dangerColor
                                  : _primaryColor,
                              size: 20,
                            ),
                            border: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(12),
                              borderSide: BorderSide(color: _borderColor),
                            ),
                            enabledBorder: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(12),
                              borderSide: BorderSide(
                                color: _emailError != null
                                    ? _dangerColor
                                    : _borderColor,
                              ),
                            ),
                            focusedBorder: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(12),
                              borderSide:
                                  BorderSide(color: _primaryColor, width: 1.5),
                            ),
                            errorBorder: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(12),
                              borderSide: BorderSide(color: _dangerColor),
                            ),
                            errorText: _emailError,
                            errorStyle: TextStyle(
                              color: _dangerColor,
                              fontSize: 13,
                            ),
                            filled: true,
                            fillColor: Colors.white,
                            contentPadding: EdgeInsets.symmetric(
                              vertical: 16,
                              horizontal: 16,
                            ),
                          ),
                          keyboardType: TextInputType.emailAddress,
                          style: TextStyle(
                            fontSize: 15,
                            color: _darkTextColor,
                          ),
                        ),
                      ),
                      SizedBox(height: 20),

                      // Password Field
                      Container(
                        decoration: BoxDecoration(
                          boxShadow: [
                            BoxShadow(
                              color: _passwordError != null
                                  ? _dangerColor.withOpacity(0.1)
                                  : Colors.grey.withOpacity(0.05),
                              blurRadius: 10,
                              offset: Offset(0, 4),
                            ),
                          ],
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: TextFormField(
                          controller: _passwordController,
                          obscureText: !_isPasswordVisible,
                          decoration: InputDecoration(
                            labelText: 'Password',
                            labelStyle: TextStyle(
                              color: _passwordError != null
                                  ? _dangerColor
                                  : _lightTextColor,
                              fontSize: 15,
                            ),
                            prefixIcon: Icon(
                              Icons.lock_outline,
                              color: _passwordError != null
                                  ? _dangerColor
                                  : _primaryColor,
                              size: 20,
                            ),
                            suffixIcon: IconButton(
                              icon: Icon(
                                _isPasswordVisible
                                    ? Icons.visibility_outlined
                                    : Icons.visibility_off_outlined,
                                color: _isPasswordVisible
                                    ? _primaryColor
                                    : Colors.grey,
                                size: 20,
                              ),
                              onPressed: () {
                                setState(() {
                                  _isPasswordVisible = !_isPasswordVisible;
                                });
                              },
                            ),
                            border: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(12),
                              borderSide: BorderSide(color: _borderColor),
                            ),
                            enabledBorder: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(12),
                              borderSide: BorderSide(
                                color: _passwordError != null
                                    ? _dangerColor
                                    : _borderColor,
                              ),
                            ),
                            focusedBorder: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(12),
                              borderSide:
                                  BorderSide(color: _primaryColor, width: 1.5),
                            ),
                            errorBorder: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(12),
                              borderSide: BorderSide(color: _dangerColor),
                            ),
                            errorText: _passwordError,
                            errorStyle: TextStyle(
                              color: _dangerColor,
                              fontSize: 13,
                            ),
                            filled: true,
                            fillColor: Colors.white,
                            contentPadding: EdgeInsets.symmetric(
                              vertical: 16,
                              horizontal: 16,
                            ),
                          ),
                          style: TextStyle(
                            fontSize: 15,
                            color: _darkTextColor,
                          ),
                        ),
                      ),
                      SizedBox(height: 20),

                      // Remember Me and Forgot Password
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Row(
                            children: [
                              SizedBox(
                                height: 24,
                                width: 24,
                                child: Checkbox(
                                  value: _rememberMe,
                                  onChanged: (value) {
                                    setState(() {
                                      _rememberMe = value ?? false;
                                    });
                                    _saveRememberMeState(_rememberMe);
                                  },
                                  activeColor: _primaryColor,
                                  shape: RoundedRectangleBorder(
                                    borderRadius: BorderRadius.circular(4),
                                  ),
                                ),
                              ),
                              SizedBox(width: 8),
                              Text(
                                'Remember me',
                                style: TextStyle(
                                  fontSize: 14,
                                  color: _lightTextColor,
                                ),
                              ),
                            ],
                          ),
                        ],
                      ),
                      SizedBox(height: 24),

                      // Login Button
                      Container(
                        width: double.infinity,
                        height: 54,
                        decoration: BoxDecoration(
                          borderRadius: BorderRadius.circular(12),
                          boxShadow: [
                            BoxShadow(
                              color: _primaryColor.withOpacity(0.3),
                              blurRadius: 12,
                              offset: Offset(0, 4),
                            ),
                          ],
                        ),
                        child: ElevatedButton(
                          onPressed: _isLoading ? null : _handleLogin,
                          style: ElevatedButton.styleFrom(
                            foregroundColor: Colors.white,
                            backgroundColor: _primaryColor,
                            disabledForegroundColor: Colors.white70,
                            disabledBackgroundColor:
                                _primaryColor.withOpacity(0.7),
                            elevation: 0,
                            padding: EdgeInsets.zero,
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(12),
                            ),
                          ),
                          child: _isLoading
                              ? SizedBox(
                                  height: 24,
                                  width: 24,
                                  child: CircularProgressIndicator(
                                    color: Colors.white,
                                    strokeWidth: 2,
                                  ),
                                )
                              : Row(
                                  mainAxisAlignment: MainAxisAlignment.center,
                                  children: [
                                    Icon(Icons.login, size: 20),
                                    SizedBox(width: 8),
                                    Text(
                                      'Login',
                                      style: TextStyle(
                                        fontSize: 16,
                                        fontWeight: FontWeight.w600,
                                        letterSpacing: 0.5,
                                      ),
                                    ),
                                  ],
                                ),
                        ),
                      ),
                      SizedBox(height: 20),

                      // Emergency Report Button
                      Container(
                        width: double.infinity,
                        height: 54,
                        decoration: BoxDecoration(
                          borderRadius: BorderRadius.circular(12),
                          boxShadow: [
                            BoxShadow(
                              color: _dangerColor.withOpacity(0.2),
                              blurRadius: 12,
                              offset: Offset(0, 4),
                            ),
                          ],
                        ),
                        child: ElevatedButton(
                          onPressed: () {
                            Navigator.pushNamed(context, '/addkspublic');
                          },
                          style: ElevatedButton.styleFrom(
                            foregroundColor: Colors.white,
                            backgroundColor: _dangerColor,
                            elevation: 0,
                            padding: EdgeInsets.zero,
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(12),
                            ),
                          ),
                          child: Row(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              Icon(Icons.warning_amber_rounded, size: 20),
                              SizedBox(width: 8),
                              Text(
                                'Lapor Kekerasan Seksual',
                                style: TextStyle(
                                  fontSize: 16,
                                  fontWeight: FontWeight.w600,
                                  letterSpacing: 0.5,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                      SizedBox(height: 32),

                      // Footer text
                      Text(
                        '© 2025 D3TI - Universitas Sebelas Maret',
                        style: TextStyle(
                          color: _lightTextColor,
                          fontSize: 12,
                        ),
                        textAlign: TextAlign.center,
                      ),
                    ],
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
