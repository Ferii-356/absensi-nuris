import 'package:flutter/material.dart';
import '../../models/user_model.dart';
import '../../services/auth_service.dart';
import '../../utils/app_theme.dart';
import '../../utils/role_helper.dart';
import '../login/login_screen.dart';

class AkunScreen extends StatelessWidget {
  final UserModel currentUser;

  const AkunScreen({super.key, required this.currentUser});

  Future<void> _logout(BuildContext context) async {
    final konfirmasi = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Logout'),
        content: const Text('Yakin mau keluar dari aplikasi?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Batal'),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text('Logout'),
          ),
        ],
      ),
    );

    if (konfirmasi != true) return;
    if (!context.mounted) return;

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
          padding: const EdgeInsets.all(20.0),
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
                'AKUN',
                style: TextStyle(
                  fontSize: 26,
                  fontWeight: FontWeight.w900,
                  fontFamily: 'monospace',
                  color: Colors.black,
                ),
              ),
              const SizedBox(height: 24),
              Center(
                child: Column(
                  children: [
                    Container(
                      width: 80,
                      height: 80,
                      decoration: BoxDecoration(
                        color: AppColors.accent,
                        borderRadius: BorderRadius.circular(8),
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
                        child: Text(
                          currentUser.nama.isNotEmpty
                              ? currentUser.nama[0].toUpperCase()
                              : '?',
                          style: const TextStyle(
                            fontSize: 32,
                            fontWeight: FontWeight.w900,
                            fontFamily: 'monospace',
                            color: Colors.black,
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(height: 14),
                    Text(
                      currentUser.nama,
                      style: const TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                    Text(
                      RoleHelper.labelRole(currentUser.role),
                      style: const TextStyle(
                        color: AppColors.textSecondary,
                        fontSize: 13,
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 32),
              Card(
                child: ListTile(
                  leading: const Icon(
                    Icons.email_outlined,
                    color: AppColors.primary,
                  ),
                  title: const Text('Email'),
                  subtitle: Text(currentUser.email),
                ),
              ),
              const SizedBox(height: 12),
              Card(
                child: ListTile(
                  leading: const Icon(
                    Icons.badge_outlined,
                    color: AppColors.primary,
                  ),
                  title: const Text('Role'),
                  subtitle: Text(RoleHelper.labelRole(currentUser.role)),
                ),
              ),
              const Spacer(),
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
                child: OutlinedButton.icon(
                  onPressed: () => _logout(context),
                  icon: const Icon(Icons.logout, color: AppColors.alpa),
                  label: const Text('LOGOUT'),
                  style: OutlinedButton.styleFrom(
                    backgroundColor: Colors.white,
                    foregroundColor: AppColors.alpa,
                    side: const BorderSide(color: Colors.black, width: 2.5),
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
