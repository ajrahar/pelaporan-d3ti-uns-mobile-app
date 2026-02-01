import 'dart:convert';

class Laporan {
  final int? id;
  final String? judul;
  final String? deskripsi;
  final String? deskripsiKejadian;
  final String? lokasi;
  final String? tanggalKejadian;
  String? status;
  final String? namaPelapor;
  final String? niPelapor;
  final String? nomorTelepon;
  final String? teleponPelapor;
  final String? email;
  final String? emailPelapor;
  final String? nomorLaporan;
  final int? categoryId;
  final String? jenisKejadian;
  final dynamic imagePath; // Untuk menangani kemungkinan format yang berbeda
  final String? fotoKejadian;
  final DateTime? createdAt;
  final DateTime? updatedAt;
  dynamic tanggapan;
  final String? profesi;
  final String? jenisKelamin;
  final String? umurPelapor;
  final List<String>? buktiPelanggaran;
  final List<Map<String, dynamic>>? terlapor;
  final List<Map<String, dynamic>>? saksi;
  final String? lampiranLink;
  final int? userId;

  Laporan({
    required this.id,
    this.judul,
    this.deskripsi,
    this.deskripsiKejadian,
    this.lokasi,
    this.tanggalKejadian,
    this.status,
    this.namaPelapor,
    this.niPelapor,
    this.nomorTelepon,
    this.teleponPelapor,
    this.email,
    this.emailPelapor,
    this.nomorLaporan,
    this.categoryId,
    this.jenisKejadian,
    this.imagePath,
    this.fotoKejadian,
    this.createdAt,
    this.updatedAt,
    this.tanggapan,
    this.profesi,
    this.jenisKelamin,
    this.umurPelapor,
    this.buktiPelanggaran,
    this.terlapor,
    this.saksi,
    this.lampiranLink,
    this.userId,
  });

  factory Laporan.fromJson(Map<String, dynamic> json) {
    // Penanganan laporan_id yang bisa integer atau string
    int? laporanId;
    if (json['laporan_id'] != null) {
      laporanId = json['laporan_id'] is int
          ? json['laporan_id']
          : int.tryParse(json['laporan_id'].toString());
    } else if (json['id'] != null) {
      laporanId =
          json['id'] is int ? json['id'] : int.tryParse(json['id'].toString());
    }

    // Penanganan category_id yang bisa integer atau string
    int? catId;
    if (json['category_id'] != null) {
      catId = json['category_id'] is int
          ? json['category_id']
          : int.tryParse(json['category_id'].toString());
    }

    // Penanganan user_id yang bisa integer atau string
    int? userId;
    if (json['user_id'] != null) {
      userId = json['user_id'] is int
          ? json['user_id']
          : int.tryParse(json['user_id'].toString());
    }

    // Penanganan image_path yang bisa string JSON atau array langsung
    List<String>? imagePathList;
    if (json['image_path'] != null) {
      if (json['image_path'] is List) {
        // Jika sudah dalam bentuk List
        imagePathList = List<String>.from(
            json['image_path'].map((item) => item.toString()));
      } else if (json['image_path'] is String) {
        // Jika dalam bentuk string JSON
        try {
          List<dynamic> decoded = jsonDecode(json['image_path']);
          imagePathList =
              List<String>.from(decoded.map((item) => item.toString()));
        } catch (e) {
          // Jika gagal parse, gunakan string aslinya
          imagePathList = [json['image_path'].toString()];
        }
      }
    }

    // Penanganan bukti_pelanggaran
    List<String>? buktiPelanggaranList;
    if (json['bukti_pelanggaran'] != null) {
      if (json['bukti_pelanggaran'] is List) {
        buktiPelanggaranList = List<String>.from(
            json['bukti_pelanggaran'].map((item) => item.toString()));
      } else if (json['bukti_pelanggaran'] is String) {
        try {
          List<dynamic> decoded = jsonDecode(json['bukti_pelanggaran']);
          buktiPelanggaranList =
              List<String>.from(decoded.map((item) => item.toString()));
        } catch (e) {
          buktiPelanggaranList = [json['bukti_pelanggaran'].toString()];
        }
      }
    }

    // Penanganan terlapor
    List<Map<String, dynamic>>? terlaporList;
    if (json['terlapor'] != null) {
      if (json['terlapor'] is List) {
        terlaporList = List<Map<String, dynamic>>.from(json['terlapor'].map(
            (item) => item is Map
                ? Map<String, dynamic>.from(item)
                : {"data": item}));
      } else if (json['terlapor'] is String) {
        try {
          List<dynamic> decoded = jsonDecode(json['terlapor']);
          terlaporList = List<Map<String, dynamic>>.from(decoded.map((item) =>
              item is Map ? Map<String, dynamic>.from(item) : {"data": item}));
        } catch (e) {
          // Handle other cases if needed
        }
      }
    }

    // Penanganan saksi
    List<Map<String, dynamic>>? saksiList;
    if (json['saksi'] != null) {
      if (json['saksi'] is List) {
        saksiList = List<Map<String, dynamic>>.from(json['saksi'].map((item) =>
            item is Map ? Map<String, dynamic>.from(item) : {"data": item}));
      } else if (json['saksi'] is String) {
        try {
          List<dynamic> decoded = jsonDecode(json['saksi']);
          saksiList = List<Map<String, dynamic>>.from(decoded.map((item) =>
              item is Map ? Map<String, dynamic>.from(item) : {"data": item}));
        } catch (e) {
          // Handle other cases if needed
        }
      }
    }

    return Laporan(
      id: laporanId,
      judul: json['judul']?.toString(),
      deskripsi: json['deskripsi']?.toString(),
      deskripsiKejadian: json['deskripsi_kejadian']?.toString(),
      lokasi: json['lokasi']?.toString(),
      tanggalKejadian: json['tanggal_kejadian']?.toString(),
      status: json['status']?.toString(),
      namaPelapor: json['nama_pelapor']?.toString(),
      niPelapor: json['ni_pelapor']?.toString(),
      nomorTelepon: json['nomor_telepon']?.toString(),
      teleponPelapor: json['telepon_pelapor']?.toString(),
      email: json['email']?.toString(),
      emailPelapor: json['email_pelapor']?.toString(),
      nomorLaporan: json['nomor_laporan']?.toString(),
      categoryId: catId,
      jenisKejadian: json['jenis_kejadian']?.toString(),
      imagePath: imagePathList, // Simpan sebagai List<String>
      fotoKejadian: json['foto_kejadian']?.toString(),
      createdAt: json['created_at'] != null
          ? DateTime.parse(json['created_at'].toString())
          : null,
      updatedAt: json['updated_at'] != null
          ? DateTime.parse(json['updated_at'].toString())
          : null,
      tanggapan: json['tanggapan'],
      profesi: json['profesi']?.toString(),
      jenisKelamin: json['jenis_kelamin']?.toString(),
      umurPelapor: json['umur_pelapor']?.toString(),
      buktiPelanggaran: buktiPelanggaranList,
      terlapor: terlaporList,
      saksi: saksiList,
      lampiranLink: json['lampiran_link']?.toString(),
      userId: userId,
    );
  }

