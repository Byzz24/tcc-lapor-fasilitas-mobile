import 'package:flutter/material.dart';
import 'dart:convert';
import 'dart:io';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';
import 'package:image_picker/image_picker.dart';
import 'package:geolocator/geolocator.dart';
import '../utils/constants.dart';
import 'package:http_parser/http_parser.dart'; // Import ini wajib untuk MediaType

class LaporScreen extends StatefulWidget {
  const LaporScreen({super.key});

  @override
  State<LaporScreen> createState() => _LaporScreenState();
}

class _LaporScreenState extends State<LaporScreen> {
  final _formKey = GlobalKey<FormState>();
  final TextEditingController _lokasiController = TextEditingController();
  final TextEditingController _deskripsiController = TextEditingController();

  List<dynamic> _kategoriList = [];
  String? _selectedKategoriId;
  bool _isLoadingKategori = true;
  bool _isSubmitting = false;

  // Variabel Perangkat Keras
  File? _fotoBukti;
  Position? _posisiUser;
  final ImagePicker _picker = ImagePicker();
  bool _isGettingLocation = false;

  @override
  void initState() {
    super.initState();
    _ambilKategori();
  }

  Future<void> _ambilKategori() async {
    try {
      final response = await http.get(
        Uri.parse('${Constants.baseUrl}/api/kategori'),
      );
      if (response.statusCode == 200) {
        final result = jsonDecode(response.body);
        setState(() {
          _kategoriList = result['data'] ?? [];
          _isLoadingKategori = false;
        });
      }
    } catch (e) {
      setState(() => _isLoadingKategori = false);
      _tampilkanPesan('Gagal memuat kategori kerusakan', isError: true);
    }
  }

  // --- LOGIKA KAMERA ---
  Future<void> _bukaKamera() async {
    try {
      final XFile? foto = await _picker.pickImage(
        source: ImageSource.camera,
        imageQuality: 70, // Kompresi agar upload cepat
      );
      if (foto != null) {
        setState(() => _fotoBukti = File(foto.path));
      }
    } catch (e) {
      _tampilkanPesan('Gagal mengakses kamera', isError: true);
    }
  }

  // --- LOGIKA GPS ---
  Future<void> _dapatkanLokasi() async {
    setState(() => _isGettingLocation = true);
    try {
      bool serviceEnabled = await Geolocator.isLocationServiceEnabled();
      if (!serviceEnabled) {
        _tampilkanPesan(
          'Aktifkan GPS ponsel Anda terlebih dahulu',
          isError: true,
        );
        setState(() => _isGettingLocation = false);
        return;
      }

      LocationPermission permission = await Geolocator.checkPermission();
      if (permission == LocationPermission.denied) {
        permission = await Geolocator.requestPermission();
        if (permission == LocationPermission.denied) {
          _tampilkanPesan('Izin lokasi ditolak', isError: true);
          setState(() => _isGettingLocation = false);
          return;
        }
      }

      if (permission == LocationPermission.deniedForever) {
        _tampilkanPesan(
          'Izin lokasi diblokir permanen di pengaturan',
          isError: true,
        );
        setState(() => _isGettingLocation = false);
        return;
      }

      Position position = await Geolocator.getCurrentPosition(
        desiredAccuracy: LocationAccuracy.high,
      );
      setState(() {
        _posisiUser = position;
        _isGettingLocation = false;
      });
      _tampilkanPesan('Titik koordinat berhasil didapatkan!', isError: false);
    } catch (e) {
      _tampilkanPesan('Gagal mendapatkan lokasi satelit', isError: true);
      setState(() => _isGettingLocation = false);
    }
  }

