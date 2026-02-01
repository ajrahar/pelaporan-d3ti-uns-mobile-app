import 'package:flutter/material.dart';

class SplashScreen extends StatefulWidget {
  @override
  _SplashScreenState createState() => _SplashScreenState();
}

class _SplashScreenState extends State<SplashScreen> {
  @override
  void initState() {
    super.initState();
    // Tunggu selama 3 detik sebelum pindah ke halaman utama
    Future.delayed(Duration(seconds: 3), () {
      Navigator.pushReplacementNamed(context, '/login');
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white, // Latar belakang putih
      body: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Image.asset(
              'assets/images/d3ti_logo.png', // Path gambar
              width: 150, // Atur lebar gambar
              height: 150, // Atur tinggi gambar
            ),
            SizedBox(height: 20), // Jarak antara logo dan teks
          ],
        ),
      ),
    );
  }
}
