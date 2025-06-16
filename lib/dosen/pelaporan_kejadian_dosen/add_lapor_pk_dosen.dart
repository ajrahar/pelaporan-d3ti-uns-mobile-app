import 'dart:io';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:intl/intl.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:pelaporan_d3ti/services/api_service.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';

class AddLaporPKDosenPage extends StatefulWidget {
  const AddLaporPKDosenPage({Key? key}) : super(key: key);

  @override
  _AddLaporPKDosenPageState createState() => _AddLaporPKDosenPageState();
}

class _AddLaporPKDosenPageState extends State<AddLaporPKDosenPage> {
  // API service instance
  final ApiService _apiService = ApiService();

  // GlobalKey untuk mengelola form
  final _formKey = GlobalKey<FormState>();

  // Controller untuk input teks
  final TextEditingController _judulController = TextEditingController();
  final TextEditingController _deskripsiController = TextEditingController();
  final TextEditingController _nomorTeleponController = TextEditingController();
  final TextEditingController _namaPelaporController = TextEditingController();
  final TextEditingController _nipPelaporController = TextEditingController();
  final TextEditingController _lampiranLinkController = TextEditingController();

  // Controller untuk terlapor
  final List<Map<String, dynamic>> _terlaporList = [
    {
      'nama_lengkap': TextEditingController(),
      'email': TextEditingController(),
      'nomor_telepon': TextEditingController(),
      'jenis_kelamin': null,
      'umur_terlapor': null,
      'status_warga': null,
      'unit_kerja': null,
    }
  ];

  // Controller untuk saksi
  final List<Map<String, dynamic>> _saksiList = [
    {
      'nama_lengkap': TextEditingController(),
      'email': TextEditingController(),
      'nomor_telepon': TextEditingController(),
    }
  ];

  // Status loading dan errors
  bool _isLoading = false;
  bool _isLoadingCategories = true;
  String? _categoryError;
  Map<String, dynamic> _errors = {};

  // Variabel untuk menyimpan tanggal dan waktu
  DateTime? _selectedDate;
  TimeOfDay? _selectedTime;

  // Variabel untuk menyimpan gambar yang dipilih
  List<File> _imageFiles = [];

  // Daftar kategori dan kategori yang dipilih
  List<Map<String, dynamic>> _kategoriList = [];
  int? _selectedKategori;

  // Daftar bukti pelanggaran
  List<Map<String, dynamic>> _buktiOptions = [
    {
      'value': 'bukti_transfer',
      'label': 'Bukti transfer, cek, bukti penyetoran, dan rekening koran bank'
    },
    {'value': 'dokumen_rekaman', 'label': 'Dokumen dan/atau rekaman'},
    {'value': 'foto_dokumentasi', 'label': 'Foto dokumentasi'},
    {'value': 'surat_disposisi', 'label': 'Surat disposisi perintah'},
    {'value': 'identitas_sumber', 'label': 'Identitas sumber informasi'},
    {'value': 'lainnya', 'label': 'Lainnya'},
  ];
  List<String> _selectedBuktiPelanggaran = [];

  // Informasi pelapor
  String? _jabatan;
  String? _jenisKelamin;
  String? _umurPelapor;
  bool _agreement = false;

  @override
  void initState() {
    super.initState();
    _loadUserData();
    _fetchCategories();
  }

  Future<void> _fetchCategories() async {
    setState(() {
      _isLoadingCategories = true;
      _categoryError = null;
    });

    try {
      final Map<int, String> categories = await _apiService.getCategories();

      if (categories.isNotEmpty) {
        // Track category names we've already added
        Set<String> addedCategoryNames = {};
        List<Map<String, dynamic>> categoryList = [];

        categories.forEach((id, name) {
          // Only add this category if we haven't seen this name before
          if (!addedCategoryNames.contains(name.toLowerCase())) {
            categoryList.add({'id': id, 'nama': name});
            addedCategoryNames.add(name.toLowerCase());
          }
        });

        setState(() {
          _kategoriList = categoryList;
          _isLoadingCategories = false;
        });

        print('Categories loaded (deduplicated): ${_kategoriList.length}');
      } else {
        setState(() {
          _categoryError = 'Tidak ada kategori yang tersedia';
          _isLoadingCategories = false;
        });
      }
    } catch (e) {
      print('Error fetching categories: $e');
      setState(() {
        _categoryError = 'Gagal memuat kategori: $e';
        _isLoadingCategories = false;

        // Fallback to default categories if API fails
        _kategoriList = [
          {'id': 1, 'nama': 'Kehilangan Barang'},
          {'id': 2, 'nama': 'Kerusakan Fasilitas'},
          {'id': 5, 'nama': 'Kecelakaan'},
          {'id': 6, 'nama': 'Lainnya'}
        ];
      });
    }
  }

  // Filter kategori sesuai permintaan (tidak menampilkan kategori yang berawalan "Kekerasan")
  List<Map<String, dynamic>> get filteredKategori {
    return _kategoriList
        .where((kategori) =>
            !kategori['nama'].toString().toLowerCase().startsWith('kekerasan'))
        .toList();
  }

  // Fungsi untuk memuat data user dari SharedPreferences
  Future<void> _loadUserData() async {
    try {
      final prefs = await SharedPreferences.getInstance();

      setState(() {
        _namaPelaporController.text = prefs.getString('user_name') ?? '';
        _nipPelaporController.text = prefs.getString('user_nik') ?? '';
        _nomorTeleponController.text = prefs.getString('user_no_telp') ?? '';
      });
    } catch (e) {
      print('Error loading user data: $e');
    }
  }

