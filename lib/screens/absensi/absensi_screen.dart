import 'package:flutter/material.dart';
import 'package:mobile_scanner/mobile_scanner.dart';
import '../../models/absensi_guru_model.dart';
import '../../models/absensi_model.dart';
import '../../models/guru_model.dart';
import '../../models/user_model.dart';
import '../../services/santri_service.dart';
import '../../services/absensi_service.dart';
import '../../services/guru_absensi_service.dart';
import '../../utils/constants.dart';
import '../../utils/app_theme.dart';
import '../../widgets/entrance_animation.dart';

enum ModeAbsensi { santri, guru }

class AbsensiScreen extends StatefulWidget {
  final UserModel currentUser;

  const AbsensiScreen({super.key, required this.currentUser});

  @override
  State<AbsensiScreen> createState() => _AbsensiScreenState();
}

class _AbsensiScreenState extends State<AbsensiScreen> {
  final SantriService _santriService = SantriService();
  final AbsensiService _absensiService = AbsensiService();
  final GuruAbsensiService _guruService = GuruAbsensiService();

  ModeAbsensi _mode = ModeAbsensi.santri;
  String _sesi = SesiAbsensi.daftar.first;

  bool _sedangProses = false;
  String? _pesanStatus;
  Color _warnaPesan = AppColors.textSecondary;

  DateTime _tanggal = DateTime.now();
  bool _sedangSimpan = false;

  void _onDetect(BarcodeCapture capture) async {
    if (_sedangProses) return;

    final barcode = capture.barcodes.first;
    final nim = barcode.rawValue;
    if (nim == null) return;

    setState(() {
      _sedangProses = true;
      _pesanStatus = 'Memproses...';
      _warnaPesan = AppColors.textSecondary;
    });

    try {
      final santri = await _santriService.getSantriByNim(nim);

      if (santri == null) {
        setState(() {
          _pesanStatus = 'Santri dengan NIM "$nim" tidak ditemukan.';
          _warnaPesan = AppColors.alpa;
        });
        return;
      }

      final sudahAbsen = await _absensiService.sudahAbsenSesiIni(
        santriId: santri.id,
        sesi: _sesi,
        tanggal: DateTime.now(),
      );

      if (sudahAbsen) {
        setState(() {
          _pesanStatus = '${santri.nama} sudah absen sesi $_sesi hari ini.';
          _warnaPesan = AppColors.sakit;
        });
        return;
      }

      await _absensiService.catatAbsensi(
        AbsensiModel(
          id: '',
          santriId: santri.id,
          kelasId: santri.kelasId,
          sesi: _sesi,
          waktu: DateTime.now(),
          status: StatusAbsensi.hadir,
          dicatatOleh: widget.currentUser.id,
        ),
      );

      setState(() {
        _pesanStatus = '${santri.nama} berhasil absen ($_sesi)';
        _warnaPesan = AppColors.hadir;
      });
    } catch (e) {
      setState(() {
        _pesanStatus = 'Terjadi error: $e';
        _warnaPesan = AppColors.alpa;
      });
    } finally {
      _sedangProses = false;
    }
  }

  IconData _getIcon() {
    if (_pesanStatus == null) return Icons.qr_code_scanner;
    if (_warnaPesan == AppColors.hadir) return Icons.check_circle;
    if (_warnaPesan == AppColors.sakit) return Icons.info;
    return Icons.error;
  }

  Future<void> _pilihTanggal() async {
    final dipilih = await showDatePicker(
      context: context,
      initialDate: _tanggal,
      firstDate: DateTime(2024),
      lastDate: DateTime.now(),
      helpText: 'Pilih Tanggal Absensi',
    );
    if (dipilih != null) setState(() => _tanggal = dipilih);
  }

