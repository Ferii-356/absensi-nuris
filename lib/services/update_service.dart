import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:package_info_plus/package_info_plus.dart';
import 'package:dio/dio.dart';
import 'package:path_provider/path_provider.dart';
import 'package:open_filex/open_filex.dart';

class UpdateInfo {
  final bool adaUpdate;
  final String urlDownload;
  final String catatan;

  UpdateInfo({
    required this.adaUpdate,
    required this.urlDownload,
    required this.catatan,
  });
}

class UpdateService {
  Future<UpdateInfo> cekUpdate() async {
    try {
      final packageInfo = await PackageInfo.fromPlatform();
      final versiSekarang = int.tryParse(packageInfo.buildNumber) ?? 1;

      final doc = await FirebaseFirestore.instance
          .collection('app_config')
          .doc('version')
          .get();

      if (!doc.exists) {
        return UpdateInfo(adaUpdate: false, urlDownload: '', catatan: '');
      }

      final data = doc.data()!;
      final versiTerbaru = data['versi_terbaru'] ?? 1;

      return UpdateInfo(
        adaUpdate: versiTerbaru > versiSekarang,
        urlDownload: data['url_download'] ?? '',
        catatan: data['catatan'] ?? '',
      );
    } catch (e) {
      return UpdateInfo(adaUpdate: false, urlDownload: '', catatan: '');
    }
  }

  // Download APK, lalu buka installer Android.
  // Melempar Exception dengan pesan jelas kalau ada tahap yang gagal.
  Future<void> downloadDanInstall(
    String url, {
    required void Function(double progress) onProgress,
  }) async {
    final dio = Dio();

    // Pakai folder khusus aplikasi (app-specific external storage),
    // tidak butuh permission tambahan di Android 10+, dan bisa diakses installer.
    final dir = await getExternalStorageDirectory();
    if (dir == null) {
      throw Exception('Tidak bisa mengakses folder penyimpanan aplikasi.');
    }
    final savePath = '${dir.path}/nurisgo_update.apk';

    try {
      await dio.download(
        url,
        savePath,
        onReceiveProgress: (received, total) {
          if (total > 0) {
            onProgress(received / total);
          }
        },
      );
    } catch (e) {
      throw Exception('Gagal download file: $e');
    }

    final result = await OpenFilex.open(savePath);

    // OpenFilex tidak melempar error otomatis kalau gagal,
    // jadi kita cek manual hasilnya di sini.
    if (result.type != ResultType.done) {
      throw Exception(
        'Gagal membuka installer: ${result.message} (${result.type})',
      );
    }
  }
}
