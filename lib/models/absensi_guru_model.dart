class AbsensiGuruModel {
  final String id;
  final String guruId;
  final String guruNama;
  final String sesi;
  final DateTime tanggal;
  final String status;
  final String dicatatOleh;

  AbsensiGuruModel({
    required this.id,
    required this.guruId,
    required this.guruNama,
    required this.sesi,
    required this.tanggal,
    required this.status,
    required this.dicatatOleh,
  });

  factory AbsensiGuruModel.fromMap(String id, Map<String, dynamic> map) {
    return AbsensiGuruModel(
      id: id,
      guruId: map['guru_id'] ?? '',
      guruNama: map['guru_nama'] ?? '',
      sesi: map['sesi'] ?? '',
      tanggal: map['tanggal']?.toDate() ?? DateTime.now(),
      status: map['status'] ?? '',
      dicatatOleh: map['dicatat_oleh'] ?? '',
    );
  }
}