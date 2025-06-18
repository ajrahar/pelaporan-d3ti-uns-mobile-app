import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';
import 'dart:math' as Math;

class RegisterMhsPage extends StatefulWidget {
  @override
  _RegisterMhsPageState createState() => _RegisterMhsPageState();
}

class _RegisterMhsPageState extends State<RegisterMhsPage> {
  // Controllers
  final TextEditingController _nameController = TextEditingController();
  final TextEditingController _nimController = TextEditingController();
  final TextEditingController _emailController = TextEditingController();
  final TextEditingController _passwordController = TextEditingController();
  final TextEditingController _confirmPasswordController =
      TextEditingController();
  final TextEditingController _nomorhpController = TextEditingController();

  // Error states
  String? _nameError;
  String? _nimError;
  String? _emailError;
  String? _passwordError;
  String? _confirmPasswordError;
  String? _nomorhpError;

  // UI states
  bool _isPasswordVisible = false;
  bool _isConfirmPasswordVisible = false;
  bool _isLoading = false;

  // Theme colors
  final Color _primaryColor = Color(0xFF00A2EA);
  final Color _secondaryColor = Color(0xFFF78052);
  final Color _darkTextColor = Color(0xFF2D3748);
  final Color _lightTextColor = Color(0xFF718096);
  final Color _dangerColor = Color(0xFFE53E3E);
  final Color _successColor = Color(0xFF38A169);
  final Color _borderColor = Color(0xFFE2E8F0);
  final Color _backgroundColor = Colors.white;
  final Color _cardColor = Colors.white;
  final Color _shadowColor = Color(0x1A000000);

  bool _validateInputs() {
    setState(() {
      // Validasi Nama
      if (_nameController.text.isEmpty) {
        _nameError = 'Nama tidak boleh kosong';
      } else {
        _nameError = null;
      }

      // Validasi NIM
      if (_nimController.text.isEmpty) {
        _nimError = 'NIM tidak boleh kosong';
      } else if (!_nimController.text.startsWith('V34')) {
        _nimError = 'NIM harus dimulai dengan V34';
      } else if (_nimController.text.length < 10) {
        _nimError = 'NIM harus minimal 10 karakter';
      } else {
        _nimError = null;
      }

      // Validasi Email
      if (_emailController.text.isEmpty) {
        _emailError = 'Email tidak boleh kosong';
      } else if (!RegExp(r'^[\w-\.]+@([\w-]+\.)+[\w-]{2,4}$')
          .hasMatch(_emailController.text)) {
        _emailError = 'Format email tidak valid';
      } else if (!_emailController.text.endsWith('@student.uns.ac.id')) {
        _emailError = 'Email harus menggunakan domain @student.uns.ac.id';
      } else {
        _emailError = null;
      }

      // Validasi Password
      if (_passwordController.text.isEmpty) {
        _passwordError = 'Password tidak boleh kosong';
      } else if (_passwordController.text.length < 6) {
        _passwordError = 'Password minimal 6 karakter';
      } else {
        _passwordError = null;
      }

      // Validasi Konfirmasi Password
      if (_confirmPasswordController.text.isEmpty) {
        _confirmPasswordError = 'Konfirmasi password tidak boleh kosong';
      } else if (_confirmPasswordController.text != _passwordController.text) {
        _confirmPasswordError = 'Konfirmasi password tidak cocok';
      } else {
        _confirmPasswordError = null;
      }

      // Validasi Nomor HP
      if (_nomorhpController.text.isEmpty) {
        _nomorhpError = 'Nomor HP tidak boleh kosong';
      } else if (_nomorhpController.text.length < 10) {
        _nomorhpError = 'Nomor HP minimal 10 karakter';
      } else {
        _nomorhpError = null;
      }
    });

    // Kembalikan true jika tidak ada error, false jika ada error
    return _nameError == null &&
        _nimError == null &&
        _emailError == null &&
        _passwordError == null &&
        _confirmPasswordError == null &&
        _nomorhpError == null;
  }

