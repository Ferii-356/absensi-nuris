import 'package:flutter/material.dart';
import '../../models/izin_model.dart';
import '../../services/izin_service.dart';
import '../../services/santri_session.dart';
import '../../utils/app_theme.dart';
import '../../utils/constants.dart';

// Riwayat pengajuan izin milik santri yang sedang login.
class RiwayatIzinScreen extends StatelessWidget {
  const RiwayatIzinScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final nis = SantriSession.nis ?? '';

    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(title: const Text('Riwayat Izin Saya')),
      body: nis.isEmpty
          ? const Center(child: Text('Sesi santri berakhir.'))
          : StreamBuilder<List<IzinModel>>(
              stream: IzinService().getIzinSantri(nis),
              builder: (context, snapshot) {
                if (snapshot.connectionState == ConnectionState.waiting) {
                  return const Center(child: CircularProgressIndicator());
                }
                if (snapshot.hasError) {
                  return Center(child: Text('Terjadi error: ${snapshot.error}'));
                }

                final izinList = snapshot.data ?? [];
                if (izinList.isEmpty) {
                  return const Center(
                    child: Text('Belum ada pengajuan izin.'),
                  );
                }

                return ListView.builder(
                  padding: const EdgeInsets.fromLTRB(16, 8, 16, 24),
                  itemCount: izinList.length,
                  itemBuilder: (context, index) =>
                      _IzinCard(izin: izinList[index]),
                );
              },
            ),
    );
  }
}

class _IzinCard extends StatelessWidget {
  final IzinModel izin;

  const _IzinCard({required this.izin});

  Color _warnaStatus() {
    switch (izin.status) {
      case StatusIzin.disetujui:
        return AppColors.hadir;
      case StatusIzin.ditolak:
        return AppColors.alpa;
      default:
        return AppColors.secondary;
    }
  }

  String _labelStatus() {
    switch (izin.status) {
      case StatusIzin.disetujui:
        return 'DISETUJUI';
      case StatusIzin.ditolak:
        return 'DITOLAK';
      default:
        return 'MENUNGGU';
    }
  }

  @override
  Widget build(BuildContext context) {
    final warna = _warnaStatus();
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
                  padding:
                      const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                  decoration: BoxDecoration(
                    color: warna.withValues(alpha: 0.12),
                    borderRadius: BorderRadius.circular(20),
                    border: Border.all(color: warna.withValues(alpha: 0.3)),
                  ),
                  child: Text(
                    _labelStatus(),
                    style: TextStyle(
                      color: warna,
                      fontWeight: FontWeight.bold,
                      fontSize: 11,
                    ),
                  ),
                ),
              ],
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
          ],
        ),
      ),
    );
  }
}