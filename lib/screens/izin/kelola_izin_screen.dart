import 'package:flutter/material.dart';
import '../../models/izin_model.dart';
import '../../models/kelas_model.dart';
import '../../models/user_model.dart';
import '../../services/izin_service.dart';
import '../../services/kelas_service.dart';
import '../../utils/app_theme.dart';
import '../../utils/constants.dart';

// Kelola izin santri untuk staff (super_admin/sekretaris/wali_kelas):
// setujui/tolak izin pending + tandai hari libur.
class KelolaIzinScreen extends StatefulWidget {
  final UserModel currentUser;

  const KelolaIzinScreen({super.key, required this.currentUser});

  @override
  State<KelolaIzinScreen> createState() => _KelolaIzinScreenState();
}

class _KelolaIzinScreenState extends State<KelolaIzinScreen> {
  final IzinService _izinService = IzinService();
  String _memprosesId = '';
  bool _isTandaiLibur = false;

  // Izin yang tampil dibatasi ke kelas yang dikelola user (jika ada).
  bool _bolehLihat(String kelasId) {
    final dikelola = widget.currentUser.kelasDikelola;
    if (dikelola.isEmpty) return true;
    return dikelola.contains(kelasId);
  }

  Future<void> _approve(IzinModel izin, String kelasNama) async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Setujui Izin'),
        content: Text(
          'Setujui izin ${izin.nama} ($kelasNama)? '
          'Santri akan tercatat absen ${JenisIzin.label(izin.jenisIzin)} '
          'untuk setiap hari pada rentang tanggal izin.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Batal'),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text('Setujui'),
          ),
        ],
      ),
    );
    if (ok != true) return;

    setState(() => _memprosesId = izin.id);
    try {
      await _izinService.approveIzin(izin, widget.currentUser.id);
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Izin ${izin.nama} disetujui.')),
      );
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Gagal menyetujui izin: $e')),
        );
      }
    } finally {
      if (mounted) setState(() => _memprosesId = '');
    }
  }

  Future<void> _tolak(IzinModel izin) async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Tolak Izin'),
        content: Text('Yakin menolak izin ${izin.nama}?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Batal'),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text('Tolak'),
          ),
        ],
      ),
    );
    if (ok != true) return;

    setState(() => _memprosesId = izin.id);
    try {
      await _izinService.tolakIzin(izin.id, widget.currentUser.id);
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Izin ${izin.nama} ditolak.')),
      );
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Gagal menolak izin: $e')),
        );
      }
    } finally {
      if (mounted) setState(() => _memprosesId = '');
    }
  }

  Future<void> _tandaiLibur() async {
    final tanggal = formatTanggalLabel(DateTime.now());
    final ok = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Tandai Libur'),
        content: Text(
          'Tandai $tanggal sebagai hari libur?\n'
          'Semua santri akan tercatat LIBUR di laporan.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Batal'),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text('Libur'),
          ),
        ],
      ),
    );
    if (ok != true) return;

    setState(() => _isTandaiLibur = true);
    try {
      await _izinService.tandaiLiburHariIni(widget.currentUser.id);
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Hari ini ditandai libur.')),
      );
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Gagal menandai libur: $e')),
        );
      }
    } finally {
      if (mounted) setState(() => _isTandaiLibur = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        title: const Text('Kelola Izin'),
        actions: [
          IconButton(
            icon: _isTandaiLibur
                ? const SizedBox(
                    height: 20,
                    width: 20,
                    child: CircularProgressIndicator(
                      color: Colors.white,
                      strokeWidth: 2,
                    ),
                  )
                : const Icon(Icons.event_busy_outlined),
            tooltip: 'Tandai Libur Hari Ini',
            onPressed: _isTandaiLibur ? null : _tandaiLibur,
          ),
        ],
      ),
      body: StreamBuilder<List<IzinModel>>(
        stream: _izinService.getIzinPending(),
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          }
          if (snapshot.hasError) {
            return Center(child: Text('Terjadi error: ${snapshot.error}'));
          }

          final izinList = (snapshot.data ?? [])
              .where((izin) => _bolehLihat(izin.kelasId))
              .toList();
          if (izinList.isEmpty) {
            return const Center(child: Text('Tidak ada izin yang menunggu.'));
          }

          return StreamBuilder<List<KelasModel>>(
            stream: KelasService().getAllKelas(),
            builder: (context, kelasSnap) {
              final kelasById = <String, String>{};
              for (final k in (kelasSnap.data ?? <KelasModel>[])) {
                kelasById[k.id] = k.namaKelas;
              }
              return ListView.builder(
                padding: const EdgeInsets.fromLTRB(16, 8, 16, 24),
                itemCount: izinList.length,
                itemBuilder: (context, index) {
                  final izin = izinList[index];
                  final kelasNama = kelasById[izin.kelasId] ?? '-';
                  return _IzinPendingCard(
                    izin: izin,
                    kelasNama: kelasNama,
                    memproses: _memprosesId == izin.id,
                    onApprove: () => _approve(izin, kelasNama),
                    onTolak: () => _tolak(izin),
                  );
                },
              );
            },
          );
        },
      ),
    );
  }
}

