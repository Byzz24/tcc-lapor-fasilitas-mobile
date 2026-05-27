import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:image_picker/image_picker.dart';
import 'package:http_parser/http_parser.dart';
import 'dart:convert';
import 'package:http/http.dart' as http;
import '../utils/constants.dart';
import 'login_screen.dart';

class ProfilScreen extends StatefulWidget {
  final Function(bool)? onScrollDirectionChanged;
  const ProfilScreen({super.key, this.onScrollDirectionChanged});

  @override
  State<ProfilScreen> createState() => _ProfilScreenState();
}

class _ProfilScreenState extends State<ProfilScreen> {
  int? _userId;
  String _nama = 'Memuat...';
  String _email = '';
  String _role = '';
  String _noTelp = '';
  String _urlFoto = '';
  bool _isLoading = true;

  final TextEditingController _namaController = TextEditingController();
  final TextEditingController _telpController = TextEditingController();
  final TextEditingController _passLamaController = TextEditingController();
  final TextEditingController _passBaruController = TextEditingController();

  @override
  void initState() {
    super.initState();
    _tarikDataLangsungDariDatabase();
  }

  // Penarikan data profil terbaru langsung dari server
  Future<void> _tarikDataLangsungDariDatabase() async {
    final prefs = await SharedPreferences.getInstance();
    _userId = prefs.getInt('user_id');

    if (_userId != null) {
      try {
        final response = await http.get(
          Uri.parse('${Constants.baseUrl}/api/users/$_userId/profil'),
        );
        if (response.statusCode == 200) {
          final data = jsonDecode(response.body)['data'];
          setState(() {
            _nama = data['nama'] ?? 'Pengguna';
            _email = data['email'] ?? '';
            _role = data['role'] ?? 'warga';
            _noTelp = data['no_telp'] ?? '';

            _urlFoto =
                prefs.getString('url_foto') ??
                '';

            _namaController.text = _nama;
            _telpController.text = _noTelp;
            _isLoading = false;
          });
        } else {
          setState(() => _isLoading = false);
        }
      } catch (e) {
        setState(() => _isLoading = false);
      }
    } else {
      setState(() => _isLoading = false);
    }
  }

  Future<void> _simpanProfilDasar() async {
    if (_userId == null) return;
    setState(() => _isLoading = true);

    try {
      final response = await http.put(
        Uri.parse('${Constants.baseUrl}/api/users/$_userId/profil'),
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode({
          'nama': _namaController.text.trim(),
          'no_telp': _telpController.text.trim(),
        }),
      );

      if (response.statusCode == 200) {
        setState(() {
          _nama = _namaController.text.trim();
          _noTelp = _telpController.text.trim();
        });
        _tampilkanPesan('Profil berhasil diperbarui!');
      } else {
        _tampilkanPesan('Gagal memperbarui data profil', isError: true);
      }
    } catch (e) {
      _tampilkanPesan('Masalah koneksi ke server', isError: true);
    } finally {
      setState(() => _isLoading = false);
    }
  }

  Future<void> _ubahPassword() async {
    if (_passLamaController.text.isEmpty || _passBaruController.text.isEmpty) {
      _tampilkanPesan('Password lama dan baru harus diisi', isError: true);
      return;
    }

    setState(() => _isLoading = true);
    try {
      final response = await http.put(
        Uri.parse('${Constants.baseUrl}/api/users/$_userId/profile/password'),
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode({
          'password_lama': _passLamaController.text,
          'password_baru': _passBaruController.text,
        }),
      );

      if (response.statusCode == 200) {
        _passLamaController.clear();
        _passBaruController.clear();
        _tampilkanPesan('Password keamanan berhasil diubah!');
      } else {
        _tampilkanPesan(
          'Gagal ganti password. Password lama salah',
          isError: true,
        );
      }
    } catch (e) {
      _tampilkanPesan('Gagal menghubungi peladen', isError: true);
    } finally {
      setState(() => _isLoading = false);
    }
  }

  Future<void> _ubahFotoProfil() async {
    final ImagePicker picker = ImagePicker();
    final XFile? foto = await picker.pickImage(
      source: ImageSource.gallery,
      imageQuality: 40,
    );

    if (foto != null && _userId != null) {
      setState(() => _isLoading = true);
      try {
        var request = http.MultipartRequest(
          'POST',
          Uri.parse('${Constants.baseUrl}/api/upload/avatar-user'),
        );
        request.files.add(
          await http.MultipartFile.fromPath(
            'file',
            foto.path,
            contentType: MediaType('image', 'jpeg'),
          ),
        );

        var response = await request.send();
        if (response.statusCode == 200) {
          var responseData = await response.stream.bytesToString();
          String urlBaru = jsonDecode(responseData)['url_foto'];

          final prefs = await SharedPreferences.getInstance();
          await prefs.setString('url_foto', urlBaru);

          setState(() => _urlFoto = urlBaru);
          _tampilkanPesan('Foto profil baru berhasil dipasang!');
        } else {
          _tampilkanPesan('Gagal memproses unggah foto', isError: true);
        }
      } catch (e) {
        _tampilkanPesan(
          'Gagal terhubung dengan server cloud storage',
          isError: true,
        );
      } finally {
        setState(() => _isLoading = false);
      }
    }
  }

