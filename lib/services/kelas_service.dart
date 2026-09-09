import 'package:cloud_firestore/cloud_firestore.dart';
import '../models/kelas_model.dart';

class KelasService {
  final CollectionReference _kelasRef =
      FirebaseFirestore.instance.collection('kelas');

  Stream<List<KelasModel>> getAllKelas() {
    return _kelasRef.snapshots().map((snapshot) => snapshot.docs
        .map((doc) =>
            KelasModel.fromMap(doc.id, doc.data() as Map<String, dynamic>))
        .toList());
  }

  Future<void> tambahKelas(KelasModel kelas) async {
    await _kelasRef.add(kelas.toMap());
  }
}
