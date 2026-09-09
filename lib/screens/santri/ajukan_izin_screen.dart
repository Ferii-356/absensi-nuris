import 'package:flutter/material.dart';
import '../../models/izin_model.dart';
import '../../models/kelas_model.dart';
import '../../services/izin_service.dart';
import '../../services/kelas_service.dart';
import '../../services/santri_session.dart';
import '../../utils/app_theme.dart';
import '../../utils/constants.dart';

// Form pengajuan izin santri. Nama, NIS, dan kelas diisi otomatis dari data
// santri yang login (read-only), bukan input manual — sesuai permintaan fitur.
class AjukanIzinScreen extends StatefulWidget {
  const AjukanIzinScreen({super.key});

  @override
  State<AjukanIzinScreen> createState() => _AjukanIzinScreenState();
}

class _AjukanIzinScreenState extends State<AjukanIzinScreen> {
  final IzinService _izinService = IzinService();
  final _alasanController = TextEditingController();

  String _jenisIzin = JenisIzin.sakit;
  DateTime? _tanggalMulai;
  DateTime? _tanggalSelesai;
  String? _errorMessage;
  bool _isSubmitting = false;

  @override
  void dispose() {
    _alasanController.dispose();
    super.dispose();
  }

  Future<void> _pilihTanggal({required bool isMulai}) async {
    final sekarang = DateTime.now();
    final pilih = await showDatePicker(
      context: context,
      initialDate: isMulai
          ? (_tanggalMulai ?? sekarang)
          : (_tanggalSelesai ?? _tanggalMulai ?? sekarang),
      firstDate: DateTime(2020),
      lastDate: DateTime(2030),
    );
    if (pilih == null) return;
    setState(() {
      if (isMulai) {
        _tanggalMulai = tanggalAwalHari(pilih);
      } else {
        _tanggalSelesai = tanggalAwalHari(pilih);
      }
    });
  }

