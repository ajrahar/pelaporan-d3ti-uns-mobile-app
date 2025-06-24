import 'dart:io';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:intl/intl.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';
import 'package:shared_preferences/shared_preferences.dart';

class AddLaporPKMendesakDosen extends StatefulWidget {
  const AddLaporPKMendesakDosen({Key? key}) : super(key: key);

  @override
  State<AddLaporPKMendesakDosen> createState() =>
      _AddLaporPKMendesakDosenState();
}

class _AddLaporPKMendesakDosenState extends State<AddLaporPKMendesakDosen> {
  // Form key for validation
  final _formKey = GlobalKey<FormState>();

  // Form data
  final TextEditingController _judulController = TextEditingController();
  final TextEditingController _tanggalKejadianController =
      TextEditingController();
  final TextEditingController _lampiranLinkController = TextEditingController();

  // Category data
  int? _selectedCategoryId;
  List<Map<String, dynamic>> _categories = [];

  // Image data
  final ImagePicker _picker = ImagePicker();
  List<XFile> _selectedImages = [];

  // Agreement checkbox
  bool _isAgreementChecked = false;

  // Loading state
  bool _isLoading = false;

  // Error mapping
  Map<String, List<String>> _errors = {};

  @override
  void initState() {
    super.initState();
    _fetchCategories();
    _loadUserData();
  }

  Future<void> _loadUserData() async {
    final prefs = await SharedPreferences.getInstance();
    // You would implement your own decryption mechanism here
  }

  Future<void> _fetchCategories() async {
    setState(() => _isLoading = true);

    try {
      final response =
          await http.get(Uri.parse('http://pelaporan-d3ti.my.id/api/category'));

      if (response.statusCode == 200) {
        final List<dynamic> data = json.decode(response.body);
        setState(() {
          _categories = List<Map<String, dynamic>>.from(data);

          // Find the "Darurat dan Mendesak" category
          final mendesakCategory = _categories.firstWhere(
              (cat) => cat['nama'] == "Darurat dan Mendesak",
              orElse: () => _categories.isNotEmpty
                  ? _categories.first
                  : {'category_id': 21, 'nama': "Darurat dan Mendesak"});

          _selectedCategoryId = mendesakCategory['category_id'];
        });
      } else {
        _setFallbackCategory();
      }
    } catch (e) {
      _setFallbackCategory();
    } finally {
      setState(() => _isLoading = false);
    }
  }

  void _setFallbackCategory() {
    setState(() {
      _categories = [
        {'category_id': 21, 'nama': "Darurat dan Mendesak"}
      ];
      _selectedCategoryId = 21;
    });
  }

  Future<void> _pickImages() async {
    try {
      final List<XFile> images = await _picker.pickMultiImage();
      if (images.isNotEmpty) {
        setState(() {
          _selectedImages.addAll(images);
        });
      }
    } catch (e) {
      ScaffoldMessenger.of(context)
          .showSnackBar(SnackBar(content: Text('Error picking images: $e')));
    }
  }

  void _removeImage(int index) {
    setState(() {
      _selectedImages.removeAt(index);
    });
  }

  Future<void> _selectDateTime() async {
    final DateTime? pickedDate = await showDatePicker(
      context: context,
      initialDate: DateTime.now(),
      firstDate: DateTime(2020),
      lastDate: DateTime.now(),
    );

    if (pickedDate != null) {
      final TimeOfDay? pickedTime = await showTimePicker(
        context: context,
        initialTime: TimeOfDay.now(),
      );

      if (pickedTime != null) {
        final DateTime combinedDateTime = DateTime(
          pickedDate.year,
          pickedDate.month,
          pickedDate.day,
          pickedTime.hour,
          pickedTime.minute,
        );

        setState(() {
          _tanggalKejadianController.text =
              DateFormat('yyyy-MM-dd HH:mm').format(combinedDateTime);
        });
      }
    }
  }