  Future<void> _handleRegistration() async {
    if (!_validateInputs()) {
      return;
    }

    setState(() {
      _isLoading = true;
    });

    // Use the new API URL
    final url =
        Uri.parse('https://v3422040.mhs.d3tiuns.com/api/register/mahasiswa');

    try {
      // Create form data based on the required payload format
      final formData = {
        'nim': _nimController.text,
        'name': _nameController.text,
        'email': _emailController.text,
        'password': _passwordController.text,
        'no_telp': _nomorhpController.text,
      };

      // Add headers
      final headers = {
        'Content-Type': 'application/json',
        'Accept': 'application/json',
      };

      print("Attempting registration for: ${_emailController.text}");

      // Send POST request
      final response = await http
          .post(
            url,
            headers: headers,
            body: json.encode(formData),
          )
          .timeout(Duration(seconds: 30));

      setState(() {
        _isLoading = false;
      });

      print("Registration response status: ${response.statusCode}");
      print(
          "Registration response: ${response.body.substring(0, Math.min(500, response.body.length))}");

      if (response.statusCode == 200 || response.statusCode == 201) {
        // Parse the JSON response
        final jsonResponse = jsonDecode(response.body);

        if (jsonResponse['status'] == true) {
          // Show success message
          _showMessage(
            'Pendaftaran berhasil! Silakan login dengan akun yang telah didaftarkan.',
            _successColor,
            Icons.check_circle,
          );

          // Navigate to login page after successful registration
          Future.delayed(Duration(seconds: 2), () {
            Navigator.pushReplacementNamed(context, '/login');
          });
        } else {
          _showMessage(
            jsonResponse['message'] ?? 'Pendaftaran gagal. Silakan coba lagi.',
            _dangerColor,
            Icons.error_outline,
          );
        }
      } else if (response.statusCode == 422) {
        // Handle validation errors from server
        final jsonResponse = jsonDecode(response.body);
        String errorMessage = 'Validasi gagal:';

        if (jsonResponse['errors'] != null) {
          Map<String, dynamic> errors = jsonResponse['errors'];
          errors.forEach((key, value) {
            if (value is List && value.isNotEmpty) {
              errorMessage += '\n- $key: ${value[0]}';
            } else if (value is String) {
              errorMessage += '\n- $key: $value';
            }
          });
        } else {
          errorMessage = jsonResponse['message'] ??
              'Pendaftaran gagal. Silakan coba lagi.';
        }

        _showMessage(errorMessage, _dangerColor, Icons.warning);
      } else {
        _showMessage(
          'Pendaftaran gagal dengan status: ${response.statusCode}',
          _dangerColor,
          Icons.error_outline,
        );
      }
    } catch (e) {
      print('Registration error: $e');
      setState(() {
        _isLoading = false;
      });
      _showMessage(
        'Error connecting to server: ${e.toString().split('\n')[0]}',
        _dangerColor,
        Icons.wifi_off,
      );
    }
  }