  Future<void> _ajukan() async {
    final alasan = _alasanController.text.trim();

    // Tanggal hanya wajib diisi jika jenis izin adalah 'pulang'
    final bool butuhTanggal = _jenisIzin == JenisIzin.pulang;
    final DateTime today = tanggalAwalHari(DateTime.now());
    final DateTime mulai = butuhTanggal ? (_tanggalMulai ?? today) : today;
    final DateTime selesai = butuhTanggal ? (_tanggalSelesai ?? today) : today;

    if (butuhTanggal && (_tanggalMulai == null || _tanggalSelesai == null)) {
      setState(() => _errorMessage = 'Pilih tanggal mulai dan tanggal selesai.');
      return;
    }
    if (butuhTanggal && selesai.isBefore(mulai)) {
      setState(
        () => _errorMessage = 'Tanggal selesai tidak boleh sebelum tanggal mulai.',
      );
      return;
    }
    if (alasan.isEmpty) {
      setState(() => _errorMessage = 'Tulis alasan izin terlebih dahulu.');
      return;
    }
    if (!SantriSession.isLoggedIn) {
      setState(() => _errorMessage = 'Sesi santri berakhir. Silakan masuk ulang.');
      return;
    }

    setState(() {
      _isSubmitting = true;
      _errorMessage = null;
    });

    try {
      final izin = IzinModel(
        id: '',
        nis: SantriSession.nis!,
        nama: SantriSession.nama!,
        kelasId: SantriSession.kelasId!,
        jenisIzin: _jenisIzin,
        tanggalMulai: mulai,
        tanggalSelesai: selesai,
        alasan: alasan,
        status: StatusIzin.pending,
      );
      await _izinService.ajukanIzin(izin);
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Izin diajukan. Tunggu persetujuan pengurus.')),
      );
      Navigator.pop(context);
    } catch (e) {
      if (mounted) {
        setState(() => _errorMessage = 'Gagal mengajukan izin: $e');
      }
    } finally {
      if (mounted) setState(() => _isSubmitting = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(title: const Text('Ajukan Izin')),
      body: SingleChildScrollView(
        padding: const EdgeInsets.fromLTRB(20, 24, 20, 32),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _InfoDataSantri(
              nis: SantriSession.nis ?? '-',
              nama: SantriSession.nama ?? '-',
              kelasId: SantriSession.kelasId ?? '',
            ),
            const SizedBox(height: 24),
            const Text(
              'JENIS IZIN',
              style: TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.w900,
                fontFamily: 'monospace',
                color: AppColors.textSecondary,
              ),
            ),
            const SizedBox(height: 8),
            DropdownButtonFormField<String>(
              initialValue: _jenisIzin,
              decoration: const InputDecoration(
                labelText: 'Keperluan izin',
              ),
              items: JenisIzin.daftar
                  .map(
                    (jenis) => DropdownMenuItem(
                      value: jenis,
                      child: Text(JenisIzin.label(jenis)),
                    ),
                  )
                  .toList(),
              onChanged: (value) {
                if (value != null) {
                  setState(() {
                    _jenisIzin = value;
                    // Reset tanggal jika bukan izin pulang
                    if (value != JenisIzin.pulang) {
                      _tanggalMulai = null;
                      _tanggalSelesai = null;
                    }
                  });
                }
              },
            ),
            const SizedBox(height: 16),
            if (_jenisIzin == JenisIzin.pulang) ...[
              const Text(
                'RENTANG TANGGAL',
                style: TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.w900,
                  fontFamily: 'monospace',
                  color: AppColors.textSecondary,
                ),
              ),
              const SizedBox(height: 8),
              Row(
                children: [
                  Expanded(
                    child: _PilihTanggalField(
                      label: 'Mulai',
                      pilihan: _tanggalMulai,
                      onTap: () => _pilihTanggal(isMulai: true),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: _PilihTanggalField(
                      label: 'Selesai',
                      pilihan: _tanggalSelesai,
                      onTap: () => _pilihTanggal(isMulai: false),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 20),
            ],
            const Text(
              'ALASAN',
              style: TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.w900,
                fontFamily: 'monospace',
                color: AppColors.textSecondary,
              ),
            ),
            const SizedBox(height: 8),
            TextField(
              controller: _alasanController,
              maxLines: 3,
              maxLength: 500,
              decoration: const InputDecoration(
                hintText: 'Tulis alasan izinmu di sini...',
                alignLabelWithHint: true,
              ),
            ),
            if (_errorMessage != null)
              Container(
                width: double.infinity,
                padding: const EdgeInsets.all(12),
                margin: const EdgeInsets.only(bottom: 16),
                decoration: BoxDecoration(
                  color: AppColors.alpa.withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Row(
                  children: [
                    const Icon(Icons.error_outline, color: AppColors.alpa, size: 18),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        _errorMessage!,
                        style: const TextStyle(color: AppColors.alpa, fontSize: 13),
                      ),
                    ),
                  ],
                ),
              ),
            const SizedBox(height: 8),
            SizedBox(
              width: double.infinity,
              child: ElevatedButton(
                onPressed: _isSubmitting ? null : _ajukan,
                child: _isSubmitting
                    ? const SizedBox(
                        height: 20,
                        width: 20,
                        child: CircularProgressIndicator(
                          color: Colors.white,
                          strokeWidth: 2,
                        ),
                      )
                    : const Text('AJUKAN IZIN'),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// Ringkasan identitas santri (baca-saja, dari data login).
class _InfoDataSantri extends StatelessWidget {
  final String nis;
  final String nama;
  final String kelasId;

  const _InfoDataSantri({
    required this.nis,
    required this.nama,
    required this.kelasId,
  });

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<List<KelasModel>>(
      stream: KelasService().getAllKelas(),
      builder: (context, snap) {
        String namaKelas = '-';
        for (final k in (snap.data ?? <KelasModel>[])) {
          if (k.id == kelasId) {
            namaKelas = k.namaKelas;
            break;
          }
        }
        return Container(
          width: double.infinity,
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(6),
            border: Border.all(color: Colors.black, width: 2.5),
            boxShadow: const [
              BoxShadow(color: Colors.black, offset: Offset(4, 4), blurRadius: 0),
            ],
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              _Baris('Nama', nama),
              const SizedBox(height: 8),
              _Baris('NIS', nis),
              const SizedBox(height: 8),
              _Baris('Kelas', namaKelas),
            ],
          ),
        );
      },
    );
  }
}

class _Baris extends StatelessWidget {
  final String label;
  final String value;

  const _Baris(this.label, this.value);

  @override
  Widget build(BuildContext context) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        SizedBox(
          width: 72,
          child: Text(
            label.toUpperCase(),
            style: const TextStyle(
              fontSize: 11,
              fontWeight: FontWeight.w900,
              fontFamily: 'monospace',
              color: AppColors.textSecondary,
            ),
          ),
        ),
        Expanded(
          child: Text(
            value,
            style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w600),
          ),
        ),
      ],
    );
  }
}

class _PilihTanggalField extends StatelessWidget {
  final String label;
  final DateTime? pilihan;
  final VoidCallback onTap;

  const _PilihTanggalField({
    required this.label,
    required this.pilihan,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      child: InputDecorator(
        decoration: InputDecoration(
          labelText: label,
          prefixIcon: const Icon(Icons.calendar_today_outlined, size: 18),
          suffixIcon: const Icon(Icons.arrow_drop_down),
        ),
        child: Text(
          pilihan == null ? 'Pilih' : formatTanggalLabel(pilihan!),
          style: TextStyle(
            fontSize: 14,
            fontWeight: FontWeight.w600,
            color: pilihan == null ? AppColors.textSecondary : AppColors.textPrimary,
          ),
        ),
      ),
    );
  }
}