  // Metode untuk mendapatkan URL gambar pertama
  String? get firstImageUrl {
    if (imagePath == null) {
      return null;
    }

    if (imagePath is List && imagePath.isNotEmpty) {
      return imagePath[0].toString();
    } else if (imagePath is String) {
      return imagePath;
    }

    return null;
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'judul': judul,
      'deskripsi': deskripsi,
      'deskripsi_kejadian': deskripsiKejadian,
      'lokasi': lokasi,
      'tanggal_kejadian': tanggalKejadian,
      'status': status,
      'nama_pelapor': namaPelapor,
      'ni_pelapor': niPelapor,
      'nomor_telepon': nomorTelepon,
      'telepon_pelapor': teleponPelapor,
      'email': email,
      'email_pelapor': emailPelapor,
      'nomor_laporan': nomorLaporan,
      'category_id': categoryId,
      'jenis_kejadian': jenisKejadian,
      'image_path': imagePath is List ? jsonEncode(imagePath) : imagePath,
      'foto_kejadian': fotoKejadian,
      'created_at': createdAt?.toIso8601String(),
      'updated_at': updatedAt?.toIso8601String(),
      'tanggapan': tanggapan,
      'profesi': profesi,
      'jenis_kelamin': jenisKelamin,
      'umur_pelapor': umurPelapor,
      'bukti_pelanggaran': buktiPelanggaran,
      'terlapor': terlapor,
      'saksi': saksi,
      'lampiran_link': lampiranLink,
      'user_id': userId,
    };
  }

  // Buat salinan Laporan dengan properti tertentu yang diperbarui
  Laporan copyWith({
    String? status,
    dynamic tanggapan,
    DateTime? updatedAt,
    String? lampiranLink,
  }) {
    return Laporan(
      id: this.id,
      judul: this.judul,
      deskripsi: this.deskripsi,
      deskripsiKejadian: this.deskripsiKejadian,
      lokasi: this.lokasi,
      tanggalKejadian: this.tanggalKejadian,
      status: status ?? this.status,
      namaPelapor: this.namaPelapor,
      niPelapor: this.niPelapor,
      nomorTelepon: this.nomorTelepon,
      teleponPelapor: this.teleponPelapor,
      email: this.email,
      emailPelapor: this.emailPelapor,
      nomorLaporan: this.nomorLaporan,
      categoryId: this.categoryId,
      jenisKejadian: this.jenisKejadian,
      imagePath: this.imagePath,
      fotoKejadian: this.fotoKejadian,
      createdAt: this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
      tanggapan: tanggapan ?? this.tanggapan,
      profesi: this.profesi,
      jenisKelamin: this.jenisKelamin,
      umurPelapor: this.umurPelapor,
      buktiPelanggaran: this.buktiPelanggaran,
      terlapor: this.terlapor,
      saksi: this.saksi,
      lampiranLink: lampiranLink ?? this.lampiranLink,
      userId: this.userId,
    );
  }
}
