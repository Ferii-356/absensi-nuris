import 'package:flutter/material.dart';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:printing/printing.dart';
import '../../services/santri_service.dart';
import '../../services/kelas_service.dart';
import '../../services/absensi_service.dart';
import '../../services/izin_service.dart';
import '../../services/guru_absensi_service.dart';
import '../../models/santri_model.dart';
import '../../models/kelas_model.dart';
import '../../models/user_model.dart';
import '../../models/guru_model.dart';
import '../../models/absensi_model.dart';
import '../../utils/constants.dart';
import '../../utils/app_theme.dart';
import '../../widgets/status_badge.dart';

class LaporanScreen extends StatefulWidget {
  final UserModel currentUser;

  const LaporanScreen({super.key, required this.currentUser});

  @override
  State<LaporanScreen> createState() => _LaporanScreenState();
}

class _LaporanScreenState extends State<LaporanScreen> {
  final SantriService _santriService = SantriService();
  final KelasService _kelasService = KelasService();
  final AbsensiService _absensiService = AbsensiService();

  String? _kelasIdTerpilih;
  String _namaKelasTerpilih = '';
  String _sesiTerpilih = SesiAbsensi.daftar.first;
  DateTime _tanggalTerpilih = DateTime.now();
  String _periode = 'harian';
  String _jenis = 'santri';

  bool _sedangMuat = false;
  bool _sedangExport = false;
  List<_BarisHarian>? _hasilHarian;
  List<_RingkasanSantri>? _hasilPeriode;
  List<_BarisGuruHarian>? _hasilGuruHarian;
  List<_RingkasanGuru>? _hasilGuruPeriode;

  (DateTime, DateTime) _getRentangTanggal() {
    if (_periode == 'mingguan') {
      final senin = _tanggalTerpilih.subtract(
        Duration(days: _tanggalTerpilih.weekday - 1),
      );
      final awal = DateTime(senin.year, senin.month, senin.day);
      return (awal, awal.add(const Duration(days: 7)));
    } else if (_periode == 'bulanan') {
      final awal = DateTime(_tanggalTerpilih.year, _tanggalTerpilih.month, 1);
      final akhir = DateTime(
        _tanggalTerpilih.year,
        _tanggalTerpilih.month + 1,
        1,
      );
      return (awal, akhir);
    } else {
      final awal = DateTime(
        _tanggalTerpilih.year,
        _tanggalTerpilih.month,
        _tanggalTerpilih.day,
      );
      return (awal, awal.add(const Duration(days: 1)));
    }
  }

