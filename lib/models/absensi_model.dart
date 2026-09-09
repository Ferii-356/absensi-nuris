class AbsensiModel {
  final String id;
  final String santriId;
  final String kelasId;
  final String sesi; // maghrib, isya, dst
  final DateTime waktu;
  final String status; // hadir, izin, sakit, alpa, pulang
  final String keterangan;
  final String dicatatOleh;

  AbsensiModel({
    required this.id,
    required this.santriId,
    required this.kelasId,
    required this.sesi,
    required this.waktu,
    required this.status,
    this.keterangan = '',
    required this.dicatatOleh,
  });

  factory AbsensiModel.fromMap(String id, Map<String, dynamic> map) {
    return AbsensiModel(
      id: id,
      santriId: map['santri_id'] ?? '',
      kelasId: map['kelas_id'] ?? '',
      sesi: map['sesi'] ?? '',
      waktu: map['waktu']?.toDate() ?? DateTime.now(),
      status: map['status'] ?? '',
      keterangan: map['keterangan'] ?? '',
      dicatatOleh: map['dicatat_oleh'] ?? '',
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'santri_id': santriId,
      'kelas_id': kelasId,
      'sesi': sesi,
      'waktu': waktu,
      'status': status,
      'keterangan': keterangan,
      'dicatat_oleh': dicatatOleh,
    };
  }
}