  void _showMessage(String message, Color backgroundColor, IconData icon) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Row(
          children: [
            Icon(icon, color: Colors.white),
            SizedBox(width: 16),
            Expanded(child: Text(message)),
          ],
        ),
        backgroundColor: backgroundColor,
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
      body: SafeArea(
        child: SingleChildScrollView(
          child: Center(
            child: Container(
              constraints: BoxConstraints(
                maxWidth: isLargeScreen ? 1200 : 600,
              ),
              padding: EdgeInsets.all(24),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.center,
                children: [
                  // Back Button
                  Align(
                    alignment: Alignment.topLeft,
                    child: IconButton(
                      onPressed: () {
                        Navigator.of(context).pop();
                      },
                      icon: Icon(Icons.arrow_back, color: _darkTextColor),
                      tooltip: 'Back to login',
                      style: ButtonStyle(
                        shape:
                            MaterialStateProperty.all<RoundedRectangleBorder>(
                          RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(8),
                          ),
                        ),
                      ),
                    ),
                  ),
                  SizedBox(height: 16),

                  // Logo and D3TI text
                  Container(
                    padding: EdgeInsets.all(16),
                    decoration: BoxDecoration(
                      color: Colors.white,
                      shape: BoxShape.circle,
                      boxShadow: [
                        BoxShadow(
                          color: _shadowColor.withOpacity(0.2),
                          blurRadius: 10,
                          spreadRadius: 2,
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

                  // Register header
                  Text(
                    'Register Mahasiswa',
                    style: TextStyle(
                      fontSize: 28,
                      fontWeight: FontWeight.bold,
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

                  // Subtitle
                  Text(
                    'Create your account to access the report system',
                    style: TextStyle(
                      fontSize: 16,
                      color: _lightTextColor,
                      letterSpacing: 0.3,
                    ),
                  ),
                  SizedBox(height: 32),

                  // Registration form area
                  Container(
                    decoration: BoxDecoration(
                      color: _cardColor,
                      borderRadius: BorderRadius.circular(20),
                      boxShadow: [
                        BoxShadow(
                          color: _shadowColor.withOpacity(0.1),
                          blurRadius: 20,
                          offset: Offset(0, 10),
                        ),
                      ],
                    ),
                    padding: EdgeInsets.all(32),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        // Registration form layout
                        isLargeScreen
                            ? _buildTwoColumnForm()
                            : _buildSingleColumnForm(),

                        SizedBox(height: 32),

                        // Register button
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
                            onPressed: _isLoading ? null : _handleRegistration,
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
                                      Icon(Icons.app_registration, size: 20),
                                      SizedBox(width: 8),
                                      Text(
                                        'Register',
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

                        SizedBox(height: 24),

                        // Login link
                        Row(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Text(
                              "Already have an account? ",
                              style: TextStyle(
                                fontSize: 15,
                                color: _lightTextColor,
                              ),
                            ),
                            TextButton(
                              onPressed: () {
                                Navigator.pushReplacementNamed(
                                    context, '/login');
                              },
                              style: TextButton.styleFrom(
                                padding: EdgeInsets.zero,
                                minimumSize: Size(0, 0),
                                tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                              ),
                              child: Text(
                                'Login here',
                                style: TextStyle(
                                  color: _secondaryColor,
                                  fontWeight: FontWeight.w600,
                                  fontSize: 15,
                                ),
                              ),
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),

                  SizedBox(height: 24),

                  // Footer text
                  Text(
                    '© 2025 D3TI - Universitas Sebelas Maret',
                    style: TextStyle(
                      color: _lightTextColor,
                      fontSize: 12,
                    ),
                    textAlign: TextAlign.center,
                  ),
                  SizedBox(height: 16),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  // Single column form layout for narrow screens
  Widget _buildSingleColumnForm() {
    return Column(
      children: [
        _buildInputField(
          controller: _nameController,
          label: 'Nama Lengkap',
          hint: 'Masukkan nama lengkap Anda',
          icon: Icons.person_outline,
          errorText: _nameError,
        ),
        SizedBox(height: 20),
        _buildInputField(
          controller: _nimController,
          label: 'NIM',
          hint: 'V34XXXXXXX',
          icon: Icons.badge_outlined,
          errorText: _nimError,
        ),
        SizedBox(height: 20),
        _buildInputField(
          controller: _emailController,
          label: 'Email',
          hint: 'mahasiswa@student.uns.ac.id',
          icon: Icons.email_outlined,
          errorText: _emailError,
          keyboardType: TextInputType.emailAddress,
        ),
        SizedBox(height: 20),
        _buildPasswordField(
          controller: _passwordController,
          label: 'Password',
          isVisible: _isPasswordVisible,
          errorText: _passwordError,
          toggleVisibility: () {
            setState(() {
              _isPasswordVisible = !_isPasswordVisible;
            });
          },
        ),
        SizedBox(height: 20),
        _buildPasswordField(
          controller: _confirmPasswordController,
          label: 'Konfirmasi Password',
          isVisible: _isConfirmPasswordVisible,
          errorText: _confirmPasswordError,
          toggleVisibility: () {
            setState(() {
              _isConfirmPasswordVisible = !_isConfirmPasswordVisible;
            });
          },
        ),
        SizedBox(height: 20),
        _buildInputField(
          controller: _nomorhpController,
          label: 'Nomor HP',
          hint: '08XXXXXXXXXX',
          icon: Icons.phone_android,
          errorText: _nomorhpError,
          keyboardType: TextInputType.phone,
        ),
      ],
    );
  }

  // Two column form layout for wider screens
  Widget _buildTwoColumnForm() {
    return Column(
      children: [
        Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Expanded(
              child: _buildInputField(
                controller: _nameController,
                label: 'Nama Lengkap',
                hint: 'Masukkan nama lengkap Anda',
                icon: Icons.person_outline,
                errorText: _nameError,
              ),
            ),
            SizedBox(width: 20),
            Expanded(
              child: _buildInputField(
                controller: _nimController,
                label: 'NIM',
                hint: 'V34XXXXXXX',
                icon: Icons.badge_outlined,
                errorText: _nimError,
              ),
            ),
          ],
        ),
        SizedBox(height: 20),
        Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Expanded(
              child: _buildInputField(
                controller: _emailController,
                label: 'Email',
                hint: 'mahasiswa@student.uns.ac.id',
                icon: Icons.email_outlined,
                errorText: _emailError,
                keyboardType: TextInputType.emailAddress,
              ),
            ),
            SizedBox(width: 20),
            Expanded(
              child: _buildInputField(
                controller: _nomorhpController,
                label: 'Nomor HP',
                hint: '08XXXXXXXXXX',
                icon: Icons.phone_android,
                errorText: _nomorhpError,
                keyboardType: TextInputType.phone,
              ),
            ),
          ],
        ),
        SizedBox(height: 20),
        Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Expanded(
              child: _buildPasswordField(
                controller: _passwordController,
                label: 'Password',
                isVisible: _isPasswordVisible,
                errorText: _passwordError,
                toggleVisibility: () {
                  setState(() {
                    _isPasswordVisible = !_isPasswordVisible;
                  });
                },
              ),
            ),
            SizedBox(width: 20),
            Expanded(
              child: _buildPasswordField(
                controller: _confirmPasswordController,
                label: 'Konfirmasi Password',
                isVisible: _isConfirmPasswordVisible,
                errorText: _confirmPasswordError,
                toggleVisibility: () {
                  setState(() {
                    _isConfirmPasswordVisible = !_isConfirmPasswordVisible;
                  });
                },
              ),
            ),
          ],
        ),
      ],
    );
  }

  // Reusable input field widget
  Widget _buildInputField({
    required TextEditingController controller,
    required String label,
    required String hint,
    required IconData icon,
    String? errorText,
    TextInputType keyboardType = TextInputType.text,
  }) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label,
          style: TextStyle(
            fontSize: 15,
            fontWeight: FontWeight.w600,
            color: _darkTextColor,
            letterSpacing: 0.3,
          ),
        ),
        SizedBox(height: 8),
        Container(
          decoration: BoxDecoration(
            boxShadow: [
              BoxShadow(
                color: errorText != null
                    ? _dangerColor.withOpacity(0.1)
                    : Colors.grey.withOpacity(0.05),
                blurRadius: 10,
                offset: Offset(0, 4),
              ),
            ],
            borderRadius: BorderRadius.circular(12),
          ),
          child: TextFormField(
            controller: controller,
            keyboardType: keyboardType,
            decoration: InputDecoration(
              hintText: hint,
              hintStyle: TextStyle(
                color: Colors.grey[400],
                fontSize: 14,
              ),
              prefixIcon: Icon(
                icon,
                color: errorText != null ? _dangerColor : _primaryColor,
                size: 20,
              ),
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(12),
                borderSide: BorderSide(color: _borderColor),
              ),
              enabledBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(12),
                borderSide: BorderSide(
                  color: errorText != null ? _dangerColor : _borderColor,
                ),
              ),
              focusedBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(12),
                borderSide: BorderSide(color: _primaryColor, width: 1.5),
              ),
              errorBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(12),
                borderSide: BorderSide(color: _dangerColor),
              ),
              errorText: errorText,
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
      ],
    );
  }

  // Reusable password field widget
  Widget _buildPasswordField({
    required TextEditingController controller,
    required String label,
    required bool isVisible,
    required Function toggleVisibility,
    String? errorText,
  }) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label,
          style: TextStyle(
            fontSize: 15,
            fontWeight: FontWeight.w600,
            color: _darkTextColor,
            letterSpacing: 0.3,
          ),
        ),
        SizedBox(height: 8),
        Container(
          decoration: BoxDecoration(
            boxShadow: [
              BoxShadow(
                color: errorText != null
                    ? _dangerColor.withOpacity(0.1)
                    : Colors.grey.withOpacity(0.05),
                blurRadius: 10,
                offset: Offset(0, 4),
              ),
            ],
            borderRadius: BorderRadius.circular(12),
          ),
          child: TextFormField(
            controller: controller,
            obscureText: !isVisible,
            decoration: InputDecoration(
              prefixIcon: Icon(
                Icons.lock_outline,
                color: errorText != null ? _dangerColor : _primaryColor,
                size: 20,
              ),
              suffixIcon: IconButton(
                icon: Icon(
                  isVisible
                      ? Icons.visibility_outlined
                      : Icons.visibility_off_outlined,
                  color: isVisible ? _primaryColor : Colors.grey,
                  size: 20,
                ),
                onPressed: () => toggleVisibility(),
              ),
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(12),
                borderSide: BorderSide(color: _borderColor),
              ),
              enabledBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(12),
                borderSide: BorderSide(
                  color: errorText != null ? _dangerColor : _borderColor,
                ),
              ),
              focusedBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(12),
                borderSide: BorderSide(color: _primaryColor, width: 1.5),
              ),
              errorBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(12),
                borderSide: BorderSide(color: _dangerColor),
              ),
              errorText: errorText,
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
      ],
    );
  }
}
