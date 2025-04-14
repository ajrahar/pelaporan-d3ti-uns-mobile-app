import 'package:flutter/material.dart';
import 'package:pelaporan_d3ti/home_screen/home_screen.dart';

class LoginPage extends StatefulWidget {
  @override
  _LoginPageState createState() => _LoginPageState();
}

class _LoginPageState extends State<LoginPage> {
  final TextEditingController _emailController = TextEditingController();
  final TextEditingController _passwordController = TextEditingController();
  bool _rememberMe = false;
  bool _isPasswordVisible = false; // Untuk toggle visibility password
  String? _emailError; // Pesan error untuk email
  String? _passwordError; // Pesan error untuk password

  bool _handleLogin() {
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

    // Kembalikan true jika tidak ada error, false jika ada error
    return _emailError == null && _passwordError == null;
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

                  // Remember Me dan Forgot Password
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Row(
                        children: [
                          Checkbox(
                            value: _rememberMe,
                            onChanged: (value) {
                              setState(() {
                                _rememberMe = value ?? false;
                              });
                            },
                            activeColor: Color(0xFF00A2EA),
                          ),
                          Text('Remember me'),
                        ],
                      ),
                    ],
                  ),

                  // Tombol Login
                  ElevatedButton(
                    onPressed: () {
                      // Panggil _handleLogin dan periksa hasilnya
                      if (_handleLogin()) {
                        // Navigasi ke HomeScreen hanya jika validasi berhasil
                        Navigator.pushReplacement(
                          context,
                          MaterialPageRoute(builder: (context) => HomeScreen()),
                        );
                      }
                    },
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Color(0xFF00A2EA),
                      padding: EdgeInsets.symmetric(vertical: 16),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(8),
                      ),
                      minimumSize: Size(double.infinity, 50),
                    ),
                    child: const Text(
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
