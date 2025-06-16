// File: lib/main.dart
import 'package:flutter/material.dart';
import 'package:flutter_native_splash/flutter_native_splash.dart';
import 'package:pelaporan_d3ti/auth_screen/login_dosen.dart';
import 'package:pelaporan_d3ti/auth_screen/login_mhs.dart';
import 'package:pelaporan_d3ti/auth_screen/register_mhs.dart';
import 'package:pelaporan_d3ti/dosen/home/home_screen_dosen.dart';
import 'package:pelaporan_d3ti/dosen/pelaporan_kejadian_dosen/add_lapor_pk_dosen.dart';
import 'package:pelaporan_d3ti/dosen/pelaporan_kejadian_dosen/add_lapor_pk_mendesak_dosen.dart';
import 'package:pelaporan_d3ti/dosen/pelaporan_kejadian_dosen/lapor_pk_dosen.dart';
import 'package:pelaporan_d3ti/dosen/pelaporan_kekerasan_seksual_dosen/add_lapor_ks_dosen.dart';
import 'package:pelaporan_d3ti/dosen/pelaporan_kekerasan_seksual_dosen/lapor_ks_dosen.dart';
import 'package:pelaporan_d3ti/kekerasan_seksual/add_ks_public.dart';
import 'package:pelaporan_d3ti/kekerasan_seksual/test_page.dart';
import 'package:pelaporan_d3ti/mahasiswa/home_screen/home_screen.dart';
import 'package:pelaporan_d3ti/mahasiswa/pelaporan%20kekerasan%20seksual/add_lapor_ks.dart';
import 'package:pelaporan_d3ti/mahasiswa/pelaporan%20kekerasan%20seksual/lapor_ks.dart';
import 'package:pelaporan_d3ti/mahasiswa/pelaporan/add_lapor_kejadian.dart';
import 'package:pelaporan_d3ti/mahasiswa/pelaporan/lapor_kejadian.dart';
import 'package:pelaporan_d3ti/mahasiswa/pelaporan/add_lapor_kejadian_mendesak.dart';
import 'package:pelaporan_d3ti/services/notification_service.dart';
import 'package:pelaporan_d3ti/settings/settings_screen.dart'; // You'll need to create this
// Remove this import since we're replacing it with native splash
// import 'splash_screen/splash_screen.dart';
import 'package:timezone/data/latest.dart' as tz_init;

void main() async {
  // Ensure Flutter is initialized and preserve splash screen
  WidgetsBinding widgetsBinding = WidgetsFlutterBinding.ensureInitialized();
  FlutterNativeSplash.preserve(widgetsBinding: widgetsBinding);

  // Initialize timezone data
  tz_init.initializeTimeZones();

  // Initialize notification service
  await NotificationService().initialize();

  // Add any other initialization needed here

  // Remove the splash screen when initialization is done
  // You can add a small delay if you want the splash screen to show for a minimum amount of time
  await Future.delayed(Duration(seconds: 3));
  FlutterNativeSplash.remove();

  runApp(MyApp());
}

class MyApp extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      debugShowCheckedModeBanner: false, // Hide debug banner
      initialRoute:
          '/login', // Changed initial route to login since splash is now native
      routes: {
        // Removed the splash screen route since we're using native splash
        // '/': (context) => SplashScreen(),

        '/login': (context) => LoginPage(), // Route for login page
        '/logindosen': (context) => LoginDosenPage(), // Route for faculty login
        '/home': (context) => HomeScreen(), // Route for main page

        '/homedosen': (context) => HomeScreenDosen(),
        '/laporpkdosen': (context) => LaporKejadianDosenPage(),

        '/laporksdosen': (context) =>
            LaporKekerasanDosenPage(), // Route for faculty violence reports

        '/addlaporpkdosen': (context) =>
            AddLaporPKDosenPage(), // Route for adding faculty incident reports

        '/addlaporpkmendesakdosen': (context) =>
            AddLaporPKMendesakDosen(), // Route for adding urgent faculty incident reports

        '/addlaporksdosen': (context) =>
            AddLaporKsDosenPage(), // Route for adding faculty violence reports

        '/addkspublic': (context) =>
            AddKSPublicPage(), // Route for adding public violence reports

        '/recaptchatestpage': (context) =>
            RecaptchaTestPage(), // Route for reCAPTCHA test page

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
