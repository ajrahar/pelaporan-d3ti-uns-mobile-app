import 'package:flutter/material.dart';
import 'package:pelaporan_d3ti/pelaporan%20kekerasan%20seksual/add_lapor_ks.dart';

class DetailLaporKsPage extends StatelessWidget {
  final Map<String, dynamic> laporan;

  const DetailLaporKsPage({Key? key, required this.laporan}) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text('Detail Laporan Kekerasan Seksual'),
        leading: IconButton(
          icon: Icon(Icons.arrow_back),
          onPressed: () {
            Navigator.pop(context);
          },
        ),
      ),
      body: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Judul
            Text(
              'Judul:',
              style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
            ),
            SizedBox(height: 4),
            Text(laporan['judul']),
            SizedBox(height: 16),

            // Lokasi
            Text(
              'Lokasi:',
              style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
            ),
            SizedBox(height: 4),
            Text(laporan['lokasi']),
            SizedBox(height: 16),

            // Deskripsi
            Text(
              'Deskripsi:',
              style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
            ),
            SizedBox(height: 4),
            Text(laporan['deskripsi'] ?? '-'),
            SizedBox(height: 16),

            // Tanggal
            Text(
              'Tanggal Kejadian:',
              style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
            ),
            SizedBox(height: 4),
            Text(laporan['tanggal']),
            SizedBox(height: 16),

            // Tombol Edit
            ElevatedButton(
              onPressed: () {
                // Navigasi ke halaman edit laporan
                Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (context) => AddLaporKsPage(),
                  ),
                );
              },
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.blue,
                padding: EdgeInsets.symmetric(vertical: 16),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(8),
                ),
                minimumSize: Size(double.infinity, 50),
              ),
              child: Text(
                'Edit Laporan',
                style: TextStyle(fontSize: 16, color: Colors.white),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