  // --- LOGIKA PENGIRIMAN MULTIPART & JSON ---
  Future<void> _kirimLaporan() async {
    if (!_formKey.currentState!.validate()) return;
    if (_fotoBukti == null) {
      _tampilkanPesan(
        'Anda wajib menyertakan foto bukti kerusakan',
        isError: true,
      );
      return;
    }
    if (_posisiUser == null) {
      _tampilkanPesan(
        'Anda wajib menandai lokasi GPS terlebih dahulu',
        isError: true,
      );
      return;
    }

    setState(() => _isSubmitting = true);

    try {
      final prefs = await SharedPreferences.getInstance();
      final int pelaporId = prefs.getInt('user_id') ?? 1;

      // 1. Upload Foto ke Cloud Storage
      var requestUpload = http.MultipartRequest(
        'POST',
        Uri.parse('${Constants.baseUrl}/api/upload/foto-kerusakan'),
      );

      // PERBAIKAN: Menambahkan contentType MediaType agar lolos dari validasi FastAPI
      requestUpload.files.add(
        await http.MultipartFile.fromPath(
          'file',
          _fotoBukti!.path,
          contentType: MediaType('image', 'jpeg'),
        ),
      );

      var responseUpload = await requestUpload.send();
      var responseData = await responseUpload.stream.bytesToString();

      if (responseUpload.statusCode != 200) {
        setState(() => _isSubmitting = false);
        _tampilkanPesan(
          'Gagal mengunggah foto ke server. Kode: ${responseUpload.statusCode}',
          isError: true,
        );
        return;
      }

      final String urlFotoCloud = jsonDecode(responseData)['url_foto'];

      // 2. Kirim Data Laporan JSON ke MySQL & MongoDB
      final Map<String, dynamic> payload = {
        'pelapor_id': pelaporId,
        'kategori_id': int.parse(_selectedKategoriId!),
        'lokasi_administratif': _lokasiController.text.trim(),
        'deskripsi_kerusakan': _deskripsiController.text.trim(),
        'latitude': _posisiUser!.latitude,
        'longitude': _posisiUser!.longitude,
        'akurasi_meter': _posisiUser!.accuracy,
        'url_foto_bukti': [urlFotoCloud],
      };

      final responseLapor = await http.post(
        Uri.parse('${Constants.baseUrl}/api/laporan'),
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode(payload),
      );

      setState(() => _isSubmitting = false);

      if (responseLapor.statusCode == 200) {
        _tampilkanPesan(
          'Laporan berhasil dikirim beserta GPS & Foto!',
          isError: false,
        );
        // Reset Form
        _lokasiController.clear();
        _deskripsiController.clear();
        setState(() {
          _selectedKategoriId = null;
          _fotoBukti = null;
          _posisiUser = null;
        });
      } else {
        _tampilkanPesan(
          'Gagal menyimpan laporan. Kode: ${responseLapor.statusCode}',
          isError: true,
        );
      }
    } catch (e) {
      setState(() => _isSubmitting = false);
      _tampilkanPesan('Terjadi kesalahan koneksi', isError: true);
    }
  }

  void _tampilkanPesan(String pesan, {bool isError = false}) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(
          pesan,
          style: const TextStyle(fontWeight: FontWeight.w500),
        ),
        backgroundColor: isError ? Colors.redAccent : Colors.green,
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
        margin: const EdgeInsets.all(16),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    if (_isLoadingKategori) {
      return const Center(child: CircularProgressIndicator());
    }

    return Scaffold(
      backgroundColor: Colors.grey.shade50,
      appBar: AppBar(
        title: const Text(
          'Buat Laporan',
          style: TextStyle(fontWeight: FontWeight.bold, fontSize: 18),
        ),
        backgroundColor: Colors.white,
        foregroundColor: Colors.blue.shade900,
        elevation: 0,
        centerTitle: true,
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.only(
          left: 24,
          right: 24,
          top: 16,
          bottom: 100,
        ),
        child: Form(
          key: _formKey,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // --- SEKSI FOTO ---
              const Text(
                'Foto Bukti',
                style: TextStyle(
                  fontWeight: FontWeight.bold,
                  color: Colors.grey,
                ),
              ),
              const SizedBox(height: 8),
              GestureDetector(
                onTap: _bukaKamera,
                child: Container(
                  height: 200,
                  width: double.infinity,
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(16),
                    border: Border.all(
                      color: Colors.blue.shade200,
                      style: BorderStyle.solid,
                    ),
                  ),
                  child: _fotoBukti != null
                      ? ClipRRect(
                          borderRadius: BorderRadius.circular(16),
                          child: Image.file(_fotoBukti!, fit: BoxFit.cover),
                        )
                      : Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Icon(
                              Icons.camera_alt_rounded,
                              size: 48,
                              color: Colors.blue.shade300,
                            ),
                            const SizedBox(height: 8),
                            Text(
                              'Ketuk untuk mengambil foto',
                              style: TextStyle(color: Colors.blue.shade400),
                            ),
                          ],
                        ),
                ),
              ),
              const SizedBox(height: 24),

