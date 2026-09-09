import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import '../main.dart';

class NotificationService {
  final FirebaseMessaging _messaging = FirebaseMessaging.instance;

  Future<void> init(String userId) async {
    // Minta izin notifikasi ke pengguna
    await _messaging.requestPermission(alert: true, badge: true, sound: true);

    // Ambil token perangkat ini, simpan ke data user di Firestore
    final token = await _messaging.getToken();
    if (token != null) {
      await _simpanToken(userId, token);
    }

    // Kalau token berubah (bisa terjadi sewaktu-waktu), update lagi
    _messaging.onTokenRefresh.listen((newToken) {
      _simpanToken(userId, newToken);
    });

    // Tampilkan notifikasi sederhana (SnackBar) saat app sedang dibuka
    FirebaseMessaging.onMessage.listen((message) {
      final context = navigatorKey.currentContext;
      if (context == null || !context.mounted) return;

      final judul = message.notification?.title ?? 'Notifikasi baru';
      final isi = message.notification?.body ?? '';

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('$judul\n$isi'),
          duration: const Duration(seconds: 4),
        ),
      );
    });
  }

  Future<void> _simpanToken(String userId, String token) async {
    await FirebaseFirestore.instance.collection('users').doc(userId).update({
      'fcm_token': token,
    });
  }
}
