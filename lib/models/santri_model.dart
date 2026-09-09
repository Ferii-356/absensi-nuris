class SantriModel {
  final String id;
  final String nim;
  final String nama;
  final String kelasId;
  final String jenisKelamin;
  final bool statusAktif;

  SantriModel({
    required this.id,
    required this.nim,
    required this.nama,
    required this.kelasId,
    required this.jenisKelamin,
    required this.statusAktif,
  });

  factory SantriModel.fromMap(String id, Map<String, dynamic> map) {
    return SantriModel(
      id: id,
      nim: map['nim'] ?? '',
      nama: map['nama'] ?? '',
      kelasId: map['kelas_id'] ?? '',
      jenisKelamin: map['jenis_kelamin'] ?? '',
      statusAktif: map['status_aktif'] ?? true,
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'nim': nim,
      'nama': nama,
      'kelas_id': kelasId,
      'jenis_kelamin': jenisKelamin,
      'status_aktif': statusAktif,
    };
  }
}
