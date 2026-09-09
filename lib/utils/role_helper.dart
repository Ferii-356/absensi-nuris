// Konstanta role user, dan helper cek hak akses
class UserRole {
  static const String superAdmin = 'super_admin';
  static const String sekretaris = 'sekretaris';
  static const String waliKelas = 'wali_kelas';
  static const String pengabsen = 'pengabsen';
}

class RoleHelper {
  // Bisa kelola data (tambah/edit santri, dst)
  static bool bisaKelolaSantri(String role) {
    return role == UserRole.superAdmin || role == UserRole.sekretaris;
  }

  // Bisa melakukan scan absensi
  static bool bisaScanAbsensi(String role) {
    return role == UserRole.superAdmin ||
        role == UserRole.sekretaris ||
        role == UserRole.pengabsen;
  }

  // Bisa mencatat absensi guru (super_admin, sekretaris, pengabsen)
  static bool bisaKelolaAbsensiGuru(String role) {
    return bisaScanAbsensi(role);
  }

  // Bisa lihat laporan
  static bool bisaLihatLaporan(String role) {
    return true; // semua role boleh lihat laporan
  }

  // Bisa kelola izin santri (setujui/tolak) & tandai hari libur
  static bool bisaKelolaIzin(String role) {
    return role == UserRole.superAdmin ||
        role == UserRole.sekretaris ||
        role == UserRole.waliKelas;
  }

  // Label role dalam Bahasa Indonesia, buat ditampilkan di UI
  static String labelRole(String role) {
    switch (role) {
      case UserRole.superAdmin:
        return 'Super Admin';
      case UserRole.sekretaris:
        return 'Sekretaris';
      case UserRole.waliKelas:
        return 'Wali Kelas';
      case UserRole.pengabsen:
        return 'Pengabsen';
      default:
        return role;
    }
  }
}
