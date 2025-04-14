import 'dart:io';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:intl/intl.dart';

class AddLaporKejadianPage extends StatefulWidget {
  const AddLaporKejadianPage({Key? key}) : super(key: key);

  @override
  _AddLaporKejadianPageState createState() => _AddLaporKejadianPageState();
}

class _AddLaporKejadianPageState extends State<AddLaporKejadianPage> {
  // GlobalKey untuk mengelola form
  final _formKey = GlobalKey<FormState>();

  // Controller untuk input teks
  final TextEditingController _judulController = TextEditingController();
  final TextEditingController _deskripsiController = TextEditingController();
  final TextEditingController _nomorTeleponController = TextEditingController();
  final TextEditingController _namaPelaporController = TextEditingController();
  final TextEditingController _nimPelaporController = TextEditingController();

  // Variabel untuk menyimpan tanggal
  DateTime? _selectedDate;

  // Variabel untuk menyimpan gambar yang dipilih
  File? _imageFile;

  // Daftar kategori dan kategori yang dipilih
  final List<String> _kategoriList = [
    'Kehilangan',
    'Kerusakan',
    'Keamanan',
    'Lainnya'
  ];
  String? _selectedKategori;

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
    String formattedDate = DateFormat('yyyy-MM-dd').format(_selectedDate!);

    // Simpan data (bisa dikirim ke API atau database)
    Map<String, dynamic> newLaporan = {
      'judul': _judulController.text,
      'image_path': _imageFile?.path ?? '', // Path gambar jika ada
      'category_id':
          _kategoriList.indexOf(_selectedKategori!) + 1, // ID berdasarkan index
      'deskripsi': _deskripsiController.text,
      'tanggal_kejadian': formattedDate,
      'nomor_telepon': _nomorTeleponController.text,
      'nama_pelapor': _namaPelaporController.text,
      'nim_pelapor': _nimPelaporController.text,
      'status': 'pending', // Placeholder untuk status
      'tanggapan': '', // Placeholder untuk tanggapan
      'user_id':
          1, // Placeholder untuk user_id (bisa diambil dari session/auth)
    };

    // Tampilkan notifikasi bahwa data berhasil disimpan
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text('Laporan berhasil disimpan!')),
    );

    // Kosongkan form setelah disimpan
    _judulController.clear();
    _deskripsiController.clear();
    _nomorTeleponController.clear();
    _namaPelaporController.clear();
    _nimPelaporController.clear();
    setState(() {
      _selectedDate = null;
      _imageFile = null; // Reset gambar
      _selectedKategori = null; // Reset kategori
    });

    // Kembali ke halaman sebelumnya
    Navigator.pop(
        context, newLaporan); // Mengirim data kembali ke halaman utama
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text('Tambah Laporan'),
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
                          text: 'Judul atau Nama Laporan ',
                          style: TextStyle(fontWeight: FontWeight.bold)),
                    ],
                  ),
                ),
                SizedBox(height: 8), // Jarak antara label dan TextFormField
                // Input Judul
                TextFormField(
                  controller: _judulController,
                  decoration: InputDecoration(
                    hintText: 'Judul atau Nama Laporan',
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
                          text: 'Kategori',
                          style: TextStyle(fontWeight: FontWeight.bold)),
                    ],
                  ),
                ),
                SizedBox(height: 8),
                // Dropdown Kategori
                DropdownButtonFormField<String>(
                  decoration: InputDecoration(
                    labelText: 'Kategori',
                    labelStyle: TextStyle(color: Colors.grey[500]),
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(8),
                    ),
                  ),
                  value: _selectedKategori,
                  items: _kategoriList.map((String kategori) {
                    return DropdownMenuItem<String>(
                      value: kategori,
                      child: Text(kategori),
                    );
                  }).toList(),
                  onChanged: (String? newValue) {
                    setState(() {
                      _selectedKategori = newValue;
                    });
                  },
                  validator: (value) {
                    if (value == null || value.isEmpty) {
                      return 'Kategori harus dipilih';
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
                        text: "Bukti Laporan",
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
                    ),
                    ElevatedButton.icon(
                      onPressed: () => _pickImage(ImageSource.gallery),
                      icon: Icon(Icons.photo_library),
                      label: Text('Pilih dari Galeri'),
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

                SizedBox(height: 8),

                RichText(
                    text: const TextSpan(
                  style: TextStyle(fontSize: 16, color: Colors.black),
                  children: [
                    TextSpan(
                        text: "Deskripsi Laporan",
                        style: TextStyle(fontWeight: FontWeight.bold)),
                  ],
                )),
                SizedBox(height: 16),

                // Input Deskripsi
                TextFormField(
                  controller: _deskripsiController,
                  maxLines: 3,
                  decoration: InputDecoration(
                    hintText: 'Deskripsi',
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
                SizedBox(height: 16),

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
                SizedBox(height: 16),
                // Input Nama Pelapor
                TextFormField(
                  controller: _namaPelaporController,
                  decoration: InputDecoration(
                    labelText: 'Nama Pelapor',
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
                SizedBox(height: 16),
                // Input NIM Pelapor
                TextFormField(
                  controller: _nimPelaporController,
                  keyboardType: TextInputType.number,
                  decoration: InputDecoration(
                    labelText: 'NIM Pelapor',
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
                SizedBox(height: 16),
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
                    backgroundColor: Colors.blue,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(8),
                    ),
                    padding: EdgeInsets.symmetric(vertical: 16),
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
