import 'package:flutter/material.dart';

class DetailLaporanPage extends StatelessWidget {
  final Map<String, dynamic> laporan;

  const DetailLaporanPage({Key? key, required this.laporan}) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text('Detail Laporan Kejadian'),
        leading: IconButton(
          icon: Icon(Icons.arrow_back), // Ikon panah kembali
          onPressed: () {
            Navigator.pushReplacementNamed(context, '/laporkejadian');
          },
        ),
      ),
      body: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Judul: ${laporan['judul']}',
              style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
            ),
            SizedBox(height: 8),
            Text('Lokasi: ${laporan['lokasi']}'),
            SizedBox(height: 8),
            Text('Tanggal: ${laporan['tanggal']}'),
            SizedBox(height: 16),
            ElevatedButton(
              onPressed: () {
                // Aksi untuk menutup halaman detail
                Navigator.pop(context);
              },
              child: Text('Kembali'),
            ),
          ],
        ),
      ),
    );
  }
}
