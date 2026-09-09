import 'package:cloud_firestore/cloud_firestore.dart';
import '../models/santri_model.dart';

class SantriService {
  final CollectionReference _santriRef = FirebaseFirestore.instance.collection(
    'santri',
  );

  // Ambil semua santri dalam satu kelas
  Stream<List<SantriModel>> getSantriByKelas(String kelasId) {
    return _santriRef
        .where('kelas_id', isEqualTo: kelasId)
        .snapshots()
        .map(
          (snapshot) => snapshot.docs
              .map(
                (doc) => SantriModel.fromMap(
                  doc.id,
                  doc.data() as Map<String, dynamic>,
                ),
              )
              .toList(),
        );
  }

  Stream<List<SantriModel>> getAllSantriAktif() {
    return _santriRef
        .where('status_aktif', isEqualTo: true)
        .snapshots()
        .map(
          (snapshot) => snapshot.docs
              .map(
                (doc) => SantriModel.fromMap(
                  doc.id,
                  doc.data() as Map<String, dynamic>,
                ),
              )
              .toList(),
        );
  }

  // Cari santri berdasarkan NIM (buat proses scan QR)
  Future<SantriModel?> getSantriByNim(String nim) async {
    final query = await _santriRef.where('nim', isEqualTo: nim).limit(1).get();
    if (query.docs.isEmpty) return null;
    return SantriModel.fromMap(
      query.docs.first.id,
      query.docs.first.data() as Map<String, dynamic>,
    );
  }

  Future<void> tambahSantri(SantriModel santri) async {
    await _santriRef.add(santri.toMap());
  }

  Future<void> updateSantri(String id, Map<String, dynamic> data) async {
    await _santriRef.doc(id).update(data);
  }

  Future<void> hapusSantri(String id) async {
    await _santriRef.doc(id).delete();
  }
}
