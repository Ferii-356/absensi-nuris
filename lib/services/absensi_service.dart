import 'package:cloud_firestore/cloud_firestore.dart';
import '../models/absensi_model.dart';

class AbsensiService {
  final CollectionReference _absensiRef = FirebaseFirestore.instance.collection(
    'absensi_log',
  );

  // Semua log absensi hari ini, lintas kelas — dipakai buat kartu ringkasan dashboard
  Stream<List<AbsensiModel>> getAbsensiHariIni(DateTime tanggal) {
    final startOfDay = DateTime(tanggal.year, tanggal.month, tanggal.day);
    final endOfDay = startOfDay.add(const Duration(days: 1));

    return _absensiRef
        .where('waktu', isGreaterThanOrEqualTo: startOfDay)
        .where('waktu', isLessThan: endOfDay)
        .snapshots()
        .map(
          (snapshot) => snapshot.docs
              .map(
                (doc) => AbsensiModel.fromMap(
                  doc.id,
                  doc.data() as Map<String, dynamic>,
                ),
              )
              .toList(),
        );
  }

  // Cek apakah santri sudah absen di sesi & tanggal yang sama (cegah dobel)
  Future<bool> sudahAbsenSesiIni({
    required String santriId,
    required String sesi,
    required DateTime tanggal,
  }) async {
    final startOfDay = DateTime(tanggal.year, tanggal.month, tanggal.day);
    final endOfDay = startOfDay.add(const Duration(days: 1));

    final query = await _absensiRef
        .where('santri_id', isEqualTo: santriId)
        .where('sesi', isEqualTo: sesi)
        .where('waktu', isGreaterThanOrEqualTo: startOfDay)
        .where('waktu', isLessThan: endOfDay)
        .limit(1)
        .get();

    return query.docs.isNotEmpty;
  }

  Future<void> catatAbsensi(AbsensiModel absensi) async {
    await _absensiRef.add(absensi.toMap());
  }

  // Laporan absensi per kelas & tanggal
  Stream<List<AbsensiModel>> getAbsensiByKelasTanggal(
    String kelasId,
    DateTime tanggal,
  ) {
    final startOfDay = DateTime(tanggal.year, tanggal.month, tanggal.day);
    final endOfDay = startOfDay.add(const Duration(days: 1));

    return _absensiRef
        .where('kelas_id', isEqualTo: kelasId)
        .where('waktu', isGreaterThanOrEqualTo: startOfDay)
        .where('waktu', isLessThan: endOfDay)
        .snapshots()
        .map(
          (snapshot) => snapshot.docs
              .map(
                (doc) => AbsensiModel.fromMap(
                  doc.id,
                  doc.data() as Map<String, dynamic>,
                ),
              )
              .toList(),
        );
  }

  // Ambil semua izin yang masuk dari Telegram untuk kelas & tanggal tertentu
  Stream<List<Map<String, dynamic>>> getIzinByKelasTanggal(
    String kelasId,
    DateTime tanggal,
  ) {
    final startOfDay = DateTime(tanggal.year, tanggal.month, tanggal.day);
    final endOfDay = startOfDay.add(const Duration(days: 1));

    return FirebaseFirestore.instance
        .collection('izin')
        .where('kelas_id', isEqualTo: kelasId)
        .where('timestamp', isGreaterThanOrEqualTo: startOfDay)
        .where('timestamp', isLessThan: endOfDay)
        .snapshots()
        .map(
          (snapshot) => snapshot.docs
              .map(
                (doc) => {
                  'santri_id': doc['santri_id'],
                  'alasan': doc['alasan'],
                  'sesi': doc.data().containsKey('sesi') ? doc['sesi'] : '',
                },
              )
              .toList(),
        );
  }

  // Ambil semua absensi untuk kelas & rentang tanggal tertentu (dipakai untuk laporan mingguan/bulanan)
  Stream<List<AbsensiModel>> getAbsensiByKelasRentang(
    String kelasId,
    DateTime awal,
    DateTime akhir,
  ) {
    return FirebaseFirestore.instance
.collection('absensi_log')
            .where('kelas_id', isEqualTo: kelasId)
            .where('waktu', isGreaterThanOrEqualTo: awal)
            .where('waktu', isLessThan: akhir)
            .snapshots()
            .map(
              (snapshot) => snapshot.docs
                  .map(
                    (doc) => AbsensiModel.fromMap(
                      doc.id,
                      doc.data(),
                ),
              )
              .toList(),
        );
  }

  // Ambil semua izin untuk kelas & rentang tanggal tertentu
  Stream<List<Map<String, dynamic>>> getIzinByKelasRentang(
    String kelasId,
    DateTime awal,
    DateTime akhir,
  ) {
    return FirebaseFirestore.instance
        .collection('izin')
        .where('kelas_id', isEqualTo: kelasId)
        .where('timestamp', isGreaterThanOrEqualTo: awal)
        .where('timestamp', isLessThan: akhir)
        .snapshots()
        .map(
          (snapshot) => snapshot.docs
              .map(
                (doc) => {
                  'santri_id': doc['santri_id'],
                  'sesi': doc.data().containsKey('sesi') ? doc['sesi'] : '',
                },
              )
              .toList(),
        );
  }
}