  bool _validateForm() {
    _errors.clear();

    if (_judulController.text.isEmpty) {
      _errors['judul'] = ['Judul laporan harus diisi'];
    }

    if (_tanggalKejadianController.text.isEmpty) {
      _errors['tanggal_kejadian'] = ['Tanggal dan waktu kejadian harus diisi'];
    }

    if (_selectedImages.isEmpty) {
      _errors['image_path'] = ['Lampiran foto harus diisi'];
    }

    if (_lampiranLinkController.text.isEmpty) {
      _errors['lampiran_link'] = ['Lampiran link harus diisi'];
    }

    if (!_isAgreementChecked) {
      _errors['agreement'] = [
        'Anda harus menyetujui pernyataan untuk melanjutkan'
      ];
    }

    setState(() {});
    return _errors.isEmpty;
  }

  Future<void> _submitForm() async {
    if (!_validateForm()) return;

    setState(() => _isLoading = true);

    try {
      // Create multipart request
      final request = http.MultipartRequest(
        'POST',
        Uri.parse('http://pelaporan-d3ti.my.id/api/laporan/add_laporan'),
      );

      // Get token from shared preferences
      final prefs = await SharedPreferences.getInstance();
      final String? token = prefs.getString('auth_token');

      if (token != null) {
        request.headers['Authorization'] = 'Bearer $token';
      }

      // Add text fields
      request.fields['judul'] = _judulController.text;
      request.fields['category_id'] = _selectedCategoryId.toString();
      request.fields['deskripsi'] = '-';
      request.fields['tanggal_kejadian'] = _tanggalKejadianController.text;
      request.fields['profesi'] = 'Dosen';
      request.fields['jenis_kelamin'] = 'laki-laki';
      request.fields['umur_pelapor'] = '20-40';
      request.fields['lampiran_link'] = _lampiranLinkController.text;

      // Add terlapor data
      request.fields['terlapor[0][nama_lengkap]'] = 'Nama Terlapor';
      request.fields['terlapor[0][email]'] = 'terlapor@example.com';
      request.fields['terlapor[0][nomor_telepon]'] = '081234567890';
      request.fields['terlapor[0][status_warga]'] = 'mahasiswa';
      request.fields['terlapor[0][unit_kerja]'] = 'Fakultas Teknik';
      request.fields['terlapor[0][jenis_kelamin]'] = 'laki-laki';
      request.fields['terlapor[0][umur_terlapor]'] = '20-40';

      // Add saksi data
      request.fields['saksi[0][nama_lengkap]'] = 'Nama Saksi';
      request.fields['saksi[0][email]'] = 'saksi@example.com';
      request.fields['saksi[0][nomor_telepon]'] = '089876543210';

      // Add bukti_pelanggaran
      request.fields['bukti_pelanggaran[0]'] = 'foto_dokumentasi';

      // Add agreement
      request.fields['agreement'] = '1';

      // Add images
      for (var i = 0; i < _selectedImages.length; i++) {
        final file = await http.MultipartFile.fromPath(
          'image_path[]',
          _selectedImages[i].path,
        );
        request.files.add(file);
      }

      // Send the request
      final response = await request.send();

      // Check response
      if (response.statusCode >= 200 && response.statusCode < 300) {
        // Success
        _showSuccessDialog();
      } else {
        // Error
        final responseData = await response.stream.bytesToString();
        final errorData = json.decode(responseData);

        setState(() {
          if (errorData is Map) {
            _errors = Map<String, List<String>>.from(errorData
                .map((key, value) => MapEntry(key, List<String>.from(value))));
          }
        });

        _showErrorDialog('Terjadi kesalahan saat mengirim laporan');
      }
    } catch (e) {
      _showErrorDialog('Terjadi kesalahan: $e');
    } finally {
      setState(() => _isLoading = false);
    }
  }

