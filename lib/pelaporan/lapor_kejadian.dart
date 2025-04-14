import 'package:flutter/material.dart';
import 'package:pelaporan_d3ti/pelaporan/detail_lapor_kejadian.dart';

class LaporKejadianPage extends StatefulWidget {
  const LaporKejadianPage({Key? key}) : super(key: key);

  @override
  _LaporKejadianPageState createState() => _LaporKejadianPageState();
}

class _LaporKejadianPageState extends State<LaporKejadianPage> {
  // Dummy data laporan
  List<Map<String, dynamic>> _laporanList = [
    {
      'id': 1,
      'judul': 'Kerusakan Jalan',
      'lokasi': 'Jl. Sudirman',
      'tanggal': '2023-10-01'
    },
    {
      'id': 2,
      'judul': 'Banjir di Perumahan',
      'lokasi': 'Perumahan ABC',
      'tanggal': '2023-10-02'
    },
    {
      'id': 3,
      'judul': 'Pohon Tumbang',
      'lokasi': 'Taman Kota',
      'tanggal': '2023-10-03'
    },
  ];

  // Data sementara untuk pencarian
  List<Map<String, dynamic>> _filteredLaporanList = [];

  // Controller untuk kolom pencarian
  final TextEditingController _searchController = TextEditingController();

  @override
  void initState() {
    super.initState();
    _filteredLaporanList = _laporanList; // Inisialisasi dengan semua data
  }

  // Fungsi untuk memfilter data berdasarkan teks pencarian
  void _filterLaporan(String query) {
    setState(() {
      _filteredLaporanList = _laporanList.where((laporan) {
        return laporan['judul'].toLowerCase().contains(query.toLowerCase()) ||
            laporan['lokasi'].toLowerCase().contains(query.toLowerCase());
      }).toList();
    });
  }

  // Fungsi untuk menghapus laporan
  void _deleteLaporan(int id) {
    setState(() {
      _laporanList.removeWhere((laporan) => laporan['id'] == id);
      _filteredLaporanList = _laporanList; // Perbarui daftar terfilter
    });

    // Tampilkan notifikasi bahwa laporan berhasil dihapus
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text('Laporan berhasil dihapus')),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text('Laporan Kejadian'),
        leading: IconButton(
          icon: Icon(Icons.arrow_back), // Ikon panah kembali
          onPressed: () {
            Navigator.pushReplacementNamed(context, '/home');
          },
        ),
      ),
      body: Column(
        children: [
          // Baris untuk Kolom Pencarian dan Tombol Tambah
          Padding(
            padding: const EdgeInsets.all(16.0),
            child: Row(
              children: [
                // Kolom Pencarian
                Expanded(
                  child: TextField(
                    controller: _searchController,
                    decoration: InputDecoration(
                      labelText: 'Cari Laporan',
                      prefixIcon: Icon(Icons.search),
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(8),
                      ),
                    ),
                    onChanged:
                        _filterLaporan, // Memanggil fungsi filter saat teks berubah
                  ),
                ),

                // Spacer kecil antara kolom pencarian dan tombol tambah
                SizedBox(width: 16),

                // Tombol Tambah
                ElevatedButton(
                  onPressed: () {
                    Navigator.pushNamed(context, '/addlaporkejadian');
                  },
                  style: ElevatedButton.styleFrom(
                    foregroundColor: Colors.white, // Warna teks tombol
                    backgroundColor: Colors.blue, // Warna latar belakang tombol
                    shape: RoundedRectangleBorder(
                      borderRadius:
                          BorderRadius.circular(8), // Sudut melengkung
                    ),
                    padding: EdgeInsets.symmetric(
                        horizontal: 16, vertical: 16), // Padding tombol
                    elevation: 3, // Efek bayangan
                  ),
                  child: Row(
                    mainAxisSize:
                        MainAxisSize.min, // Agar konten berada di tengah tombol
                    children: [
                      Icon(Icons.add, size: 18), // Ikon "+"
                      SizedBox(width: 8), // Jarak antara ikon dan teks
                      Text('Tambah'), // Teks tombol
                    ],
                  ),
                ),
              ],
            ),
          ),

          // Daftar Laporan
          Expanded(
            child: ListView.builder(
              itemCount: _filteredLaporanList.length,
              itemBuilder: (context, index) {
                final laporan = _filteredLaporanList[index];
                return Card(
                  margin: EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                  elevation: 2,
                  child: ListTile(
                    title: Text(laporan['judul']),
                    subtitle: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text('Lokasi: ${laporan['lokasi']}'),
                        Text('Tanggal: ${laporan['tanggal']}'),
                      ],
                    ),
                    trailing: IconButton(
                      icon: Icon(Icons.delete, color: Colors.red),
                      onPressed: () {
                        // Hapus laporan
                        _deleteLaporan(laporan['id']);
                      },
                    ),
                    onTap: () {
                      // Navigasi ke halaman detail laporan
                      Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder: (context) =>
                              DetailLaporanPage(laporan: laporan),
                        ),
                      );
                    },
                  ),
                );
              },
            ),
          ),
        ],
      ),
    );
  }
}
