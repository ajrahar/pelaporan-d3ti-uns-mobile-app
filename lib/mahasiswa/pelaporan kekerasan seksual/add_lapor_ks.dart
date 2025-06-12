import 'dart:io';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:intl/intl.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../../models/laporan_kekerasan.dart';
import '../../models/laporan_kekerasan_form.dart';
import '../../services/api_service.dart';

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

  // Daftar jenis kekerasan yang dipilih
  String? _selectedJenisKekerasan;

  // List untuk menyimpan kategori dari API
  List<String> _jenisKekerasanList = [];

  // Map untuk menyimpan kategori dari API
  Map<int, String> _categoriesMap = {};
  // Map terbalik untuk pencarian ID berdasarkan nama kategori
  Map<String, int> _categoryNameToIdMap = {};

  // Status loading
  bool _isLoading = false;
  bool _isLoadingCategories = true;

  @override
  void initState() {
    super.initState();
    _loadUserData();
    _loadCategories();
  }

  // Fungsi untuk memuat kategori dari API
  Future<void> _loadCategories() async {
    setState(() {
      _isLoadingCategories = true;
    });

    try {
      final ApiService apiService = ApiService();
      final categories = await apiService.getCategories();

      setState(() {
        _categoriesMap = categories;

        // Buat map terbalik untuk pencarian ID berdasarkan nama
        _categoriesMap.forEach((key, value) {
          _categoryNameToIdMap[value] = key;
        });

        // Update _jenisKekerasanList dengan hanya kategori yang dimulai dengan "Kekerasan"
        _jenisKekerasanList = _categoriesMap.values
            .where((categoryName) => categoryName.startsWith('Kekerasan'))
            .toList();

        _isLoadingCategories = false;
      });
    } catch (e) {
      print('Error loading categories: $e');
      // Jika gagal memuat kategori, sediakan daftar default
      setState(() {
        _jenisKekerasanList = [
          'Kekerasan Verbal',
          'Kekerasan Fisik',
          'Pelecehan Seksual',
          'Intimidasi',
          'Lainnya'
        ];
        _isLoadingCategories = false;
      });
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Gagal memuat kategori laporan')),
      );
    }
  }

  // Fungsi untuk memuat data user dari SharedPreferences
  Future<void> _loadUserData() async {
    try {
      final prefs = await SharedPreferences.getInstance();

      setState(() {
        _namaPelaporController.text = prefs.getString('user_name') ?? '';
        _nimPelaporController.text = prefs.getString('user_nim') ?? '';
        _nomorTeleponController.text = prefs.getString('user_no_telp') ?? '';
      });
    } catch (e) {
      print('Error loading user data: $e');
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Gagal memuat data pengguna')),
      );
    }
  }

  // Fungsi untuk membuka date picker
  Future<void> _selectDate(BuildContext context) async {
    final DateTime? picked = await showDatePicker(
      context: context,
      initialDate: DateTime.now(),
      firstDate: DateTime(2020),
      lastDate: DateTime.now(),
    );
    if (picked != null) {
      setState(() {
        _selectedDate = picked;
      });
    }
  }

  // Fungsi untuk memilih gambar dari galeri atau kamera
  Future<void> _pickImage(ImageSource source) async {
    try {
      final picker = ImagePicker();
      final pickedFile = await picker.pickImage(source: source);

      if (pickedFile != null) {
        setState(() {
          _imageFile = File(pickedFile.path);
        });
      }
    } catch (e) {
      print('Error picking image: $e');
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Gagal memilih gambar')),
      );
    }
  }

  // Validasi form
  bool _validateForm() {
    if (_formKey.currentState!.validate() &&
        _selectedDate != null &&
        _selectedJenisKekerasan != null &&
        _imageFile != null) {
      return true;
    }

    if (_selectedDate == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Tanggal kejadian harus dipilih')),
      );
    }

    if (_selectedJenisKekerasan == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Jenis kekerasan harus dipilih')),
      );
    }

    if (_imageFile == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Bukti foto harus diunggah')),
      );
    }

    return false;
  }

  // Fungsi untuk menyimpan data laporan kekerasan seksual ke API
  Future<void> _saveLaporan() async {
    if (!_validateForm()) {
      return;
    }

    setState(() {
      _isLoading = true;
    });

    try {
      // Prepare data for API submission
      final ApiService apiService = ApiService();

      // Get categoryId from the _categoryNameToIdMap using the selected jenis kekerasan
      int categoryId;
      if (_categoryNameToIdMap.containsKey(_selectedJenisKekerasan)) {
        // If we've loaded the categories from API, use the correct ID
        categoryId = _categoryNameToIdMap[_selectedJenisKekerasan]!;
      } else {
        // Fallback mapping if API categories couldn't be loaded
        switch (_selectedJenisKekerasan) {
          case 'Kekerasan Verbal':
            categoryId = 1;
            break;
          case 'Kekerasan Fisik':
            categoryId = 2;
            break;
          case 'Pelecehan Seksual':
            categoryId = 3;
            break;
          case 'Intimidasi':
            categoryId = 4;
            break;
          case 'Lainnya':
          default:
            categoryId = 5;
            break;
        }
      }

      // Submit report using the appropriate method
      final result = await apiService.submitLaporanKekerasan(
        title: _judulController.text,
        categoryId: categoryId,
        description: _deskripsiController.text,
        tanggalKejadian: DateFormat('yyyy-MM-dd').format(_selectedDate!),
        namaPelapor: _namaPelaporController.text,
        nimPelapor: _nimPelaporController.text,
        nomorTelepon: _nomorTeleponController.text,
        buktiPelanggaran: [_lokasiController.text],
        terlapor: [], // Not collected in this form
        saksi: [], // Not collected in this form
        imageFiles: [_imageFile!], // Convert the selected image to a list
        agreement: true, // Assuming the user agrees by submitting
      );

      setState(() {
        _isLoading = false;
      });

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Laporan kekerasan seksual berhasil disimpan')),
      );

      // Navigate back after successful submission
      Navigator.pop(context);
    } catch (e) {
      setState(() {
        _isLoading = false;
      });

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Error: ${e.toString()}')),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text('Laporan Kekerasan Seksual'),
        backgroundColor: Color(0xFFE53935),
      ),
      body: _isLoading || _isLoadingCategories
          ? Center(child: CircularProgressIndicator())
          : Padding(
              padding: const EdgeInsets.all(16.0),
              child: Form(
                key: _formKey,
                child: SingleChildScrollView(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      RichText(
                        text: const TextSpan(
                          style: TextStyle(fontSize: 16, color: Colors.black),
                          children: [
                            TextSpan(
                                text: 'Judul Laporan ',
                                style: TextStyle(fontWeight: FontWeight.bold)),
                          ],
                        ),
                      ),
                      SizedBox(height: 8),
                      // Input Judul
                      TextFormField(
                        controller: _judulController,
                        decoration: InputDecoration(
                          hintText: 'Judul Laporan',
                          hintStyle: TextStyle(
                            color: Colors.grey[500],
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
                          style: TextStyle(fontSize: 16, color: Colors.black),
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
                                text: "Bukti Laporan (Foto)",
                                style: TextStyle(fontWeight: FontWeight.bold)),
                          ],
                        ),
                      ),
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
                        ),
                      ),
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
                        ),
                      ),
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
                                text: "Nama Pelapor",
                                style: TextStyle(fontWeight: FontWeight.bold)),
                          ],
                        ),
                      ),
                      SizedBox(height: 8),
                      // Input Nama Pelapor
                      TextFormField(
                        controller: _namaPelaporController,
                        decoration: InputDecoration(
                          hintText: 'Nama Pelapor',
                          hintStyle: TextStyle(color: Colors.grey[500]),
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
                        ),
                      ),
                      SizedBox(height: 8),
                      // Input NIM Pelapor
                      TextFormField(
                        controller: _nimPelaporController,
                        keyboardType: TextInputType.number,
                        decoration: InputDecoration(
                          hintText: 'NIM Pelapor',
                          hintStyle: TextStyle(color: Colors.grey[500]),
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
                                text: "Nomor Telepon Pelapor",
                                style: TextStyle(fontWeight: FontWeight.bold)),
                          ],
                        ),
                      ),
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
                                text: "Tanggal Kejadian",
                                style: TextStyle(fontWeight: FontWeight.bold)),
                          ],
                        ),
                      ),
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
                                    : DateFormat('yyyy-MM-dd')
                                        .format(_selectedDate!),
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
                          minimumSize:
                              Size(double.infinity, 50), // Full width button
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

  @override
  void dispose() {
    // Dispose controllers
    _judulController.dispose();
    _lokasiController.dispose();
    _deskripsiController.dispose();
    _nomorTeleponController.dispose();
    _namaPelaporController.dispose();
    _nimPelaporController.dispose();
    super.dispose();
  }
}
