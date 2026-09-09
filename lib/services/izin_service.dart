import 'package:cloud_firestore/cloud_firestore.dart';
import '../models/izin_model.dart';
import '../utils/constants.dart';

// Layanan fitur izin santri:
// - santri: ajukan izin & lihat riwayat
// - staff: setujui/tolak izin (approve = tulis dokumen izin_harian per tanggal)
// - staff: tandai hari libur
class IzinService {
  final CollectionReference _izinRef = FirebaseFirestore.instance.collection(
    FirestoreCollections.izin,
  );
  final CollectionReference _izinHarianRef = FirebaseFirestore.instance.collection(
    FirestoreCollections.izinHarian,
  );
  final CollectionReference _hariLiburRef = FirebaseFirestore.instance.collection(
    FirestoreCollections.hariLibur,
  );

  // ── Santri: ajukan & lihat riwayat izin sendiri ──
  Stream<List<IzinModel>> getIzinSantri(String nis) {
    return _izinRef
        .where('nis', isEqualTo: nis)
        .orderBy('createdAt', descending: true)
        .snapshots()
        .map(_convertList);
  }

  Future<String> ajukanIzin(IzinModel izin) async {
    final data = izin.toMap()..['createdAt'] = FieldValue.serverTimestamp();
    final docRef = await _izinRef.add(data);
    return docRef.id;
  }

  // ── Staff: kelola izin pending ──
  Stream<List<IzinModel>> getIzinPending() {
    return _izinRef
        .where('status', isEqualTo: StatusIzin.pending)
        .orderBy('createdAt', descending: true)
        .snapshots()
        .map(_convertList);
  }

  Future<void> tolakIzin(String izinId, String diprosesOleh) async {
    await _izinRef.doc(izinId).update({
      'status': StatusIzin.ditolak,
      'diprosesOleh': diprosesOleh,
    });
  }

  // Setujui izin: ubah status izin + tulis satu dokumen izin_harian untuk
  // setiap tanggal izin dalam satu batch. Pakai set() (idempotent) biar
  // aman kalau izin kebetulan disetujui dua kali.
  Future<void> approveIzin(IzinModel izin, String diprosesOleh) async {
    final mulai = tanggalAwalHari(izin.tanggalMulai);
    final selesai = tanggalAwalHari(izin.tanggalSelesai);

    final batch = FirebaseFirestore.instance.batch();
    batch.update(_izinRef.doc(izin.id), {
      'status': StatusIzin.disetujui,
      'diprosesOleh': diprosesOleh,
    });

    var t = mulai;
    while (!t.isAfter(selesai)) {
      final key = tanggalKey(t);
      batch.set(_izinHarianRef.doc('${izin.nis}_$key'), {
        'nis': izin.nis,
        'tanggal': key,
        'izinRefId': izin.id,
        'jenisIzin': izin.jenisIzin,
      });
      t = t.add(const Duration(days: 1));
    }
    await batch.commit();
  }

  // ── Hari libur ──
  Future<void> tandaiLiburHariIni(String ditandaiOleh) async {
    final key = tanggalKey(DateTime.now());
    await _hariLiburRef.doc(key).set({
      'ditandaiOleh': ditandaiOleh,
      'createdAt': FieldValue.serverTimestamp(),
    });
  }

  // Semua tanggal libur (id dokumen = kunci tanggal YYYY-MM-DD).
  Future<Set<String>> getHariLibur() async {
    final snap = await _hariLiburRef.get();
    return snap.docs.map((doc) => doc.id).toSet();
  }

  // ── Izin harian (dipakai laporan) ──
  // Entri izin_harian dalam rentang [awal, akhir) hari.
  Future<List<Map<String, String>>> getIzinHarianRentang(
    DateTime awal,
    DateTime akhir,
  ) async {
    final query = await _izinHarianRef
        .where('tanggal', isGreaterThanOrEqualTo: tanggalKey(awal))
        .where('tanggal', isLessThan: tanggalKey(akhir))
        .get();
    return query.docs.map((doc) {
      final data = doc.data() as Map<String, dynamic>;
      return <String, String>{
        'nis': data['nis'] ?? '',
        'tanggal': data['tanggal'] ?? '',
        'jenisIzin': data['jenisIzin'] ?? JenisIzin.lainnya,
      };
    }).toList();
  }

  List<IzinModel> _convertList(QuerySnapshot snapshot) {
    return snapshot.docs
        .map((doc) => IzinModel.fromMap(doc.id, doc.data() as Map<String, dynamic>))
        .toList();
  }
}