import 'package:cloud_firestore/cloud_firestore.dart';
import '../models/absensi_guru_model.dart';
import '../models/guru_model.dart';
import '../utils/constants.dart';

class GuruAbsensiService {
  final CollectionReference _guruRef = FirebaseFirestore.instance.collection(
    FirestoreCollections.guru,
  );
  final CollectionReference _absensiGuruRef = FirebaseFirestore.instance
      .collection(FirestoreCollections.absensiGuru);

  // ── Daftar guru ──
  Stream<List<GuruModel>> getSemuaGuru() {
    return _guruRef
        .orderBy('nama')
        .snapshots()
        .map(
          (snapshot) => snapshot.docs
              .map(
                (doc) => GuruModel.fromMap(
                  doc.id,
                  doc.data() as Map<String, dynamic>,
                ),
              )
              .toList(),
        );
  }

  Future<List<GuruModel>> getSemuaGuruSekali() async {
    final snapshot = await _guruRef.orderBy('nama').get();
    return snapshot.docs
        .map(
          (doc) => GuruModel.fromMap(
            doc.id,
            doc.data() as Map<String, dynamic>,
          ),
        )
        .toList();
  }

  Future<void> tambahGuru(String nama) async {
    final trimmed = nama.trim();
    if (trimmed.isEmpty) return;
    await _guruRef.add({'nama': trimmed});
  }

  Future<void> hapusGuru(String id) async {
    await _guruRef.doc(id).delete();
  }

  // ── Absensi guru ──
  Stream<List<AbsensiGuruModel>> getAbsensiGuruTanggal(DateTime tanggal) {
    final start = DateTime(tanggal.year, tanggal.month, tanggal.day);
    final end = start.add(const Duration(days: 1));

    return _absensiGuruRef
        .where('tanggal', isGreaterThanOrEqualTo: start)
        .where('tanggal', isLessThan: end)
        .snapshots()
        .map(
          (snapshot) => snapshot.docs
              .map(
                (doc) => AbsensiGuruModel.fromMap(
                  doc.id,
                  doc.data() as Map<String, dynamic>,
                ),
              )
              .toList(),
        );
  }

  Future<List<AbsensiGuruModel>> getAbsensiGuruRentang(
    DateTime awal,
    DateTime akhir,
  ) async {
    final snapshot = await _absensiGuruRef
        .where('tanggal', isGreaterThanOrEqualTo: awal)
        .where('tanggal', isLessThan: akhir)
        .get();

    return snapshot.docs
        .map(
          (doc) => AbsensiGuruModel.fromMap(
            doc.id,
            doc.data() as Map<String, dynamic>,
          ),
        )
        .toList();
  }

  String _docId({
    required String guruId,
    required DateTime tanggal,
    required String sesi,
  }) =>
      '${guruId}_${tanggalKey(tanggal)}_$sesi';

  Future<void> catatAbsensiGuru({
    required String guruId,
    required String guruNama,
    required String sesi,
    required DateTime tanggal,
    required String status,
    required String dicatatOleh,
  }) async {
    await _absensiGuruRef
        .doc(_docId(guruId: guruId, tanggal: tanggal, sesi: sesi))
        .set({
          'guru_id': guruId,
          'guru_nama': guruNama,
          'sesi': sesi,
          'tanggal': tanggalAwalHari(tanggal),
          'status': status,
          'dicatat_oleh': dicatatOleh,
          'waktu': FieldValue.serverTimestamp(),
        });
  }

  Future<void> hapusAbsensiGuru({
    required String guruId,
    required DateTime tanggal,
    required String sesi,
  }) async {
    await _absensiGuruRef
        .doc(_docId(guruId: guruId, tanggal: tanggal, sesi: sesi))
        .delete();
  }
}