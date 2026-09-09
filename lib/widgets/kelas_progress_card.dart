import 'dart:math' as math;
import 'package:flutter/material.dart';
import '../models/kelas_model.dart';
import '../utils/app_theme.dart';

/// Card kelas dengan ring persentase kehadiran hari ini, animasi masuk
/// (fade + slide) dan animasi progress ring yang "mengisi" dari 0.
///
/// Data hadir/total dihitung di luar widget ini (di parent, lewat
/// StreamBuilder gabungan santri + absensi) lalu dikirim sebagai parameter,
/// supaya widget ini tetap ringan & reusable.
class KelasProgressCard extends StatefulWidget {
  final KelasModel kelas;
  final int totalSantri;
  final int totalHadir;
  final VoidCallback onTap;
  final Duration animationDelay;

  const KelasProgressCard({
    super.key,
    required this.kelas,
    required this.totalSantri,
    required this.totalHadir,
    required this.onTap,
    this.animationDelay = Duration.zero,
  });

  @override
  State<KelasProgressCard> createState() => _KelasProgressCardState();
}

class _KelasProgressCardState extends State<KelasProgressCard>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller;
  late final Animation<double> _progressAnim;
  late final Animation<double> _entranceAnim;

  double get _persen =>
      widget.totalSantri == 0 ? 0 : widget.totalHadir / widget.totalSantri;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 900),
    );
    _progressAnim = Tween<double>(
      begin: 0,
      end: _persen,
    ).animate(CurvedAnimation(parent: _controller, curve: Curves.easeOutCubic));
    _entranceAnim = CurvedAnimation(parent: _controller, curve: Curves.easeOut);

    Future.delayed(widget.animationDelay, () {
      if (mounted) _controller.forward();
    });
  }

  @override
  void didUpdateWidget(covariant KelasProgressCard oldWidget) {
    super.didUpdateWidget(oldWidget);
    // Kalau data berubah (misal ada absensi baru masuk lewat stream),
    // animasikan ring ke nilai persentase yang baru.
    if (oldWidget.totalHadir != widget.totalHadir ||
        oldWidget.totalSantri != widget.totalSantri) {
      final newAnim = Tween<double>(begin: _progressAnim.value, end: _persen)
          .animate(
            CurvedAnimation(parent: _controller, curve: Curves.easeOutCubic),
          );
      setState(() => _progressAnim = newAnim);
      _controller.forward(from: 0);
    }
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  Color get _ringColor {
    if (widget.totalSantri == 0) return AppColors.textSecondary;
    if (_persen >= 0.8) return AppColors.hadir;
    if (_persen >= 0.5) return AppColors.secondary;
    return AppColors.alpa;
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: _controller,
      builder: (context, child) {
        return Opacity(
          opacity: _entranceAnim.value,
          child: Transform.translate(
            offset: Offset(0, (1 - _entranceAnim.value) * 24),
            child: child,
          ),
        );
      },
      child: Card(
        child: InkWell(
          borderRadius: BorderRadius.circular(14),
          onTap: widget.onTap,
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(10),
                  decoration: BoxDecoration(
                    color: AppColors.primary.withValues(alpha: 0.1),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: const Icon(Icons.class_, color: AppColors.primary),
                ),
                const SizedBox(width: 14),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        widget.kelas.namaKelas,
                        style: const TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        widget.totalSantri == 0
                            ? 'Belum ada santri'
                            : '${widget.totalHadir}/${widget.totalSantri} hadir hari ini',
                        style: const TextStyle(
                          fontSize: 12,
                          color: AppColors.textSecondary,
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(width: 8),
                AnimatedBuilder(
                  animation: _progressAnim,
                  builder: (context, _) => _RingPercent(
                    value: _progressAnim.value,
                    color: _ringColor,
                    showDash: widget.totalSantri == 0,
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

/// Ring lingkaran kecil + label persentase di tengah, mirip pola
/// "circular progress" pada referensi desain.
class _RingPercent extends StatelessWidget {
  final double value; // 0..1
  final Color color;
  final bool showDash;

  const _RingPercent({
    required this.value,
    required this.color,
    this.showDash = false,
  });

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: 52,
      height: 52,
      child: Stack(
        alignment: Alignment.center,
        children: [
          CustomPaint(
            size: const Size(52, 52),
            painter: _RingPainter(value: value, color: color),
          ),
          Text(
            showDash ? '–' : '${(value * 100).round()}%',
            style: TextStyle(
              fontSize: 12,
              fontWeight: FontWeight.bold,
              color: color,
            ),
          ),
        ],
      ),
    );
  }
}

class _RingPainter extends CustomPainter {
  final double value;
  final Color color;

  _RingPainter({required this.value, required this.color});

  @override
  void paint(Canvas canvas, Size size) {
    final center = size.center(Offset.zero);
    final radius = size.width / 2 - 4;

    final trackPaint = Paint()
      ..color = color.withValues(alpha: 0.15)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 5
      ..strokeCap = StrokeCap.round;

    final progressPaint = Paint()
      ..color = color
      ..style = PaintingStyle.stroke
      ..strokeWidth = 5
      ..strokeCap = StrokeCap.round;

    canvas.drawCircle(center, radius, trackPaint);

    final sweepAngle = 2 * math.pi * value;
    canvas.drawArc(
      Rect.fromCircle(center: center, radius: radius),
      -math.pi / 2,
      sweepAngle,
      false,
      progressPaint,
    );
  }

  @override
  bool shouldRepaint(covariant _RingPainter oldDelegate) {
    return oldDelegate.value != value || oldDelegate.color != color;
  }
}
