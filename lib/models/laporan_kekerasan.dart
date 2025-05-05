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
    this.buktiPelanggaran,
    this.terlapor,
    this.saksi,
    this.lampiranLink,
    this.createdAt,
    this.updatedAt,
  });

  factory LaporanKekerasan.fromJson(Map<String, dynamic> json) {
    return LaporanKekerasan(
      id: json['laporan_kekerasan_id'],
      judul: json['judul'],
      imagePath: json['image_path'] != null
          ? List<String>.from(jsonDecode(json['image_path']))
          : null,
      categoryId: json['category_id'],
      deskripsi: json['deskripsi'],
      tanggalKejadian: json['tanggal_kejadian'] != null
          ? DateTime.parse(json['tanggal_kejadian'])
          : null,
      nomorTelepon: json['nomor_telepon'],
      nomorLaporanKekerasan: json['nomor_laporan_kekerasan'],
      namaPelapor: json['nama_pelapor'],
      nimPelapor: json['nim_pelapor'],
      buktiPelanggaran: json['bukti_pelanggaran'] != null
          ? List<String>.from(json['bukti_pelanggaran'])
          : null,
      terlapor: json['terlapor'] != null
          ? List<Terlapor>.from(
              json['terlapor'].map((x) => Terlapor.fromJson(x)))
          : null,
      saksi: json['saksi'] != null
          ? List<Saksi>.from(json['saksi'].map((x) => Saksi.fromJson(x)))
          : null,
      lampiranLink: json['lampiran_link'],
      createdAt: json['created_at'] != null
          ? DateTime.parse(json['created_at'])
          : null,
      updatedAt: json['updated_at'] != null
          ? DateTime.parse(json['updated_at'])
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
  final String? jenisKelamin;

  Terlapor({
    this.namaLengkap,
    this.email,
    this.nomorTelepon,
    this.statusWarga,
    this.jenisKelamin,
  });

  factory Terlapor.fromJson(Map<String, dynamic> json) {
    return Terlapor(
      namaLengkap: json['nama_lengkap'],
      email: json['email'],
      nomorTelepon: json['nomor_telepon'],
      statusWarga: json['status_warga'],
      jenisKelamin: json['jenis_kelamin'],
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'nama_lengkap': namaLengkap,
      'email': email,
      'nomor_telepon': nomorTelepon,
      'status_warga': statusWarga,
      'jenis_kelamin': jenisKelamin,
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
      namaLengkap: json['nama_lengkap'],
      email: json['email'],
      nomorTelepon: json['nomor_telepon'],
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
