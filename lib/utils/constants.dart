// Nama-nama collection Firestore, biar konsisten dan gak typo di seluruh project
class FirestoreCollections {
  static const String santri = 'santri';
  static const String kelas = 'kelas';
  static const String users = 'users';
  static const String absensiLog = 'absensi_log';
  static const String absensiGuru = 'absensi_guru';
  static const String guru = 'guru';
  static const String izin = 'izin';
  static const String izinHarian = 'izin_harian';
  static const String hariLibur = 'hari_libur';
  static const String santriAuth = 'santri_auth';
}

// Daftar sesi absensi
class SesiAbsensi {
  static const List<String> daftar = ['maghrib', 'isya', 'subuh'];
}

// Daftar status absensi
class StatusAbsensi {
  static const String hadir = 'hadir';
  static const String izin = 'izin';
  static const String sakit = 'sakit';
  static const String alpa = 'alpa';
  static const String pulang = 'pulang';
  static const String libur = 'libur';
}

// Status pengajuan izin
class StatusIzin {
  static const String pending = 'pending';
  static const String disetujui = 'disetujui';
  static const String ditolak = 'ditolak';
}

// Jenis izin yang bisa diajukan santri
class JenisIzin {
  static const String sakit = 'sakit';
  static const String pulang = 'pulang';
  static const String lainnya = 'lainnya';
  static const List<String> daftar = [sakit, pulang, lainnya];

  static String label(String jenis) {
    switch (jenis) {
      case sakit:
        return 'Sakit';
      case pulang:
        return 'Pulang';
      default:
        return 'Lainnya';
    }
  }

  // Padanan status absensi saat izin sudah disetujui (dipakai di laporan)
  static String padananStatusAbsensi(String jenis) {
    switch (jenis) {
      case sakit:
        return StatusAbsensi.sakit;
      case pulang:
        return StatusAbsensi.pulang;
      default:
        return StatusAbsensi.izin;
    }
  }
}

// Kunci tanggal berformat YYYY-MM-DD.
// Dipakai buat id dokumen izin_harian ("{nis}_{tanggal}") & hari_libur ("{tanggal}").
String tanggalKey(DateTime t) {
  final y = t.year.toString().padLeft(4, '0');
  final m = t.month.toString().padLeft(2, '0');
  final d = t.day.toString().padLeft(2, '0');
  return '$y-$m-$d';
}

// Awal hari (pukul 00:00) dari sebuah DateTime — buat normalisasi tanggal.
DateTime tanggalAwalHari(DateTime t) => DateTime(t.year, t.month, t.day);

const List<String> _namaBulanBaca = [
  'Jan',
  'Feb',
  'Mar',
  'Apr',
  'Mei',
  'Jun',
  'Jul',
  'Agu',
  'Sep',
  'Okt',
  'Nov',
  'Des',
];

// Label tanggal ringkas contoh: "5 Jan 2026"
String formatTanggalLabel(DateTime t) =>
    '${t.day} ${_namaBulanBaca[t.month - 1]} ${t.year}';