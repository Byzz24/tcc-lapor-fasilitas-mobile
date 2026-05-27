import 'package:flutter/material.dart';
import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';
import 'package:url_launcher/url_launcher.dart';
import '../utils/constants.dart';

class DetailLaporanScreen extends StatefulWidget {
  final String laporanId;
  const DetailLaporanScreen({super.key, required this.laporanId});

  @override
  State<DetailLaporanScreen> createState() => _DetailLaporanScreenState();
}

class _DetailLaporanScreenState extends State<DetailLaporanScreen> {
  Map<String, dynamic>? _laporanData;
  bool _isLoading = true;
  String _errorMessage = '';
  String _userRole = 'warga';
  bool _isUpdatingStatus = false;

  @override
  void initState() {
    super.initState();
    _muatDetailDanRole();
  }

  Future<void> _muatDetailDanRole() async {
    await _fetchDetailLaporan();
    await _loadUserRole();
  }

  Future<void> _loadUserRole() async {
    final prefs = await SharedPreferences.getInstance();
    setState(() {
      _userRole =
          prefs.getString('role') ?? prefs.getString('user_role') ?? 'warga';
    });
  }

  Future<void> _fetchDetailLaporan() async {
    try {
      final response = await http.get(
        Uri.parse('${Constants.baseUrl}/api/laporan/${widget.laporanId}'),
      );
      if (response.statusCode == 200) {
        setState(() {
          _laporanData = jsonDecode(response.body);
          _isLoading = false;
        });
      } else {
        setState(() {
          _errorMessage = 'Laporan tidak ditemukan';
          _isLoading = false;
        });
      }
    } catch (e) {
      setState(() {
        _errorMessage = 'Gagal terhubung ke server';
        _isLoading = false;
      });
    }
  }

  Future<void> _kirimPembaruanStatus(String statusBaru, String catatan) async {
    setState(() => _isUpdatingStatus = true);
    try {
      final prefs = await SharedPreferences.getInstance();
      final String namaPetugas =
          prefs.getString('nama') ?? prefs.getString('name') ?? 'Petugas';

      final response = await http.put(
        Uri.parse(
          '${Constants.baseUrl}/api/laporan/${widget.laporanId}/status',
        ),
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode({
          'status_baru': statusBaru,
          'diperbarui_oleh': namaPetugas,
          'catatan': catatan.isEmpty
              ? 'Diperbarui oleh petugas lapangan'
              : catatan,
        }),
      );

      if (!mounted) return;

      if (response.statusCode == 200) {
        _tampilkanPesan('Status laporan berhasil diperbarui!', isError: false);
        await Future.delayed(const Duration(milliseconds: 500));
        await _fetchDetailLaporan();
      } else {
        _tampilkanPesan(
          'Gagal memperbarui status. Kode: ${response.statusCode}',
          isError: true,
        );
      }
    } catch (e) {
      _tampilkanPesan('Terjadi kesalahan koneksi', isError: true);
    } finally {
      if (mounted) {
        setState(() => _isUpdatingStatus = false);
      }
    }
  }

  Future<void> _bukaGoogleMaps(double lat, double lng) async {
    final Uri url = Uri.parse(
      'https://www.google.com/maps/search/?api=1&query=$lat,$lng',
    );
    if (!await launchUrl(url, mode: LaunchMode.externalApplication)) {
      _tampilkanPesan('Tidak dapat membuka Google Maps', isError: true);
    }
  }

