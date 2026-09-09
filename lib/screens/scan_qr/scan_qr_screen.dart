import 'package:flutter/material.dart';
import 'package:mobile_scanner/mobile_scanner.dart';
import '../../services/santri_service.dart';
import '../../services/absensi_service.dart';
import '../../models/absensi_model.dart';
import '../../models/user_model.dart';
import '../../utils/constants.dart';
import '../../utils/app_theme.dart';

class ScanQrScreen extends StatefulWidget {
  final UserModel currentUser;

  const ScanQrScreen({super.key, required this.currentUser});

  @override
  State<ScanQrScreen> createState() => _ScanQrScreenState();
}

class _ScanQrScreenState extends State<ScanQrScreen> {
  final SantriService _santriService = SantriService();
  final AbsensiService _absensiService = AbsensiService();

  String _sesi = SesiAbsensi.daftar.first;

  bool _sedangProses = false;
  String? _pesanStatus;
  Color _warnaPesan = AppColors.textSecondary;

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
    }
  }

  IconData _getIcon() {
    if (_pesanStatus == null) return Icons.qr_code_scanner;
    if (_warnaPesan == AppColors.hadir) return Icons.check_circle;
    if (_warnaPesan == AppColors.sakit) return Icons.info;
    return Icons.error;
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      body: SafeArea(
        child: Column(
          children: [
            // Header custom — dekorasi kotak + judul bold, gaya konsisten dengan login
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 12, 20, 8),
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
                  const Text(
                    'SCAN QR',
                    style: TextStyle(
                      fontSize: 26,
                      fontWeight: FontWeight.w900,
                      fontFamily: 'monospace',
                      color: Colors.black,
                    ),
                  ),
                  const SizedBox(height: 4),
                  const Text(
                    'Arahkan kamera ke QR code santri',
                    style: TextStyle(
                      fontSize: 13,
                      color: AppColors.textSecondary,
                    ),
                  ),
                ],
              ),
            ),

            // Pilihan sesi jadi pill/chip, bukan dropdown
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 20),
              child: Align(
                alignment: Alignment.centerLeft,
                child: Wrap(
                  spacing: 8,
                  runSpacing: 8,
                  children: SesiAbsensi.daftar.map((sesi) {
                    final terpilih = sesi == _sesi;
                    return GestureDetector(
                      onTap: () => setState(() => _sesi = sesi),
                      child: Container(
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
            ),
            const SizedBox(height: 14),

            // Kamera dibingkai card tebal + hard shadow
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

            // Kartu status hasil scan, hard shadow konsisten
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
                        if (_pesanStatus != null) ...[
                          const SizedBox(height: 12),
                          Container(
                            decoration: const BoxDecoration(
                              boxShadow: [
                                BoxShadow(
                                  color: Colors.black,
                                  offset: Offset(3, 3),
                                  blurRadius: 0,
                                ),
                              ],
                            ),
                            child: ElevatedButton(
                              onPressed: () {
                                setState(() {
                                  _pesanStatus = null;
                                  _sedangProses = false;
                                });
                              },
                              child: const Text('SCAN LAGI'),
                            ),
                          ),
                        ],
                      ],
                    ),
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
