import 'package:flutter/material.dart';
import '../../services/auth_service.dart';
import '../../services/santri_session.dart';
import '../../utils/app_theme.dart';
import '../login/login_screen.dart';
import 'ajukan_izin_screen.dart';
import 'riwayat_izin_screen.dart';
import '../../widgets/entrance_animation.dart';

// Beranda khusus santri (masuk via NIS, auth anonymous).
class SantriDashboardScreen extends StatelessWidget {
  const SantriDashboardScreen({super.key});

  Future<void> _keluar(BuildContext context) async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Keluar'),
        content: const Text('Yakin mau keluar dari akun santri ini?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Batal'),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text('Keluar'),
          ),
        ],
      ),
    );
    if (ok != true) return;

    SantriSession.clear();
    await AuthService().logout();

    if (!context.mounted) return;
    Navigator.pushAndRemoveUntil(
      context,
      MaterialPageRoute(builder: (context) => const LoginScreen()),
      (route) => false,
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(20, 12, 20, 24),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text(
                'NURISGO',
                style: TextStyle(
                  color: AppColors.primary,
                  fontSize: 14,
                  fontWeight: FontWeight.w900,
                  fontFamily: 'monospace',
                  letterSpacing: 2,
                ),
              ),
              const SizedBox(height: 8),
              const Text(
                'DASHBOARD SANTRI',
                style: TextStyle(
                  fontSize: 24,
                  fontWeight: FontWeight.w900,
                  fontFamily: 'monospace',
                  color: Colors.black,
                ),
              ),
              const SizedBox(height: 6),
              Text(
                'Halo, ${SantriSession.nama ?? '-'} · NIS ${SantriSession.nis ?? '-'}',
                style: const TextStyle(
                  color: AppColors.textSecondary,
                  fontSize: 14,
                ),
              ),
              const Spacer(),
              EntranceAnimation(
                delayMilliseconds: 150,
                slideOffset: const Offset(0, 24),
                child: _MenuCard(
                  icon: Icons.note_add_outlined,
                  judul: 'Ajukan Izin',
                  deskripsi: 'Izinkan sakit, pulang, atau keperluan lainnya',
                  onTap: () {
                    Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (context) => const AjukanIzinScreen(),
                      ),
                    );
                  },
                ),
              ),
              const SizedBox(height: 16),
              EntranceAnimation(
                delayMilliseconds: 250,
                slideOffset: const Offset(0, 24),
                child: _MenuCard(
                  icon: Icons.history_rounded,
                  judul: 'Riwayat Izin Saya',
                  deskripsi: 'Lihat status pengajuan izin-mu',
                  onTap: () {
                    Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (context) => const RiwayatIzinScreen(),
                      ),
                    );
                  },
                ),
              ),
              const Spacer(),
              EntranceAnimation(
                delayMilliseconds: 360,
                child: SizedBox(
                  width: double.infinity,
                  child: OutlinedButton.icon(
                    onPressed: () => _keluar(context),
                    icon: const Icon(Icons.logout),
                    label: const Text('KELUAR'),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _MenuCard extends StatefulWidget {
  final IconData icon;
  final String judul;
  final String deskripsi;
  final VoidCallback onTap;

  const _MenuCard({
    required this.icon,
    required this.judul,
    required this.deskripsi,
    required this.onTap,
  });

  @override
  State<_MenuCard> createState() => _MenuCardState();
}

class _MenuCardState extends State<_MenuCard> {
  bool _ditekan = false;

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: const BoxDecoration(
        boxShadow: [
          BoxShadow(color: Colors.black, offset: Offset(4, 4), blurRadius: 0),
        ],
      ),
      child: Card(
        margin: EdgeInsets.zero,
        child: InkWell(
          borderRadius: BorderRadius.circular(6),
          onTap: widget.onTap,
          onHighlightChanged: (value) => setState(() => _ditekan = value),
          child: AnimatedScale(
            scale: _ditekan ? 0.98 : 1.0,
            duration: const Duration(milliseconds: 120),
            curve: Curves.easeOut,
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Row(
                children: [
                  Container(
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: AppColors.accent,
                      borderRadius: BorderRadius.circular(6),
                      border: Border.all(color: Colors.black, width: 1.5),
                    ),
                    child: Icon(widget.icon, color: Colors.black),
                  ),
                  const SizedBox(width: 14),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          widget.judul,
                          style: const TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.w800,
                            color: AppColors.textPrimary,
                          ),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          widget.deskripsi,
                          style: const TextStyle(
                            fontSize: 13,
                            color: AppColors.textSecondary,
                          ),
                        ),
                      ],
                    ),
                  ),
                  const Icon(
                    Icons.chevron_right,
                    color: AppColors.textSecondary,
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}