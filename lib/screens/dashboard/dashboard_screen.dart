import 'package:flutter/material.dart';
import '../../services/kelas_service.dart';
import '../../services/santri_service.dart';
import '../../services/absensi_service.dart';
import '../../models/kelas_model.dart';
import '../../models/user_model.dart';
import '../../utils/role_helper.dart';
import '../../utils/app_theme.dart';
import '../kelola_santri/santri_list_screen.dart';
import '../kelola_santri/kelola_santri_screen.dart';
import '../absensi/absensi_screen.dart';
import '../laporan/laporan_screen.dart';
import '../akun/akun_screen.dart';
import '../izin/kelola_izin_screen.dart';
import '../../widgets/entrance_animation.dart';

class DashboardScreen extends StatefulWidget {
  final UserModel currentUser;

  const DashboardScreen({super.key, required this.currentUser});

  @override
  State<DashboardScreen> createState() => _DashboardScreenState();
}

class _DashboardScreenState extends State<DashboardScreen> {
  int _selectedIndex = 0;

  late final List<_NavItem> _navItems;

  @override
  void initState() {
    super.initState();
    final role = widget.currentUser.role;

    _navItems = [
      const _NavItem(icon: Icons.class_outlined, label: 'Kelas'),
      if (RoleHelper.bisaLihatLaporan(role))
        const _NavItem(icon: Icons.bar_chart_outlined, label: 'Laporan'),
      if (RoleHelper.bisaKelolaIzin(role))
        const _NavItem(icon: Icons.event_note_outlined, label: 'Izin'),
      const _NavItem(icon: Icons.person_outline, label: 'Akun'),
    ];
  }

  Widget _bangunHalaman(int index) {
    final label = _navItems[index].label;
    switch (label) {
      case 'Kelas':
        return _KelasTab(currentUser: widget.currentUser);
      case 'Laporan':
        return LaporanScreen(currentUser: widget.currentUser);
      case 'Izin':
        return KelolaIzinScreen(currentUser: widget.currentUser);
      case 'Akun':
        return AkunScreen(currentUser: widget.currentUser);
      default:
        return const SizedBox();
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: AnimatedSwitcher(
        duration: const Duration(milliseconds: 260),
        switchInCurve: Curves.easeOutCubic,
        switchOutCurve: Curves.easeInCubic,
        transitionBuilder: (child, animation) => FadeTransition(
          opacity: animation,
          child: SlideTransition(
            position: Tween<Offset>(
              begin: const Offset(0.03, 0),
              end: Offset.zero,
            ).animate(animation),
            child: child,
          ),
        ),
        child: KeyedSubtree(
          key: ValueKey(_selectedIndex),
          child: _bangunHalaman(_selectedIndex),
        ),
      ),
      floatingActionButton: RoleHelper.bisaScanAbsensi(widget.currentUser.role)
          ? FloatingActionButton(
              onPressed: () {
                Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (context) => AbsensiScreen(
                      currentUser: widget.currentUser,
                    ),
                  ),
                );
              },
              tooltip: 'Absensi',
              child: const Icon(Icons.qr_code_scanner, size: 28),
            )
          : null,
      bottomNavigationBar: NavigationBar(
        selectedIndex: _selectedIndex,
        onDestinationSelected: (index) {
          setState(() => _selectedIndex = index);
        },
        backgroundColor: Colors.white,
        indicatorColor: AppColors.primary.withValues(alpha: 0.12),
        destinations: _navItems
            .map(
              (item) => NavigationDestination(
                icon: Icon(item.icon),
                label: item.label,
              ),
            )
            .toList(),
      ),
    );
  }
}

class _NavItem {
  final IconData icon;
  final String label;
  const _NavItem({required this.icon, required this.label});
}

// Tab "Kelas" — header sapaan + daftar kelas dengan ring persentase hadir hari ini
class _KelasTab extends StatelessWidget {
  final UserModel currentUser;

  const _KelasTab({required this.currentUser});

  String _sapaan() {
    final jam = DateTime.now().hour;
    if (jam < 11) return 'Selamat Pagi';
    if (jam < 15) return 'Selamat Siang';
    if (jam < 18) return 'Selamat Sore';
    return 'Selamat Malam';
  }