  void _logout() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.clear();
    if (!mounted) return;
    Navigator.of(context).pushAndRemoveUntil(
      MaterialPageRoute(builder: (context) => const LoginScreen()),
      (route) => false,
    );
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
    return Scaffold(
      backgroundColor: Colors.grey.shade50,
      appBar: AppBar(
        title: const Text(
          'Pengaturan Profil',
          style: TextStyle(fontWeight: FontWeight.bold, fontSize: 18),
        ),
        backgroundColor: Colors.white,
        foregroundColor: Colors.blue.shade900,
        elevation: 0,
        centerTitle: true,
        actions: [
          IconButton(
            icon: const Icon(Icons.logout, color: Colors.redAccent),
            onPressed: _logout,
          ),
        ],
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : NotificationListener<UserScrollNotification>(
              onNotification: (notification) {
                if (widget.onScrollDirectionChanged != null) {
                  if (notification.direction == ScrollDirection.reverse) {
                    widget.onScrollDirectionChanged!(false);
                  } else if (notification.direction ==
                      ScrollDirection.forward) {
                    widget.onScrollDirectionChanged!(true);
                  }
                }
                return true;
              },
              child: ListView(
                physics: const AlwaysScrollableScrollPhysics(),
                padding: const EdgeInsets.only(
                  left: 24,
                  right: 24,
                  top: 24,
                  bottom: 120,
                ),
                children: [
                  CircleAvatar(
                    radius: 50,
                    backgroundColor: Colors.blue.shade100,
                    backgroundImage: _urlFoto.isNotEmpty
                        ? NetworkImage(_urlFoto)
                        : null,
                    child: _urlFoto.isEmpty
                        ? const Icon(
                            Icons.person,
                            size: 50,
                            color: Colors.white,
                          )
                        : null,
                  ),
                  const SizedBox(height: 16),
                  Text(
                    _nama,
                    textAlign: TextAlign.center,
                    style: const TextStyle(
                      fontSize: 22,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  Text(
                    _email.isNotEmpty
                        ? '${_role.toUpperCase()} | $_email'
                        : _role.toUpperCase(),
                    textAlign: TextAlign.center,
                    style: TextStyle(color: Colors.grey.shade600),
                  ),
                  const SizedBox(height: 16),
                  Center(
                    child: ElevatedButton.icon(
                      onPressed: _ubahFotoProfil,
                      icon: const Icon(Icons.camera_alt, size: 18),
                      label: const Text('Ganti Foto'),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Colors.blue.shade50,
                        foregroundColor: Colors.blue.shade700,
                        elevation: 0,
                      ),
                    ),
                  ),
                  const SizedBox(height: 32),

                  const Text(
                    'Informasi Dasar',
                    style: TextStyle(
                      fontWeight: FontWeight.bold,
                      color: Colors.grey,
                    ),
                  ),
                  const SizedBox(height: 12),
                  TextField(
                    controller: _namaController,
                    decoration: InputDecoration(
                      labelText: 'Nama Lengkap',
                      filled: true,
                      fillColor: Colors.white,
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(12),
                        borderSide: BorderSide.none,
                      ),
                    ),
                  ),
                  const SizedBox(height: 12),
                  TextField(
                    controller: _telpController,
                    keyboardType: TextInputType.phone,
                    decoration: InputDecoration(
                      labelText: 'Nomor Telepon',
                      filled: true,
                      fillColor: Colors.white,
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(12),
                        borderSide: BorderSide.none,
                      ),
                    ),
                  ),
                  const SizedBox(height: 16),
                  SizedBox(
                    width: double.infinity,
                    height: 48,
                    child: ElevatedButton(
                      onPressed: _simpanProfilDasar,
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Colors.blue.shade700,
                        foregroundColor: Colors.white,
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                      ),
                      child: const Text(
                        'Simpan Perubahan Profil',
                        style: TextStyle(fontWeight: FontWeight.bold),
                      ),
                    ),
                  ),

                  const SizedBox(height: 32),
                  const Text(
                    'Keamanan Akun',
                    style: TextStyle(
                      fontWeight: FontWeight.bold,
                      color: Colors.grey,
                    ),
                  ),
                  const SizedBox(height: 12),
                  TextField(
                    controller: _passLamaController,
                    obscureText: true,
                    decoration: InputDecoration(
                      labelText: 'Password Lama',
                      filled: true,
                      fillColor: Colors.white,
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(12),
                        borderSide: BorderSide.none,
                      ),
                    ),
                  ),
                  const SizedBox(height: 12),
                  TextField(
                    controller: _passBaruController,
                    obscureText: true,
                    decoration: InputDecoration(
                      labelText: 'Password Baru',
                      filled: true,
                      fillColor: Colors.white,
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(12),
                        borderSide: BorderSide.none,
                      ),
                    ),
                  ),
                  const SizedBox(height: 16),
                  SizedBox(
                    width: double.infinity,
                    height: 48,
                    child: ElevatedButton(
                      onPressed: _ubahPassword,
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Colors.red.shade400,
                        foregroundColor: Colors.white,
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                      ),
                      child: const Text(
                        'Ubah Password',
                        style: TextStyle(fontWeight: FontWeight.bold),
                      ),
                    ),
                  ),
                ],
              ),
            ),
    );
  }
}