class _IzinPendingCard extends StatelessWidget {
  final IzinModel izin;
  final String kelasNama;
  final bool memproses;
  final VoidCallback onApprove;
  final VoidCallback onTolak;

  const _IzinPendingCard({
    required this.izin,
    required this.kelasNama,
    required this.memproses,
    required this.onApprove,
    required this.onTolak,
  });

  @override
  Widget build(BuildContext context) {
    final rentang = formatTanggalLabel(izin.tanggalMulai) ==
            formatTanggalLabel(izin.tanggalSelesai)
        ? formatTanggalLabel(izin.tanggalMulai)
        : '${formatTanggalLabel(izin.tanggalMulai)} – ${formatTanggalLabel(izin.tanggalSelesai)}';

    return Card(
      margin: const EdgeInsets.symmetric(vertical: 6),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  JenisIzin.label(izin.jenisIzin).toUpperCase(),
                  style: const TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.w800,
                    fontFamily: 'monospace',
                    color: AppColors.textPrimary,
                  ),
                ),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                  decoration: BoxDecoration(
                    color: AppColors.secondary.withValues(alpha: 0.12),
                    borderRadius: BorderRadius.circular(20),
                    border: Border.all(
                      color: AppColors.secondary.withValues(alpha: 0.3),
                    ),
                  ),
                  child: const Text(
                    'MENUNGGU',
                    style: TextStyle(
                      color: AppColors.secondary,
                      fontWeight: FontWeight.bold,
                      fontSize: 11,
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 8),
            Text(
              izin.nama,
              style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w700),
            ),
            const SizedBox(height: 2),
            Text(
              'NIS ${izin.nis} · $kelasNama',
              style: const TextStyle(
                fontFamily: 'monospace',
                fontSize: 12,
                color: AppColors.textSecondary,
              ),
            ),
            const SizedBox(height: 8),
            Row(
              children: [
                const Icon(
                  Icons.event_outlined,
                  size: 15,
                  color: AppColors.textSecondary,
                ),
                const SizedBox(width: 6),
                Text(
                  rentang,
                  style: const TextStyle(
                    fontSize: 13,
                    color: AppColors.textSecondary,
                  ),
                ),
              ],
            ),
            if (izin.alasan.isNotEmpty) ...[
              const SizedBox(height: 8),
              Text(
                izin.alasan,
                style: const TextStyle(fontSize: 14, height: 1.4),
              ),
            ],
            const SizedBox(height: 12),
            Row(
              children: [
                Expanded(
                  child: OutlinedButton(
                    onPressed: memproses ? null : onTolak,
                    style: OutlinedButton.styleFrom(
                      foregroundColor: AppColors.alpa,
                      side: const BorderSide(color: AppColors.alpa, width: 2),
                    ),
                    child: const Text('TOLAK'),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: ElevatedButton(
                    onPressed: memproses ? null : onApprove,
                    child: memproses
                        ? const SizedBox(
                            height: 18,
                            width: 18,
                            child: CircularProgressIndicator(
                              color: Colors.white,
                              strokeWidth: 2,
                            ),
                          )
                        : const Text('SETUJUI'),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}