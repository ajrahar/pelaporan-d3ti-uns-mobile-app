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
  final String? imagePath;
  final String? fotoKejadian;
  final DateTime? createdAt; // Changed from String? to DateTime?
  final DateTime? updatedAt; // Changed from String? to DateTime?
  dynamic tanggapan;

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
  });

  factory Laporan.fromJson(Map<String, dynamic> json) {
    return Laporan(
      id: json['id'],
      judul: json['judul'],
      deskripsi: json['deskripsi'],
      deskripsiKejadian: json['deskripsi_kejadian'],
      lokasi: json['lokasi'],
      tanggalKejadian: json['tanggal_kejadian'],
      status: json['status'],
      namaPelapor: json['nama_pelapor'],
      niPelapor: json['ni_pelapor'],
      nomorTelepon: json['nomor_telepon'],
      teleponPelapor: json['telepon_pelapor'],
      email: json['email'],
      emailPelapor: json['email_pelapor'],
      nomorLaporan: json['nomor_laporan'],
      categoryId: json['category_id'],
      jenisKejadian: json['jenis_kejadian'],
      imagePath: json['image_path'],
      fotoKejadian: json['foto_kejadian'],
      createdAt: json['created_at'] != null
          ? DateTime.parse(json['created_at'])
          : null,
      updatedAt: json['updated_at'] != null
          ? DateTime.parse(json['updated_at'])
          : null,
      tanggapan: json['tanggapan'],
    );
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
      'image_path': imagePath,
      'foto_kejadian': fotoKejadian,
      'created_at': createdAt?.toIso8601String(), // Convert DateTime to String
      'updated_at': updatedAt?.toIso8601String(), // Convert DateTime to String
      'tanggapan': tanggapan,
    };
  }

  // Buat salinan Laporan dengan properti tertentu yang diperbarui
  Laporan copyWith({
    String? status,
    dynamic tanggapan,
    DateTime? updatedAt,
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
    );
  }
}
