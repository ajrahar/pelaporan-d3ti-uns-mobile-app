class Laporan {
  final int laporanId;
  final String nomorLaporan;
  final String judul;
  final String deskripsi;
  final int categoryId;
  final String namaPelapor;
  final String? niPelapor;
  final String status;
  final DateTime createdAt;

  Laporan({
    required this.laporanId,
    required this.nomorLaporan,
    required this.judul,
    required this.deskripsi,
    required this.categoryId,
    required this.namaPelapor,
    this.niPelapor,
    required this.status,
    required this.createdAt,
  });

  factory Laporan.fromJson(Map<String, dynamic> json) {
    // The actual field names from your API
    return Laporan(
      laporanId: json['laporan_id'] ?? 0,
      nomorLaporan: json['nomor_laporan'] ?? '',
      judul: json['judul'] ?? '',
      deskripsi: json['deskripsi'] ?? '',
      categoryId: json['category_id'] ?? 0,
      namaPelapor: json['nama_pelapor'] ?? '',
      niPelapor: json['ni_pelapor'], // This is the field from the API
      status: json['status'] ?? 'unverified',
      createdAt: json['created_at'] != null
          ? DateTime.parse(json['created_at'])
          : DateTime.now(),
    );
  }
}
