class ApiConstants {
  static const String baseUrl = 'https://v3422040.mhs.d3tiuns.com/api';
  static const String loginMahasiswaEndpoint = '/login/mahasiswa';
  static const String loginDosenEndpoint = '/login/dosen';

  static const Map<String, String> defaultHeaders = {
    'Content-Type': 'application/json',
    'Accept': 'application/json',
  };
}
