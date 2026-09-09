class UserModel {
  final String id;
  final String nama;
  final String email;
  final String role; // super_admin, sekretaris, wali_kelas, pengabsen
  final List<String> kelasDikelola;

  UserModel({
    required this.id,
    required this.nama,
    required this.email,
    required this.role,
    this.kelasDikelola = const [],
  });

  factory UserModel.fromMap(String id, Map<String, dynamic> map) {
    return UserModel(
      id: id,
      nama: map['nama'] ?? '',
      email: map['email'] ?? '',
      role: map['role'] ?? '',
      kelasDikelola: List<String>.from(map['kelas_dikelola'] ?? []),
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'nama': nama,
      'email': email,
      'role': role,
      'kelas_dikelola': kelasDikelola,
    };
  }
}
