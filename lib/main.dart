// File: lib/main.dart
import 'package:flutter/material.dart';
import 'package:pelaporan_d3ti/auth_screen/login_dosen.dart';
import 'package:pelaporan_d3ti/auth_screen/login_mhs.dart';
import 'package:pelaporan_d3ti/auth_screen/register_mhs.dart';
import 'package:pelaporan_d3ti/home_screen/home_screen.dart';
import 'package:pelaporan_d3ti/pelaporan%20kekerasan%20seksual/add_lapor_ks.dart';
import 'package:pelaporan_d3ti/pelaporan%20kekerasan%20seksual/lapor_ks.dart';
import 'package:pelaporan_d3ti/pelaporan/add_lapor_kejadian.dart';
import 'package:pelaporan_d3ti/pelaporan/lapor_kejadian.dart';
import 'splash_screen/splash_screen.dart';

void main() {
  runApp(MyApp());
}

class MyApp extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      debugShowCheckedModeBanner: false, // Hilangkan banner debug
      initialRoute: '/', // Rute awal adalah splash screen
      routes: {
        '/': (context) => SplashScreen(), // Splash screen sebagai halaman awal
        '/login': (context) => LoginPage(), // Rute untuk halaman login
        '/logindosen': (context) =>
            LoginDosenPage(), // Rute untuk halaman login
        '/home': (context) => HomeScreen(), // Rute untuk halaman utama
        '/laporkejadian': (context) =>
            LaporKejadianPage(), // Rute untuk halaman utama
        '/addlaporkejadian': (context) =>
            AddLaporKejadianPage(), // Rute untuk halaman utama
        '/regismhs': (context) => RegisterMhsPage(), // Rute untuk halaman utama
        '/laporanks': (context) =>
            LaporKekerasanPage(), // Rute untuk halaman utama
        '/addlaporks': (context) => AddLaporKsPage(),
      },
    );
  }
}
