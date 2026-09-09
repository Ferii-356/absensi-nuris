import '../models/santri_model.dart';

// Penyimpanan sesi santri sementara (dalam memori) selama aplikasi berjalan.
// Tanpa package state management tambahan — cukup singleton statis.
class SantriSession {
  SantriSession._();

  static String? _authUid;
  static String? _nis;
  static String? _nama;
  static String? _kelasId;

  static String? get authUid => _authUid;
  static String? get nis => _nis;
  static String? get nama => _nama;
  static String? get kelasId => _kelasId;
  static bool get isLoggedIn => _nis != null && _authUid != null;

  static void setSession({
    required String authUid,
    required SantriModel santri,
  }) {
    _authUid = authUid;
    _nis = santri.nim;
    _nama = santri.nama;
    _kelasId = santri.kelasId;
  }

  static void clear() {
    _authUid = null;
    _nis = null;
    _nama = null;
    _kelasId = null;
  }
}