import 'package:flutter/material.dart';
import '../../services/auth_service.dart';
import '../../services/notification_service.dart';
import '../../services/santri_service.dart';
import '../../services/santri_session.dart';
import '../../services/update_service.dart';
import '../../utils/app_theme.dart';
import '../../widgets/entrance_animation.dart';
import '../dashboard/dashboard_screen.dart';
import '../santri/santri_dashboard_screen.dart';

class LoginScreen extends StatefulWidget {
  const LoginScreen({super.key});

  @override
  State<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends State<LoginScreen> {
  final AuthService _authService = AuthService();
  final SantriService _santriService = SantriService();
  final _emailController = TextEditingController();
  final _passwordController = TextEditingController();
  final _nisController = TextEditingController();

  bool _isLoading = false;
  String? _errorMessage;
  bool _showWelcome = true;
  bool _isSantriMode = false;
  bool _obscurePassword = true;

  @override
  void initState() {
    super.initState();
    _cekUpdate();
  }

  @override
  void dispose() {
    _emailController.dispose();
    _passwordController.dispose();
    _nisController.dispose();
    super.dispose();
  }

  Future<void> _cekUpdate() async {
    final info = await UpdateService().cekUpdate();
    if (!mounted || !info.adaUpdate) return;

    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) =>
          _DialogUpdate(urlDownload: info.urlDownload, catatan: info.catatan),
    );
  }

  Future<void> _handleLogin() async {
    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });

    try {
      final user = await _authService.login(
        _emailController.text.trim(),
        _passwordController.text.trim(),
      );

      if (user == null) {
        setState(() => _errorMessage = 'Login gagal. Coba lagi.');
        return;
      }

      await NotificationService().init(user.id);

      if (!mounted) return;

      Navigator.pushReplacement(
        context,
        MaterialPageRoute(
          builder: (context) => DashboardScreen(currentUser: user),
        ),
      );
    } catch (e) {
      setState(() => _errorMessage = 'Email atau password salah.');
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  // Login santri: NIS + auth anonymous (tanpa password).
  Future<void> _handleSantriLogin() async {
    final nis = _nisController.text.trim();
    if (nis.isEmpty) {
      setState(() => _errorMessage = 'Masukkan NIS terlebih dahulu.');
      return;
    }

    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });

    try {
      final user = await _authService.signInSantriAnon();
      final santri = await _santriService.getSantriByNim(nis);

      if (!mounted) return;
      if (santri == null) {
        setState(() => _errorMessage = 'NIS "$nis" tidak ditemukan.');
        return;
      }

      final lanjut = await showDialog<bool>(
        context: context,
        barrierDismissible: false,
        builder: (context) => AlertDialog(
          title: const Text('Konfirmasi'),
          content: Text('Ini kamu, ${santri.nama}?'),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context, false),
              child: const Text('Batal'),
            ),
            ElevatedButton(
              onPressed: () => Navigator.pop(context, true),
              child: const Text('Lanjut'),
            ),
          ],
        ),
      );

      if (lanjut != true) {
        await _authService.logout();
        if (mounted) setState(() => _isLoading = false);
        return;
      }
      if (!mounted) return;

      await _authService.simpanAuthNis(user.uid, santri.nim);
      SantriSession.setSession(authUid: user.uid, santri: santri);

      if (!mounted) return;
      Navigator.pushReplacement(
        context,
        MaterialPageRoute(builder: (context) => const SantriDashboardScreen()),
      );
    } catch (e) {
      if (mounted) setState(() => _errorMessage = 'Gagal masuk: $e');
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      body: AnimatedSwitcher(
        duration: const Duration(milliseconds: 320),
        switchInCurve: Curves.easeOutCubic,
        switchOutCurve: Curves.easeInCubic,
        transitionBuilder: (child, animation) {
          final slide = Tween<Offset>(
            begin: const Offset(0.06, 0),
            end: Offset.zero,
          ).animate(animation);
          final scale = Tween<double>(begin: 0.99, end: 1).animate(animation);
          return FadeTransition(
            opacity: animation,
            child: SlideTransition(
              position: slide,
              child: ScaleTransition(scale: scale, child: child),
            ),
          );
        },
        child: _showWelcome
            ? _buildWelcome()
            : (_isSantriMode ? _buildSantriLogin() : _buildLoginForm()),
      ),
    );
  }

  // Slide pertama — gaya taxi app: krem, headline besar, kotak ilustrasi, dekorasi kotak
  Widget _buildWelcome() {
    return Container(
      key: const ValueKey('welcome'),
      width: double.infinity,
      height: double.infinity,
      color: AppColors.background,
      child: SafeArea(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(28, 16, 28, 32),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              EntranceAnimation(
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
                    const SizedBox(height: 24),
                    const Text(
                      'ABSENSI',
                      style: TextStyle(
                        fontSize: 34,
                        fontWeight: FontWeight.w900,
                        fontFamily: 'monospace',
                        color: Colors.black,
                        height: 1.1,
                      ),
                    ),
                    Container(
                      color: AppColors.accent,
                      padding: const EdgeInsets.symmetric(horizontal: 4),
                      child: const Text(
                        'PPPM NURIS.',
                        style: TextStyle(
                          fontSize: 34,
                          fontWeight: FontWeight.w900,
                          fontFamily: 'monospace',
                          color: Colors.black,
                          height: 1.1,
                        ),
                      ),
                    ),
                    const SizedBox(height: 12),
                    const Text(
                      'بِسْمِ اللَّهِ الرَّحْمَٰنِ الرَّحِيمِ',
                      style: TextStyle(
                        fontSize: 14,
                        color: AppColors.textSecondary,
                      ),
                    ),
                  ],
                ),
              ),
              const Spacer(),
              EntranceAnimation(
                delayMilliseconds: 150,
                slideOffset: const Offset(0, 18),
                child: Center(
                  child: Container(
                    width: 150,
                    height: 150,
                    decoration: BoxDecoration(
                      color: AppColors.primary,
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
                    child: const Icon(
                      Icons.mosque_rounded,
                      color: Colors.white,
                      size: 72,
                    ),
                  ),
                ),
              ),
              const Spacer(),
              EntranceAnimation(
                delayMilliseconds: 250,
                slideOffset: const Offset(0, 18),
                child: GestureDetector(
                  onTap: () => setState(() => _showWelcome = false),
                  child: Container(
                    decoration: BoxDecoration(
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
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Expanded(
                          child: Container(
                            padding: const EdgeInsets.symmetric(vertical: 16),
                            decoration: const BoxDecoration(
                              color: Colors.black,
                            ),
                            child: const Center(
                              child: Text(
                                "LET'S GO",
                                style: TextStyle(
                                  color: Colors.white,
                                  fontSize: 15,
                                  fontWeight: FontWeight.w900,
                                  fontFamily: 'monospace',
                                  letterSpacing: 1,
                                ),
                              ),
                            ),
                          ),
                        ),
                        Container(
                          width: 52,
                          height: 52,
                          decoration: BoxDecoration(
                            color: AppColors.accent,
                            border: const Border(
                              left: BorderSide(color: Colors.black, width: 2.5),
                            ),
                          ),
                          child: const Icon(
                            Icons.arrow_forward,
                            color: Colors.black,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
              const SizedBox(height: 12),
              EntranceAnimation(
                delayMilliseconds: 340,
                slideOffset: const Offset(0, 18),
                child: GestureDetector(
                  onTap: () => setState(() {
                    _showWelcome = false;
                    _isSantriMode = true;
                  }),
                child: Container(
                  width: double.infinity,
                  padding: const EdgeInsets.symmetric(vertical: 14),
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(6),
                    border: Border.all(color: Colors.black, width: 2),
                    boxShadow: const [
                      BoxShadow(
                        color: Colors.black,
                        offset: Offset(4, 4),
                        blurRadius: 0,
                      ),
                    ],
                  ),
                  child: const Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(
                        Icons.school_outlined,
                        color: AppColors.textPrimary,
                      ),
                      SizedBox(width: 10),
                      Text(
                        'MASUK SEBAGAI SANTRI',
                        style: TextStyle(
                          color: AppColors.textPrimary,
                          fontSize: 15,
                          fontWeight: FontWeight.w900,
                          fontFamily: 'monospace',
                          letterSpacing: 0.5,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
            ],
          ),
        ),
      ),
    );
  }

  // Slide kedua — form login putih minimal
  Widget _buildLoginForm() {
    return SafeArea(
      key: const ValueKey('login'),
      child: SingleChildScrollView(
        child: Column(
          children: [
            Align(
              alignment: Alignment.topLeft,
              child: Padding(
                padding: const EdgeInsets.only(left: 8, top: 4),
                child: IconButton(
                  onPressed: () => setState(() => _showWelcome = true),
                  icon: const Icon(
                    Icons.arrow_back,
                    color: AppColors.textPrimary,
                  ),
                ),
              ),
            ),
            EntranceAnimation(
              delayMilliseconds: 40,
              slideOffset: const Offset(0, 20),
              child: Padding(
                padding: const EdgeInsets.fromLTRB(24, 56, 24, 0),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'NURISGO',
                      style: TextStyle(
                        color: AppColors.primary,
                        fontSize: 14,
                        fontWeight: FontWeight.w900,
                        fontFamily: 'monospace',
                        letterSpacing: 2,
                      ),
                    ),
                    const SizedBox(height: 12),
                    const Text(
                      'SELAMAT DATANG',
                      style: TextStyle(
                        fontSize: 28,
                        fontWeight: FontWeight.w900,
                        fontFamily: 'monospace',
                        color: Colors.black,
                      ),
                    ),
                    const SizedBox(height: 6),
                    const Text(
                      'Masuk untuk melanjutkan ke akun kamu',
                      style: TextStyle(
                        color: AppColors.textSecondary,
                        fontSize: 14,
                      ),
                    ),
                  ],
                ),
              ),
            ),
            EntranceAnimation(
              delayMilliseconds: 100,
              slideOffset: const Offset(0, 20),
              child: Padding(
                padding: const EdgeInsets.fromLTRB(24, 32, 24, 24),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    TextField(
                      controller: _emailController,
                      keyboardType: TextInputType.emailAddress,
                      decoration: const InputDecoration(
                        labelText: 'Email',
                        prefixIcon: Icon(Icons.email_outlined),
                      ),
                    ),
                    const SizedBox(height: 16),
                    TextField(
                      controller: _passwordController,
                      obscureText: _obscurePassword,
                      decoration: InputDecoration(
                        labelText: 'Password',
                        prefixIcon: const Icon(Icons.lock_outline),
                      suffixIcon: IconButton(
                        icon: Icon(
                          _obscurePassword
                              ? Icons.visibility_off_outlined
                              : Icons.visibility_outlined,
                        ),
                        onPressed: () =>
                            setState(() => _obscurePassword = !_obscurePassword),
                      ),
                    ),
                  ),
                  const SizedBox(height: 20),
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
                          const Icon(
                            Icons.error_outline,
                            color: AppColors.alpa,
                            size: 18,
                          ),
                          const SizedBox(width: 8),
                          Expanded(
                            child: Text(
                              _errorMessage!,
                              style: const TextStyle(
                                color: AppColors.alpa,
                                fontSize: 13,
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
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
                      onPressed: _isLoading ? null : _handleLogin,
                      child: _isLoading
                          ? const SizedBox(
                              height: 20,
                              width: 20,
                              child: CircularProgressIndicator(
                                color: Colors.white,
                                strokeWidth: 2,
                              ),
                            )
                          : const Text('MASUK'),
                    ),
                  ),
                ],
              ),
            ),
            ),
          ],
        ),
      ),
    );
  }

  // Slide login santri — cukup masukkan NIS, nggak perlu password.
  Widget _buildSantriLogin() {
    return SafeArea(
      key: const ValueKey('santri'),
      child: SingleChildScrollView(
        child: Column(
          children: [
            Align(
              alignment: Alignment.topLeft,
              child: Padding(
                padding: const EdgeInsets.only(left: 8, top: 4),
                child: IconButton(
                  onPressed: () => setState(() {
                    _showWelcome = true;
                    _isSantriMode = false;
                  }),
                  icon: const Icon(
                    Icons.arrow_back,
                    color: AppColors.textPrimary,
                  ),
                ),
              ),
            ),
            EntranceAnimation(
              delayMilliseconds: 40,
              slideOffset: const Offset(0, 20),
              child: Padding(
                padding: const EdgeInsets.fromLTRB(24, 56, 24, 0),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Container(
                          padding: const EdgeInsets.all(10),
                          decoration: BoxDecoration(
                            color: AppColors.accent,
                            borderRadius: BorderRadius.circular(6),
                            border: Border.all(color: Colors.black, width: 2),
                          ),
                          child: const Icon(
                            Icons.school_outlined,
                            color: Colors.black,
                          ),
                        ),
                        const SizedBox(width: 12),
                        Text(
                          'NURISGO',
                          style: TextStyle(
                            color: AppColors.primary,
                            fontSize: 14,
                            fontWeight: FontWeight.w900,
                            fontFamily: 'monospace',
                            letterSpacing: 2,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 14),
                    const Text(
                      'MASUK SANTRI',
                      style: TextStyle(
                        fontSize: 28,
                        fontWeight: FontWeight.w900,
                        fontFamily: 'monospace',
                        color: Colors.black,
                      ),
                    ),
                    const SizedBox(height: 6),
                    const Text(
                      'Masukkan NIS kamu untuk mengajukan izin',
                      style: TextStyle(
                        color: AppColors.textSecondary,
                        fontSize: 14,
                      ),
                    ),
                  ],
                ),
              ),
            ),
            EntranceAnimation(
              delayMilliseconds: 100,
              slideOffset: const Offset(0, 20),
              child: Padding(
                padding: const EdgeInsets.fromLTRB(24, 32, 24, 24),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    TextField(
                      controller: _nisController,
                    keyboardType: TextInputType.number,
                    decoration: const InputDecoration(
                      labelText: 'NIS',
                      prefixIcon: Icon(Icons.badge_outlined),
                      hintText: 'Contoh: 1234',
                    ),
                    onSubmitted: (_) => _handleSantriLogin(),
                  ),
                  const SizedBox(height: 20),
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
                          const Icon(
                            Icons.error_outline,
                            color: AppColors.alpa,
                            size: 18,
                          ),
                          const SizedBox(width: 8),
                          Expanded(
                            child: Text(
                              _errorMessage!,
                              style: const TextStyle(
                                color: AppColors.alpa,
                                fontSize: 13,
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
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
                      onPressed: _isLoading ? null : _handleSantriLogin,
                      child: _isLoading
                          ? const SizedBox(
                              height: 20,
                              width: 20,
                              child: CircularProgressIndicator(
                                color: Colors.white,
                                strokeWidth: 2,
                              ),
                            )
                          : const Text('LANJUT'),
                    ),
                  ),
                ],
              ),
            ),
            ),
          ],
        ),
      ),
    );
  }
}

