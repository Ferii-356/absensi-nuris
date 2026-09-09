import 'package:flutter/material.dart';
import '../../services/santri_service.dart';
import '../../services/kelas_service.dart';
import '../../models/santri_model.dart';
import '../../models/kelas_model.dart';
import '../../utils/app_theme.dart';

class KelolaSantriScreen extends StatefulWidget {
  const KelolaSantriScreen({super.key});

  @override
  State<KelolaSantriScreen> createState() => _KelolaSantriScreenState();
}

class _KelolaSantriScreenState extends State<KelolaSantriScreen> {
  final _formKey = GlobalKey<FormState>();
  final SantriService _santriService = SantriService();
  final KelasService _kelasService = KelasService();

  final _nimController = TextEditingController();
  final _namaController = TextEditingController();

  String? _kelasIdTerpilih;
  String _jenisKelamin = 'L';
  bool _sedangSimpan = false;

  @override
  void dispose() {
    _nimController.dispose();
    _namaController.dispose();
    super.dispose();
  }

  Future<void> _simpanSantri() async {
    if (!_formKey.currentState!.validate()) return;
    if (_kelasIdTerpilih == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Pilih kelas terlebih dahulu')),
      );
      return;
    }

    setState(() => _sedangSimpan = true);

    try {
      await _santriService.tambahSantri(
        SantriModel(
          id: '',
          nim: _nimController.text.trim(),
          nama: _namaController.text.trim(),
          kelasId: _kelasIdTerpilih!,
          jenisKelamin: _jenisKelamin,
          statusAktif: true,
        ),
      );

      if (!mounted) return;

      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Santri berhasil ditambahkan')),
      );

      _nimController.clear();
      _namaController.clear();
      setState(() => _jenisKelamin = 'L');
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
      appBar: AppBar(title: const Text('Tambah Santri')),
      body: Padding(
        padding: const EdgeInsets.all(20.0),
        child: Form(
          key: _formKey,
          child: ListView(
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
                'DATA SANTRI BARU',
                style: TextStyle(
                  fontSize: 22,
                  fontWeight: FontWeight.w900,
                  fontFamily: 'monospace',
                  color: Colors.black,
                ),
              ),
              const SizedBox(height: 4),
              const Text(
                'Isi data lengkap santri di bawah ini',
                style: TextStyle(color: AppColors.textSecondary, fontSize: 13),
              ),
              const SizedBox(height: 20),

              TextFormField(
                controller: _nimController,
                decoration: const InputDecoration(
                  labelText: 'NIM / NIS',
                  prefixIcon: Icon(Icons.badge_outlined),
                ),
                validator: (value) => (value == null || value.trim().isEmpty)
                    ? 'NIM wajib diisi'
                    : null,
              ),
              const SizedBox(height: 16),
              TextFormField(
                controller: _namaController,
                decoration: const InputDecoration(
                  labelText: 'Nama Lengkap',
                  prefixIcon: Icon(Icons.person_outline),
                ),
                validator: (value) => (value == null || value.trim().isEmpty)
                    ? 'Nama wajib diisi'
                    : null,
              ),
              const SizedBox(height: 16),

              StreamBuilder<List<KelasModel>>(
                stream: _kelasService.getAllKelas(),
                builder: (context, snapshot) {
                  if (!snapshot.hasData) {
                    return const Center(child: CircularProgressIndicator());
                  }

                  final daftarKelas = snapshot.data!;

                  return DropdownButtonFormField<String>(
                    initialValue: _kelasIdTerpilih,
                    decoration: const InputDecoration(
                      labelText: 'Kelas',
                      prefixIcon: Icon(Icons.class_outlined),
                    ),
                    items: daftarKelas
                        .map(
                          (kelas) => DropdownMenuItem(
                            value: kelas.id,
                            child: Text(kelas.namaKelas),
                          ),
                        )
                        .toList(),
                    onChanged: (value) {
                      setState(() => _kelasIdTerpilih = value);
                    },
                  );
                },
              ),
              const SizedBox(height: 20),

              const Text(
                'Jenis Kelamin',
                style: TextStyle(fontWeight: FontWeight.w600, fontSize: 14),
              ),
              const SizedBox(height: 4),
              RadioGroup<String>(
                groupValue: _jenisKelamin,
                onChanged: (value) {
                  if (value != null) setState(() => _jenisKelamin = value);
                },
                child: Row(
                  children: [
                    Expanded(
                      child: RadioListTile<String>(
                        title: const Text('Laki-laki'),
                        value: 'L',
                        activeColor: AppColors.primary,
                      ),
                    ),
                    Expanded(
                      child: RadioListTile<String>(
                        title: const Text('Perempuan'),
                        value: 'P',
                        activeColor: AppColors.primary,
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 28),

              Container(
                width: double.infinity,
                decoration: const BoxDecoration(
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black,
                      offset: Offset(4, 4),
                      blurRadius: 0,
                    ),
                  ],
                ),
                child: ElevatedButton(
                  onPressed: _sedangSimpan ? null : _simpanSantri,
                  child: _sedangSimpan
                      ? const SizedBox(
                          height: 20,
                          width: 20,
                          child: CircularProgressIndicator(
                            color: Colors.white,
                            strokeWidth: 2,
                          ),
                        )
                      : const Text('SIMPAN SANTRI'),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
