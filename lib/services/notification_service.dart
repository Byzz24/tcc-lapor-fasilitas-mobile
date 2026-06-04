import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';
import '../utils/constants.dart';

// Handler background message harus berupa top-level function (di luar class)
// agar dapat dieksekusi oleh isolate terpisah saat aplikasi tidak aktif
@pragma('vm:entry-point')
Future<void> _firebaseMessagingBackgroundHandler(RemoteMessage message) async {
  print('Notifikasi diterima di background: ${message.messageId}');
}

class NotificationService {
  final FirebaseMessaging _firebaseMessaging = FirebaseMessaging.instance;

  // Plugin untuk menampilkan notifikasi lokal saat aplikasi aktif di foreground
  final FlutterLocalNotificationsPlugin _localNotifications =
      FlutterLocalNotificationsPlugin();

  Future<void> initNotifications() async {
    // Pendaftaran handler untuk pesan yang masuk saat aplikasi mati atau di background
    FirebaseMessaging.onBackgroundMessage(_firebaseMessagingBackgroundHandler);

    // Permintaan izin notifikasi dari pengguna (muncul pop-up di Android 13+)
    NotificationSettings settings = await _firebaseMessaging.requestPermission(
      alert: true,
      badge: true,
      sound: true,
    );

    if (settings.authorizationStatus == AuthorizationStatus.authorized) {
      print('Izin notifikasi diberikan oleh pengguna');

      // Inisialisasi plugin notifikasi lokal untuk tampilan di mode foreground
      const AndroidInitializationSettings androidSettings =
          AndroidInitializationSettings('@mipmap/ic_launcher');
      const InitializationSettings initSettings =
          InitializationSettings(android: androidSettings);
      await _localNotifications.initialize(initSettings);

      // Pembuatan notification channel Android agar notifikasi tampil dengan prioritas tinggi
      const AndroidNotificationChannel channel = AndroidNotificationChannel(
        'tcc_lapor_channel',
        'TCC Lapor Notifikasi',
        description: 'Notifikasi dari aplikasi TCC Lapor',
        importance: Importance.high,
      );
      await _localNotifications
          .resolvePlatformSpecificImplementation<
              AndroidFlutterLocalNotificationsPlugin>()
          ?.createNotificationChannel(channel);

      // Listener untuk notifikasi yang masuk saat aplikasi sedang aktif di foreground
      FirebaseMessaging.onMessage.listen((RemoteMessage message) {
        print('Notifikasi diterima di foreground: ${message.notification?.title}');
        final notification = message.notification;
        if (notification != null) {
          _localNotifications.show(
            notification.hashCode,
            notification.title,
            notification.body,
            const NotificationDetails(
              android: AndroidNotificationDetails(
                'tcc_lapor_channel',
                'TCC Lapor Notifikasi',
                channelDescription: 'Notifikasi dari aplikasi TCC Lapor',
                importance: Importance.high,
                priority: Priority.high,
                icon: '@mipmap/ic_launcher',
              ),
            ),
          );
        }
      });

      // Pengambilan FCM Token unik perangkat ini
      String? fcmToken = await _firebaseMessaging.getToken();
      print('FCM Token: $fcmToken');

      // Pengiriman token ke backend agar server dapat mengirim notifikasi ke perangkat ini
      if (fcmToken != null) {
        await _kirimTokenKeServer(fcmToken);
      }

      // Pembaruan token ke server jika Google memperbaruinya secara otomatis
      _firebaseMessaging.onTokenRefresh.listen(_kirimTokenKeServer);
    }
  }

  // Dipanggil setelah proses login berhasil untuk memastikan token FCM
  // selalu tersimpan di database (saat app pertama dibuka, user_id belum ada)
  Future<void> kirimTokenSetelahLogin() async {
    try {
      String? fcmToken = await _firebaseMessaging.getToken();
      print('Mengirim ulang FCM Token setelah login: $fcmToken');
      if (fcmToken != null) {
        await _kirimTokenKeServer(fcmToken);
      }
    } catch (e) {
      print('Gagal mengirim token setelah login: $e');
    }
  }

  Future<void> _kirimTokenKeServer(String token) async {
    final prefs = await SharedPreferences.getInstance();
    final int? userId = prefs.getInt('user_id');

    // Hanya kirim ke server jika user sudah login (memiliki ID)
    if (userId != null) {
      try {
        final response = await http.put(
          Uri.parse('${Constants.baseUrl}/api/users/$userId/fcm-token'),
          headers: {'Content-Type': 'application/json'},
          body: jsonEncode({'fcm_token': token}),
        );

        if (response.statusCode == 200) {
          print('FCM Token berhasil disimpan ke database');
        }
      } catch (e) {
        print('Gagal mengirim token ke server: $e');
      }
    }
  }
}
