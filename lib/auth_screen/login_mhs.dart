import 'package:flutter/material.dart';
import 'package:pelaporan_d3ti/home_screen/home_screen.dart';
import 'package:http/http.dart' as http;
import 'package:pelaporan_d3ti/services/api_service.dart';
import 'dart:convert';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:pelaporan_d3ti/services/token_manager.dart';
import 'dart:math' as Math;

class LoginPage extends StatefulWidget {
  @override
  _LoginPageState createState() => _LoginPageState();
}

class _LoginPageState extends State<LoginPage> {
  final TextEditingController _emailController = TextEditingController();
  final TextEditingController _passwordController = TextEditingController();
  bool _rememberMe = false;
  bool _isPasswordVisible = false;
  String? _emailError;
  String? _passwordError;
  bool _isLoading = false;
  bool _prefsInitialized = false;

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

      // Get remember me value
      final rememberValue = prefs.getBool('remember_me');

      // Only if we have a valid value
      if (rememberValue != null) {
        setState(() {
          _rememberMe = rememberValue;

          // If remember me is true, load saved email
          if (_rememberMe) {
            final savedEmail = prefs.getString('saved_email');
            if (savedEmail != null && savedEmail.isNotEmpty) {
              _emailController.text = savedEmail;
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

      // Save remember me state
      await prefs.setBool('remember_me', value);

      // If remember me is checked and we have an email, save it
      if (value && _emailController.text.isNotEmpty) {
        await prefs.setString('saved_email', _emailController.text);
      }
      // If remember me is unchecked, clear saved email
      else if (!value) {
        await prefs.remove('saved_email');
      }
    } catch (e) {
      print('Failed to save remember me state: $e');
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

    // Updated API URL to match the new endpoint
    final url =
        Uri.parse('https://v3422040.mhs.d3tiuns.com/api/login/mahasiswa');

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
          // Extract user data and token
          final userData = jsonResponse['data']['user'];
          final token = jsonResponse['data']['token'];

          print('Login successful! Token received');

          // Save token using our TokenManager
          await TokenManager.setToken(token);

          // Handle remember me
          if (_rememberMe) {
            await _saveRememberMeState(true);
          }

          // Save user data using safer methods
          await _safeSetPrefs('user_id', userData['id'],
              (prefs, key, value) => prefs.setInt(key, value));
          await _safeSetPrefs('user_name', userData['name'],
              (prefs, key, value) => prefs.setString(key, value));
          await _safeSetPrefs('user_email', userData['email'],
              (prefs, key, value) => prefs.setString(key, value));
          await _safeSetPrefs('user_nim', userData['nim'],
              (prefs, key, value) => prefs.setString(key, value));
          await _safeSetPrefs('user_no_telp', userData['no_telp'],
              (prefs, key, value) => prefs.setString(key, value));
          await _safeSetPrefs('is_logged_in', true,
              (prefs, key, value) => prefs.setBool(key, value));

          // Navigate to home screen
          Navigator.pushReplacement(
            context,
            MaterialPageRoute(builder: (context) => HomeScreen()),
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
        content: Text(message),
        backgroundColor: Colors.red,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      body: Row(
        children: [
          // Bagian Kanan (Form Login)
          Expanded(
            flex: 1,
            child: Padding(
              padding: const EdgeInsets.all(32.0),
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                crossAxisAlignment: CrossAxisAlignment.center,
                children: [
                  // Judul "Welcome to Portal D3TI"
                  Text(
                    'Welcome to Pelaporan',
                    style: TextStyle(
                      fontSize: 24,
                      fontWeight: FontWeight.bold,
                      color: Colors.black,
                    ),
                  ),
                  RichText(
                    text: TextSpan(
                      style:
                          TextStyle(fontSize: 24, fontWeight: FontWeight.bold),
                      children: [
                        TextSpan(
                            text: 'D',
                            style: TextStyle(color: Color(0xFF00A2EA))),
                        TextSpan(
                            text: '3',
                            style: TextStyle(color: Color(0xFFF78052))),
                        TextSpan(
                            text: 'TI',
                            style: TextStyle(color: Color(0xFF00A2EA))),
                      ],
                    ),
                  ),
                  SizedBox(height: 8),
                  Text(
                    'Login to Your Account',
                    style: TextStyle(fontSize: 16, color: Colors.grey),
                  ),
                  SizedBox(height: 24),

                  // Tombol Mahasiswa dan Dosen
                  Container(
                    width: 250,
                    height: 60,
                    decoration: BoxDecoration(
                      color: Color(0xFF00A2EA),
                      borderRadius: BorderRadius.circular(50),
                      boxShadow: [
                        BoxShadow(
                          color: Colors.black.withOpacity(0.1),
                          blurRadius: 10,
                          offset: Offset(0, 5),
                        ),
                      ],
                    ),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        // Tombol Mahasiswa
                        ElevatedButton(
                          onPressed: () {},
                          style: ElevatedButton.styleFrom(
                            foregroundColor: Color(0xFF00A2EA),
                            backgroundColor: Colors.white,
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(50),
                            ),
                            padding: EdgeInsets.symmetric(
                                horizontal: 24, vertical: 12),
                          ),
                          child: Text('Mahasiswa'),
                        ),
                        SizedBox(width: 8),

                        // Tombol Dosen
                        ElevatedButton(
                          onPressed: () {
                            Navigator.pushNamed(context, '/logindosen');
                          },
                          style: ElevatedButton.styleFrom(
                            foregroundColor: Colors.white,
                            backgroundColor: Color(0xFF00A2EA),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(50),
                            ),
                            padding: EdgeInsets.symmetric(
                                horizontal: 24, vertical: 12),
                          ),
                          child: Text('Dosen'),
                        ),
                      ],
                    ),
                  ),
                  SizedBox(height: 24),

                  // Form Input Email
                  TextFormField(
                    controller: _emailController,
                    decoration: InputDecoration(
                      labelText: 'Email',
                      hintText:
                          'mahasiswa@student.uns.ac.id', // Placeholder email
                      hintStyle: TextStyle(
                        color: Colors.grey[500], // Warna abu-abu sedang
                      ),
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(8),
                      ),
                      contentPadding:
                          EdgeInsets.symmetric(vertical: 12, horizontal: 16),
                      errorText: _emailError, // Tampilkan pesan error jika ada
                    ),
                    keyboardType: TextInputType.emailAddress,
                  ),
                  SizedBox(height: 16),

                  // Form Input Password
                  TextFormField(
                    controller: _passwordController,
                    obscureText:
                        !_isPasswordVisible, // Toggle visibility password
                    decoration: InputDecoration(
                      labelText: 'Password',
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(8),
                      ),
                      contentPadding:
                          EdgeInsets.symmetric(vertical: 12, horizontal: 16),
                      errorText:
                          _passwordError, // Tampilkan pesan error jika ada
                      suffixIcon: IconButton(
                        icon: Icon(
                          _isPasswordVisible
                              ? Icons.visibility
                              : Icons.visibility_off,
                          color: Colors.grey,
                        ),
                        onPressed: () {
                          setState(() {
                            _isPasswordVisible =
                                !_isPasswordVisible; // Toggle visibility
                          });
                        },
                      ),
                    ),
                  ),
                  SizedBox(height: 16),

                  // Remember Me and Forgot Password
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Row(
                        children: [
                          // Fixed Checkbox implementation with proper error handling
                          Checkbox(
                            value: _rememberMe,
                            onChanged: (value) {
                              // Update UI immediately
                              setState(() {
                                _rememberMe = value ?? false;
                              });

                              // Save preference in the background with error handling
                              _saveRememberMeState(_rememberMe);
                            },
                            activeColor: Color(0xFF00A2EA),
                          ),
                          Text('Remember me'),
                        ],
                      ),
                    ],
                  ),

                  // Tombol Login with loading indicator
                  ElevatedButton(
                    onPressed: _isLoading ? null : _handleLogin,
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Color(0xFF00A2EA),
                      padding: EdgeInsets.symmetric(vertical: 16),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(8),
                      ),
                      minimumSize: Size(double.infinity, 50),
                    ),
                    child: _isLoading
                        ? CircularProgressIndicator(color: Colors.white)
                        : Text(
                            'Login',
                            style: TextStyle(fontSize: 16, color: Colors.white),
                          ),
                  ),
                  SizedBox(height: 16),

                  // Register Link
                  Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Text("Don't have an account? "),
                      TextButton(
                        onPressed: () {
                          Navigator.pushNamed(context, '/regismhs');
                        },
                        child: Text(
                          'Register here',
                          style: TextStyle(color: Color(0xFFF78052)),
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}
