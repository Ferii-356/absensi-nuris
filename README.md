# Struktur Folder — Sistem Absensi Santri

## Cara pakai
1. Buka project Flutter kamu yang sudah ada di VS Code.
2. Copy semua isi folder `lib/` di sini, lalu **timpa (replace)** folder `lib/` di project Flutter kamu.
   - `main.dart` di sini berisi setup dasar (MaterialApp + LoginScreen). Kalau `main.dart` kamu yang lama sudah ada isinya, cek dulu sebelum ditimpa.
3. Tambahkan dependency ini di `pubspec.yaml`:
   ```yaml
   dependencies:
     flutter:
       sdk: flutter
     cloud_firestore: ^5.0.0
     firebase_core: ^3.0.0
   ```
   Lalu jalankan `flutter pub get`.
4. Jalankan `flutterfire configure` untuk generate `firebase_options.dart` dan hubungkan ke project Firebase `absensi-santri-nuris`.
5. Uncomment bagian `Firebase.initializeApp` di `main.dart`.

## Struktur
- `models/` — representasi data Firestore (santri, kelas, users, absensi) dalam bentuk class Dart
- `services/` — semua logic komunikasi ke Firestore (CRUD, query)
- `screens/` — halaman UI, dikelompokkan per fitur (login, dashboard, scan_qr, laporan, kelola_santri)
- `widgets/` — komponen UI yang dipakai berulang
- `utils/` — konstanta nama collection, role, dan status

Semua file screen masih berupa kerangka kosong (placeholder `TODO`) — tinggal diisi UI dan dihubungkan ke `services/` sesuai kebutuhan.