  @override
  Widget build(BuildContext context) {
    final role = currentUser.role;
    final kelasService = KelasService();

    return Scaffold(
      backgroundColor: AppColors.background,
      body: CustomScrollView(
        slivers: [
          SliverAppBar(
            pinned: true,
            expandedHeight: 118,
            backgroundColor: AppColors.primary,
            elevation: 0,
            automaticallyImplyLeading: false,
            actions: [
              if (RoleHelper.bisaKelolaSantri(role))
                IconButton(
                  icon: const Icon(Icons.person_add, color: Colors.white),
                  tooltip: 'Tambah Santri',
                  onPressed: () {
                    Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (context) => const KelolaSantriScreen(),
                      ),
                    );
                  },
                ),
            ],
            flexibleSpace: FlexibleSpaceBar(
              titlePadding: const EdgeInsets.only(
                left: 20,
                bottom: 16,
                right: 56,
              ),
              title: Text(
                currentUser.nama.isEmpty ? 'Pengurus' : currentUser.nama,
                style: const TextStyle(
                  color: Colors.white,
                  fontSize: 16,
                  fontWeight: FontWeight.w700,
                ),
                overflow: TextOverflow.ellipsis,
              ),
              background: Container(
                decoration: const BoxDecoration(
                  gradient: LinearGradient(
                    colors: [AppColors.primary, AppColors.primaryLight],
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                  ),
                ),
                padding: const EdgeInsets.fromLTRB(20, 44, 20, 0),
                alignment: Alignment.topLeft,
                child: Text(
                  _sapaan(),
                  style: TextStyle(
                    color: Colors.white.withValues(alpha: 0.85),
                    fontSize: 13,
                  ),
                ),
              ),
            ),
          ),
          SliverToBoxAdapter(child: _StatSummaryRow()),
          SliverToBoxAdapter(
            child: Padding(
              padding: const EdgeInsets.fromLTRB(20, 16, 20, 4),
              child: Text(
                'Daftar Kelas',
                style: Theme.of(context).textTheme.titleMedium,
              ),
            ),
          ),
          StreamBuilder<List<KelasModel>>(
            stream: kelasService.getAllKelas(),
            builder: (context, snapshot) {
              if (snapshot.connectionState == ConnectionState.waiting) {
                return const SliverFillRemaining(
                  child: Center(child: CircularProgressIndicator()),
                );
              }

              if (snapshot.hasError) {
                return SliverFillRemaining(
                  child: Center(
                    child: Text('Terjadi error: ${snapshot.error}'),
                  ),
                );
              }

              final daftarKelas = snapshot.data ?? [];

              if (daftarKelas.isEmpty) {
                return const SliverFillRemaining(
                  child: Center(child: Text('Belum ada data kelas.')),
                );
              }

              return SliverPadding(
                padding: const EdgeInsets.only(bottom: 12),
                sliver: SliverList(
                  delegate: SliverChildBuilderDelegate((context, index) {
                    final kelas = daftarKelas[index];
                    return _KelasCardData(
                      key: ValueKey(kelas.id),
                      index: index,
                      kelas: kelas,
                      onTap: () {
                        Navigator.push(
                          context,
                          MaterialPageRoute(
                            builder: (context) => SantriListScreen(
                              kelasId: kelas.id,
                              namaKelas: kelas.namaKelas,
                            ),
                          ),
                        );
                      },
                    );
                  }, childCount: daftarKelas.length),
                ),
              );
            },
          ),
        ],
      ),
    );
  }
}

// Menggabungkan stream santri aktif + absensi hari ini untuk satu kelas,
// lalu merender kartu kelas dengan angka hadir/total yang real-time.
class _KelasCardData extends StatelessWidget {
  final KelasModel kelas;
  final VoidCallback onTap;
  final int index;

  const _KelasCardData({
    super.key,
    required this.kelas,
    required this.onTap,
    required this.index,
  });

  @override
  Widget build(BuildContext context) {
    final santriService = SantriService();
    final absensiService = AbsensiService();

    return StreamBuilder(
      stream: santriService.getSantriByKelas(kelas.id),
      builder: (context, santriSnap) {
        final santriAktif = (santriSnap.data ?? [])
            .where((s) => s.statusAktif)
            .toList();

        return StreamBuilder(
          stream: absensiService.getAbsensiByKelasTanggal(
            kelas.id,
            DateTime.now(),
          ),
          builder: (context, absensiSnap) {
            final absensiHariIni = absensiSnap.data ?? [];
            final santriHadir = absensiHariIni
                .where((a) => a.status == 'hadir')
                .map((a) => a.santriId)
                .toSet();

            return _KelasCardSimple(
              kelas: kelas,
              totalSantri: santriAktif.length,
              totalHadir: santriHadir.length,
              onTap: onTap,
              delayMilliseconds: index * 70,
            );
          },
        );
      },
    );
  }
}

// Kartu kelas versi sederhana — fade + slide masuk saat muncul, ringkas
// nama kelas + hadir hari ini, dan sedikit mengecil saat ditekan.
class _KelasCardSimple extends StatefulWidget {
  final KelasModel kelas;
  final int totalSantri;
  final int totalHadir;
  final VoidCallback onTap;
  final int delayMilliseconds;

  const _KelasCardSimple({
    required this.kelas,
    required this.totalSantri,
    required this.totalHadir,
    required this.onTap,
    this.delayMilliseconds = 0,
  });

  @override
  State<_KelasCardSimple> createState() => _KelasCardSimpleState();
}

class _KelasCardSimpleState extends State<_KelasCardSimple> {
  bool _ditekan = false;

