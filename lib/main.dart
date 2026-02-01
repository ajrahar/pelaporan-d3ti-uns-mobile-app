import 'package:flutter/material.dart';
import 'package:flutter_native_splash/flutter_native_splash.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:provider/provider.dart';
import 'package:pelaporan_d3ti/core/di/injection_container.dart' as di;
import 'package:pelaporan_d3ti/features/auth/presentation/providers/auth_provider.dart';
import 'package:pelaporan_d3ti/features/auth/presentation/pages/login_dosen.dart';
import 'package:pelaporan_d3ti/features/auth/presentation/pages/login_page.dart';
import 'package:pelaporan_d3ti/features/auth/presentation/pages/register_mhs.dart';
import 'package:pelaporan_d3ti/features/dosen/home/home_screen_dosen.dart';
import 'package:pelaporan_d3ti/features/dosen/pelaporan_kejadian/add_lapor_pk_dosen.dart';
import 'package:pelaporan_d3ti/features/dosen/pelaporan_kejadian/add_lapor_pk_mendesak_dosen.dart';
import 'package:pelaporan_d3ti/features/dosen/pelaporan_kejadian/lapor_pk_dosen.dart';
import 'package:pelaporan_d3ti/features/dosen/pelaporan_kekerasan_seksual/add_lapor_ks_dosen.dart';
import 'package:pelaporan_d3ti/features/dosen/pelaporan_kekerasan_seksual/lapor_ks_dosen.dart';
import 'package:pelaporan_d3ti/features/kekerasan_seksual/add_ks_public.dart';
import 'package:pelaporan_d3ti/features/kekerasan_seksual/test_page.dart';
import "package:pelaporan_d3ti/features/mahasiswa/home_screen/home_screen.dart";
import 'package:pelaporan_d3ti/features/mahasiswa/pelaporan_kekerasan_seksual/add_lapor_ks.dart';
import 'package:pelaporan_d3ti/features/mahasiswa/pelaporan_kekerasan_seksual/lapor_ks.dart';
import 'package:pelaporan_d3ti/features/mahasiswa/pelaporan_kejadian/add_lapor_kejadian.dart';
import 'package:pelaporan_d3ti/features/mahasiswa/pelaporan_kejadian/lapor_kejadian.dart';
import 'package:pelaporan_d3ti/features/mahasiswa/pelaporan_kejadian/add_lapor_kejadian_mendesak.dart';
import 'package:pelaporan_d3ti/shared/services/notification_service.dart';
import 'package:pelaporan_d3ti/features/settings/settings_screen.dart';
import 'package:timezone/data/latest.dart' as tz_init;

void main() async {
  // Ensure Flutter is initialized and preserve splash screen
  WidgetsBinding widgetsBinding = WidgetsFlutterBinding.ensureInitialized();
  FlutterNativeSplash.preserve(widgetsBinding: widgetsBinding);

  // Initialize DI
  await di.setupLocator();

  // Initialize timezone data
  tz_init.initializeTimeZones();

  // Initialize notification service
  await NotificationService().initialize();

  // Add any other initialization needed here

  // Remove the splash screen when initialization is done
  // You can add a small delay if you want the splash screen to show for a minimum amount of time
  await Future.delayed(const Duration(seconds: 3));
  FlutterNativeSplash.remove();

  runApp(MyApp());
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MultiProvider(
      providers: [
        ChangeNotifierProvider(create: (_) => di.sl<AuthProvider>()),
      ],
      child: MaterialApp(
        debugShowCheckedModeBanner: false, // Hide debug banner
        initialRoute: '/login', // Changed initial route to login since splash is now native

        // Set Poppins as the default font for the entire application
        theme: ThemeData(
          textTheme: GoogleFonts.poppinsTextTheme(
            Theme.of(context).textTheme,
          ),
          // You can also customize other theme properties here
          primarySwatch: Colors.blue,
          visualDensity: VisualDensity.adaptivePlatformDensity,
        ),

        routes: {
          // Removed the splash screen route since we're using native splash
          // '/': (context) => SplashScreen(),

          '/login': (context) => const LoginPage(), // Route for login page
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
      ),
    );
  }
}
