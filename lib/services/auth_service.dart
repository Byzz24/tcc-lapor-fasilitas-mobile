import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';
import '../utils/constants.dart';

class AuthService {
  Future<Map<String, dynamic>> login(String email, String password) async {
    try {
      final response = await http.post(
        Uri.parse('${Constants.baseUrl}/api/auth/login'),
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode({'email': email, 'password': password}),
      );

      final data = jsonDecode(response.body);

      if (response.statusCode == 200) {
        // Simpan token dan data user ke penyimpanan lokal
        final prefs = await SharedPreferences.getInstance();
        await prefs.setString('token', data['access_token']);
        await prefs.setInt('user_id', data['user_info']['id']);
        await prefs.setString('user_nama', data['user_info']['nama']);
        await prefs.setString('user_role', data['user_info']['role']);

        return {'success': true, 'message': 'Login berhasil'};
      } else {
        return {'success': false, 'message': data['detail'] ?? 'Gagal login'};
      }
    } catch (e) {
      return {'success': false, 'message': 'Terjadi kesalahan koneksi server'};
    }
  }
}
