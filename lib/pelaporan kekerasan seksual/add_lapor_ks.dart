import 'dart:io';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:intl/intl.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../models/laporan_kekerasan.dart';
import '../models/laporan_kekerasan_form.dart';
import '../services/api_service.dart';

class AddLaporKsPage extends StatefulWidget {
  const AddLaporKsPage({Key? key}) : super(key: key);

  @override
  _AddLaporKsPageState createState() => _AddLaporKsPageState();
}

class _AddLaporKsPageState extends State<AddLaporKsPage> {
  // GlobalKey untuk mengelola form
  final _formKey = GlobalKey<FormState>();

  // Controller untuk input teks
  final TextEditingController _judulController = TextEditingController();
  final TextEditingController _lokasiController = TextEditingController();
  final TextEditingController _deskripsiController = TextEditingController();
  final TextEditingController _nomorTeleponController = TextEditingController();
  final TextEditingController _namaPelaporController = TextEditingController();
  final TextEditingController _nimPelaporController = TextEditingController();

  // Variabel untuk menyimpan tanggal
  DateTime? _selectedDate;

  // Variabel untuk menyimpan gambar yang dipilih
  File? _imageFile;

  // Daftar jenis kekerasan dan jenis yang dipilih
  final List<String> _jenisKekerasanList = [
    'Kekerasan Verbal',
    'Kekerasan Fisik',
    'Pelecehan Seksual',
    'Intimidasi',
    'Lainnya'
  ];
  String? _selectedJenisKekerasan;

  // Fungsi untuk membuka date picker
  Future<void> _selectDate(BuildContext context) async {
    final DateTime? picked = await showDatePicker(
      context: context,
      initialDate: DateTime.now(),
      firstDate: DateTime(2020),
      lastDate: DateTime(2100),
    );
    if (picked != null && picked != _selectedDate) {
      setState(() {
        _selectedDate = picked;
      });
    }
  }

  // Fungsi untuk memilih gambar dari galeri atau kamera
  Future<void> _pickImage(ImageSource source) async {
    final picker = ImagePicker();
    final pickedFile = await picker.pickImage(source: source);
    if (pickedFile != null) {
      setState(() {
        _imageFile = File(pickedFile.path);
      });
    }
  }