  void _showSuccessDialog() {
    showDialog(
      context: context,
      builder: (BuildContext context) {
        return AlertDialog(
          title: const Text('Berhasil!'),
          content: const Text('Laporan kejadian mendesak berhasil dikirim'),
          actions: [
            TextButton(
              onPressed: () {
                Navigator.of(context).pop();
                Navigator.of(context).pop(); // Navigate back
              },
              child: const Text('OK'),
            ),
          ],
        );
      },
    );
  }

  void _showErrorDialog(String message) {
    showDialog(
      context: context,
      builder: (BuildContext context) {
        return AlertDialog(
          title: const Text('Error!'),
          content: Text(message),
          actions: [
            TextButton(
              onPressed: () {
                Navigator.of(context).pop();
              },
              child: const Text('OK'),
            ),
          ],
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Tambah Laporan Kejadian Mendesak'),
        centerTitle: true,
      ),
      body: _isLoading && _categories.isEmpty
          ? const Center(child: CircularProgressIndicator())
          : SingleChildScrollView(
              padding: const EdgeInsets.all(16.0),
              child: Form(
                key: _formKey,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // Form header
                    const Center(
                      child: Text(
                        'Tambah Laporan Kejadian Mendesak',
                        style: TextStyle(
                          fontSize: 20,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ),
                    const SizedBox(height: 24),

                    // Section 1: Detail Laporan
                    const Text(
                      'Detail Laporan',
                      style: TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    const SizedBox(height: 16),

                    // Judul Laporan
                    TextFormField(
                      controller: _judulController,
                      decoration: InputDecoration(
                        labelText: 'Judul Laporan *',
                        border: const OutlineInputBorder(),
                        errorText: _errors['judul']?.first,
                      ),
                    ),
                    const SizedBox(height: 16),

                    // Lampiran Foto
                    Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text('Lampiran Foto *'),
                        const SizedBox(height: 8),
                        ElevatedButton.icon(
                          onPressed: _pickImages,
                          icon: const Icon(Icons.photo_library),
                          label: const Text('Pilih Foto'),
                        ),
                        if (_errors['image_path'] != null)
                          Text(
                            _errors['image_path']!.first,
                            style: const TextStyle(
                                color: Colors.red, fontSize: 12),
                          ),
                        const SizedBox(height: 8),
                        const Text(
                          'Anda dapat memilih beberapa foto sekaligus',
                          style: TextStyle(color: Colors.grey, fontSize: 12),
                        ),
                        const SizedBox(height: 8),
                        _selectedImages.isNotEmpty
                            ? SizedBox(
                                height: 120,
                                child: ListView.builder(
                                  scrollDirection: Axis.horizontal,
                                  itemCount: _selectedImages.length,
                                  itemBuilder: (context, index) {
                                    return Stack(
                                      children: [
                                        Container(
                                          margin:
                                              const EdgeInsets.only(right: 8),
                                          width: 100,
                                          height: 100,
                                          decoration: BoxDecoration(
                                            border:
                                                Border.all(color: Colors.grey),
                                            borderRadius:
                                                BorderRadius.circular(8),
                                          ),
                                          child: ClipRRect(
                                            borderRadius:
                                                BorderRadius.circular(8),
                                            child: Image.file(
                                              File(_selectedImages[index].path),
                                              fit: BoxFit.cover,
                                            ),
                                          ),
                                        ),
                                        Positioned(
                                          top: 0,
                                          right: 8,
                                          child: IconButton(
                                            icon: const Icon(Icons.close,
                                                color: Colors.red),
                                            onPressed: () =>
                                                _removeImage(index),
                                          ),
                                        ),
                                      ],
                                    );
                                  },
                                ),
                              )
                            : Container(),
                      ],
                    ),
                    const SizedBox(height: 16),

                    // Kategori
                    DropdownButtonFormField<int>(
                      value: _selectedCategoryId,
                      decoration: const InputDecoration(
                        labelText: 'Kategori *',
                        border: OutlineInputBorder(),
                        enabled: false,
                      ),
                      items: _categories.map((category) {
                        return DropdownMenuItem<int>(
                          value: category['category_id'],
                          child: Text(category['nama']),
                        );
                      }).toList(),
                      onChanged: null, // Disabled
                    ),
                    const SizedBox(height: 4),
                    const Text(
                      'Kategori tidak dapat diubah',
                      style: TextStyle(color: Colors.grey, fontSize: 12),
                    ),
                    const SizedBox(height: 16),

                    // Tanggal & Waktu Kejadian
                    TextFormField(
                      controller: _tanggalKejadianController,
                      readOnly: true,
                      decoration: InputDecoration(
                        labelText: 'Tanggal & Waktu Kejadian *',
                        border: const OutlineInputBorder(),
                        suffixIcon: const Icon(Icons.calendar_today),
                        errorText: _errors['tanggal_kejadian']?.first,
                      ),
                      onTap: _selectDateTime,
                    ),
                    const SizedBox(height: 16),

                    // Lampiran Link
                    TextFormField(
                      controller: _lampiranLinkController,
                      decoration: InputDecoration(
                        labelText: 'Lampiran Link *',
                        hintText: 'https://www.example.com',
                        border: const OutlineInputBorder(),
                        errorText: _errors['lampiran_link']?.first,
                      ),
                    ),
                    const SizedBox(height: 4),
                    const Text(
                      'Masukkan URL yang valid, contoh: https://www.example.com',
                      style: TextStyle(color: Colors.grey, fontSize: 12),
                    ),
                    const SizedBox(height: 24),

                    // Pernyataan
                    const Text(
                      'Pernyataan',
                      style: TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    const SizedBox(height: 16),
                    Container(
                      padding: const EdgeInsets.all(16),
                      decoration: BoxDecoration(
                        border: Border.all(color: Colors.grey),
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Text('Dengan ini saya menyatakan bahwa:'),
                          const SizedBox(height: 8),
                          const Text(
                              '1. Segala informasi yang saya berikan dalam laporan ini adalah benar dan dapat dipertanggungjawabkan.'),
                          const Text(
                              '2. Saya bersedia memberikan keterangan lebih lanjut apabila diperlukan untuk proses penanganan laporan.'),
                          const Text(
                              '3. Saya memahami bahwa memberikan laporan palsu dapat dikenakan sanksi sesuai dengan peraturan yang berlaku.'),
                          const SizedBox(height: 16),
                          Row(
                            children: [
                              Checkbox(
                                value: _isAgreementChecked,
                                onChanged: (value) {
                                  setState(() {
                                    _isAgreementChecked = value!;
                                  });
                                },
                              ),
                              const Expanded(
                                child: Text(
                                    'Saya menyetujui pernyataan di atas *'),
                              ),
                            ],
                          ),
                          if (_errors['agreement'] != null)
                            Text(
                              _errors['agreement']!.first,
                              style: const TextStyle(
                                  color: Colors.red, fontSize: 12),
                            ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 24),

                    // Form Actions
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        ElevatedButton(
                          onPressed: () => Navigator.of(context).pop(),
                          style: ElevatedButton.styleFrom(
                            backgroundColor: Colors.grey,
                          ),
                          child: const Text('Kembali'),
                        ),
                        ElevatedButton(
                          onPressed: _isLoading || !_isAgreementChecked
                              ? null
                              : _submitForm,
                          child: _isLoading
                              ? const SizedBox(
                                  width: 20,
                                  height: 20,
                                  child: CircularProgressIndicator(
                                    strokeWidth: 2,
                                    color: Colors.white,
                                  ),
                                )
                              : const Text('Kirim Laporan'),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ),
    );
  }

  @override
  void dispose() {
    _judulController.dispose();
    _tanggalKejadianController.dispose();
    _lampiranLinkController.dispose();
    super.dispose();
  }
}
