import 'dart:convert';

class LaporanKekerasan {
  final int? id;
  final String? judul;
  final List<String>? imagePath;
  final int? categoryId;
  final String? deskripsi;
  final DateTime? tanggalKejadian;
  final String? nomorTelepon;
  final String? nomorLaporanKekerasan;
  final String? namaPelapor;
  final String? nimPelapor;
  final String? umurPelapor; // Ditambahkan sesuai data JSON
  final String? profesi; // Ditambahkan sesuai data JSON
  final String? jenisKelamin; // Ditambahkan sesuai data JSON
  final List<String>? buktiPelanggaran;
  final List<Terlapor>? terlapor;
  final List<Saksi>? saksi;
  final String? lampiranLink;
  final DateTime? createdAt;
  final DateTime? updatedAt;

  LaporanKekerasan({
    this.id,
    this.judul,
    this.imagePath,
    this.categoryId,
    this.deskripsi,
    this.tanggalKejadian,
    this.nomorTelepon,
    this.nomorLaporanKekerasan,
    this.namaPelapor,
    this.nimPelapor,
    this.umurPelapor,
    this.profesi,
    this.jenisKelamin,
    this.buktiPelanggaran,
    this.terlapor,
    this.saksi,
    this.lampiranLink,
    this.createdAt,
    this.updatedAt,
  });

  factory LaporanKekerasan.fromJson(Map<String, dynamic> json) {
    // Penanganan laporan_kekerasan_id yang bisa berbentuk integer atau string
    int? laporanId;
    if (json['laporan_kekerasan_id'] != null) {
      laporanId = json['laporan_kekerasan_id'] is int
          ? json['laporan_kekerasan_id']
          : int.tryParse(json['laporan_kekerasan_id'].toString());
    }

    // Penanganan category_id yang bisa integer atau string
    int? catId;
    if (json['category_id'] != null) {
      catId = json['category_id'] is int
          ? json['category_id']
          : int.tryParse(json['category_id'].toString());
    }

    // Penanganan image_path yang bisa string JSON atau array
    List<String>? imagePathList;
    if (json['image_path'] != null) {
      if (json['image_path'] is List) {
        imagePathList = List<String>.from(
            json['image_path'].map((item) => item.toString()));
      } else if (json['image_path'] is String) {
        try {
          List<dynamic> decoded = jsonDecode(json['image_path']);
          imagePathList =
              List<String>.from(decoded.map((item) => item.toString()));
        } catch (e) {
          imagePathList = [json['image_path'].toString()];
        }
      }
    }

    return LaporanKekerasan(
      id: laporanId,
      judul: json['judul']?.toString(),
      imagePath: imagePathList,
      categoryId: catId,
      deskripsi: json['deskripsi']?.toString(),
      tanggalKejadian: json['tanggal_kejadian'] != null
          ? DateTime.parse(json['tanggal_kejadian'].toString())
          : null,
      nomorTelepon: json['nomor_telepon']?.toString(),
      nomorLaporanKekerasan: json['nomor_laporan_kekerasan']?.toString(),
      namaPelapor: json['nama_pelapor']?.toString(),
      nimPelapor: json['nim_pelapor']?.toString(),
      umurPelapor: json['umur_pelapor']?.toString(),
      profesi: json['profesi']?.toString(),
      jenisKelamin: json['jenis_kelamin']?.toString(),
      buktiPelanggaran: json['bukti_pelanggaran'] != null
          ? List<String>.from(
              json['bukti_pelanggaran'].map((item) => item.toString()))
          : null,
      terlapor: json['terlapor'] != null
          ? List<Terlapor>.from(
              json['terlapor'].map((x) => Terlapor.fromJson(x)))
          : null,
      saksi: json['saksi'] != null
          ? List<Saksi>.from(json['saksi'].map((x) => Saksi.fromJson(x)))
          : null,
      lampiranLink: json['lampiran_link']?.toString(),
      createdAt: json['created_at'] != null
          ? DateTime.parse(json['created_at'].toString())
          : null,
      updatedAt: json['updated_at'] != null
          ? DateTime.parse(json['updated_at'].toString())
          : null,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'laporan_kekerasan_id': id,
      'judul': judul,
      'image_path': imagePath != null ? jsonEncode(imagePath) : null,
      'category_id': categoryId,
      'deskripsi': deskripsi,
      'tanggal_kejadian': tanggalKejadian?.toIso8601String(),
      'nomor_telepon': nomorTelepon,
      'nomor_laporan_kekerasan': nomorLaporanKekerasan,
      'nama_pelapor': namaPelapor,
      'nim_pelapor': nimPelapor,
      'umur_pelapor': umurPelapor,
      'profesi': profesi,
      'jenis_kelamin': jenisKelamin,
      'bukti_pelanggaran': buktiPelanggaran,
      'terlapor': terlapor?.map((x) => x.toJson()).toList(),
      'saksi': saksi?.map((x) => x.toJson()).toList(),
      'lampiran_link': lampiranLink,
      'created_at': createdAt?.toIso8601String(),
      'updated_at': updatedAt?.toIso8601String(),
    };
  }
}

class Terlapor {
  final String? namaLengkap;
  final String? email;
  final String? nomorTelepon;
  final String? statusWarga;
  final String? unitKerja; // Ditambahkan sesuai data JSON
  final String? jenisKelamin;
  final String? umurTerlapor; // Ditambahkan sesuai data JSON

  Terlapor({
    this.namaLengkap,
    this.email,
    this.nomorTelepon,
    this.statusWarga,
    this.unitKerja,
    this.jenisKelamin,
    this.umurTerlapor,
  });

  factory Terlapor.fromJson(Map<String, dynamic> json) {
    return Terlapor(
      namaLengkap: json['nama_lengkap']?.toString(),
      email: json['email']?.toString(),
      nomorTelepon: json['nomor_telepon']?.toString(),
      statusWarga: json['status_warga']?.toString(),
      unitKerja: json['unit_kerja']?.toString(),
      jenisKelamin: json['jenis_kelamin']?.toString(),
      umurTerlapor: json['umur_terlapor']?.toString(),
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'nama_lengkap': namaLengkap,
      'email': email,
      'nomor_telepon': nomorTelepon,
      'status_warga': statusWarga,
      'unit_kerja': unitKerja,
      'jenis_kelamin': jenisKelamin,
      'umur_terlapor': umurTerlapor,
    };
  }
}

class Saksi {
  final String? namaLengkap;
  final String? email;
  final String? nomorTelepon;

  Saksi({
    this.namaLengkap,
    this.email,
    this.nomorTelepon,
  });

  factory Saksi.fromJson(Map<String, dynamic> json) {
    return Saksi(
      namaLengkap: json['nama_lengkap']?.toString(),
      email: json['email']?.toString(),
      nomorTelepon: json['nomor_telepon']?.toString(),
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'nama_lengkap': namaLengkap,
      'email': email,
      'nomor_telepon': nomorTelepon,
    };
  }
}