  // Fungsi untuk membuka date picker
  Future<void> _selectDate(BuildContext context) async {
    final DateTime? picked = await showDatePicker(
      context: context,
      initialDate: DateTime.now(),
      firstDate: DateTime(2020),
      lastDate: DateTime(2100),
    );
    if (picked != null) {
      setState(() {
        _selectedDate = picked;
      });

      // Setelah memilih tanggal, buka time picker
      _selectTime(context);
    }
  }

  // Fungsi untuk membuka time picker
  Future<void> _selectTime(BuildContext context) async {
    final TimeOfDay? picked = await showTimePicker(
      context: context,
      initialTime: TimeOfDay.now(),
    );
    if (picked != null) {
      setState(() {
        _selectedTime = picked;
      });
    }
  }

  // Fungsi untuk memilih gambar dari galeri atau kamera
  Future<void> _pickImage(ImageSource source) async {
    final picker = ImagePicker();
    final pickedFile = await picker.pickImage(
      source: source,
      imageQuality: 80, // Kompresi kualitas gambar
    );

    if (pickedFile != null) {
      setState(() {
        _imageFiles.add(File(pickedFile.path));
      });
    }
  }

  // Fungsi untuk menghapus gambar
  void _removeImage(int index) {
    setState(() {
      _imageFiles.removeAt(index);
    });
  }

  // Fungsi untuk menambah terlapor
  void _addTerlapor() {
    setState(() {
      _terlaporList.add({
        'nama_lengkap': TextEditingController(),
        'email': TextEditingController(),
        'nomor_telepon': TextEditingController(),
        'jenis_kelamin': null,
        'umur_terlapor': null,
        'status_warga': null,
        'unit_kerja': null,
      });
    });
  }

  // Fungsi untuk menghapus terlapor
  void _removeTerlapor(int index) {
    if (_terlaporList.length > 1) {
      setState(() {
        _terlaporList.removeAt(index);
      });
    }
  }

  // Fungsi untuk menambah saksi
  void _addSaksi() {
    setState(() {
      _saksiList.add({
        'nama_lengkap': TextEditingController(),
        'email': TextEditingController(),
        'nomor_telepon': TextEditingController(),
      });
    });
  }

  // Fungsi untuk menghapus saksi
  void _removeSaksi(int index) {
    if (_saksiList.length > 1) {
      setState(() {
        _saksiList.removeAt(index);
      });
    }
  }

  // Validasi form
  bool _validateForm() {
    _errors = {};
    bool isValid = true;

    // Validasi field wajib
    if (_judulController.text.isEmpty) {
      _errors['judul'] = 'Judul tidak boleh kosong';
      isValid = false;
    }

    if (_selectedKategori == null) {
      _errors['category_id'] = 'Kategori harus dipilih';
      isValid = false;
    }

    if (_imageFiles.isEmpty) {
      _errors['image_path'] = 'Bukti laporan harus diunggah';
      isValid = false;
    }

    if (_deskripsiController.text.isEmpty) {
      _errors['deskripsi'] = 'Deskripsi tidak boleh kosong';
      isValid = false;
    }

    if (_selectedDate == null) {
      _errors['tanggal_kejadian'] = 'Tanggal kejadian harus dipilih';
      isValid = false;
    }

    if (_jabatan == null) {
      _errors['jabatan'] = 'Jabatan harus dipilih';
      isValid = false;
    }

    if (_jenisKelamin == null) {
      _errors['jenis_kelamin'] = 'Jenis kelamin harus dipilih';
      isValid = false;
    }

    if (_umurPelapor == null) {
      _errors['umur_pelapor'] = 'Rentang umur harus dipilih';
      isValid = false;
    }

    if (_selectedBuktiPelanggaran.isEmpty) {
      _errors['bukti_pelanggaran'] = 'Pilih minimal satu alat bukti';
      isValid = false;
    }

    if (!_agreement) {
      _errors['agreement'] = 'Anda harus menyetujui pernyataan';
      isValid = false;
    }

    // Validasi terlapor (jika ada data yang diisi)
    for (int i = 0; i < _terlaporList.length; i++) {
      final terlapor = _terlaporList[i];
      bool hasData = terlapor['nama_lengkap'].text.isNotEmpty ||
          terlapor['email'].text.isNotEmpty ||
          terlapor['nomor_telepon'].text.isNotEmpty;

      if (hasData) {
        if (terlapor['nama_lengkap'].text.isEmpty) {
          _errors['terlapor_$i'] = 'Nama terlapor harus diisi';
          isValid = false;
        }
      }
    }

    // Validasi saksi (jika ada data yang diisi)
    for (int i = 0; i < _saksiList.length; i++) {
      final saksi = _saksiList[i];
      bool hasData = saksi['nama_lengkap'].text.isNotEmpty ||
          saksi['email'].text.isNotEmpty ||
          saksi['nomor_telepon'].text.isNotEmpty;

      if (hasData) {
        if (saksi['nama_lengkap'].text.isEmpty) {
          _errors['saksi_$i'] = 'Nama saksi harus diisi';
          isValid = false;
        }
      }
    }

    setState(() {}); // Update UI dengan error
    return isValid;
  }