  Future<void> _muatLaporan() async {
    if (_jenis == 'santri' && _kelasIdTerpilih == null) return;

    setState(() {
      _sedangMuat = true;
      _hasilHarian = null;
      _hasilPeriode = null;
      _hasilGuruHarian = null;
      _hasilGuruPeriode = null;
    });

    try {
      if (_jenis == 'guru') {
        await _muatLaporanGuru();
      } else {
        await _muatLaporanSantri();
      }
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text('Gagal memuat laporan: $e')));
    } finally {
      if (mounted) setState(() => _sedangMuat = false);
    }
  }

  Future<void> _muatLaporanSantri() async {
    final (awal, akhir) = _getRentangTanggal();

      final semuaSantriAsli = await _santriService
          .getSantriByKelas(_kelasIdTerpilih!)
          .first;

      // Hanya santri yang statusnya aktif yang dihitung di laporan
      final semuaSantri = semuaSantriAsli.where((s) => s.statusAktif).toList();

      final semuaAbsensi = await _absensiService
          .getAbsensiByKelasRentang(_kelasIdTerpilih!, awal, akhir)
          .first;

      // Sumber izin baru: hari libur + izin_harian (hasil approve izin santri).
      // Prioritas status: libur > izin_harian > absensi_log.
      final izinService = IzinService();
      final izinHarianList = await izinService.getIzinHarianRentang(awal, akhir);
      final hariLiburSet = await izinService.getHariLibur();

      final tanggalAwalKey = tanggalKey(awal);
      final tanggalAkhirKey = tanggalKey(akhir);
      final liburDalamRentang = hariLiburSet
          .where(
            (key) => key.compareTo(tanggalAwalKey) >= 0 &&
                key.compareTo(tanggalAkhirKey) < 0,
          )
          .toList();

      final nisSet = semuaSantri.map((s) => s.nim).toSet();
      final izinHarianKelas = izinHarianList
          .where((e) => nisSet.contains(e['nis']))
          .toList();

      // izin_harian bersifat full-day (tanpa sesi): tanggal -> set NIS
      final izinByTanggal = <String, Set<String>>{};
      final jenisIzinByKey = <String, String>{}; // "{tanggal}_{nis}" -> jenisIzin
      for (final e in izinHarianKelas) {
        final tanggal = e['tanggal'] ?? '';
        final nis = e['nis'] ?? '';
        izinByTanggal.putIfAbsent(tanggal, () => <String>{});
        izinByTanggal[tanggal]!.add(nis);
        jenisIzinByKey['${tanggal}_$nis'] = e['jenisIzin'] ?? JenisIzin.lainnya;
      }

      if (_periode == 'harian') {
        final dateKey = tanggalKey(_tanggalTerpilih);
        final hasil = semuaSantri.map((santri) {
          if (hariLiburSet.contains(dateKey)) {
            return _BarisHarian(
              santri: santri,
              status: StatusAbsensi.libur,
              keterangan: '',
            );
          }

          if (izinByTanggal[dateKey]?.contains(santri.nim) ?? false) {
            final jenis = jenisIzinByKey['${dateKey}_${santri.nim}'] ??
                JenisIzin.lainnya;
            return _BarisHarian(
              santri: santri,
              status: JenisIzin.padananStatusAbsensi(jenis),
              keterangan: '',
            );
          }

          final absensiSantri = semuaAbsensi.where(
            (a) => a.santriId == santri.id && a.sesi == _sesiTerpilih,
          );
          if (absensiSantri.isNotEmpty) {
            return _BarisHarian(
              santri: santri,
              status: absensiSantri.first.status,
              keterangan: absensiSantri.first.keterangan,
            );
          }

          return _BarisHarian(santri: santri, status: null, keterangan: '');
        }).toList();

        hasil.sort((a, b) {
          if (a.status == null && b.status != null) return -1;
          if (a.status != null && b.status == null) return 1;
          return a.santri.nama.compareTo(b.santri.nama);
        });

        setState(() => _hasilHarian = hasil);
      } else {
        final hasil = semuaSantri.map((santri) {
          final jumlah = <String, int>{
            'hadir': 0,
            'izin': 0,
            'sakit': 0,
            'alpa': 0,
            'pulang': 0,
            'libur': 0,
          };

          // absensi_log biasa; tanggal libur/izin dilewati karena sudah
          // dihitung lewat sumber izin (libur > izin_harian).
          for (final a in semuaAbsensi.where((a) => a.santriId == santri.id)) {
            final key = tanggalKey(a.waktu);
            if (hariLiburSet.contains(key)) continue;
            if (izinByTanggal[key]?.contains(santri.nim) ?? false) continue;
            jumlah[a.status] = (jumlah[a.status] ?? 0) + 1;
          }

          // izin_harian santri ini (sudah disetujui staff)
          for (final e in izinHarianKelas) {
            if (e['nis'] != santri.nim) continue;
            final status = JenisIzin.padananStatusAbsensi(
              e['jenisIzin'] ?? JenisIzin.lainnya,
            );
            jumlah[status] = (jumlah[status] ?? 0) + 1;
          }

          // setiap hari libur dalam rentang dihitung sekali per santri
          jumlah['libur'] = liburDalamRentang.length;

          return _RingkasanSantri(santri: santri, jumlah: jumlah);
        }).toList();

        hasil.sort((a, b) => a.santri.nama.compareTo(b.santri.nama));

        setState(() => _hasilPeriode = hasil);
      }
  }

  Future<void> _muatLaporanGuru() async {
    final (awal, akhir) = _getRentangTanggal();
    final guruService = GuruAbsensiService();
    final daftarGuru = await guruService.getSemuaGuruSekali();

    if (_periode == 'harian') {
      final absensi = await guruService.getAbsensiGuruRentang(awal, akhir);

      final hasil = daftarGuru.map((guru) {
        final bySesi = <String, String>{};
        for (final a in absensi) {
          if (a.guruId == guru.id) bySesi[a.sesi] = a.status;
        }
        return _BarisGuruHarian(guru: guru, bySesi: bySesi);
      }).toList();

      hasil.sort((a, b) => a.guru.nama.compareTo(b.guru.nama));

      setState(() => _hasilGuruHarian = hasil);
    } else {
      final absensi = await guruService.getAbsensiGuruRentang(awal, akhir);

      final hasil = daftarGuru.map((guru) {
        final jumlah = <String, int>{
          'hadir': 0,
          'izin': 0,
          'sakit': 0,
          'alpa': 0,
        };
        for (final a in absensi) {
          if (a.guruId != guru.id) continue;
          jumlah[a.status] = (jumlah[a.status] ?? 0) + 1;
        }
        return _RingkasanGuru(guru: guru, jumlah: jumlah);
      }).toList();

      hasil.sort((a, b) => a.guru.nama.compareTo(b.guru.nama));

      setState(() => _hasilGuruPeriode = hasil);
    }
  }

  Future<void> _tandaiAlpa(SantriModel santri) async {
    await _absensiService.catatAbsensi(
      AbsensiModel(
        id: '',
        santriId: santri.id,
        kelasId: santri.kelasId,
        sesi: _sesiTerpilih,
        waktu: _tanggalTerpilih,
        status: StatusAbsensi.alpa,
        dicatatOleh: widget.currentUser.id,
      ),
    );
    if (!mounted) return;
    ScaffoldMessenger.of(
      context,
    ).showSnackBar(SnackBar(content: Text('${santri.nama} ditandai Alpa')));
    _muatLaporan();
  }

  Future<void> _tandaiSemuaBelumAbsenJadiAlpa() async {
    final belumAbsen = (_hasilHarian ?? [])
        .where((b) => b.status == null)
        .toList();

    if (belumAbsen.isEmpty) return;

    final konfirmasi = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Tandai Alpa'),
        content: Text(
          'Tandai ${belumAbsen.length} santri yang belum absen sebagai Alpa?',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Batal'),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text('Ya, Tandai'),
          ),
        ],
      ),
    );

    if (konfirmasi != true) return;

    for (final baris in belumAbsen) {
      await _absensiService.catatAbsensi(
        AbsensiModel(
          id: '',
          santriId: baris.santri.id,
          kelasId: baris.santri.kelasId,
          sesi: _sesiTerpilih,
          waktu: _tanggalTerpilih,
          status: StatusAbsensi.alpa,
          dicatatOleh: widget.currentUser.id,
        ),
      );
    }

    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text('${belumAbsen.length} santri ditandai Alpa')),
    );
    _muatLaporan();
  }

  Future<void> _pilihTanggal() async {
    final dipilih = await showDatePicker(
      context: context,
      initialDate: _tanggalTerpilih,
      firstDate: DateTime(2024),
      lastDate: DateTime.now(),
    );
    if (dipilih != null) {
      setState(() => _tanggalTerpilih = dipilih);
      if (_kelasIdTerpilih != null) _muatLaporan();
    }
  }

  Map<String, int> _hitungRingkasanHarian() {
    final ringkasan = {
      'hadir': 0,
      'izin': 0,
      'sakit': 0,
      'alpa': 0,
      'pulang': 0,
      'libur': 0,
      'belum_absen': 0,
    };

    for (final baris in _hasilHarian ?? []) {
      if (baris.status == null) {
        ringkasan['belum_absen'] = ringkasan['belum_absen']! + 1;
      } else {
        ringkasan[baris.status!] = (ringkasan[baris.status!] ?? 0) + 1;
      }
    }
    return ringkasan;
  }

  String _formatTanggal(DateTime tanggal) {
    return '${tanggal.day.toString().padLeft(2, '0')}/${tanggal.month.toString().padLeft(2, '0')}/${tanggal.year}';
  }

  String _labelPeriode() {
    final (awal, akhir) = _getRentangTanggal();
    if (_periode == 'harian') {
      return _formatTanggal(_tanggalTerpilih);
    } else if (_periode == 'mingguan') {
      final akhirAsli = akhir.subtract(const Duration(days: 1));
      return '${_formatTanggal(awal)} - ${_formatTanggal(akhirAsli)}';
    } else {
      const namaBulan = [
        '',
        'Januari',
        'Februari',
        'Maret',
        'April',
        'Mei',
        'Juni',
        'Juli',
        'Agustus',
        'September',
        'Oktober',
        'November',
        'Desember',
      ];
      return '${namaBulan[_tanggalTerpilih.month]} ${_tanggalTerpilih.year}';
    }
  }

  String _labelStatus(String status) {
    switch (status) {
      case 'hadir':
        return 'Hadir';
      case 'izin':
        return 'Izin';
      case 'sakit':
        return 'Sakit';
      case 'alpa':
        return 'Alpa';
      case 'pulang':
        return 'Pulang';
      case 'libur':
        return 'Libur';
      default:
        return status;
    }
  }

  Future<void> _exportPdf() async {
    if (_jenis == 'guru') {
      await _exportPdfGuru();
      return;
    }

    final adaData = _periode == 'harian'
        ? (_hasilHarian != null && _hasilHarian!.isNotEmpty)
        : (_hasilPeriode != null && _hasilPeriode!.isNotEmpty);

    if (!adaData) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Pilih kelas dan pastikan data laporan sudah dimuat'),
        ),
      );
      return;
    }

    setState(() => _sedangExport = true);

    try {
      final pdf = pw.Document();

      final headerWidget = pw.Column(
        crossAxisAlignment: pw.CrossAxisAlignment.start,
        children: [
          pw.Text(
            'Laporan Absensi Santri',
            style: pw.TextStyle(fontSize: 18, fontWeight: pw.FontWeight.bold),
          ),
          pw.SizedBox(height: 4),
          pw.Text('PPPM Nuris', style: const pw.TextStyle(fontSize: 12)),
          pw.SizedBox(height: 12),
          pw.Text('Kelas: $_namaKelasTerpilih'),
          pw.Text(
            'Periode: ${_periode == 'harian'
                ? 'Harian'
                : _periode == 'mingguan'
                ? 'Mingguan'
                : 'Bulanan'}',
          ),
          if (_periode == 'harian')
            pw.Text('Sesi: ${_sesiTerpilih.toUpperCase()}'),
          pw.Text('Tanggal: ${_labelPeriode()}'),
          pw.SizedBox(height: 16),
        ],
      );

      pw.Widget tableWidget;

      if (_periode == 'harian') {
        tableWidget = pw.TableHelper.fromTextArray(
          headers: ['No', 'Nama', 'NIM', 'Status', 'Keterangan'],
          data: _hasilHarian!.asMap().entries.map((entry) {
            final i = entry.key + 1;
            final baris = entry.value;
            return [
              i.toString(),
              baris.santri.nama,
              baris.santri.nim,
              baris.status == null
                  ? 'Belum Absen'
                  : _labelStatus(baris.status!),
              baris.keterangan,
            ];
          }).toList(),
          headerStyle: pw.TextStyle(
            fontWeight: pw.FontWeight.bold,
            fontSize: 10,
          ),
          cellStyle: const pw.TextStyle(fontSize: 10),
          headerDecoration: const pw.BoxDecoration(
            color: PdfColor.fromInt(0xFF0F766E),
          ),
          headerAlignment: pw.Alignment.centerLeft,
          cellAlignment: pw.Alignment.centerLeft,
          border: pw.TableBorder.all(color: PdfColors.grey400, width: 0.5),
        );
      } else {
        tableWidget = pw.TableHelper.fromTextArray(
          headers: ['No', 'Nama', 'NIM', 'Hadir', 'Izin', 'Sakit', 'Alpa', 'Libur'],
          data: _hasilPeriode!.asMap().entries.map((entry) {
            final i = entry.key + 1;
            final r = entry.value;
            return [
              i.toString(),
              r.santri.nama,
              r.santri.nim,
              r.jumlah['hadir'].toString(),
              r.jumlah['izin'].toString(),
              r.jumlah['sakit'].toString(),
              r.jumlah['alpa'].toString(),
              r.jumlah['libur'].toString(),
            ];
          }).toList(),
          headerStyle: pw.TextStyle(
            fontWeight: pw.FontWeight.bold,
            fontSize: 10,
          ),
          cellStyle: const pw.TextStyle(fontSize: 10),
          headerDecoration: const pw.BoxDecoration(
            color: PdfColor.fromInt(0xFF0F766E),
          ),
          headerAlignment: pw.Alignment.centerLeft,
          cellAlignment: pw.Alignment.centerLeft,
          border: pw.TableBorder.all(color: PdfColors.grey400, width: 0.5),
        );
      }

      pdf.addPage(
        pw.MultiPage(
          pageFormat: PdfPageFormat.a4,
          build: (context) => [
            headerWidget,
            tableWidget,
            pw.SizedBox(height: 20),
            pw.Text(
              'Dicetak pada: ${_formatTanggal(DateTime.now())}',
              style: const pw.TextStyle(fontSize: 9, color: PdfColors.grey600),
            ),
          ],
        ),
      );

      final namaFile =
          'laporan_${_namaKelasTerpilih.replaceAll(' ', '_')}_${_periode}_${DateTime.now().millisecondsSinceEpoch}.pdf';

      await Printing.sharePdf(bytes: await pdf.save(), filename: namaFile);
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text('Gagal membuat PDF: $e')));
    } finally {
      if (mounted) setState(() => _sedangExport = false);
    }
  }

  Future<void> _exportPdfGuru() async {
    final adaData = _periode == 'harian'
        ? (_hasilGuruHarian != null && _hasilGuruHarian!.isNotEmpty)
        : (_hasilGuruPeriode != null && _hasilGuruPeriode!.isNotEmpty);

    if (!adaData) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Pastikan data laporan guru sudah dimuat'),
        ),
      );
      return;
    }

    setState(() => _sedangExport = true);

    try {
      final pdf = pw.Document();

      final headerWidget = pw.Column(
        crossAxisAlignment: pw.CrossAxisAlignment.start,
        children: [
          pw.Text(
            'Laporan Absensi Guru',
            style: pw.TextStyle(fontSize: 18, fontWeight: pw.FontWeight.bold),
          ),
          pw.SizedBox(height: 4),
          pw.Text('PPPM Nuris', style: const pw.TextStyle(fontSize: 12)),
          pw.SizedBox(height: 12),
          pw.Text(
            'Periode: ${_periode == 'harian'
                ? 'Harian'
                : _periode == 'mingguan'
                ? 'Mingguan'
                : 'Bulanan'}',
          ),
          pw.Text('Tanggal: ${_labelPeriode()}'),
          pw.SizedBox(height: 16),
        ],
      );

      pw.Widget tableWidget;

      if (_periode == 'harian') {
        tableWidget = pw.TableHelper.fromTextArray(
          headers: ['No', 'Nama', 'Subuh', 'Isya', 'Maghrib'],
          data: _hasilGuruHarian!.asMap().entries.map((entry) {
            final i = entry.key + 1;
            final baris = entry.value;
            return [
              i.toString(),
              baris.guru.nama,
              baris.bySesi['subuh'] ?? 'Belum',
              baris.bySesi['isya'] ?? 'Belum',
              baris.bySesi['maghrib'] ?? 'Belum',
            ];
          }).toList(),
          headerStyle: pw.TextStyle(
            fontWeight: pw.FontWeight.bold,
            fontSize: 10,
          ),
          cellStyle: const pw.TextStyle(fontSize: 10),
          headerDecoration: const pw.BoxDecoration(
            color: PdfColor.fromInt(0xFF0F766E),
          ),
          headerAlignment: pw.Alignment.centerLeft,
          cellAlignment: pw.Alignment.centerLeft,
          border: pw.TableBorder.all(color: PdfColors.grey400, width: 0.5),
        );
      } else {
        tableWidget = pw.TableHelper.fromTextArray(
          headers: ['No', 'Nama', 'Hadir', 'Izin', 'Sakit', 'Alpa'],
          data: _hasilGuruPeriode!.asMap().entries.map((entry) {
            final i = entry.key + 1;
            final r = entry.value;
            return [
              i.toString(),
              r.guru.nama,
              r.jumlah['hadir'].toString(),
              r.jumlah['izin'].toString(),
              r.jumlah['sakit'].toString(),
              r.jumlah['alpa'].toString(),
            ];
          }).toList(),
          headerStyle: pw.TextStyle(
            fontWeight: pw.FontWeight.bold,
            fontSize: 10,
          ),
          cellStyle: const pw.TextStyle(fontSize: 10),
          headerDecoration: const pw.BoxDecoration(
            color: PdfColor.fromInt(0xFF0F766E),
          ),
          headerAlignment: pw.Alignment.centerLeft,
          cellAlignment: pw.Alignment.centerLeft,
          border: pw.TableBorder.all(color: PdfColors.grey400, width: 0.5),
        );
      }

      pdf.addPage(
        pw.MultiPage(
          pageFormat: PdfPageFormat.a4,
          build: (context) => [
            headerWidget,
            tableWidget,
            pw.SizedBox(height: 20),
            pw.Text(
              'Dicetak pada: ${_formatTanggal(DateTime.now())}',
              style: const pw.TextStyle(fontSize: 9, color: PdfColors.grey600),
            ),
          ],
        ),
      );

      final namaFile =
          'laporan_guru_${_periode}_${DateTime.now().millisecondsSinceEpoch}.pdf';

      await Printing.sharePdf(bytes: await pdf.save(), filename: namaFile);
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text('Gagal membuat PDF: $e')));
    } finally {
      if (mounted) setState(() => _sedangExport = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final adaBelumAbsen =
        _periode == 'harian' &&
        (_hasilHarian ?? []).any((b) => b.status == null);

    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        title: const Text('Laporan Absensi'),
        actions: [
          IconButton(
            icon: _sedangExport
                ? const SizedBox(
                    height: 20,
                    width: 20,
                    child: CircularProgressIndicator(
                      color: Colors.white,
                      strokeWidth: 2,
                    ),
                  )
                : const Icon(Icons.picture_as_pdf_outlined),
            tooltip: 'Export PDF',
            onPressed: _sedangExport ? null : _exportPdf,
          ),
        ],
      ),
      body: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            SegmentedButton<String>(
              segments: const [
                ButtonSegment(value: 'santri', label: Text('Santri')),
                ButtonSegment(value: 'guru', label: Text('Guru')),
              ],
              selected: {_jenis},
              onSelectionChanged: (value) {
                setState(() {
                  _jenis = value.first;
                  _hasilHarian = null;
                  _hasilPeriode = null;
                  _hasilGuruHarian = null;
                  _hasilGuruPeriode = null;
                });
                if (_jenis == 'santri' && _kelasIdTerpilih != null) {
                  _muatLaporan();
                } else if (_jenis == 'guru') {
                  _muatLaporan();
                }
              },
              style: SegmentedButton.styleFrom(
                selectedBackgroundColor: AppColors.primary,
                selectedForegroundColor: Colors.white,
                backgroundColor: Colors.white,
                foregroundColor: Colors.black,
                side: const BorderSide(color: Colors.black, width: 2),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(6),
                ),
              ),
            ),
            const SizedBox(height: 12),
            SegmentedButton<String>(
              segments: const [
                ButtonSegment(value: 'harian', label: Text('Harian')),
                ButtonSegment(value: 'mingguan', label: Text('Mingguan')),
                ButtonSegment(value: 'bulanan', label: Text('Bulanan')),
              ],
              selected: {_periode},
              onSelectionChanged: (value) {
                setState(() => _periode = value.first);
                _muatLaporan();
              },
              style: SegmentedButton.styleFrom(
                selectedBackgroundColor: AppColors.accent,
                selectedForegroundColor: Colors.black,
                backgroundColor: Colors.white,
                foregroundColor: Colors.black,
                side: const BorderSide(color: Colors.black, width: 2),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(6),
                ),
              ),
            ),
            const SizedBox(height: 12),

            if (_jenis == 'santri') ...[
              StreamBuilder<List<KelasModel>>(
                stream: _kelasService.getAllKelas(),
                builder: (context, snapshot) {
                  if (!snapshot.hasData) {
                    return const LinearProgressIndicator();
                  }
                  final daftarKelas = snapshot.data!;
                  return DropdownButtonFormField<String>(
                    initialValue: _kelasIdTerpilih,
                    decoration: const InputDecoration(
                      labelText: 'Pilih Kelas',
                      prefixIcon: Icon(Icons.class_outlined),
                    ),
                    items: daftarKelas
                        .map(
                          (k) => DropdownMenuItem(
                            value: k.id,
                            child: Text(k.namaKelas),
                          ),
                        )
                        .toList(),
                    onChanged: (value) {
                      final kelas = daftarKelas.firstWhere(
                        (k) => k.id == value,
                      );
                      setState(() {
                        _kelasIdTerpilih = value;
                        _namaKelasTerpilih = kelas.namaKelas;
                      });
                      _muatLaporan();
                    },
                  );
                },
              ),
              const SizedBox(height: 12),
            ],

            Row(
              children: [
                if (_periode == 'harian' && _jenis == 'santri')
                  Expanded(
                    child: DropdownButtonFormField<String>(
                      initialValue: _sesiTerpilih,
                      decoration: const InputDecoration(
                        labelText: 'Sesi',
                        prefixIcon: Icon(Icons.access_time),
                      ),
                      items: SesiAbsensi.daftar
                          .map(
                            (s) => DropdownMenuItem(
                              value: s,
                              child: Text(s.toUpperCase()),
                            ),
                          )
                          .toList(),
                      onChanged: (value) {
                        setState(() => _sesiTerpilih = value!);
                        if (_kelasIdTerpilih != null) _muatLaporan();
                      },
                    ),
                  ),
                if (_periode == 'harian' && _jenis == 'santri')
                  const SizedBox(width: 12),
                Expanded(
                  child: InkWell(
                    onTap: _pilihTanggal,
                    borderRadius: BorderRadius.circular(12),
                    child: InputDecorator(
                      decoration: InputDecoration(
                        labelText: _periode == 'harian'
                            ? 'Tanggal'
                            : _periode == 'mingguan'
                            ? 'Pekan'
                            : 'Bulan',
                        prefixIcon: const Icon(Icons.calendar_today_outlined),
                      ),
                      child: Text(_labelPeriode()),
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 16),

            if (_sedangMuat) const LinearProgressIndicator(),

            if (_jenis == 'santri' && _periode == 'harian' && _hasilHarian != null) ...[
              _buildRingkasanHarian(),
              const SizedBox(height: 8),
            ],

            if (_jenis == 'guru' && _periode == 'harian' && _hasilGuruHarian != null) ...[
              _buildRingkasanGuru(),
              const SizedBox(height: 8),
            ],

            if (_jenis == 'santri' && adaBelumAbsen) ...[
              SizedBox(
                width: double.infinity,
                child: OutlinedButton.icon(
                  onPressed: _tandaiSemuaBelumAbsenJadiAlpa,
                  icon: const Icon(Icons.playlist_add_check, size: 18),
                  label: const Text(
                    'Tandai Semua yang Belum Absen sebagai Alpa',
                  ),
                  style: OutlinedButton.styleFrom(
                    foregroundColor: AppColors.alpa,
                    side: const BorderSide(color: AppColors.alpa),
                  ),
                ),
              ),
              const SizedBox(height: 8),
            ],

            Expanded(
              child: _jenis == 'santri'
                  ? _kelasIdTerpilih == null
                        ? const Center(
                            child: Text(
                              'Pilih kelas dulu untuk melihat laporan',
                              style: TextStyle(
                                color: AppColors.textSecondary,
                              ),
                            ),
                          )
                        : _periode == 'harian'
                        ? _buildListHarian()
                        : _buildListPeriode()
                  : _periode == 'harian'
                  ? _buildListGuruHarian()
                  : _buildListGuruPeriode(),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildListHarian() {
    if (_hasilHarian == null) {
      return const Center(child: Text('Memuat...'));
    }
    return ListView.builder(
      padding: const EdgeInsets.symmetric(vertical: 8),
      itemCount: _hasilHarian!.length,
      itemBuilder: (context, index) {
        final baris = _hasilHarian![index];
        return Card(
          child: ListTile(
            title: Text(
              baris.santri.nama,
              style: const TextStyle(fontWeight: FontWeight.w600),
            ),
            subtitle: Text('NIM: ${baris.santri.nim}'),
            trailing: baris.status == null
                ? TextButton(
                    onPressed: () => _tandaiAlpa(baris.santri),
                    child: const Text(
                      'Tandai Alpa',
                      style: TextStyle(fontSize: 12, color: AppColors.alpa),
                    ),
                  )
                : StatusBadge(status: baris.status!),
          ),
        );
      },
    );
  }

  Widget _buildListPeriode() {
    if (_hasilPeriode == null) {
      return const Center(child: Text('Memuat...'));
    }
    return ListView.builder(
      padding: const EdgeInsets.symmetric(vertical: 8),
      itemCount: _hasilPeriode!.length,
      itemBuilder: (context, index) {
        final ringkasan = _hasilPeriode![index];
        return Card(
          child: Padding(
            padding: const EdgeInsets.all(14),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  ringkasan.santri.nama,
                  style: const TextStyle(
                    fontWeight: FontWeight.w600,
                    fontSize: 15,
                  ),
                ),
                Text(
                  'NIM: ${ringkasan.santri.nim}',
                  style: const TextStyle(
                    color: AppColors.textSecondary,
                    fontSize: 12,
                  ),
                ),
                const SizedBox(height: 10),
                Wrap(
                  spacing: 8,
                  runSpacing: 8,
                  children: [
                    _miniChip(
                      'Hadir',
                      ringkasan.jumlah['hadir']!,
                      AppColors.hadir,
                    ),
                    _miniChip(
                      'Izin',
                      ringkasan.jumlah['izin']!,
                      AppColors.izin,
                    ),
                    _miniChip(
                      'Sakit',
                      ringkasan.jumlah['sakit']!,
                      AppColors.sakit,
                    ),
                    _miniChip(
                      'Alpa',
                      ringkasan.jumlah['alpa']!,
                      AppColors.alpa,
                    ),
                    _miniChip(
                      'Libur',
                      ringkasan.jumlah['libur']!,
                      AppColors.libur,
                    ),
                  ],
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  Widget _miniChip(String label, int jumlah, Color warna) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(
        color: warna.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(8),
      ),
      child: Text(
        '$label: $jumlah',
        style: TextStyle(
          color: warna,
          fontWeight: FontWeight.bold,
          fontSize: 12,
        ),
      ),
    );
  }

  Widget _buildRingkasanHarian() {
    final ringkasan = _hitungRingkasanHarian();
    final total = _hasilHarian!.length;

    return Wrap(
      spacing: 8,
      runSpacing: 8,
      children: [
        _chipRingkasan('Total', total, AppColors.textSecondary),
        _chipRingkasan('Hadir', ringkasan['hadir']!, AppColors.hadir),
        _chipRingkasan('Izin', ringkasan['izin']!, AppColors.izin),
        _chipRingkasan('Sakit', ringkasan['sakit']!, AppColors.sakit),
        _chipRingkasan('Alpa', ringkasan['alpa']!, AppColors.alpa),
        _chipRingkasan('Libur', ringkasan['libur']!, AppColors.libur),
        _chipRingkasan('Belum Absen', ringkasan['belum_absen']!, Colors.grey),
      ],
    );
  }

  Widget _chipRingkasan(String label, int jumlah, Color warna) {
    return Chip(
      backgroundColor: warna.withValues(alpha: 0.12),
      side: BorderSide(color: warna.withValues(alpha: 0.3)),
      label: Text(
        '$label: $jumlah',
        style: TextStyle(
          color: warna,
          fontWeight: FontWeight.bold,
          fontSize: 12,
        ),
      ),
    );
  }

  Color _warnaStatusGuru(String status) {
    switch (status) {
      case StatusAbsensi.hadir:
        return AppColors.hadir;
      case StatusAbsensi.izin:
        return AppColors.izin;
      case StatusAbsensi.sakit:
        return AppColors.sakit;
      case StatusAbsensi.alpa:
        return AppColors.alpa;
      default:
        return Colors.grey;
    }
  }

  Widget _buildListGuruHarian() {
    if (_hasilGuruHarian == null) {
      return const Center(child: Text('Memuat...'));
    }
    return ListView.builder(
      padding: const EdgeInsets.symmetric(vertical: 8),
      itemCount: _hasilGuruHarian!.length,
      itemBuilder: (context, index) {
        final baris = _hasilGuruHarian![index];
        return Card(
          child: Padding(
            padding: const EdgeInsets.all(14),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  baris.guru.nama,
                  style: const TextStyle(
                    fontWeight: FontWeight.w600,
                    fontSize: 15,
                  ),
                ),
                const SizedBox(height: 10),
                Wrap(
                  spacing: 8,
                  runSpacing: 8,
                  children: SesiAbsensi.daftar.map((sesi) {
                    final status = baris.bySesi[sesi];
                    if (status == null) {
                      return Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 10,
                          vertical: 6,
                        ),
                        decoration: BoxDecoration(
                          color: Colors.grey.withValues(alpha: 0.1),
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: Text(
                          '${sesi[0].toUpperCase()}${sesi.substring(1)}: Belum',
                          style: const TextStyle(
                            color: Colors.grey,
                            fontWeight: FontWeight.bold,
                            fontSize: 12,
                          ),
                        ),
                      );
                    }
                    final warna = _warnaStatusGuru(status);
                    return Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 10,
                        vertical: 6,
                      ),
                      decoration: BoxDecoration(
                        color: warna.withValues(alpha: 0.1),
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: Text(
                        '${sesi[0].toUpperCase()}${sesi.substring(1)}: ${_labelStatus(status)}',
                        style: TextStyle(
                          color: warna,
                          fontWeight: FontWeight.bold,
                          fontSize: 12,
                        ),
                      ),
                    );
                  }).toList(),
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  Widget _buildListGuruPeriode() {
    if (_hasilGuruPeriode == null) {
      return const Center(child: Text('Memuat...'));
    }
    return ListView.builder(
      padding: const EdgeInsets.symmetric(vertical: 8),
      itemCount: _hasilGuruPeriode!.length,
      itemBuilder: (context, index) {
        final ringkasan = _hasilGuruPeriode![index];
        return Card(
          child: Padding(
            padding: const EdgeInsets.all(14),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  ringkasan.guru.nama,
                  style: const TextStyle(
                    fontWeight: FontWeight.w600,
                    fontSize: 15,
                  ),
                ),
                const SizedBox(height: 10),
                Wrap(
                  spacing: 8,
                  runSpacing: 8,
                  children: [
                    _miniChip(
                      'Hadir',
                      ringkasan.jumlah['hadir']!,
                      AppColors.hadir,
                    ),
                    _miniChip(
                      'Izin',
                      ringkasan.jumlah['izin']!,
                      AppColors.izin,
                    ),
                    _miniChip(
                      'Sakit',
                      ringkasan.jumlah['sakit']!,
                      AppColors.sakit,
                    ),
                    _miniChip(
                      'Alpa',
                      ringkasan.jumlah['alpa']!,
                      AppColors.alpa,
                    ),
                  ],
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  Widget _buildRingkasanGuru() {
    final total = _hasilGuruHarian!.length;
    final ringkasan = <String, int>{
      'hadir': 0,
      'izin': 0,
      'sakit': 0,
      'alpa': 0,
      'belum': 0,
    };

    for (final baris in _hasilGuruHarian!) {
      if (baris.bySesi.isEmpty) {
        ringkasan['belum'] = ringkasan['belum']! + 1;
      } else {
        for (final status in baris.bySesi.values) {
          if (ringkasan.containsKey(status)) {
            ringkasan[status] = ringkasan[status]! + 1;
          }
        }
      }
    }

    return Wrap(
      spacing: 8,
      runSpacing: 8,
      children: [
        _chipRingkasan('Total Guru', total, AppColors.textSecondary),
        _chipRingkasan('Hadir', ringkasan['hadir']!, AppColors.hadir),
        _chipRingkasan('Izin', ringkasan['izin']!, AppColors.izin),
        _chipRingkasan('Sakit', ringkasan['sakit']!, AppColors.sakit),
        _chipRingkasan('Alpa', ringkasan['alpa']!, AppColors.alpa),
        _chipRingkasan('Belum Absen', ringkasan['belum']!, Colors.grey),
      ],
    );
  }
}

class _BarisHarian {
  final SantriModel santri;
  final String? status;
  final String keterangan;

  _BarisHarian({
    required this.santri,
    required this.status,
    required this.keterangan,
  });
}

class _RingkasanSantri {
  final SantriModel santri;
  final Map<String, int> jumlah;

  _RingkasanSantri({required this.santri, required this.jumlah});
}

class _BarisGuruHarian {
  final GuruModel guru;
  final Map<String, String> bySesi;

  _BarisGuruHarian({required this.guru, required this.bySesi});
}

class _RingkasanGuru {
  final GuruModel guru;
  final Map<String, int> jumlah;

  _RingkasanGuru({required this.guru, required this.jumlah});
}