              // --- SEKSI GPS ---
              const Text(
                'Koordinat GPS',
                style: TextStyle(
                  fontWeight: FontWeight.bold,
                  color: Colors.grey,
                ),
              ),
              const SizedBox(height: 8),
              Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(16),
                ),
                child: Row(
                  children: [
                    Icon(
                      _posisiUser != null
                          ? Icons.check_circle
                          : Icons.gps_fixed,
                      color: _posisiUser != null
                          ? Colors.green
                          : Colors.blue.shade400,
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Text(
                        _posisiUser != null
                            ? 'Lat: ${_posisiUser!.latitude.toStringAsFixed(4)}, Lng: ${_posisiUser!.longitude.toStringAsFixed(4)}'
                            : 'Lokasi satelit belum dilacak',
                        style: TextStyle(
                          color: _posisiUser != null
                              ? Colors.green.shade700
                              : Colors.grey.shade600,
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                    ),
                    if (_posisiUser == null)
                      TextButton(
                        onPressed: _isGettingLocation ? null : _dapatkanLokasi,
                        child: _isGettingLocation
                            ? const SizedBox(
                                height: 16,
                                width: 16,
                                child: CircularProgressIndicator(
                                  strokeWidth: 2,
                                ),
                              )
                            : const Text('Lacak'),
                      ),
                  ],
                ),
              ),
              const SizedBox(height: 24),

              // --- FORM ISIAN ---
              DropdownButtonFormField<String>(
                value: _selectedKategoriId,
                hint: const Text('Pilih Kategori Fasilitas'),
                decoration: InputDecoration(
                  filled: true,
                  fillColor: Colors.white,
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(16),
                    borderSide: BorderSide.none,
                  ),
                ),
                items: _kategoriList.map((kat) {
                  return DropdownMenuItem<String>(
                    value: kat['id'].toString(),
                    child: Text(kat['nama_kategori'] ?? ''),
                  );
                }).toList(),
                onChanged: (value) =>
                    setState(() => _selectedKategoriId = value),
                validator: (value) =>
                    value == null ? 'Kategori wajib dipilih' : null,
              ),
              const SizedBox(height: 16),

              TextFormField(
                controller: _lokasiController,
                decoration: InputDecoration(
                  labelText: 'Patokan Lokasi',
                  filled: true,
                  fillColor: Colors.white,
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(16),
                    borderSide: BorderSide.none,
                  ),
                ),
                validator: (value) =>
                    value!.isEmpty ? 'Patokan lokasi wajib diisi' : null,
              ),
              const SizedBox(height: 16),

              TextFormField(
                controller: _deskripsiController,
                maxLines: 4,
                decoration: InputDecoration(
                  labelText: 'Deskripsi Kerusakan',
                  filled: true,
                  fillColor: Colors.white,
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(16),
                    borderSide: BorderSide.none,
                  ),
                ),
                validator: (value) =>
                    value!.isEmpty ? 'Deskripsi wajib diisi' : null,
              ),
              const SizedBox(height: 32),

              // --- TOMBOL SUBMIT ---
              SizedBox(
                width: double.infinity,
                height: 55,
                child: ElevatedButton(
                  onPressed: _isSubmitting ? null : _kirimLaporan,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.blue.shade700,
                    foregroundColor: Colors.white,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(16),
                    ),
                  ),
                  child: _isSubmitting
                      ? const CircularProgressIndicator(color: Colors.white)
                      : const Text(
                          'Kirim Laporan Resmi',
                          style: TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
