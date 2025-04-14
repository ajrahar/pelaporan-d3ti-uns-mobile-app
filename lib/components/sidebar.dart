// File: lib/sidebar.dart
import 'package:flutter/material.dart';

class Sidebar extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return Drawer(
      backgroundColor: Colors.white,
      child: ListView(
        padding: EdgeInsets.zero,
        children: [
          // Header Sidebar
          const DrawerHeader(
            decoration: BoxDecoration(
              color: Color(0xFF00A2EA), // Warna biru untuk header
            ),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                CircleAvatar(
                  radius: 30,
                  backgroundImage: AssetImage(
                      'assets/images/d3ti_logo.png'), // Ganti dengan path logo Anda
                ),
                SizedBox(height: 10),
                Text(
                  'Selamat Datang',
                  style: TextStyle(
                    fontSize: 16,
                    color: Colors.white,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                Text(
                  'User Name', // Ganti dengan nama pengguna
                  style: TextStyle(
                    fontSize: 14,
                    color: Colors.white,
                  ),
                ),
              ],
            ),
          ),

          // Menu Utama
          ListTile(
            leading: Icon(Icons.home, color: Color(0xFF00A2EA)),
            title: Text('Home'),
            onTap: () {
              Navigator.pushReplacementNamed(
                  context, '/home'); // Navigasi ke halaman Home
            },
          ),

          ListTile(
            leading: Icon(Icons.warning, color: Color(0xFF00A2EA)),
            title: Text('Pelaporan Kejadian'),
            onTap: () {
              Navigator.pushReplacementNamed(
                  context, '/laporkejadian'); // Navigasi ke halaman Notifikasi
            },
          ),

          ListTile(
            leading: Icon(Icons.report, color: Color(0xFF00A2EA)),
            title: Text('Pelaporan Kekerasan Seksual'),
            onTap: () {
              Navigator.pushReplacementNamed(
                  context, '/laporanks'); // Navigasi ke halaman Notifikasi
            },
          ),

          // Menu Lainnya
          ListTile(
            leading: Icon(Icons.person, color: Color(0xFF00A2EA)),
            title: Text('Profile'),
            onTap: () {
              Navigator.pushReplacementNamed(
                  context, '/profile'); // Navigasi ke halaman Profile
            },
          ),
          ListTile(
            leading: Icon(Icons.logout, color: Colors.red),
            title: Text('Logout'),
            onTap: () {
              // Logika logout (misalnya, kembali ke halaman login)
              Navigator.pushReplacementNamed(context, '/login');
            },
          ),
        ],
      ),
    );
  }
}
