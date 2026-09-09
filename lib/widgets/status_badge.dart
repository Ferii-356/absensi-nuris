import 'package:flutter/material.dart';
import '../utils/app_theme.dart';

class StatusBadge extends StatelessWidget {
  final String status;

  const StatusBadge({super.key, required this.status});

  Color _getColor() {
    switch (status) {
      case 'hadir':
        return AppColors.hadir;
      case 'izin':
        return AppColors.izin;
      case 'sakit':
        return AppColors.sakit;
      case 'alpa':
        return AppColors.alpa;
      case 'pulang':
        return AppColors.pulang;
      case 'libur':
        return AppColors.libur;
      default:
        return Colors.grey;
    }
  }

  String _getLabel() {
    switch (status) {
      case 'hadir':
        return 'HADIR';
      case 'izin':
        return 'IZIN';
      case 'sakit':
        return 'SAKIT';
      case 'alpa':
        return 'ALPA';
      case 'pulang':
        return 'PULANG';
      case 'libur':
        return 'LIBUR';
      default:
        return status.toUpperCase();
    }
  }

  @override
  Widget build(BuildContext context) {
    final warna = _getColor();
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
      decoration: BoxDecoration(
        color: warna.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: warna.withValues(alpha: 0.3)),
      ),
      child: Text(
        _getLabel(),
        style: TextStyle(
          color: warna,
          fontWeight: FontWeight.bold,
          fontSize: 11,
        ),
      ),
    );
  }
}
