import 'package:flutter/material.dart';
import 'package:pelaporan_d3ti/pelaporan%20kekerasan%20seksual/detail_lapor_ks.dart';

class LaporKekerasanSeksualPage extends StatefulWidget {
  const LaporKekerasanSeksualPage({Key? key}) : super(key: key);

  @override
  _LaporKekerasanSeksualPageState createState() =>
      _LaporKekerasanSeksualPageState();
}

class _LaporKekerasanSeksualPageState extends State<LaporKekerasanSeksualPage> {
  // Dummy data laporan kekerasan seksual
  List<Map<String, dynamic>> _laporanList = [
    {
      'id': 1,
      'judul': 'Kekerasan Seksual di Sekolah',
      'lokasi': 'SMA Negeri 1 Jakarta',
      'tanggal': '2023-10-01'
    },
    {
      'id': 2,
      'judul': 'Pelecehan di Tempat Kerja',
      'lokasi': 'PT ABC Jakarta',
      'tanggal': '2023-10-02'
    },
    {
      'id': 3,
      'judul': 'Kasus Pemerkosaan',
      'lokasi': 'Perumahan XYZ',
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
        title: Text('Laporan Kekerasan Seksual'),
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
                    Navigator.pushNamed(context, '/addlaporks');
                  },
                  style: ElevatedButton.styleFrom(
                    foregroundColor: Colors.white, // Warna teks tombol
                    backgroundColor: Colors.red, // Warna latar belakang tombol
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
                              DetailLaporKsPage(laporan: laporan),
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
