import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';
import 'dart:math' as Math;

class RegisterMhsPage extends StatefulWidget {
  @override
  _RegisterMhsPageState createState() => _RegisterMhsPageState();
}

class _RegisterMhsPageState extends State<RegisterMhsPage> {
  final TextEditingController _nameController = TextEditingController();
  final TextEditingController _nimController = TextEditingController();
  final TextEditingController _emailController = TextEditingController();
  final TextEditingController _passwordController = TextEditingController();
  final TextEditingController _confirmPasswordController =
      TextEditingController();
  final TextEditingController _nomorhpController = TextEditingController();

  String? _nameError;
  String? _nimError;
  String? _emailError;
  String? _passwordError;
  String? _confirmPasswordError;
  String? _nomorhpError;

  bool _isPasswordVisible = false;
  bool _isConfirmPasswordVisible = false;
  bool _isLoading = false;

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
            Colors.green,
          );

          // Navigate to login page after successful registration
          Future.delayed(Duration(seconds: 2), () {
            Navigator.pushReplacementNamed(context, '/login');
          });
        } else {
          _showMessage(
            jsonResponse['message'] ?? 'Pendaftaran gagal. Silakan coba lagi.',
            Colors.red,
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

        _showMessage(errorMessage, Colors.red);
      } else {
        _showMessage(
          'Pendaftaran gagal dengan status: ${response.statusCode}',
          Colors.red,
        );
      }
    } catch (e) {
      print('Registration error: $e');
      setState(() {
        _isLoading = false;
      });
      _showMessage(
        'Error connecting to server: ${e.toString().split('\n')[0]}',
        Colors.red,
      );
    }
  }

  void _showMessage(String message, Color backgroundColor) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        backgroundColor: backgroundColor,
        duration: Duration(seconds: 3),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      body: SingleChildScrollView(
        child: Padding(
          padding: const EdgeInsets.all(32.0),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              // Judul "Register Mahasiswa"
              Text(
                'Register Mahasiswa',
                style: TextStyle(
                  fontSize: 24,
                  fontWeight: FontWeight.bold,
                  color: Colors.black,
                ),
              ),
              SizedBox(height: 8),
              Text(
                'Create your account',
                style: TextStyle(fontSize: 16, color: Colors.grey),
              ),
              SizedBox(height: 24),

              // Form Input Nama
              TextFormField(
                controller: _nameController,
                decoration: InputDecoration(
                  labelText: 'Nama Lengkap',
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(8),
                  ),
                  contentPadding:
                      EdgeInsets.symmetric(vertical: 12, horizontal: 16),
                  errorText: _nameError,
                ),
              ),
              SizedBox(height: 16),

              //Form Input NIM
              TextFormField(
                controller: _nimController,
                decoration: InputDecoration(
                  labelText: 'NIM',
                  hintText: 'V34XXXXXXX',
                  hintStyle: TextStyle(color: Colors.grey[500]),
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(8),
                  ),
                  contentPadding:
                      EdgeInsets.symmetric(vertical: 12, horizontal: 16),
                  errorText: _nimError,
                ),
                keyboardType: TextInputType.text,
              ),
              SizedBox(height: 16),

              // Form Input Email
              TextFormField(
                controller: _emailController,
                decoration: InputDecoration(
                  labelText: 'Email',
                  hintText: 'mahasiswa@student.uns.ac.id',
                  hintStyle: TextStyle(color: Colors.grey[500]),
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(8),
                  ),
                  contentPadding:
                      EdgeInsets.symmetric(vertical: 12, horizontal: 16),
                  errorText: _emailError,
                ),
                keyboardType: TextInputType.emailAddress,
              ),
              SizedBox(height: 16),

              // Form Input Password
              TextFormField(
                controller: _passwordController,
                obscureText: !_isPasswordVisible,
                decoration: InputDecoration(
                  labelText: 'Password',
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(8),
                  ),
                  contentPadding:
                      EdgeInsets.symmetric(vertical: 12, horizontal: 16),
                  errorText: _passwordError,
                  suffixIcon: IconButton(
                    icon: Icon(
                      _isPasswordVisible
                          ? Icons.visibility
                          : Icons.visibility_off,
                      color: Colors.grey,
                    ),
                    onPressed: () {
                      setState(() {
                        _isPasswordVisible = !_isPasswordVisible;
                      });
                    },
                  ),
                ),
              ),
              SizedBox(height: 16),

              // Form Input Konfirmasi Password
              TextFormField(
                controller: _confirmPasswordController,
                obscureText: !_isConfirmPasswordVisible,
                decoration: InputDecoration(
                  labelText: 'Konfirmasi Password',
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(8),
                  ),
                  contentPadding:
                      EdgeInsets.symmetric(vertical: 12, horizontal: 16),
                  errorText: _confirmPasswordError,
                  suffixIcon: IconButton(
                    icon: Icon(
                      _isConfirmPasswordVisible
                          ? Icons.visibility
                          : Icons.visibility_off,
                      color: Colors.grey,
                    ),
                    onPressed: () {
                      setState(() {
                        _isConfirmPasswordVisible = !_isConfirmPasswordVisible;
                      });
                    },
                  ),
                ),
              ),
              SizedBox(height: 16),

              // Form Input Nomor HP
              TextFormField(
                controller: _nomorhpController,
                decoration: InputDecoration(
                  labelText: 'Nomor HP',
                  hintText: '08XXXXXXXXXX',
                  hintStyle: TextStyle(color: Colors.grey[500]),
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(8),
                  ),
                  contentPadding:
                      EdgeInsets.symmetric(vertical: 12, horizontal: 16),
                  errorText: _nomorhpError,
                ),
                keyboardType: TextInputType.phone,
              ),
              SizedBox(height: 24),

              // Tombol Register with loading indicator
              ElevatedButton(
                onPressed: _isLoading ? null : _handleRegistration,
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
                        'Register',
                        style: TextStyle(fontSize: 16, color: Colors.white),
                      ),
              ),
              SizedBox(height: 16),

              // Link ke Login
              Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Text("Already have an account? "),
                  TextButton(
                    onPressed: () {
                      Navigator.pushReplacementNamed(context, '/login');
                    },
                    child: Text(
                      'Login here',
                      style: TextStyle(color: Color(0xFFF78052)),
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}