  // Fungsi untuk menyimpan data laporan ke API
  Future<void> _saveLaporan() async {
    // Validasi form
    if (!_validateForm()) {
      // Scroll ke error pertama
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Formulir berisi kesalahan. Silakan periksa kembali.'),
          backgroundColor: Colors.red,
        ),
      );
      return;
    }

    // Set loading state
    setState(() {
      _isLoading = true;
    });

    try {
      // Format tanggal dan waktu ke string
      String formattedDateTime = '';
      if (_selectedDate != null) {
        if (_selectedTime != null) {
          final datetime = DateTime(
            _selectedDate!.year,
            _selectedDate!.month,
            _selectedDate!.day,
            _selectedTime!.hour,
            _selectedTime!.minute,
          );
          formattedDateTime =
              DateFormat('yyyy-MM-dd HH:mm:ss').format(datetime);
        } else {
          formattedDateTime = DateFormat('yyyy-MM-dd').format(_selectedDate!);
        }
      }

      // Siapkan data terlapor
      final terlapor = _terlaporList
          .map((item) {
            // Filter data yang kosong
            if (item['nama_lengkap'].text.isEmpty) {
              return null;
            }

            return {
              'nama_lengkap': item['nama_lengkap'].text,
              'email': item['email'].text,
              'nomor_telepon': item['nomor_telepon'].text,
              'jenis_kelamin': item['jenis_kelamin'],
              'umur_terlapor': item['umur_terlapor'],
              'status_warga': item['status_warga'],
              'unit_kerja': item['unit_kerja'],
            };
          })
          .where((item) => item != null)
          .toList();

      // Siapkan data saksi
      final saksi = _saksiList
          .map((item) {
            // Filter data yang kosong
            if (item['nama_lengkap'].text.isEmpty) {
              return null;
            }

            return {
              'nama_lengkap': item['nama_lengkap'].text,
              'email': item['email'].text,
              'nomor_telepon': item['nomor_telepon'].text,
            };
          })
          .where((item) => item != null)
          .toList();

      // Get token for authentication
      final token = await _apiService.getAuthToken();

      // Create multipart request
      var request = http.MultipartRequest(
        'POST',
        Uri.parse('${_apiService.baseUrl}/laporan/add_laporan'),
      );

      // Add headers
      if (token != null && token.isNotEmpty) {
        request.headers['Authorization'] = 'Bearer $token';
      }
      request.headers['Accept'] = 'application/json';

      // Add text fields
      request.fields['judul'] = _judulController.text;
      request.fields['category_id'] = _selectedKategori.toString();
      request.fields['deskripsi'] = _deskripsiController.text;
      request.fields['tanggal_kejadian'] = formattedDateTime;
      request.fields['nama_pelapor'] = _namaPelaporController.text;
      request.fields['ni_pelapor'] = _nipPelaporController.text;
      request.fields['no_telp'] = _nomorTeleponController.text;
      request.fields['jabatan'] = _jabatan ?? '';
      request.fields['jenis_kelamin'] = _jenisKelamin ?? '';
      request.fields['umur_pelapor'] = _umurPelapor ?? '';

      if (_lampiranLinkController.text.isNotEmpty) {
        request.fields['lampiran_link'] = _lampiranLinkController.text;
      }

      // Add bukti pelanggaran
      for (int i = 0; i < _selectedBuktiPelanggaran.length; i++) {
        request.fields['bukti_pelanggaran[$i]'] = _selectedBuktiPelanggaran[i];
      }

      // Add terlapor
      for (int i = 0; i < terlapor.length; i++) {
        terlapor[i]?.forEach((key, value) {
          if (value != null && value.toString().isNotEmpty) {
            request.fields['terlapor[$i][$key]'] = value.toString();
          }
        });
      }

      // Add saksi
      for (int i = 0; i < saksi.length; i++) {
        saksi[i]?.forEach((key, value) {
          if (value != null && value.toString().isNotEmpty) {
            request.fields['saksi[$i][$key]'] = value.toString();
          }
        });
      }

      // Add image files
      for (int i = 0; i < _imageFiles.length; i++) {
        final file = _imageFiles[i];
        final stream = http.ByteStream(file.openRead());
        final length = await file.length();
        final fileName = file.path.split('/').last;

        final multipartFile = http.MultipartFile('image_path[]', stream, length,
            filename: fileName);
        request.files.add(multipartFile);
      }

      // Send the request
      final streamedResponse = await request.send();
      final response = await http.Response.fromStream(streamedResponse);

      print('API Response (${response.statusCode}): ${response.body}');

      // Reset loading state
      setState(() {
        _isLoading = false;
      });

      if (response.statusCode == 200 || response.statusCode == 201) {
        final jsonResponse = json.decode(response.body);

        if (jsonResponse['status'] == true) {
          // Tampilkan dialog sukses
          showDialog(
            context: context,
            builder: (context) => AlertDialog(
              title: Text('Berhasil!'),
              content: Text('Laporan berhasil disimpan dan akan diproses.'),
              actions: [
                TextButton(
                  onPressed: () {
                    Navigator.of(context).pop();
                    Navigator.pop(context); // Kembali ke halaman sebelumnya
                  },
                  child: Text('OK'),
                ),
              ],
            ),
          );
        } else {
          // Show error message from API
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content:
                  Text(jsonResponse['message'] ?? 'Gagal menyimpan laporan'),
              backgroundColor: Colors.red,
            ),
          );
        }
      } else {
        // Handle error response
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Gagal menyimpan laporan: ${response.statusCode}'),
            backgroundColor: Colors.red,
          ),
        );
      }
    } catch (e) {
      // Handle exception
      setState(() {
        _isLoading = false;
      });

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Error: $e'),
          backgroundColor: Colors.red,
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text('Tambah Laporan Kejadian'),
      ),
      body: _isLoading
          ? Center(child: CircularProgressIndicator())
          : Form(
              key: _formKey,
              child: SingleChildScrollView(
                padding: EdgeInsets.all(16.0),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // SECTION 1: DETAIL LAPORAN
                    _buildSectionHeader('Detail Laporan'),
                    const SizedBox(height: 16),

                    _buildLabel('Judul Laporan', isRequired: true),
                    TextFormField(
                      controller: _judulController,
                      decoration: InputDecoration(
                        hintText: 'Masukkan judul laporan',
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(8),
                        ),
                        errorText: _errors['judul'],
                      ),
                    ),
                    const SizedBox(height: 16),

                    _buildLabel('Kategori', isRequired: true),
                    _isLoadingCategories
                        ? Center(
                            child: CircularProgressIndicator(strokeWidth: 2))
                        : _categoryError != null
                            ? Text(_categoryError!,
                                style: TextStyle(color: Colors.red))
                            : DropdownButtonFormField<int>(
                                value: _selectedKategori,
                                decoration: InputDecoration(
                                  border: OutlineInputBorder(
                                    borderRadius: BorderRadius.circular(8),
                                  ),
                                  errorText: _errors['category_id'],
                                ),
                                items: filteredKategori.map((kategori) {
                                  return DropdownMenuItem<int>(
                                    value: kategori['id'],
                                    child: Text(kategori['nama']),
                                  );
                                }).toList(),
                                onChanged: (value) {
                                  setState(() {
                                    _selectedKategori = value;
                                  });
                                },
                                hint: Text('Pilih kategori'),
                              ),
                    const SizedBox(height: 16),

                    _buildLabel('Lampiran Link', isRequired: false),
                    TextFormField(
                      controller: _lampiranLinkController,
                      decoration: InputDecoration(
                        hintText: 'https://example.com',
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(8),
                        ),
                        errorText: _errors['lampiran_link'],
                      ),
                    ),
                    const SizedBox(height: 16),

                    _buildLabel('Deskripsi', isRequired: true),
                    TextFormField(
                      controller: _deskripsiController,
                      maxLines: 4,
                      decoration: InputDecoration(
                        hintText: 'Berikan deskripsi atau kronologi kejadian',
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(8),
                        ),
                        errorText: _errors['deskripsi'],
                      ),
                    ),
                    const SizedBox(height: 16),

                    _buildLabel('Tanggal & Waktu Kejadian', isRequired: true),
                    InkWell(
                      onTap: () => _selectDate(context),
                      child: InputDecorator(
                        decoration: InputDecoration(
                          border: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(8),
                          ),
                          errorText: _errors['tanggal_kejadian'],
                        ),
                        child: Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            Text(
                              _selectedDate == null
                                  ? 'Pilih Tanggal & Waktu'
                                  : (_selectedTime == null
                                      ? DateFormat('dd MMM yyyy')
                                          .format(_selectedDate!)
                                      : '${DateFormat('dd MMM yyyy').format(_selectedDate!)} ${_selectedTime!.format(context)}'),
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
                    const SizedBox(height: 16),

                    _buildLabel('Lampiran Foto', isRequired: true),

                    // Upload buttons
                    Row(
                      children: [
                        Expanded(
                          child: ElevatedButton.icon(
                            onPressed: () => _pickImage(ImageSource.camera),
                            icon: Icon(Icons.camera_alt),
                            label: Text('Kamera'),
                            style: ElevatedButton.styleFrom(
                              backgroundColor: Colors.blue,
                              padding: EdgeInsets.symmetric(vertical: 12),
                            ),
                          ),
                        ),
                        const SizedBox(width: 8),
                        Expanded(
                          child: ElevatedButton.icon(
                            onPressed: () => _pickImage(ImageSource.gallery),
                            icon: Icon(Icons.photo_library),
                            label: Text('Galeri'),
                            style: ElevatedButton.styleFrom(
                              backgroundColor: Colors.teal,
                              padding: EdgeInsets.symmetric(vertical: 12),
                            ),
                          ),
                        ),
                      ],
                    ),

                    if (_errors['image_path'] != null)
                      Padding(
                        padding: const EdgeInsets.only(top: 8.0),
                        child: Text(
                          _errors['image_path'],
                          style: TextStyle(color: Colors.red, fontSize: 12),
                        ),
                      ),

                    // Image previews
                    if (_imageFiles.isNotEmpty)
                      Container(
                        margin: EdgeInsets.only(top: 16),
                        height: 120,
                        child: ListView.builder(
                          scrollDirection: Axis.horizontal,
                          itemCount: _imageFiles.length,
                          itemBuilder: (context, index) {
                            return Stack(
                              children: [
                                Container(
                                  margin: EdgeInsets.only(right: 8),
                                  width: 120,
                                  decoration: BoxDecoration(
                                    border: Border.all(color: Colors.grey),
                                    borderRadius: BorderRadius.circular(8),
                                  ),
                                  child: ClipRRect(
                                    borderRadius: BorderRadius.circular(7),
                                    child: Image.file(
                                      _imageFiles[index],
                                      fit: BoxFit.cover,
                                    ),
                                  ),
                                ),
                                Positioned(
                                  right: 10,
                                  top: 2,
                                  child: InkWell(
                                    onTap: () => _removeImage(index),
                                    child: Container(
                                      padding: EdgeInsets.all(2),
                                      decoration: BoxDecoration(
                                        color: Colors.white,
                                        shape: BoxShape.circle,
                                        boxShadow: [
                                          BoxShadow(
                                            color: Colors.black26,
                                            blurRadius: 2,
                                          ),
                                        ],
                                      ),
                                      child: Icon(
                                        Icons.close,
                                        size: 18,
                                        color: Colors.red,
                                      ),
                                    ),
                                  ),
                                ),
                              ],
                            );
                          },
                        ),
                      ),
                    const SizedBox(height: 24),

                    // Bukti Pelanggaran section
                    _buildLabel('Bukti Pelanggaran', isRequired: true),
                    Container(
                      padding: EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        border: Border.all(
                            color: _errors['bukti_pelanggaran'] != null
                                ? Colors.red
                                : Colors.grey.shade400),
                        borderRadius: BorderRadius.circular(8),
                        color: Colors.grey.shade50,
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: _buktiOptions.map((option) {
                          return CheckboxListTile(
                            contentPadding: EdgeInsets.zero,
                            title: Text(
                              option['label'],
                              style: TextStyle(fontSize: 14),
                            ),
                            value: _selectedBuktiPelanggaran
                                .contains(option['value']),
                            onChanged: (bool? value) {
                              setState(() {
                                if (value == true) {
                                  _selectedBuktiPelanggaran
                                      .add(option['value']);
                                } else {
                                  _selectedBuktiPelanggaran
                                      .remove(option['value']);
                                }
                              });
                            },
                            controlAffinity: ListTileControlAffinity.leading,
                            dense: true,
                          );
                        }).toList(),
                      ),
                    ),
                    if (_errors['bukti_pelanggaran'] != null)
                      Padding(
                        padding: const EdgeInsets.only(left: 12, top: 8),
                        child: Text(
                          _errors['bukti_pelanggaran'],
                          style: TextStyle(color: Colors.red, fontSize: 12),
                        ),
                      ),
                    const SizedBox(height: 24),

                    // SECTION 2: INFORMASI PELAPOR
                    _buildSectionHeader('Informasi Pelapor'),
                    const SizedBox(height: 16),

                    _buildLabel('Nama Pelapor'),
                    TextFormField(
                      controller: _namaPelaporController,
                      readOnly:
                          true, // Data dari user session, tidak bisa diedit
                      decoration: InputDecoration(
                        border: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(8)),
                        filled: true,
                        fillColor: Colors.grey.shade200,
                      ),
                    ),
                    const SizedBox(height: 16),

                    _buildLabel('NIP Pelapor'),
                    TextFormField(
                      controller: _nipPelaporController,
                      readOnly:
                          true, // Data dari user session, tidak bisa diedit
                      decoration: InputDecoration(
                        border: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(8)),
                        filled: true,
                        fillColor: Colors.grey.shade200,
                      ),
                    ),
                    const SizedBox(height: 16),

                    _buildLabel('Nomor Telepon'),
                    TextFormField(
                      controller: _nomorTeleponController,
                      readOnly:
                          true, // Data dari user session, tidak bisa diedit
                      decoration: InputDecoration(
                        border: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(8)),
                        filled: true,
                        fillColor: Colors.grey.shade200,
                      ),
                    ),
                    const SizedBox(height: 16),

                    _buildLabel('Jabatan', isRequired: true),
                    DropdownButtonFormField<String>(
                      value: _jabatan,
                      decoration: InputDecoration(
                        border: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(8)),
                        errorText: _errors['jabatan'],
                      ),
                      items: [
                        DropdownMenuItem(value: 'Dosen', child: Text('Dosen')),
                        DropdownMenuItem(
                            value: 'Kaprodi', child: Text('Kaprodi')),
                        DropdownMenuItem(
                            value: 'Koordinator Mata Kuliah',
                            child: Text('Koordinator Mata Kuliah')),
                        DropdownMenuItem(
                            value: 'Lainnya', child: Text('Lainnya')),
                      ],
                      onChanged: (value) {
                        setState(() {
                          _jabatan = value;
                        });
                      },
                      hint: Text('Pilih Jabatan'),
                    ),
                    const SizedBox(height: 16),

                    // Jenis Kelamin Radio
                    _buildLabel('Jenis Kelamin', isRequired: true),
                    Container(
                      padding:
                          EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                      decoration: BoxDecoration(
                        border: Border.all(
                            color: _errors['jenis_kelamin'] != null
                                ? Colors.red
                                : Colors.grey.shade400),
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: Column(
                        children: [
                          RadioListTile<String>(
                            title: Text('Laki-laki'),
                            value: 'laki-laki',
                            groupValue: _jenisKelamin,
                            onChanged: (value) {
                              setState(() {
                                _jenisKelamin = value;
                              });
                            },
                            contentPadding: EdgeInsets.zero,
                            dense: true,
                          ),
                          RadioListTile<String>(
                            title: Text('Perempuan'),
                            value: 'perempuan',
                            groupValue: _jenisKelamin,
                            onChanged: (value) {
                              setState(() {
                                _jenisKelamin = value;
                              });
                            },
                            contentPadding: EdgeInsets.zero,
                            dense: true,
                          ),
                        ],
                      ),
                    ),
                    if (_errors['jenis_kelamin'] != null)
                      Padding(
                        padding: const EdgeInsets.only(left: 12, top: 8),
                        child: Text(
                          _errors['jenis_kelamin'],
                          style: TextStyle(color: Colors.red, fontSize: 12),
                        ),
                      ),
                    const SizedBox(height: 16),

                    // Rentang Umur Radio
                    _buildLabel('Rentang Umur', isRequired: true),
                    Container(
                      padding:
                          EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                      decoration: BoxDecoration(
                        border: Border.all(
                            color: _errors['umur_pelapor'] != null
                                ? Colors.red
                                : Colors.grey.shade400),
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: Column(
                        children: [
                          RadioListTile<String>(
                            title: Text('20 - 40 tahun'),
                            value: '20-40',
                            groupValue: _umurPelapor,
                            onChanged: (value) {
                              setState(() {
                                _umurPelapor = value;
                              });
                            },
                            contentPadding: EdgeInsets.zero,
                            dense: true,
                          ),
                          RadioListTile<String>(
                            title: Text('41 - 60 tahun'),
                            value: '41-60',
                            groupValue: _umurPelapor,
                            onChanged: (value) {
                              setState(() {
                                _umurPelapor = value;
                              });
                            },
                            contentPadding: EdgeInsets.zero,
                            dense: true,
                          ),
                          RadioListTile<String>(
                            title: Text('Lebih dari 60 tahun'),
                            value: '60<',
                            groupValue: _umurPelapor,
                            onChanged: (value) {
                              setState(() {
                                _umurPelapor = value;
                              });
                            },
                            contentPadding: EdgeInsets.zero,
                            dense: true,
                          ),
                        ],
                      ),
                    ),
                    if (_errors['umur_pelapor'] != null)
                      Padding(
                        padding: const EdgeInsets.only(left: 12, top: 8),
                        child: Text(
                          _errors['umur_pelapor'],
                          style: TextStyle(color: Colors.red, fontSize: 12),
                        ),
                      ),
                    const SizedBox(height: 24),

                    // SECTION 3: IDENTITAS TERLAPOR
                    _buildSectionHeader('Identitas Terlapor/Terduga'),
                    Padding(
                      padding: const EdgeInsets.symmetric(vertical: 8.0),
                      child: Text(
                        'Opsional: Anda dapat mengosongkan semua field terlapor jika tidak ingin mengisikan.',
                        style: TextStyle(
                            color: Colors.grey.shade700, fontSize: 13),
                      ),
                    ),

                    // List of terlapor
                    ...List.generate(_terlaporList.length, (index) {
                      return _buildTerlaporItem(index);
                    }),

                    // Button to add more terlapor
                    Padding(
                      padding: const EdgeInsets.symmetric(vertical: 8.0),
                      child: OutlinedButton.icon(
                        onPressed: _addTerlapor,
                        icon: Icon(Icons.add),
                        label: Text('Tambah Terlapor'),
                        style: OutlinedButton.styleFrom(
                          foregroundColor: Colors.blue,
                          side: BorderSide(color: Colors.blue),
                          padding: EdgeInsets.symmetric(
                              vertical: 12, horizontal: 16),
                        ),
                      ),
                    ),
                    const SizedBox(height: 24),

                    // SECTION 4: SAKSI
                    _buildSectionHeader('Saksi'),
                    Padding(
                      padding: const EdgeInsets.symmetric(vertical: 8.0),
                      child: Text(
                        'Opsional: Anda dapat mengosongkan semua field saksi jika tidak ingin mengisikan.',
                        style: TextStyle(
                            color: Colors.grey.shade700, fontSize: 13),
                      ),
                    ),

                    // List of saksi
                    ...List.generate(_saksiList.length, (index) {
                      return _buildSaksiItem(index);
                    }),

                    // Button to add more saksi
                    Padding(
                      padding: const EdgeInsets.symmetric(vertical: 8.0),
                      child: OutlinedButton.icon(
                        onPressed: _addSaksi,
                        icon: Icon(Icons.add),
                        label: Text('Tambah Saksi'),
                        style: OutlinedButton.styleFrom(
                          foregroundColor: Colors.blue,
                          side: BorderSide(color: Colors.blue),
                          padding: EdgeInsets.symmetric(
                              vertical: 12, horizontal: 16),
                        ),
                      ),
                    ),
                    const SizedBox(height: 24),

                    // SECTION 5: PERNYATAAN
                    _buildSectionHeader('Pernyataan'),
                    Container(
                      margin: EdgeInsets.symmetric(vertical: 16),
                      padding: EdgeInsets.all(16),
                      decoration: BoxDecoration(
                        color: Colors.grey.shade50,
                        border: Border.all(color: Colors.grey.shade300),
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'Dengan ini saya menyatakan bahwa:',
                            style: TextStyle(fontWeight: FontWeight.bold),
                          ),
                          SizedBox(height: 12),
                          _buildListItem(
                              'Segala informasi yang saya berikan dalam laporan ini adalah benar dan dapat dipertanggungjawabkan.'),
                          _buildListItem(
                              'Saya bersedia memberikan keterangan lebih lanjut apabila diperlukan untuk proses penanganan laporan.'),
                          _buildListItem(
                              'Saya memahami bahwa memberikan laporan palsu dapat dikenakan sanksi sesuai dengan peraturan yang berlaku.'),
                          SizedBox(height: 16),
                          Row(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Checkbox(
                                value: _agreement,
                                onChanged: (value) {
                                  setState(() {
                                    _agreement = value ?? false;
                                  });
                                },
                              ),
                              Expanded(
                                child: Padding(
                                  padding: const EdgeInsets.only(top: 10),
                                  child: Text(
                                    'Saya menyetujui pernyataan di atas',
                                    style: TextStyle(
                                      fontSize: 14,
                                    ),
                                  ),
                                ),
                              ),
                            ],
                          ),
                          if (_errors['agreement'] != null)
                            Padding(
                              padding: const EdgeInsets.only(left: 32, top: 4),
                              child: Text(
                                _errors['agreement'],
                                style:
                                    TextStyle(color: Colors.red, fontSize: 12),
                              ),
                            ),
                        ],
                      ),
                    ),

                    const SizedBox(height: 32),

                    // SUBMIT BUTTON
                    SizedBox(
                      width: double.infinity,
                      child: ElevatedButton(
                        onPressed: _agreement ? _saveLaporan : null,
                        style: ElevatedButton.styleFrom(
                          foregroundColor: Colors.white,
                          backgroundColor: Colors.blue,
                          padding: EdgeInsets.symmetric(vertical: 16),
                          disabledForegroundColor:
                              Colors.white.withOpacity(0.38),
                          disabledBackgroundColor:
                              Colors.blue.withOpacity(0.12),
                        ),
                        child: Text(
                          'Kirim Laporan',
                          style: TextStyle(fontSize: 16),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
    );
  }

  // Helper Widgets
  Widget _buildSectionHeader(String title) {
    return Container(
      width: double.infinity,
      padding: EdgeInsets.symmetric(vertical: 8),
      decoration: BoxDecoration(
        border: Border(bottom: BorderSide(color: Colors.grey.shade300)),
      ),
      child: Text(
        title,
        style: TextStyle(
          fontSize: 18,
          fontWeight: FontWeight.bold,
          color: Colors.blue.shade800,
        ),
      ),
    );
  }

  Widget _buildLabel(String text, {bool isRequired = false}) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8.0),
      child: RichText(
        text: TextSpan(
          style: TextStyle(fontSize: 14, color: Colors.black87),
          children: [
            TextSpan(
              text: text,
              style: TextStyle(fontWeight: FontWeight.w500),
            ),
            if (isRequired)
              TextSpan(
                text: ' *',
                style: TextStyle(
                  color: Colors.red,
                  fontWeight: FontWeight.bold,
                ),
              ),
          ],
        ),
      ),
    );
  }

  Widget _buildListItem(String text) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8.0),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('• ', style: TextStyle(fontWeight: FontWeight.bold)),
          Expanded(
            child: Text(text),
          ),
        ],
      ),
    );
  }

  Widget _buildTerlaporItem(int index) {
    final item = _terlaporList[index];

    return Container(
      margin: EdgeInsets.only(bottom: 16),
      padding: EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.grey.shade50,
        border: Border.all(color: Colors.grey.shade300),
        borderRadius: BorderRadius.circular(8),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                'Terlapor #${index + 1}',
                style: TextStyle(
                  fontWeight: FontWeight.bold,
                ),
              ),
              if (_terlaporList.length > 1)
                IconButton(
                  icon: Icon(Icons.delete, color: Colors.red),
                  onPressed: () => _removeTerlapor(index),
                  tooltip: 'Hapus terlapor',
                  iconSize: 20,
                  padding: EdgeInsets.all(4),
                  constraints: BoxConstraints(),
                ),
            ],
          ),
          SizedBox(height: 8),

          if (_errors['terlapor_$index'] != null)
            Container(
              padding: EdgeInsets.all(8),
              margin: EdgeInsets.only(bottom: 8),
              decoration: BoxDecoration(
                color: Colors.red.shade50,
                borderRadius: BorderRadius.circular(4),
                border: Border.all(color: Colors.red.shade200),
              ),
              child: Text(
                _errors['terlapor_$index'],
                style: TextStyle(color: Colors.red, fontSize: 12),
              ),
            ),

          // Terlapor form fields
          _buildLabel('Nama Lengkap'),
          TextFormField(
            controller: item['nama_lengkap'],
            decoration: InputDecoration(
              border:
                  OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
              hintText: 'Nama lengkap terlapor',
            ),
          ),
          SizedBox(height: 12),

          _buildLabel('Email'),
          TextFormField(
            controller: item['email'],
            keyboardType: TextInputType.emailAddress,
            decoration: InputDecoration(
              border:
                  OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
              hintText: 'Email terlapor',
            ),
          ),
          SizedBox(height: 12),

          _buildLabel('Nomor Telepon'),
          TextFormField(
            controller: item['nomor_telepon'],
            keyboardType: TextInputType.phone,
            decoration: InputDecoration(
              border:
                  OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
              hintText: 'Nomor telepon terlapor',
            ),
          ),
          SizedBox(height: 12),

          // Two columns for the rest of the form
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Left column
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // Two columns in a row for gender and age
                    Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        // Left column
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              _buildLabel('Jenis Kelamin'),
                              Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  RadioListTile<String>(
                                    title: Text('Laki-laki'),
                                    value: 'laki-laki',
                                    groupValue: item['jenis_kelamin'],
                                    onChanged: (value) {
                                      setState(() {
                                        item['jenis_kelamin'] = value;
                                      });
                                    },
                                    contentPadding:
                                        EdgeInsets.symmetric(horizontal: 0),
                                  ),
                                  RadioListTile<String>(
                                    title: Text('Perempuan'),
                                    value: 'perempuan',
                                    groupValue: item['jenis_kelamin'],
                                    onChanged: (value) {
                                      setState(() {
                                        item['jenis_kelamin'] = value;
                                      });
                                    },
                                    contentPadding:
                                        EdgeInsets.symmetric(horizontal: 0),
                                  ),
                                ],
                              ),
                              SizedBox(height: 12),
                              _buildLabel('Status Warga UNS'),
                              DropdownButtonFormField<String>(
                                value: item['status_warga'],
                                decoration: InputDecoration(
                                  border: OutlineInputBorder(
                                      borderRadius: BorderRadius.circular(8)),
                                ),
                                items: [
                                  DropdownMenuItem(
                                      value: 'dosen', child: Text('Dosen')),
                                  DropdownMenuItem(
                                      value: 'mahasiswa',
                                      child: Text('Mahasiswa')),
                                  DropdownMenuItem(
                                      value: 'staff', child: Text('Staff')),
                                  DropdownMenuItem(
                                      value: 'lainnya', child: Text('Lainnya')),
                                ],
                                onChanged: (value) {
                                  setState(() {
                                    item['status_warga'] = value;
                                  });
                                },
                                hint: Text('Pilih status'),
                              ),
                            ],
                          ),
                        ),
                        SizedBox(width: 16),

                        // Right column
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              _buildLabel('Rentang Umur'),
                              Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  RadioListTile<String>(
                                    title: Text('Kurang dari 20 tahun'),
                                    value: '<20',
                                    groupValue: item['umur_terlapor'],
                                    onChanged: (value) {
                                      setState(() {
                                        item['umur_terlapor'] = value;
                                      });
                                    },
                                    contentPadding:
                                        EdgeInsets.symmetric(horizontal: 0),
                                  ),
                                  RadioListTile<String>(
                                    title: Text('20 - 40 tahun'),
                                    value: '20-40',
                                    groupValue: item['umur_terlapor'],
                                    onChanged: (value) {
                                      setState(() {
                                        item['umur_terlapor'] = value;
                                      });
                                    },
                                    contentPadding:
                                        EdgeInsets.symmetric(horizontal: 0),
                                  ),
                                  RadioListTile<String>(
                                    title: Text('Lebih dari 40 tahun'),
                                    value: '40<',
                                    groupValue: item['umur_terlapor'],
                                    onChanged: (value) {
                                      setState(() {
                                        item['umur_terlapor'] = value;
                                      });
                                    },
                                    contentPadding:
                                        EdgeInsets.symmetric(horizontal: 0),
                                  ),
                                ],
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),

                    // Unit Kerja placed below both columns
                    SizedBox(height: 12),
                    _buildLabel('Unit Kerja'),
                    DropdownButtonFormField<String>(
                      value: item['unit_kerja'],
                      decoration: InputDecoration(
                        border: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(8)),
                      ),
                      items: [
                        DropdownMenuItem(
                            value: 'Fakultas Teknik',
                            child: Text('Fakultas Teknik')),
                        DropdownMenuItem(
                            value: 'Fakultas MIPA',
                            child: Text('Fakultas MIPA')),
                        DropdownMenuItem(
                            value: 'Fakultas Ekonomi',
                            child: Text('Fakultas Ekonomi')),
                        DropdownMenuItem(
                            value: 'Fakultas Hukum',
                            child: Text('Fakultas Hukum')),
                        DropdownMenuItem(
                            value: 'Fakultas Kedokteran',
                            child: Text('Fakultas Kedokteran')),
                      ],
                      onChanged: (value) {
                        setState(() {
                          item['unit_kerja'] = value;
                        });
                      },
                      hint: Text('Pilih unit kerja'),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildSaksiItem(int index) {
    final item = _saksiList[index];

    return Container(
      margin: EdgeInsets.only(bottom: 16),
      padding: EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.grey.shade50,
        border: Border.all(color: Colors.grey.shade300),
        borderRadius: BorderRadius.circular(8),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                'Saksi #${index + 1}',
                style: TextStyle(
                  fontWeight: FontWeight.bold,
                ),
              ),
              if (_saksiList.length > 1)
                IconButton(
                  icon: Icon(Icons.delete, color: Colors.red),
                  onPressed: () => _removeSaksi(index),
                  tooltip: 'Hapus saksi',
                  iconSize: 20,
                  padding: EdgeInsets.all(4),
                  constraints: BoxConstraints(),
                ),
            ],
          ),
          SizedBox(height: 8),

          if (_errors['saksi_$index'] != null)
            Container(
              padding: EdgeInsets.all(8),
              margin: EdgeInsets.only(bottom: 8),
              decoration: BoxDecoration(
                color: Colors.red.shade50,
                borderRadius: BorderRadius.circular(4),
                border: Border.all(color: Colors.red.shade200),
              ),
              child: Text(
                _errors['saksi_$index'],
                style: TextStyle(color: Colors.red, fontSize: 12),
              ),
            ),

          // Form fields in a vertical layout
          _buildLabel('Nama Lengkap'),
          TextFormField(
            controller: item['nama_lengkap'],
            decoration: InputDecoration(
              border:
                  OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
              hintText: 'Nama lengkap saksi',
            ),
          ),
          SizedBox(height: 12),

          _buildLabel('Email'),
          TextFormField(
            controller: item['email'],
            keyboardType: TextInputType.emailAddress,
            decoration: InputDecoration(
              border:
                  OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
              hintText: 'Email saksi',
            ),
          ),
          SizedBox(height: 12),

          _buildLabel('Nomor Telepon'),
          TextFormField(
            controller: item['nomor_telepon'],
            keyboardType: TextInputType.phone,
            decoration: InputDecoration(
              border:
                  OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
              hintText: 'Nomor telepon saksi',
            ),
          ),
        ],
      ),
    );
  }

  @override
  void dispose() {
    // Dispose all controllers
    _judulController.dispose();
    _deskripsiController.dispose();
    _nomorTeleponController.dispose();
    _namaPelaporController.dispose();
    _nipPelaporController.dispose();
    _lampiranLinkController.dispose();

    // Dispose terlapor controllers
    for (var terlapor in _terlaporList) {
      terlapor['nama_lengkap'].dispose();
      terlapor['email'].dispose();
      terlapor['nomor_telepon'].dispose();
    }

    // Dispose saksi controllers
    for (var saksi in _saksiList) {
      saksi['nama_lengkap'].dispose();
      saksi['email'].dispose();
      saksi['nomor_telepon'].dispose();
    }

    super.dispose();
  }
}
