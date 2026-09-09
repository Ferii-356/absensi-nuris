class KelasModel {
  final String id;
  final String namaKelas;
  final String waliKelasId;

  KelasModel({
    required this.id,
    required this.namaKelas,
    required this.waliKelasId,
  });

  factory KelasModel.fromMap(String id, Map<String, dynamic> map) {
    return KelasModel(
      id: id,
      namaKelas: map['nama_kelas'] ?? '',
      waliKelasId: map['wali_kelas_id'] ?? '',
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'nama_kelas': namaKelas,
      'wali_kelas_id': waliKelasId,
    };
  }
}