  Future<void> _tambahGuru() async {
    final controller = TextEditingController();
    final nama = await showDialog<String>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Tambah Guru'),
        content: TextField(
          controller: controller,
          autofocus: true,
          textCapitalization: TextCapitalization.words,
          decoration: const InputDecoration(
            labelText: 'Nama Guru',
            hintText: 'Contoh: Bapak Galih',
          ),
          onSubmitted: (v) => Navigator.pop(context, v),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Batal'),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(context, controller.text),
            child: const Text('Simpan'),
          ),
        ],
      ),
    );

    if (nama == null || nama.trim().isEmpty) return;
    try {
      await _guruService.tambahGuru(nama);
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text('Gagal menambah guru: $e')));
    }
  }

  Future<void> _hapusGuru(GuruModel guru) async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Hapus Guru'),
        content: Text('Yakin hapus "${guru.nama}" dari daftar guru?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Batal'),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text('Hapus'),
          ),
        ],
      ),
    );

    if (ok != true) return;
    try {
      await _guruService.hapusGuru(guru.id);
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text('Gagal menghapus guru: $e')));
    }
  }

  Future<void> _pilihStatus({
    required GuruModel guru,
    required AbsensiGuruModel? existing,
    required String status,
  }) async {
    if (_sedangSimpan) return;
    setState(() => _sedangSimpan = true);

    try {
      if (existing != null && existing.status == status) {
        await _guruService.hapusAbsensiGuru(
          guruId: guru.id,
          tanggal: _tanggal,
          sesi: _sesi,
        );
      } else {
        await _guruService.catatAbsensiGuru(
          guruId: guru.id,
          guruNama: guru.nama,
          sesi: _sesi,
          tanggal: _tanggal,
          status: status,
          dicatatOleh: widget.currentUser.id,
        );
      }
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text('Gagal menyimpan: $e')));
    } finally {
      if (mounted) setState(() => _sedangSimpan = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      body: SafeArea(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _buildHeader(),
            _buildModeToggle(),
            _buildSesiChips(),
            const SizedBox(height: 6),
            Expanded(
              child: _mode == ModeAbsensi.santri
                  ? _buildScanArea()
                  : _buildGuruArea(),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildHeader() {
    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 12, 12, 10),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              ...List.generate(
                4,
                (i) => Container(
                  margin: const EdgeInsets.only(right: 6),
                  width: 8,
                  height: 8,
                  color: i.isEven ? Colors.black : AppColors.accent,
                ),
              ),
              const Spacer(),
              IconButton(
                onPressed: () => Navigator.pop(context),
                icon: const Icon(Icons.arrow_back, color: Colors.black),
                tooltip: 'Kembali',
              ),
            ],
          ),
          const SizedBox(height: 10),
          const Text(
            'ABSENSI',
            style: TextStyle(
              fontSize: 26,
              fontWeight: FontWeight.w900,
              fontFamily: 'monospace',
              color: Colors.black,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            _mode == ModeAbsensi.santri
                ? 'Arahkan kamera ke QR code santri'
                : 'Pilih status kehadiran guru per sesi',
            style: const TextStyle(
              fontSize: 13,
              color: AppColors.textSecondary,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildModeToggle() {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 20),
      child: Row(
        children: [
          Expanded(
            child: _ModePill(
              label: 'SANTRI',
              icon: Icons.qr_code_scanner,
              aktif: _mode == ModeAbsensi.santri,
              warna: AppColors.accent,
              onTap: () => setState(() {
                _mode = ModeAbsensi.santri;
                _pesanStatus = null;
              }),
            ),
          ),
          const SizedBox(width: 8),
          Expanded(
            child: _ModePill(
              label: 'GURU',
              icon: Icons.groups_outlined,
              aktif: _mode == ModeAbsensi.guru,
              warna: AppColors.secondary,
              onTap: () => setState(() => _mode = ModeAbsensi.guru),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSesiChips() {
    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 14, 20, 0),
      child: Align(
        alignment: Alignment.centerLeft,
        child: Wrap(
          spacing: 8,
          runSpacing: 8,
          children: SesiAbsensi.daftar.map((sesi) {
            final terpilih = sesi == _sesi;
            return GestureDetector(
              onTap: () => setState(() => _sesi = sesi),
              child: AnimatedContainer(
                duration: const Duration(milliseconds: 200),
                curve: Curves.easeOut,
                padding: const EdgeInsets.symmetric(
                  horizontal: 14,
                  vertical: 8,
                ),
                decoration: BoxDecoration(
                  color: terpilih ? AppColors.accent : Colors.white,
                  borderRadius: BorderRadius.circular(20),
                  border: Border.all(color: Colors.black, width: 2),
                ),
                child: Text(
                  sesi.toUpperCase(),
                  style: const TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.w900,
                    fontFamily: 'monospace',
                    color: Colors.black,
                  ),
                ),
              ),
            );
          }).toList(),
        ),
      ),
    );
  }

  Widget _buildScanArea() {
    return Column(
      children: [
        Expanded(
          flex: 3,
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 20),
            child: Container(
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(6),
                border: Border.all(color: Colors.black, width: 2.5),
                boxShadow: const [
                  BoxShadow(
                    color: Colors.black,
                    offset: Offset(5, 5),
                    blurRadius: 0,
                  ),
                ],
              ),
              clipBehavior: Clip.hardEdge,
              child: ClipRRect(
                borderRadius: BorderRadius.circular(4),
                child: MobileScanner(
                  onDetect: _onDetect,
                  errorBuilder: (context, error, child) {
                    return Container(
                      color: Colors.black,
                      padding: const EdgeInsets.all(20),
                      child: Center(
                        child: Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            const Icon(
                              Icons.error_outline,
                              color: AppColors.alpa,
                              size: 48,
                            ),
                            const SizedBox(height: 12),
                            Text(
                              'Gagal membuka kamera:\n${error.errorDetails?.message ?? error.toString()}',
                              textAlign: TextAlign.center,
                              style: const TextStyle(
                                color: Colors.white,
                                fontSize: 13,
                              ),
                            ),
                          ],
                        ),
                      ),
                    );
                  },
                ),
              ),
            ),
          ),
        ),
        const SizedBox(height: 14),
        Expanded(
          flex: 1,
          child: Padding(
            padding: const EdgeInsets.fromLTRB(20, 0, 20, 16),
            child: Container(
              width: double.infinity,
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(6),
                border: Border.all(color: Colors.black, width: 2.5),
                boxShadow: const [
                  BoxShadow(
                    color: Colors.black,
                    offset: Offset(4, 4),
                    blurRadius: 0,
                  ),
                ],
              ),
              child: Center(
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(_getIcon(), color: _warnaPesan, size: 30),
                    const SizedBox(height: 8),
                    Text(
                      _pesanStatus ?? 'Menunggu hasil scan...',
                      textAlign: TextAlign.center,
                      style: TextStyle(
                        fontSize: 14,
                        fontWeight: FontWeight.w700,
                        color: _warnaPesan,
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildGuruArea() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(20, 14, 20, 0),
          child: Row(
            children: [
              const Icon(
                Icons.calendar_today_outlined,
                size: 16,
                color: AppColors.textSecondary,
              ),
              const SizedBox(width: 8),
              GestureDetector(
                onTap: _pilihTanggal,
                child: Row(
                  children: [
                    Text(
                      formatTanggalLabel(_tanggal),
                      style: const TextStyle(
                        fontSize: 14,
                        fontWeight: FontWeight.w800,
                        color: AppColors.textPrimary,
                      ),
                    ),
                    const SizedBox(width: 4),
                    const Icon(
                      Icons.arrow_drop_down,
                      color: AppColors.textSecondary,
                    ),
                  ],
                ),
              ),
              const Spacer(),
              _TombolTambah(onTap: _tambahGuru),
            ],
          ),
        ),
        const SizedBox(height: 6),
        Expanded(
          child: StreamBuilder<List<GuruModel>>(
            stream: _guruService.getSemuaGuru(),
            builder: (context, guruSnap) {
              final guruList = guruSnap.data ?? [];

              if (guruSnap.connectionState == ConnectionState.waiting) {
                return const Center(child: CircularProgressIndicator());
              }
              if (guruSnap.hasError) {
                return Center(child: Text('Error: ${guruSnap.error}'));
              }

              return StreamBuilder<List<AbsensiGuruModel>>(
                stream: _guruService.getAbsensiGuruTanggal(_tanggal),
                builder: (context, absensiSnap) {
                  final recordsSesi = (absensiSnap.data ?? [])
                      .where((a) => a.sesi == _sesi)
                      .toList();
                  final byGuru = <String, AbsensiGuruModel>{
                    for (final a in recordsSesi) a.guruId: a,
                  };

                  if (guruList.isEmpty) {
                    return Center(
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          const Icon(
                            Icons.groups_outlined,
                            size: 48,
                            color: AppColors.textSecondary,
                          ),
                          const SizedBox(height: 12),
                          const Text('Belum ada guru di daftar.'),
                          const SizedBox(height: 12),
                          _TombolTambah(onTap: _tambahGuru),
                        ],
                      ),
                    );
                  }

                  return ListView.builder(
                    padding: const EdgeInsets.fromLTRB(16, 8, 16, 24),
                    itemCount: guruList.length,
                    itemBuilder: (context, index) {
                      final guru = guruList[index];
                      final existing = byGuru[guru.id];

                      return _GuruRow(
                        guru: guru,
                        existing: existing,
                        index: index,
                        disable: _sedangSimpan,
                        onPilih: (status) => _pilihStatus(
                          guru: guru,
                          existing: existing,
                          status: status,
                        ),
                        onHapus: () => _hapusGuru(guru),
                      );
                    },
                  );
                },
              );
            },
          ),
        ),
      ],
    );
  }
}

class _ModePill extends StatelessWidget {
  final String label;
  final IconData icon;
  final bool aktif;
  final Color warna;
  final VoidCallback onTap;

  const _ModePill({
    required this.label,
    required this.icon,
    required this.aktif,
    required this.warna,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        curve: Curves.easeOut,
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
        decoration: BoxDecoration(
          color: aktif ? warna : Colors.white,
          borderRadius: BorderRadius.circular(20),
          border: Border.all(color: Colors.black, width: 2),
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(icon, color: Colors.black, size: 16),
            const SizedBox(width: 6),
            Text(
              label,
              style: const TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.w900,
                fontFamily: 'monospace',
                color: Colors.black,
                letterSpacing: 0.4,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
// ____P2____

class _TombolTambah extends StatelessWidget {
  final VoidCallback onTap;

  const _TombolTambah({required this.onTap});

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: const BoxDecoration(
        boxShadow: [
          BoxShadow(color: Colors.black, offset: Offset(3, 3), blurRadius: 0),
        ],
      ),
      child: ElevatedButton.icon(
        onPressed: onTap,
        icon: const Icon(Icons.person_add, size: 18),
        label: const Text('TAMBAH GURU'),
        style: ElevatedButton.styleFrom(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
          backgroundColor: AppColors.accent,
          foregroundColor: Colors.black,
        ),
      ),
    );
  }
}

class _GuruRow extends StatelessWidget {
  final GuruModel guru;
  final AbsensiGuruModel? existing;
  final int index;
  final bool disable;
  final ValueChanged<String> onPilih;
  final VoidCallback onHapus;

  const _GuruRow({
    required this.guru,
    required this.existing,
    required this.index,
    required this.disable,
    required this.onPilih,
    required this.onHapus,
  });

  static const List<_OpsiStatus> opsi = [
    _OpsiStatus(StatusAbsensi.hadir, 'HADIR', AppColors.hadir),
    _OpsiStatus(StatusAbsensi.izin, 'IZIN', AppColors.izin),
    _OpsiStatus(StatusAbsensi.sakit, 'SAKIT', AppColors.sakit),
    _OpsiStatus(StatusAbsensi.alpa, 'ALPA', AppColors.alpa),
  ];

  @override
  Widget build(BuildContext context) {
    return EntranceAnimation(
      delayMilliseconds: index * 60,
      slideOffset: const Offset(0, 22),
      child: Container(
        margin: const EdgeInsets.symmetric(vertical: 6),
        decoration: const BoxDecoration(
          boxShadow: [
            BoxShadow(color: Colors.black, offset: Offset(3, 3), blurRadius: 0),
          ],
        ),
        child: Card(
          margin: EdgeInsets.zero,
          child: Padding(
            padding: const EdgeInsets.fromLTRB(14, 12, 14, 12),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Container(
                      width: 36,
                      height: 36,
                      decoration: BoxDecoration(
                        color: AppColors.accent,
                        borderRadius: BorderRadius.circular(6),
                        border: Border.all(color: Colors.black, width: 1.5),
                      ),
                      child: Center(
                        child: Text(
                          guru.nama.isNotEmpty ? guru.nama[0].toUpperCase() : '?',
                          style: const TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.w900,
                            fontFamily: 'monospace',
                            color: Colors.black,
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: Text(
                        guru.nama,
                        style: const TextStyle(
                          fontSize: 15,
                          fontWeight: FontWeight.w800,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                    ),
                    IconButton(
                      onPressed: onHapus,
                      icon: const Icon(
                        Icons.delete_outline,
                        color: AppColors.alpa,
                        size: 20,
                      ),
                      tooltip: 'Hapus guru',
                    ),
                  ],
                ),
                const SizedBox(height: 10),
                Wrap(
                  spacing: 6,
                  runSpacing: 6,
                  children: opsi.map((o) {
                    final terpilih = existing?.status == o.status;
                    return _StatusPill(
                      label: o.label,
                      warna: o.warna,
                      terpilih: terpilih,
                      onTap: disable ? null : () => onPilih(o.status),
                    );
                  }).toList(),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _StatusPill extends StatelessWidget {
  final String label;
  final Color warna;
  final bool terpilih;
  final VoidCallback? onTap;

  const _StatusPill({
    required this.label,
    required this.warna,
    required this.terpilih,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        curve: Curves.easeOut,
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 7),
        decoration: BoxDecoration(
          color: terpilih ? warna : Colors.white,
          borderRadius: BorderRadius.circular(20),
          border: Border.all(
            color: terpilih ? warna : Colors.black,
            width: terpilih ? 2 : 1.5,
          ),
        ),
        child: Text(
          label,
          style: TextStyle(
            fontSize: 11,
            fontWeight: FontWeight.w900,
            fontFamily: 'monospace',
            color: terpilih ? Colors.white : warna,
            letterSpacing: 0.4,
          ),
        ),
      ),
    );
  }
}

class _OpsiStatus {
  final String status;
  final String label;
  final Color warna;

  const _OpsiStatus(this.status, this.label, this.warna);
}