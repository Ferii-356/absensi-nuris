import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import '../models/user_model.dart';
import '../utils/constants.dart';

class AuthService {
  final FirebaseAuth _auth = FirebaseAuth.instance;
  final CollectionReference _usersRef = FirebaseFirestore.instance.collection(
    'users',
  );

  // Login pakai email & password lewat Firebase Auth
  Future<UserModel?> login(String email, String password) async {
    final credential = await _auth.signInWithEmailAndPassword(
      email: email,
      password: password,
    );

    if (credential.user == null) return null;

    // Setelah berhasil login, ambil data role dari collection users
    final query = await _usersRef
        .where('email', isEqualTo: email)
        .limit(1)
        .get();

    if (query.docs.isEmpty) return null;

    return UserModel.fromMap(
      query.docs.first.id,
      query.docs.first.data() as Map<String, dynamic>,
    );
  }

  // Login khusus santri: pakai akun anonymous dari Firebase Auth.
  // Identitas sebenarnya (NIS) ditulis terpisah ke collection 'santri_auth'.
  Future<User> signInSantriAnon() async {
    final credential = await _auth.signInAnonymously();
    return credential.user!;
  }

  // Simpan pemetaan anonymous uid -> NIS santri. Dipakai Firestore rules
  // untuk membedakan santri vs staff sekaligus memverifikasi "izin milik sendiri".
  Future<void> simpanAuthNis(String uid, String nis) async {
    await FirebaseFirestore.instance
        .collection(FirestoreCollections.santriAuth)
        .doc(uid)
        .set({
      'nis': nis,
      'createdAt': FieldValue.serverTimestamp(),
    });
  }

  Future<void> logout() async {
    await _auth.signOut();
  }

  User? get currentUser => _auth.currentUser;
}