  void _tampilkanModalStatus(String statusSekarang) {
    String statusTerpilih = statusSekarang;
    final TextEditingController catatanController = TextEditingController();

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.white,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (context) {
        return StatefulBuilder(
          builder: (context, setModalState) {
            return Padding(
              padding: EdgeInsets.only(
                top: 24,
                left: 24,
                right: 24,
                bottom: MediaQuery.of(context).viewInsets.bottom + 24,
              ),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                    'Perbarui Status Perbaikan',
                    style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                  ),
                  const SizedBox(height: 16),
                  RadioListTile<String>(
                    title: const Text('Sedang Diperbaiki'),
                    value: 'sedang_diperbaiki',
                    groupValue: statusTerpilih,
                    onChanged: (val) =>
                        setModalState(() => statusTerpilih = val!),
                  ),
                  RadioListTile<String>(
                    title: const Text('Selesai Diperbaiki'),
                    value: 'selesai',
                    groupValue: statusTerpilih,
                    onChanged: (val) =>
                        setModalState(() => statusTerpilih = val!),
                  ),
                  const SizedBox(height: 16),
                  TextField(
                    controller: catatanController,
                    decoration: InputDecoration(
                      labelText: 'Catatan Lapangan',
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                    ),
                    maxLines: 2,
                  ),
                  const SizedBox(height: 24),
                  SizedBox(
                    width: double.infinity,
                    height: 50,
                    child: ElevatedButton(
                      onPressed: () {
                        Navigator.pop(context);
                        _kirimPembaruanStatus(
                          statusTerpilih,
                          catatanController.text.trim(),
                        );
                      },
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Colors.blue.shade700,
                        foregroundColor: Colors.white,
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                      ),
                      child: const Text(
                        'Simpan Perubahan',
                        style: TextStyle(fontWeight: FontWeight.bold),
                      ),
                    ),
                  ),
                ],
              ),
            );
          },
        );
      },
    );
  }

  Color _getStatusColor(String status) {
    if (status == 'menunggu_validasi') return Colors.orange;
    if (status == 'diproses' || status == 'sedang_diperbaiki')
      return Colors.blue;
    if (status == 'selesai') return Colors.green;
    return Colors.grey;
  }

  String _formatStatus(String status) {
    if (status == 'menunggu_validasi') return 'Menunggu Validasi';
    if (status == 'sedang_diperbaiki') return 'Sedang Diperbaiki';
    return status.replaceAll('_', ' ').toUpperCase();
  }

  void _tampilkanPesan(String pesan, {bool isError = false}) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(pesan),
        backgroundColor: isError ? Colors.redAccent : Colors.green,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final bool isPetugas =
        _userRole == 'petugas' || _userRole == 'admin' || _userRole == 'dinas';
    final String statusSekarang =
        _laporanData?['informasi_umum']?['status_perbaikan'] ?? 'selesai';
    final bool tampilkanTombolAksi = isPetugas && statusSekarang != 'selesai';

    return Scaffold(
      backgroundColor: Colors.grey.shade50,
      appBar: AppBar(
        title: const Text(
          'Detail Laporan',
          style: TextStyle(fontWeight: FontWeight.bold, fontSize: 18),
        ),
        backgroundColor: Colors.white,
        foregroundColor: Colors.blue.shade900,
        elevation: 0,
        centerTitle: true,
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : _errorMessage.isNotEmpty
          ? Center(
              child: Text(
                _errorMessage,
                style: const TextStyle(color: Colors.red),
              ),
            )
          : _buildContent(),
      bottomNavigationBar: tampilkanTombolAksi
          ? Container(
              padding: const EdgeInsets.all(16),
              decoration: const BoxDecoration(
                color: Colors.white,
                boxShadow: [
                  BoxShadow(
                    color: Colors.black12,
                    blurRadius: 10,
                    offset: Offset(0, -2),
                  ),
                ],
              ),
              child: SizedBox(
                height: 50,
                child: ElevatedButton.icon(
                  onPressed: _isUpdatingStatus
                      ? null
                      : () => _tampilkanModalStatus(statusSekarang),
                  icon: _isUpdatingStatus
                      ? const SizedBox(
                          width: 20,
                          height: 20,
                          child: CircularProgressIndicator(
                            color: Colors.white,
                            strokeWidth: 2,
                          ),
                        )
                      : const Icon(Icons.edit_note_rounded),
                  label: Text(
                    _isUpdatingStatus
                        ? 'Memperbarui...'
                        : 'Perbarui Status Laporan',
                    style: const TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.blue.shade700,
                    foregroundColor: Colors.white,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                  ),
                ),
              ),
            )
          : null,
    );
  }

  Widget _buildContent() {
    final infoSql = _laporanData!['informasi_umum'];
    final infoMongo = _laporanData!['detail_lapangan'];
    final status = infoSql['status_perbaikan'] ?? 'unknown';

    double? lat;
    double? lng;
    if (infoMongo != null && infoMongo['lokasi_presisi'] != null) {
      lat = infoMongo['lokasi_presisi']['latitude']?.toDouble();
      lng = infoMongo['lokasi_presisi']['longitude']?.toDouble();
    }

    String urlFoto = 'https://via.placeholder.com/400x250?text=Tidak+Ada+Foto';
    if (infoMongo != null &&
        infoMongo['url_foto_bukti'] != null &&
        infoMongo['url_foto_bukti'].isNotEmpty) {
      urlFoto = infoMongo['url_foto_bukti'][0];
    }

    return SingleChildScrollView(
      padding: const EdgeInsets.only(bottom: 100),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            width: double.infinity,
            height: 250,
            decoration: BoxDecoration(color: Colors.grey.shade200),
            child: Image.network(
              urlFoto,
              fit: BoxFit.cover,
              errorBuilder: (context, error, stackTrace) =>
                  const Icon(Icons.broken_image, size: 64, color: Colors.grey),
            ),
          ),
          Padding(
            padding: const EdgeInsets.all(24.0),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 12,
                        vertical: 6,
                      ),
                      decoration: BoxDecoration(
                        color: _getStatusColor(status).withOpacity(0.1),
                        borderRadius: BorderRadius.circular(20),
                      ),
                      child: Text(
                        _formatStatus(status),
                        style: TextStyle(
                          color: _getStatusColor(status),
                          fontWeight: FontWeight.bold,
                          fontSize: 12,
                        ),
                      ),
                    ),
                    Text(
                      'ID: #${infoSql['id'].toString().substring(0, 8)}',
                      style: TextStyle(
                        color: Colors.grey.shade500,
                        fontSize: 12,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 16),
                Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Icon(
                      Icons.location_on,
                      color: Colors.red.shade400,
                      size: 24,
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            infoSql['lokasi_administratif'] ?? '-',
                            style: const TextStyle(
                              fontSize: 18,
                              fontWeight: FontWeight.bold,
                              height: 1.3,
                            ),
                          ),
                          const SizedBox(height: 8),
                          if (lat != null && lng != null)
                            InkWell(
                              onTap: () => _bukaGoogleMaps(lat!, lng!),
                              child: Container(
                                padding: const EdgeInsets.symmetric(
                                  horizontal: 12,
                                  vertical: 8,
                                ),
                                decoration: BoxDecoration(
                                  color: Colors.blue.shade50,
                                  borderRadius: BorderRadius.circular(8),
                                  border: Border.all(
                                    color: Colors.blue.shade200,
                                  ),
                                ),
                                child: Row(
                                  mainAxisSize: MainAxisSize.min,
                                  children: [
                                    Icon(
                                      Icons.map_rounded,
                                      size: 16,
                                      color: Colors.blue.shade700,
                                    ),
                                    const SizedBox(width: 8),
                                    Text(
                                      'Buka Navigasi di Maps',
                                      style: TextStyle(
                                        color: Colors.blue.shade700,
                                        fontWeight: FontWeight.bold,
                                        fontSize: 13,
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            ),
                        ],
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 24),
                const Text(
                  'Deskripsi Kerusakan',
                  style: TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.bold,
                    color: Colors.grey,
                  ),
                ),
                const SizedBox(height: 8),
                Container(
                  width: double.infinity,
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(16),
                  ),
                  child: Text(
                    infoSql['deskripsi_kerusakan'] ?? '-',
                    style: TextStyle(
                      fontSize: 15,
                      color: Colors.grey.shade800,
                      height: 1.5,
                    ),
                  ),
                ),
                const SizedBox(height: 24),
                const Text(
                  'Riwayat Penanganan',
                  style: TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.bold,
                    color: Colors.grey,
                  ),
                ),
                const SizedBox(height: 12),
                if (infoMongo != null &&
                    infoMongo['riwayat_pembaruan'] != null &&
                    infoMongo['riwayat_pembaruan'].isNotEmpty)
                  ...List.generate(infoMongo['riwayat_pembaruan'].length, (
                    index,
                  ) {
                    final riwayat = infoMongo['riwayat_pembaruan'][index];
                    return Container(
                      margin: const EdgeInsets.only(bottom: 12),
                      padding: const EdgeInsets.all(16),
                      decoration: BoxDecoration(
                        color: Colors.white,
                        borderRadius: BorderRadius.circular(12),
                        border: Border(
                          left: BorderSide(
                            color: _getStatusColor(riwayat['status']),
                            width: 4,
                          ),
                        ),
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              Text(
                                _formatStatus(riwayat['status']),
                                style: const TextStyle(
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                              Text(
                                riwayat['diperbarui_oleh'] ?? 'sistem',
                                style: TextStyle(
                                  color: Colors.grey.shade400,
                                  fontSize: 11,
                                  fontStyle: FontStyle.italic,
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 4),
                          Text(
                            riwayat['catatan'] ?? '-',
                            style: TextStyle(
                              color: Colors.grey.shade600,
                              fontSize: 13,
                            ),
                          ),
                        ],
                      ),
                    );
                  })
                else
                  Text(
                    'Belum ada riwayat penanganan untuk laporan ini.',
                    style: TextStyle(color: Colors.grey.shade500, fontSize: 13),
                  ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
