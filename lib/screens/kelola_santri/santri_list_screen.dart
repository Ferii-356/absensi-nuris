import 'package:flutter/material.dart';
import '../../services/santri_service.dart';
import '../../services/kelas_service.dart';
import '../../models/santri_model.dart';
import '../../models/kelas_model.dart';
import '../../utils/app_theme.dart';

class SantriListScreen extends StatelessWidget {
  final String kelasId;
  final String namaKelas;

  SantriListScreen({super.key, required this.kelasId, required this.namaKelas});

  final SantriService _santriService = SantriService();
  final KelasService _kelasService = KelasService();

  void _bukaEditSantri(BuildContext context, SantriModel santri) {
    bool statusSementara = santri.statusAktif;
    String kelasIdSementara = santri.kelasId;

    showDialog(
      context: context,
      builder: (context) => StatefulBuilder(
        builder: (context, setStateDialog) {
          return AlertDialog(
            title: Text(santri.nama),
            content: SingleChildScrollView(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'NIM: ${santri.nim}',
                    style: const TextStyle(color: AppColors.textSecondary),
                  ),
                  const SizedBox(height: 16),
                  const Text(
                    'Kelas',
                    style: TextStyle(
                      fontSize: 13,
                      fontWeight: FontWeight.w600,
                      color: AppColors.textSecondary,
                    ),
                  ),
                  const SizedBox(height: 6),
                  StreamBuilder<List<KelasModel>>(
                    stream: _kelasService.getAllKelas(),
                    builder: (context, kelasSnap) {
                      final daftarKelas = kelasSnap.data ?? [];

                      if (kelasSnap.connectionState ==
                              ConnectionState.waiting &&
                          daftarKelas.isEmpty) {
                        return const Padding(
                          padding: EdgeInsets.symmetric(vertical: 8),
                          child: LinearProgressIndicator(),
                        );
                      }

                      // Jaga-jaga kalau kelas saat ini santri belum ada di
                      // daftar (misal race condition), tetap tampilkan biar
                      // dropdown tidak error karena value tidak ketemu.
                      final valueAda = daftarKelas.any(
                        (k) => k.id == kelasIdSementara,
                      );

                      return DropdownButtonFormField<String>(
                        initialValue: valueAda ? kelasIdSementara : null,
                        decoration: const InputDecoration(
                          isDense: true,
                          border: OutlineInputBorder(),
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
                          if (value == null) return;
                          setStateDialog(() => kelasIdSementara = value);
                        },
                      );
                    },
                  ),
                  const SizedBox(height: 16),
                  SwitchListTile(
                    contentPadding: EdgeInsets.zero,
                    title: const Text('Status Aktif'),
                    subtitle: Text(
                      statusSementara
                          ? 'Santri aktif, muncul di laporan'
                          : 'Santri nonaktif, disembunyikan dari laporan',
                    ),
                    value: statusSementara,
                    activeThumbColor: AppColors.primary,
                    onChanged: (value) {
                      setStateDialog(() => statusSementara = value);
                    },
                  ),
                ],
              ),
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(context),
                child: const Text('Batal'),
              ),
              ElevatedButton(
                onPressed: () async {
                  await _santriService.updateSantri(santri.id, {
                    'status_aktif': statusSementara,
                    'kelas_id': kelasIdSementara,
                  });
                  if (context.mounted) Navigator.pop(context);
                },
                child: const Text('Simpan'),
              ),
            ],
          );
        },
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(title: Text('Santri - $namaKelas')),
      body: StreamBuilder<List<SantriModel>>(
        stream: _santriService.getSantriByKelas(kelasId),
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          }

          if (snapshot.hasError) {
            return Center(child: Text('Terjadi error: ${snapshot.error}'));
          }

          final daftarSantri = snapshot.data ?? [];

          if (daftarSantri.isEmpty) {
            return const Center(child: Text('Belum ada santri di kelas ini.'));
          }

          return ListView.builder(
            padding: const EdgeInsets.symmetric(vertical: 12),
            itemCount: daftarSantri.length,
            itemBuilder: (context, index) {
              final santri = daftarSantri[index];
              return Card(
                child: ListTile(
                  onTap: () => _bukaEditSantri(context, santri),
                  leading: Container(
                    width: 40,
                    height: 40,
                    decoration: BoxDecoration(
                      color: AppColors.accent,
                      borderRadius: BorderRadius.circular(6),
                      border: Border.all(color: Colors.black, width: 2),
                    ),
                    child: Center(
                      child: Text(
                        santri.jenisKelamin.isNotEmpty
                            ? santri.jenisKelamin
                            : '?',
                        style: const TextStyle(
                          color: Colors.black,
                          fontWeight: FontWeight.w900,
                        ),
                      ),
                    ),
                  ),
                  title: Text(
                    santri.nama,
                    style: const TextStyle(fontWeight: FontWeight.w600),
                  ),
                  subtitle: Text('NIM: ${santri.nim}'),
                  trailing: Icon(
                    santri.statusAktif ? Icons.check_circle : Icons.cancel,
                    color: santri.statusAktif
                        ? AppColors.hadir
                        : AppColors.alpa,
                    size: 20,
                  ),
                ),
              );
            },
          );
        },
      ),
    );
  }
}
