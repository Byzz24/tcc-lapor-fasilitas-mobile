import 'package:flutter/material.dart';
import 'dart:convert';
import 'package:http/http.dart' as http;
import '../utils/constants.dart';
import 'detail_laporan_screen.dart';

class TugasScreen extends StatefulWidget {
  const TugasScreen({super.key});

  @override
  State<TugasScreen> createState() => _TugasScreenState();
}

class _TugasScreenState extends State<TugasScreen> {
  List<dynamic> _tugasList = [];
  bool _isLoading = true;
  String _errorMessage = '';

  @override
  void initState() {
    super.initState();
    _fetchDaftarTugas();
  }

  Future<void> _fetchDaftarTugas() async {
    setState(() {
      _isLoading = true;
      _errorMessage = '';
    });

    try {
      final response = await http.get(
        Uri.parse('${Constants.baseUrl}/api/feed/laporan?limit=100&offset=0'),
      );

      if (response.statusCode == 200) {
        final result = jsonDecode(response.body);
        final List<dynamic> allData = result['data'] ?? [];

        // Pemfilteran: Hanya menampilkan tugas yang belum Selesai
        final activeTasks = allData.where((laporan) {
          final status = laporan['status_perbaikan'];
          return status != 'selesai';
        }).toList();

        setState(() {
          _tugasList = activeTasks;
          _isLoading = false;
        });
      } else {
        setState(() {
          _errorMessage = 'Gagal memuat tugas. Kode: ${response.statusCode}';
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

  Color _getStatusColor(String status) {
    if (status == 'menunggu_validasi') return Colors.orange;
    if (status == 'diproses') return Colors.blue;
    if (status == 'sedang_diperbaiki') return Colors.purple;
    return Colors.grey;
  }

  String _formatStatus(String status) {
    if (status == 'menunggu_validasi') return 'Perlu Validasi';
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
            Icon(Icons.wifi_off_rounded, size: 48, color: Colors.red.shade300),
            const SizedBox(height: 16),
            Text(_errorMessage, style: const TextStyle(color: Colors.grey)),
            TextButton(
              onPressed: _fetchDaftarTugas,
              child: const Text('Coba Lagi'),
            ),
          ],
        ),
      );
    }

    if (_tugasList.isEmpty) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Container(
              padding: const EdgeInsets.all(24),
              decoration: BoxDecoration(
                color: Colors.green.shade50,
                shape: BoxShape.circle,
              ),
              child: Icon(
                Icons.check_circle_outline,
                size: 64,
                color: Colors.green.shade400,
              ),
            ),
            const SizedBox(height: 16),
            const Text(
              'Mantap! Tidak ada tugas tertunda.',
              style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
            ),
            const Text(
              'Semua fasilitas dalam kondisi baik.',
              style: TextStyle(color: Colors.grey),
            ),
          ],
        ),
      );
    }

    return RefreshIndicator(
      onRefresh: _fetchDaftarTugas,
      color: Colors.blue.shade700,
      child: ListView.builder(
        padding: const EdgeInsets.only(
          top: 16,
          left: 16,
          right: 16,
          bottom: 100,
        ),
        itemCount: _tugasList.length,
        itemBuilder: (context, index) {
          final tugas = _tugasList[index];
          return GestureDetector(
            onTap: () {
              Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (context) =>
                      DetailLaporanScreen(laporanId: tugas['id'].toString()),
                ),
              );
            },
            child: Container(
              margin: const EdgeInsets.only(bottom: 16),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(16),
                border: Border(
                  left: BorderSide(
                    color: _getStatusColor(tugas['status_perbaikan']),
                    width: 5,
                  ),
                ),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withOpacity(0.04),
                    blurRadius: 10,
                    offset: const Offset(0, 4),
                  ),
                ],
              ),
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 10,
                            vertical: 4,
                          ),
                          decoration: BoxDecoration(
                            color: _getStatusColor(
                              tugas['status_perbaikan'],
                            ).withOpacity(0.1),
                            borderRadius: BorderRadius.circular(8),
                          ),
                          child: Text(
                            _formatStatus(
                              tugas['status_perbaikan'] ?? 'unknown',
                            ),
                            style: TextStyle(
                              color: _getStatusColor(tugas['status_perbaikan']),
                              fontWeight: FontWeight.bold,
                              fontSize: 11,
                            ),
                          ),
                        ),
                        Text(
                          'ID: #${tugas['id'].toString().substring(0, 8)}',
                          style: TextStyle(
                            color: Colors.grey.shade400,
                            fontSize: 12,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 12),
                    Text(
                      tugas['lokasi_administratif'] ?? 'Lokasi tidak diketahui',
                      style: const TextStyle(
                        fontWeight: FontWeight.bold,
                        fontSize: 16,
                        height: 1.2,
                      ),
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                    ),
                    const SizedBox(height: 8),
                    Text(
                      tugas['deskripsi_kerusakan'] ?? 'Tidak ada deskripsi.',
                      style: TextStyle(
                        color: Colors.grey.shade600,
                        fontSize: 13,
                      ),
                      maxLines: 1,
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