  @override
  Widget build(BuildContext context) {
    return EntranceAnimation(
      delayMilliseconds: widget.delayMilliseconds,
      slideOffset: const Offset(0, 28),
      child: Container(
        margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
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
            onHighlightChanged: (value) =>
                setState(() => _ditekan = value),
            child: AnimatedScale(
              scale: _ditekan ? 0.98 : 1.0,
              duration: const Duration(milliseconds: 120),
              curve: Curves.easeOut,
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.all(10),
                      decoration: BoxDecoration(
                        color: AppColors.accent,
                        borderRadius: BorderRadius.circular(6),
                        border: Border.all(color: Colors.black, width: 1.5),
                      ),
                      child: const Icon(Icons.class_, color: Colors.black),
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
                              fontWeight: FontWeight.w700,
                            ),
                          ),
                          const SizedBox(height: 4),
                          Text(
                            widget.totalSantri == 0
                                ? 'Belum ada santri'
                                : '${widget.totalHadir}/${widget.totalSantri} hadir hari ini',
                            style: const TextStyle(
                              fontFamily: 'monospace',
                              fontSize: 12,
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
      ),
    );
  }
}

// Baris 3 kartu ringkasan di atas dashboard: total santri, hadir hari ini, jumlah kelas.
// Dibungkus StreamBuilder sendiri (terpisah dari daftar kelas) supaya tidak mengganggu
// struktur sliver yang sudah ada — perubahan aditif, bukan restrukturisasi.
class _StatSummaryRow extends StatelessWidget {
  const _StatSummaryRow();

  @override
  Widget build(BuildContext context) {
    final kelasService = KelasService();
    final santriService = SantriService();
    final absensiService = AbsensiService();

    return StreamBuilder(
      stream: kelasService.getAllKelas(),
      builder: (context, kelasSnap) {
        final totalKelas = (kelasSnap.data ?? []).length;

        return StreamBuilder(
          stream: santriService.getAllSantriAktif(),
          builder: (context, santriSnap) {
            final totalSantri = (santriSnap.data ?? []).length;

            return StreamBuilder(
              stream: absensiService.getAbsensiHariIni(DateTime.now()),
              builder: (context, absensiSnap) {
                final absensiHariIni = absensiSnap.data ?? [];
                final totalHadir = absensiHariIni
                    .where((a) => a.status == 'hadir')
                    .map((a) => a.santriId)
                    .toSet()
                    .length;

                final statCards = [
                  _StatCard(
                    icon: Icons.groups_rounded,
                    value: '$totalSantri',
                    label: 'Santri Aktif',
                  ),
                  _StatCard(
                    icon: Icons.check_circle_rounded,
                    value: '$totalHadir',
                    label: 'Hadir Hari Ini',
                  ),
                  _StatCard(
                    icon: Icons.class_rounded,
                    value: '$totalKelas',
                    label: 'Kelas',
                  ),
                ];

                return Padding(
                  padding: const EdgeInsets.fromLTRB(20, 16, 20, 4),
                  child: Row(
                    children: [
                      for (var i = 0; i < statCards.length; i++) ...[
                        if (i > 0) const SizedBox(width: 10),
                        Expanded(
                          child: EntranceAnimation(
                            delayMilliseconds: 100 + i * 110,
                            slideOffset: const Offset(0, 22),
                            child: statCards[i],
                          ),
                        ),
                      ],
                    ],
                  ),
                );
              },
            );
          },
        );
      },
    );
  }
}

// Satu kartu statistik: ikon di lingkaran, angka besar, label kecil di bawahnya.
class _StatCard extends StatelessWidget {
  final IconData icon;
  final String value;
  final String label;

  const _StatCard({
    required this.icon,
    required this.value,
    required this.label,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(vertical: 14, horizontal: 10),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(6),
        border: Border.all(color: Colors.black, width: 2),
        boxShadow: const [
          BoxShadow(color: Colors.black, offset: Offset(3, 3), blurRadius: 0),
        ],
      ),
      child: Column(
        children: [
          Container(
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(
              color: AppColors.accent,
              shape: BoxShape.circle,
              border: Border.all(color: Colors.black, width: 1.5),
            ),
            child: Icon(icon, color: Colors.black, size: 18),
          ),
          const SizedBox(height: 8),
          AnimatedSwitcher(
            duration: const Duration(milliseconds: 350),
            switchInCurve: Curves.easeOutCubic,
            switchOutCurve: Curves.easeInCubic,
            transitionBuilder: (child, animation) => FadeTransition(
              opacity: animation,
              child: SlideTransition(
                position: Tween<Offset>(
                  begin: const Offset(0, 0.3),
                  end: Offset.zero,
                ).animate(animation),
                child: child,
              ),
            ),
            child: Text(
              value,
              key: ValueKey(value),
              style: const TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.w900,
                fontFamily: 'monospace',
                color: AppColors.textPrimary,
              ),
            ),
          ),
          const SizedBox(height: 2),
          Text(
            label,
            textAlign: TextAlign.center,
            style: const TextStyle(
              fontSize: 11,
              color: AppColors.textSecondary,
            ),
          ),
        ],
      ),
    );
  }
}