class _DialogUpdate extends StatefulWidget {
  final String urlDownload;
  final String catatan;

  const _DialogUpdate({required this.urlDownload, required this.catatan});

  @override
  State<_DialogUpdate> createState() => _DialogUpdateState();
}

class _DialogUpdateState extends State<_DialogUpdate> {
  bool _sedangDownload = false;
  double _progress = 0;
  String? _errorDownload;

  Future<void> _mulaiUpdate() async {
    setState(() {
      _sedangDownload = true;
      _errorDownload = null;
    });

    try {
      await UpdateService().downloadDanInstall(
        widget.urlDownload,
        onProgress: (p) {
          if (mounted) setState(() => _progress = p);
        },
      );
      // Kalau sampai sini tanpa exception, installer berhasil dibuka
      if (mounted) Navigator.pop(context);
    } catch (e) {
      setState(() {
        _sedangDownload = false;
        _errorDownload = e.toString();
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: const Text('Update Tersedia'),
      content: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            widget.catatan.isNotEmpty
                ? widget.catatan
                : 'Ada versi baru aplikasi. Silakan update untuk pengalaman terbaik.',
          ),
          if (_sedangDownload) ...[
            const SizedBox(height: 16),
            LinearProgressIndicator(value: _progress > 0 ? _progress : null),
            const SizedBox(height: 6),
            Text(
              '${(_progress * 100).toStringAsFixed(0)}%',
              style: const TextStyle(fontSize: 12),
            ),
          ],
          if (_errorDownload != null) ...[
            const SizedBox(height: 12),
            Text(
              _errorDownload!,
              style: const TextStyle(color: AppColors.alpa, fontSize: 12),
            ),
          ],
        ],
      ),
      actions: _sedangDownload
          ? []
          : [
              TextButton(
                onPressed: () => Navigator.pop(context),
                child: const Text('Nanti'),
              ),
              ElevatedButton(
                onPressed: _mulaiUpdate,
                child: const Text('Update Sekarang'),
              ),
            ],
    );
  }
}