  // Fungsi untuk menyimpan data laporan
  void _saveLaporan() {
    // Validasi form
    if (!_formKey.currentState!.validate()) {
      return;
    }

    // Format tanggal ke string
    String formattedDate = _selectedDate != null
        ? DateFormat('yyyy-MM-dd').format(_selectedDate!)
        : '';

    // Simpan data (bisa dikirim ke API atau database)
    Map<String, dynamic> newLaporan = {
      'judul': _judulController.text,
      'image_path': _imageFile?.path ?? '', // Path gambar jika ada
      'jenis_kekerasan': _selectedJenisKekerasan,
      'deskripsi': _deskripsiController.text,
      'lokasi': _lokasiController.text,
      'tanggal_kejadian': formattedDate,
      'nomor_telepon': _nomorTeleponController.text,
      'nama_pelapor': _namaPelaporController.text,
      'nim_pelapor': _nimPelaporController.text,
      'status': 'pending', // Placeholder untuk status
      'tanggapan': '', // Placeholder untuk tanggapan
      'user_id': 1, // Placeholder untuk user_id
    };

    // Tampilkan notifikasi bahwa data berhasil disimpan
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text('Laporan kekerasan seksual berhasil disimpan!')),
    );

    // Kosongkan form setelah disimpan
    _judulController.clear();
    _lokasiController.clear();
    _deskripsiController.clear();
    _nomorTeleponController.clear();
    _namaPelaporController.clear();
    _nimPelaporController.clear();
    setState(() {
      _selectedDate = null;
      _imageFile = null; // Reset gambar
      _selectedJenisKekerasan = null; // Reset jenis kekerasan
    });

    // Kembali ke halaman sebelumnya
    Navigator.pop(
        context, newLaporan); // Mengirim data kembali ke halaman utama
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text('Laporan Kekerasan Seksual'),
        backgroundColor: Color(0xFFE53935),
      ),
      body: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Form(
          key: _formKey, // Kunci untuk mengelola form
          child: SingleChildScrollView(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                RichText(
                  text: const TextSpan(
                    style: TextStyle(
                        fontSize: 16, color: Colors.black), // Gaya default
                    children: [
                      TextSpan(
                          text: 'Judul Laporan ',
                          style: TextStyle(fontWeight: FontWeight.bold)),
                    ],
                  ),
                ),
                SizedBox(height: 8), // Jarak antara label dan TextFormField
                // Input Judul
                TextFormField(
                  controller: _judulController,
                  decoration: InputDecoration(
                    hintText: 'Judul Laporan',
                    hintStyle: TextStyle(
                      color: Colors.grey[500], // Warna abu-abu sedang
                    ),
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(8),
                    ),
                  ),
                  validator: (value) {
                    if (value == null || value.isEmpty) {
                      return 'Judul tidak boleh kosong';
                    }
                    return null;
                  },
                ),
                SizedBox(height: 16),

                RichText(
                  text: const TextSpan(
                    style: TextStyle(
                        fontSize: 16, color: Colors.black), // Gaya default
                    children: [
                      TextSpan(
                          text: 'Jenis Kekerasan',
                          style: TextStyle(fontWeight: FontWeight.bold)),
                    ],
                  ),
                ),
                SizedBox(height: 8),
                // Dropdown Jenis Kekerasan
                DropdownButtonFormField<String>(
                  decoration: InputDecoration(
                    labelText: 'Jenis Kekerasan',
                    labelStyle: TextStyle(color: Colors.grey[500]),
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(8),
                    ),
                  ),
                  value: _selectedJenisKekerasan,
                  items: _jenisKekerasanList.map((String jenis) {
                    return DropdownMenuItem<String>(
                      value: jenis,
                      child: Text(jenis),
                    );
                  }).toList(),
                  onChanged: (String? newValue) {
                    setState(() {
                      _selectedJenisKekerasan = newValue;
                    });
                  },
                  validator: (value) {
                    if (value == null || value.isEmpty) {
                      return 'Jenis kekerasan harus dipilih';
                    }
                    return null;
                  },
                ),
                SizedBox(height: 16),

                RichText(
                    text: const TextSpan(
                  style: TextStyle(fontSize: 16, color: Colors.black),
                  children: [
                    TextSpan(
                        text: "Bukti Laporan (Opsional)",
                        style: TextStyle(fontWeight: FontWeight.bold)),
                  ],
                )),
                SizedBox(height: 16),

                // Input Gambar
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                  children: [
                    ElevatedButton.icon(
                      onPressed: () => _pickImage(ImageSource.camera),
                      icon: Icon(Icons.camera_alt),
                      label: Text('Ambil Gambar'),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Color(0xFF00A2EA),
                      ),
                    ),
                    ElevatedButton.icon(
                      onPressed: () => _pickImage(ImageSource.gallery),
                      icon: Icon(Icons.photo_library),
                      label: Text('Pilih dari Galeri'),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Color(0xFF00A2EA),
                      ),
                    ),
                  ],
                ),
                SizedBox(height: 16),

                // Preview Gambar
                if (_imageFile != null)
                  Center(
                    child: Image.file(
                      _imageFile!,
                      height: 200,
                      width: double.infinity,
                      fit: BoxFit.cover,
                    ),
                  ),

                SizedBox(height: 16),

                RichText(
                    text: const TextSpan(
                  style: TextStyle(fontSize: 16, color: Colors.black),
                  children: [
                    TextSpan(
                        text: "Lokasi Kejadian",
                        style: TextStyle(fontWeight: FontWeight.bold)),
                  ],
                )),
                SizedBox(height: 8),
                // Input Lokasi
                TextFormField(
                  controller: _lokasiController,
                  decoration: InputDecoration(
                    hintText: 'Lokasi Kejadian',
                    hintStyle: TextStyle(color: Colors.grey[500]),
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(8),
                    ),
                  ),
                  validator: (value) {
                    if (value == null || value.isEmpty) {
                      return 'Lokasi tidak boleh kosong';
                    }
                    return null;
                  },
                ),
                SizedBox(height: 16),

                RichText(
                    text: const TextSpan(
                  style: TextStyle(fontSize: 16, color: Colors.black),
                  children: [
                    TextSpan(
                        text: "Deskripsi Laporan",
                        style: TextStyle(fontWeight: FontWeight.bold)),
                  ],
                )),
                SizedBox(height: 8),
                // Input Deskripsi
                TextFormField(
                  controller: _deskripsiController,
                  maxLines: 3,
                  decoration: InputDecoration(
                    hintText: 'Deskripsi Kejadian',
                    hintStyle: TextStyle(color: Colors.grey[500]),
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(8),
                    ),
                  ),
                  validator: (value) {
                    if (value == null || value.isEmpty) {
                      return 'Deskripsi tidak boleh kosong';
                    }
                    return null;
                  },
                ),
                SizedBox(height: 16),

                RichText(
                    text: const TextSpan(
                  style: TextStyle(fontSize: 16, color: Colors.black),
                  children: [
                    TextSpan(
                        text: "Nomor Telepon Pelapor",
                        style: TextStyle(fontWeight: FontWeight.bold)),
                  ],
                )),
                SizedBox(height: 8),
                // Input Nomor Telepon
                TextFormField(
                  controller: _nomorTeleponController,
                  keyboardType: TextInputType.phone,
                  decoration: InputDecoration(
                    hintText: 'Nomor Telepon Pelapor',
                    hintStyle: TextStyle(color: Colors.grey[500]),
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(8),
                    ),
                  ),
                  validator: (value) {
                    if (value == null || value.isEmpty) {
                      return 'Nomor telepon tidak boleh kosong';
                    }
                    return null;
                  },
                ),
                SizedBox(height: 16),

                RichText(
                    text: const TextSpan(
                  style: TextStyle(fontSize: 16, color: Colors.black),
                  children: [
                    TextSpan(
                        text: "Nama Pelapor",
                        style: TextStyle(fontWeight: FontWeight.bold)),
                  ],
                )),
                SizedBox(height: 8),
                // Input Nama Pelapor
                TextFormField(
                  controller: _namaPelaporController,
                  decoration: InputDecoration(
                    hintText: 'Nama Pelapor',
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(8),
                    ),
                  ),
                  validator: (value) {
                    if (value == null || value.isEmpty) {
                      return 'Nama pelapor tidak boleh kosong';
                    }
                    return null;
                  },
                ),
                SizedBox(height: 16),

                RichText(
                    text: const TextSpan(
                  style: TextStyle(fontSize: 16, color: Colors.black),
                  children: [
                    TextSpan(
                        text: "NIM Pelapor",
                        style: TextStyle(fontWeight: FontWeight.bold)),
                  ],
                )),
                SizedBox(height: 8),
                // Input NIM Pelapor
                TextFormField(
                  controller: _nimPelaporController,
                  keyboardType: TextInputType.number,
                  decoration: InputDecoration(
                    hintText: 'NIM Pelapor',
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(8),
                    ),
                  ),
                  validator: (value) {
                    if (value == null || value.isEmpty) {
                      return 'NIM pelapor tidak boleh kosong';
                    }
                    return null;
                  },
                ),
                SizedBox(height: 16),

                RichText(
                    text: const TextSpan(
                  style: TextStyle(fontSize: 16, color: Colors.black),
                  children: [
                    TextSpan(
                        text: "Tanggal Kejadian",
                        style: TextStyle(fontWeight: FontWeight.bold)),
                  ],
                )),
                SizedBox(height: 8),
                // Input Tanggal
                InkWell(
                  onTap: () => _selectDate(context),
                  child: InputDecorator(
                    decoration: InputDecoration(
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(8),
                      ),
                    ),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Text(
                          _selectedDate == null
                              ? 'Pilih Tanggal'
                              : DateFormat('yyyy-MM-dd').format(_selectedDate!),
                          style: TextStyle(
                            color: _selectedDate == null
                                ? Colors.grey
                                : Colors.black,
                          ),
                        ),
                        Icon(Icons.calendar_today, color: Colors.grey),
                      ],
                    ),
                  ),
                ),
                SizedBox(height: 24),

                // Tombol Simpan
                ElevatedButton(
                  onPressed: _saveLaporan,
                  style: ElevatedButton.styleFrom(
                    foregroundColor: Colors.white,
                    backgroundColor: Color(0xFFE53935),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(8),
                    ),
                    padding: EdgeInsets.symmetric(vertical: 16),
                    minimumSize: Size(double.infinity, 50), // Full width button
                  ),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(Icons.save, size: 18),
                      SizedBox(width: 8),
                      Text('Simpan'),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
