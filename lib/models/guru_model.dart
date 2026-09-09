class GuruModel {
  final String id;
  final String nama;

  GuruModel({required this.id, required this.nama});

  factory GuruModel.fromMap(String id, Map<String, dynamic> map) {
    return GuruModel(
      id: id,
      nama: map['nama'] ?? '',
    );
  }

  Map<String, dynamic> toMap() {
    return {'nama': nama};
  }
}