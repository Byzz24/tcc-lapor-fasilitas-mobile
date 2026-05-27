import 'package:flutter/material.dart';
import 'package:firebase_core/firebase_core.dart';
import 'screens/splash_screen.dart';
import 'services/notification_service.dart'; // Import layanan kita

void main() async {
  // Wajib ditambahkan sebelum Firebase.initializeApp()
  WidgetsFlutterBinding.ensureInitialized();

  // Menghidupkan mesin Firebase menggunakan konfigurasi google-services.json
  await Firebase.initializeApp();

  // Meminta izin dan menyedot token
  await NotificationService().initNotifications();

  runApp(const TccLaporApp());
}

class TccLaporApp extends StatelessWidget {
  const TccLaporApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'TCC Lapor',
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        colorScheme: ColorScheme.fromSeed(seedColor: Colors.blue),
        useMaterial3: true,
        fontFamily: 'Inter',
      ),
      home: const SplashScreen(),
    );
  }
}
