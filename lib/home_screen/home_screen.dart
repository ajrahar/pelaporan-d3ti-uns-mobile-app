import 'package:flutter/material.dart';
import 'package:pelaporan_d3ti/components/bottom_navbar.dart';
import 'package:pelaporan_d3ti/components/sidebar.dart';
import 'package:pelaporan_d3ti/pelaporan%20kekerasan%20seksual/lapor_ks.dart';
import 'package:pelaporan_d3ti/pelaporan/lapor_kejadian.dart';
import 'dart:convert';
import 'package:http/http.dart' as http;

// Add this class for the quote model
class Quote {
  final String text;
  final String author;

  Quote({required this.text, required this.author});

  factory Quote.fromJson(Map<String, dynamic> json) {
    return Quote(
      text: json['q'] ?? '',
      author: json['a'] ?? '',
    );
  }
}

class HomeScreen extends StatefulWidget {
  @override
  _HomeScreenState createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  int _currentIndex = 1; // Default index untuk halaman Home

  // Daftar judul untuk setiap halaman
  final List<String> _pageTitles = [
    'Lapor Kejadian',
    'Halaman Utama',
    'Lapor Kekerasan Seksual',
  ];

  // Fungsi untuk mendapatkan salam berdasarkan waktu
  String getGreeting() {
    var hour = DateTime.now().hour;

    if (hour < 12) {
      return 'Selamat Pagi';
    } else if (hour < 18) {
      return 'Selamat Siang';
    } else {
      return 'Selamat Malam';
    }
  }

  // Daftar halaman yang akan ditampilkan
  late final List<Widget> _pages;

  @override
  void initState() {
    super.initState();
    _pages = [
      LaporKejadianPage(), // Halaman Lapor Kejadian
      _HomePageContent(greeting: getGreeting()), // Halaman Utama (Home)
      LaporKekerasanPage(), // Halaman Lapor Kekerasan Seksual
    ];
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(_pageTitles[
            _currentIndex]), // Menggunakan judul dari daftar sesuai index
        backgroundColor: Color(0xFF00A2EA), // Warna biru untuk AppBar
      ),
      drawer: Sidebar(), // Tambahkan sidebar sebagai drawer
      body: _pages[_currentIndex], // Tampilkan halaman berdasarkan index
      bottomNavigationBar: FloatingBottomNavbar(
        currentIndex: _currentIndex,
        onTap: (index) {
          setState(() {
            _currentIndex = index; // Ubah halaman saat tombol ditekan
          });
        },
      ),
    );
  }
}

// Widget untuk konten halaman utama
class _HomePageContent extends StatefulWidget {
  final String greeting;

  // Konstruktor untuk menerima salam dari _HomeScreenState
  const _HomePageContent({required this.greeting});

  @override
  _HomePageContentState createState() => _HomePageContentState();
}

class _HomePageContentState extends State<_HomePageContent> {
  bool _isLoading = true;
  Quote? _quote;
  bool _useAlternateSource = false; // Track which API source to use

  @override
  void initState() {
    super.initState();
    _fetchQuote();
  }

  Future<void> _fetchQuote() async {
    setState(() {
      _isLoading = true;
    });

    // Try primary source first or alternate based on flag
    if (!_useAlternateSource) {
      try {
        final response =
            await http.get(Uri.parse('https://zenquotes.io/api/random'));

        if (response.statusCode == 200) {
          final List<dynamic> data = jsonDecode(response.body);
          setState(() {
            _quote = Quote.fromJson(data[0]);
            _isLoading = false;
          });
          return;
        } else {
          print(
              'Failed to load quote from primary source: ${response.statusCode}');
          // Try alternate source if primary fails
          _useAlternateSource = true;
        }
      } catch (e) {
        print('Error fetching quote from primary source: $e');
        // Try alternate source if primary fails
        _useAlternateSource = true;
      }
    }

    // Try alternate source (quotable.io)
    if (_useAlternateSource) {
      try {
        final response =
            await http.get(Uri.parse('https://api.quotable.io/random'));

        if (response.statusCode == 200) {
          final Map<String, dynamic> data = jsonDecode(response.body);
          setState(() {
            // Map quotable.io response to our Quote model
            _quote = Quote(
              text: data['content'] ?? '',
              author: data['author'] ?? '',
            );
            _isLoading = false;
          });
        } else {
          setState(() {
            _isLoading = false;
          });
          print(
              'Failed to load quote from alternate source: ${response.statusCode}');
        }
      } catch (e) {
        setState(() {
          _isLoading = false;
        });
        print('Error fetching quote from alternate source: $e');
      }
    }
  }

