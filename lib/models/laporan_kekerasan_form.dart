import 'dart:io';
import 'package:pelaporan_d3ti/models/laporan_kekerasan.dart'; // Import your existing model

class LaporanKekerasanForm {
  String? title; // judul
  int? category; // categoryId
  String? description; // deskripsi
  String? reporterName; // namaPelapor
  String? nim; // nimPelapor
  String? phone; // nomorTelepon
  DateTime? incidentDate; // tanggalKejadian
  List<File>? evidenceFiles; // For file upload (not in model)
  String? lampiranLink; // lampiranLink
  List<String> buktiPelanggaran = []; // buktiPelanggaran
  bool agreement = false; // For form validation (not in model)
  List<TerlaporForm> terlapor = []; // terlapor (form version)
  List<SaksiForm> saksi = []; // saksi (form version)

  LaporanKekerasanForm() {
    // Initialize with one empty object for terlapor and saksi
    terlapor.add(TerlaporForm());
    saksi.add(SaksiForm());
  }

  // Convert to API model
  LaporanKekerasan toLaporanKekerasan() {
    return LaporanKekerasan(
      judul: title,
      categoryId: category,
      deskripsi: description,
      namaPelapor: reporterName,
      nimPelapor: nim,
      nomorTelepon: phone,
      tanggalKejadian: incidentDate,
      lampiranLink: lampiranLink,
      buktiPelanggaran: buktiPelanggaran,
      terlapor: terlapor.map((t) => t.toTerlapor()).toList(),
      saksi: saksi.map((s) => s.toSaksi()).toList(),
    );
  }
}

class TerlaporForm {
  String? namaLengkap;
  String? email;
  String? nomorTelepon;
  String? statusWarga;
  String? unitKerja; // Not in original model but needed for form
  String? jenisKelamin;
  String? umurTerlapor; // Not in original model but needed for form

  TerlaporForm({
    this.namaLengkap,
    this.email,
    this.nomorTelepon,
    this.statusWarga,
    this.unitKerja,
    this.jenisKelamin,
    this.umurTerlapor,
  });

  // Convert to API model
  Terlapor toTerlapor() {
    return Terlapor(
      namaLengkap: namaLengkap,
      email: email,
      nomorTelepon: nomorTelepon,
      statusWarga: statusWarga,
      jenisKelamin: jenisKelamin,
    );
    // Note: unitKerja and umurTerlapor are not included in the API model
    // but can be maintained in the form state for submission
  }
}

class SaksiForm {
  String? namaLengkap;
  String? email;
  String? nomorTelepon;

  SaksiForm({
    this.namaLengkap,
    this.email,
    this.nomorTelepon,
  });

  // Convert to API model
  Saksi toSaksi() {
    return Saksi(
      namaLengkap: namaLengkap,
      email: email,
      nomorTelepon: nomorTelepon,
    );
  }
}
