import 'package:flutter/material.dart';
import '../../models/absensi_guru_model.dart';
import '../../models/guru_model.dart';
import '../../models/user_model.dart';
import '../../services/guru_absensi_service.dart';
import '../../utils/app_theme.dart';
import '../../utils/constants.dart';
import '../../widgets/entrance_animation.dart';

class AbsensiGuruScreen extends StatefulWidget {
  final UserModel currentUser;

  const AbsensiGuruScreen({super.key, required this.currentUser});

  @override
  State<AbsensiGuruScreen> createState() => _AbsensiGuruScreenState();
}

class _AbsensiGuruScreenState extends State<AbsensiGuruScreen> {
  final GuruAbsensiService _service = GuruAbsensiService();

  String _sesi = SesiAbsensi.daftar.first;
  DateTime _tanggal = DateTime.now();
  bool _sedangSimpan = false;

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
      await _service.tambahGuru(nama);
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
      await _service.hapusGuru(guru.id);
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
        await _service.hapusAbsensiGuru(
          guruId: guru.id,
          tanggal: _tanggal,
          sesi: _sesi,
        );
      } else {
        await _service.catatAbsensiGuru(
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
            _buildSesiChips(),
            _buildTanggalBar(),
            const SizedBox(height: 6),
            Expanded(
              child: StreamBuilder<List<GuruModel>>(
                stream: _service.getSemuaGuru(),
                builder: (context, guruSnap) {
                  final guruList = guruSnap.data ?? [];

                  if (guruSnap.connectionState == ConnectionState.waiting) {
                    return const Center(child: CircularProgressIndicator());
                  }
                  if (guruSnap.hasError) {
                    return Center(child: Text('Error: ${guruSnap.error}'));
                  }

                  return StreamBuilder<List<AbsensiGuruModel>>(
                    stream: _service.getAbsensiGuruTanggal(_tanggal),
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
        ),
      ),
    );
  }

  Widget _buildHeader() {
    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 12, 20, 12),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: List.generate(
              4,
              (i) => Container(
                margin: const EdgeInsets.only(right: 6),
                width: 8,
                height: 8,
                color: i.isEven ? Colors.black : AppColors.accent,
              ),
            ),
          ),
          const SizedBox(height: 10),
          Row(
            children: [
              const Expanded(
                child: Text(
                  'ABSENSI GURU',
                  style: TextStyle(
                    fontSize: 26,
                    fontWeight: FontWeight.w900,
                    fontFamily: 'monospace',
                    color: Colors.black,
                  ),
                ),
              ),
              _TombolTambah(onTap: _tambahGuru),
            ],
          ),
          const SizedBox(height: 4),
          const Text(
            'Pilih status kehadiran guru per sesi',
            style: TextStyle(fontSize: 13, color: AppColors.textSecondary),
          ),
        ],
      ),
    );
  }

  Widget _buildSesiChips() {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 20),
      child: Align(
        alignment: Alignment.centerLeft,
        child: Wrap(
          spacing: 8,
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

  Widget _buildTanggalBar() {
    return Padding(
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
        ],
      ),
    );
  }
}

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