  // Add a refresh function to get a new quote
  void _refreshQuote() {
    // Toggle source for variety
    _useAlternateSource = !_useAlternateSource;
    _fetchQuote();
  }

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.all(16.0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Greeting and Welcome Card
          Card(
            elevation: 4,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(10),
            ),
            child: Padding(
              padding: const EdgeInsets.all(16.0),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    '${widget.greeting}, Miftahul!',
                    style: TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                      color: Color(0xFF222222),
                    ),
                  ),
                  SizedBox(height: 8),
                  Text(
                    'Selamat datang di aplikasi pelaporan D3 TI UNS',
                    style: TextStyle(
                      fontSize: 14,
                      color: Color(0xFF222222),
                    ),
                  ),
                ],
              ),
            ),
          ),

          SizedBox(height: 16),

          // Quote of the Day Card
          Card(
            elevation: 4,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(10),
            ),
            child: Padding(
              padding: const EdgeInsets.all(16.0),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Quote of the Day',
                    style: TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.bold,
                      color: Color(0xFF00A2EA),
                    ),
                  ),
                  SizedBox(height: 12),
                  _isLoading
                      ? Center(child: CircularProgressIndicator())
                      : _quote != null
                          ? Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  '"${_quote!.text}"',
                                  style: TextStyle(
                                    fontSize: 14,
                                    fontStyle: FontStyle.italic,
                                    color: Color(0xFF222222),
                                  ),
                                ),
                                SizedBox(height: 8),
                                Align(
                                  alignment: Alignment.centerRight,
                                  child: Text(
                                    '- ${_quote!.author}',
                                    style: TextStyle(
                                      fontSize: 12,
                                      fontWeight: FontWeight.w500,
                                      color: Color(0xFF666666),
                                    ),
                                  ),
                                ),
                              ],
                            )
                          : Text('Failed to load quote. Try again later.'),
                ],
              ),
            ),
          ),

          SizedBox(height: 16),

          // Dua card untuk statistik terlapor dan belum terverifikasi
          Row(
            children: [
              // Card Jumlah Kejadian Terlapor (Kiri)
              Expanded(
                child: Card(
                  elevation: 4,
                  color: Color(0xFF00A2EA),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: Padding(
                    padding: const EdgeInsets.all(16.0),
                    child: Column(
                      children: [
                        Text(
                          'Jumlah Kejadian Terlapor',
                          textAlign: TextAlign.center,
                          style: TextStyle(
                            fontSize: 12,
                            fontWeight: FontWeight.w500,
                            color: Colors.white,
                          ),
                        ),
                        SizedBox(height: 8),
                        Text(
                          '25',
                          style: TextStyle(
                            fontSize: 24,
                            fontWeight: FontWeight.bold,
                            color: Colors.white,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
              SizedBox(width: 12),
              // Card Jumlah Laporan Belum Terverifikasi (Kanan)
              Expanded(
                child: Card(
                  elevation: 4,
                  color: Color(0xFFFFA500),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: Padding(
                    padding: const EdgeInsets.all(16.0),
                    child: Column(
                      children: [
                        Text(
                          'Jumlah Laporan Belum Terverifikasi',
                          textAlign: TextAlign.center,
                          style: TextStyle(
                            fontSize: 12,
                            fontWeight: FontWeight.w500,
                            color: Colors.white,
                          ),
                        ),
                        SizedBox(height: 8),
                        Text(
                          '10',
                          style: TextStyle(
                            fontSize: 24,
                            fontWeight: FontWeight.bold,
                            color: Colors.white,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ],
          ),

          SizedBox(height: 16),

          // Card Laporan Tertangani
          Card(
            elevation: 4,
            color: Color(0xFF34C759),
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(10),
            ),
            child: Padding(
              padding: const EdgeInsets.all(16.0),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Jumlah Kejadian Tertangani',
                        style: TextStyle(
                          fontSize: 14,
                          fontWeight: FontWeight.w500,
                          color: Colors.white,
                        ),
                      ),
                      SizedBox(height: 4),
                      Text(
                        'Sudah diproses dan ditindaklanjuti',
                        style: TextStyle(
                          fontSize: 12,
                          color: Colors.white.withOpacity(0.8),
                        ),
                      ),
                    ],
                  ),
                  Text(
                    '15',
                    style: TextStyle(
                      fontSize: 28,
                      fontWeight: FontWeight.bold,
                      color: Colors.white,
                    ),
                  ),
                ],
              ),
            ),
          ),

          // Add your statistics cards and other content below
          SizedBox(height: 16),
          // Rest of your content...
        ],
      ),
    );
  }
}
