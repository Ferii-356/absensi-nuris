import 'package:cloud_firestore/cloud_firestore.dart';
import '../utils/constants.dart';

// Dokumen pengajuan izin santri di collection 'izin'.
class IzinModel {
  final String id;
  final String nis;
  final String nama;
  final String kelasId;
  final String jenisIzin;
  final DateTime tanggalMulai;
  final DateTime tanggalSelesai;
  final String alasan;
  final String status;
  final String? diprosesOleh;
  final DateTime createdAt;

  IzinModel({
    required this.id,
    required this.nis,
    required this.nama,
    required this.kelasId,
    required this.jenisIzin,
    required this.tanggalMulai,
    required this.tanggalSelesai,
    required this.alasan,
    required this.status,
    this.diprosesOleh,
    DateTime? createdAt,
  }) : createdAt = createdAt ?? DateTime.now();

  factory IzinModel.fromMap(String id, Map<String, dynamic> map) {
    return IzinModel(
      id: id,
      nis: map['nis'] ?? '',
      nama: map['nama'] ?? '',
      kelasId: map['kelasId'] ?? '',
      jenisIzin: map['jenisIzin'] ?? JenisIzin.lainnya,
      tanggalMulai: _parseTanggal(map['tanggalMulai']),
      tanggalSelesai: _parseTanggal(map['tanggalSelesai']),
      alasan: map['alasan'] ?? '',
      status: map['status'] ?? StatusIzin.pending,
      diprosesOleh: map['diprosesOleh'],
      createdAt: _parseTanggal(map['createdAt']),
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'nis': nis,
      'nama': nama,
      'kelasId': kelasId,
      'jenisIzin': jenisIzin,
      'tanggalMulai': tanggalMulai,
      'tanggalSelesai': tanggalSelesai,
      'alasan': alasan,
      'status': status,
      if (diprosesOleh != null) 'diprosesOleh': diprosesOleh,
      'createdAt': createdAt,
    };
  }
}

DateTime _parseTanggal(dynamic value) {
  if (value is Timestamp) return value.toDate();
  if (value is DateTime) return value;
  if (value is String) {
    final parse = DateTime.tryParse(value);
    if (parse != null) return parse;
  }
  return DateTime.now();
}