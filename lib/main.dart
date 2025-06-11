// File: lib/main.dart
import 'package:flutter/material.dart';
import 'package:pelaporan_d3ti/auth_screen/login_dosen.dart';
import 'package:pelaporan_d3ti/auth_screen/login_mhs.dart';
import 'package:pelaporan_d3ti/auth_screen/register_mhs.dart';
import 'package:pelaporan_d3ti/dosen/home/home_screen_dosen.dart';
import 'package:pelaporan_d3ti/dosen/pelaporan_kejadian_dosen/lapor_pk_dosen.dart';
import 'package:pelaporan_d3ti/dosen/pelaporan_kekerasan_seksual_dosen/lapor_ks_dosen.dart';
import 'package:pelaporan_d3ti/kekerasan_seksual/add_ks_public.dart';
import 'package:pelaporan_d3ti/mahasiswa/home_screen/home_screen.dart';
import 'package:pelaporan_d3ti/mahasiswa/pelaporan%20kekerasan%20seksual/add_lapor_ks.dart';
import 'package:pelaporan_d3ti/mahasiswa/pelaporan%20kekerasan%20seksual/lapor_ks.dart';
import 'package:pelaporan_d3ti/mahasiswa/pelaporan/add_lapor_kejadian.dart';
import 'package:pelaporan_d3ti/mahasiswa/pelaporan/lapor_kejadian.dart';
import 'package:pelaporan_d3ti/mahasiswa/pelaporan/add_lapor_kejadian_mendesak.dart';
import 'package:pelaporan_d3ti/settings/settings_screen.dart'; // You'll need to create this
import 'splash_screen/splash_screen.dart';

void main() {
  runApp(MyApp());
}

class MyApp extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      debugShowCheckedModeBanner: false, // Hide debug banner
      initialRoute: '/', // Initial route is splash screen
      routes: {
        '/': (context) => SplashScreen(), // Splash screen as initial page
        '/login': (context) => LoginPage(), // Route for login page
        '/logindosen': (context) => LoginDosenPage(), // Route for faculty login
        '/home': (context) => HomeScreen(), // Route for main page

        '/homedosen': (context) => HomeScreenDosen(),
        '/laporpkdosen': (context) => LaporKejadianDosenPage(),
        '/laporksdosen': (context) =>
            LaporKekerasanDosenPage(), // Route for faculty violence reports

        '/addkspublic': (context) =>
            AddKSPublicPage(), // Route for adding public violence reports

        // Reports routes - aligned with HomeScreen navigation
        '/reports': (context) => LaporKejadianPage(), // Route for reports list
        '/violence-reports': (context) =>
            LaporKekerasanPage(), // Route for violence reports

        // Form routes
        '/addlaporkejadian': (context) =>
            AddLaporKejadianPage(), // Route for adding reports
        '/regismhs': (context) =>
            RegisterMhsPage(), // Route for student registration
        '/addlaporks': (context) =>
            AddLaporKsPage(), // Route for adding violence reports
        '/addlaporkejadianmendesak': (context) =>
            AddLaporKejadianMendesak(), // Route for urgent reports

        // Additional routes used in HomeScreen navigation
        '/settings': (context) =>
            SettingsScreen(), // You'll need to create this screen
      },
    );
  }
}
