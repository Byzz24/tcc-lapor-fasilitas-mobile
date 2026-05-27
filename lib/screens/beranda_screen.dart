import 'package:flutter/material.dart';
import 'dart:convert';
import 'package:http/http.dart' as http;
import '../utils/constants.dart';
import 'detail_laporan_screen.dart'; // Import halaman detail

class BerandaScreen extends StatefulWidget {
  const BerandaScreen({super.key});

  @override
  State<BerandaScreen> createState() => _BerandaScreenState();
}

class _BerandaScreenState extends State<BerandaScreen> {
  List<dynamic> _laporanList = [];
  bool _isLoading = true;
  String _errorMessage = '';

  @override
  void initState() {
    super.initState();
    _fetchLaporan();
  }

  Future<void> _fetchLaporan() async {
    setState(() {
      _isLoading = true;
      _errorMessage = '';
    });

    try {
      final response = await http.get(
        Uri.parse('${Constants.baseUrl}/api/feed/laporan?limit=50&offset=0'),
      );

      if (response.statusCode == 200) {
        final result = jsonDecode(response.body);
        setState(() {
          _laporanList = result['data'] ?? [];
          _isLoading = false;
        });
      } else {
        setState(() {
          _errorMessage = 'Gagal memuat data. Kode: ${response.statusCode}';
          _isLoading = false;
        });
      }
    } catch (e) {
      setState(() {
        _errorMessage = 'Tidak ada koneksi ke server.';
        _isLoading = false;
      });
    }
  }

  // Fungsi untuk menentukan warna badge status
  Color _getStatusColor(String status) {
    if (status == 'menunggu_validasi') return Colors.orange;
    if (status == 'diproses' || status == 'sedang_diperbaiki')
      return Colors.blue;
    if (status == 'selesai') return Colors.green;
    return Colors.grey;
  }

  String _formatStatus(String status) {
    if (status == 'menunggu_validasi') return 'Menunggu';
    if (status == 'sedang_diperbaiki') return 'Diperbaiki';
    return status[0].toUpperCase() + status.substring(1);
  }

  @override
  Widget build(BuildContext context) {
    if (_isLoading) {
      return const Center(child: CircularProgressIndicator());
    }

    if (_errorMessage.isNotEmpty) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.error_outline, size: 48, color: Colors.red.shade300),
            const SizedBox(height: 16),
            Text(_errorMessage, style: const TextStyle(color: Colors.grey)),
            TextButton(
              onPressed: _fetchLaporan,
              child: const Text('Coba Lagi'),
            ),
          ],
        ),
      );
    }

    if (_laporanList.isEmpty) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.inbox_outlined, size: 64, color: Colors.grey.shade300),
            const SizedBox(height: 16),
            const Text(
              'Belum ada laporan di sekitar Anda.',
              style: TextStyle(color: Colors.grey),
            ),
          ],
        ),
      );
    }

    return RefreshIndicator(
      onRefresh: _fetchLaporan,
      color: Colors.blue.shade700,
      child: ListView.builder(
        padding: const EdgeInsets.only(
          top: 16,
          left: 16,
          right: 16,
          bottom: 100,
        ), // Bottom padding untuk BottomNav
        itemCount: _laporanList.length,
        itemBuilder: (context, index) {
          final laporan = _laporanList[index];

          // GestureDetector ditambahkan di sini agar kartu bisa diklik
          return GestureDetector(
            onTap: () {
              Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (context) =>
                      DetailLaporanScreen(laporanId: laporan['id'].toString()),
                ),
              );
            },
            child: Container(
              margin: const EdgeInsets.only(bottom: 16),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(20),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withOpacity(0.05),
                    blurRadius: 10,
                    offset: const Offset(0, 4),
                  ),
                ],
              ),
              child: Padding(
                padding: const EdgeInsets.all(20),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Expanded(
                          child: Text(
                            laporan['lokasi_administratif'] ??
                                'Lokasi tidak diketahui',
                            style: const TextStyle(
                              fontWeight: FontWeight.bold,
                              fontSize: 16,
                            ),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                        Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 12,
                            vertical: 6,
                          ),
                          decoration: BoxDecoration(
                            color: _getStatusColor(
                              laporan['status_perbaikan'],
                            ).withOpacity(0.1),
                            borderRadius: BorderRadius.circular(20),
                          ),
                          child: Text(
                            _formatStatus(
                              laporan['status_perbaikan'] ?? 'unknown',
                            ),
                            style: TextStyle(
                              color: _getStatusColor(
                                laporan['status_perbaikan'],
                              ),
                              fontWeight: FontWeight.bold,
                              fontSize: 12,
                            ),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 12),
                    Text(
                      laporan['deskripsi_kerusakan'] ?? 'Tidak ada deskripsi.',
                      style: TextStyle(
                        color: Colors.grey.shade700,
                        height: 1.5,
                      ),
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ],
                ),
              ),
            ),
          );
        },
      ),
    );
  }
}
