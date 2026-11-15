import 'package:flutter/material.dart';

import '../widgets/common.dart';
import 'institution_application_screen.dart';
import 'login_screen.dart';
import 'register_screen.dart';

/// Açılış ekranı: Hasta Girişi, Hasta Kaydı, Doktor Girişi, Yönetici Girişi, Kurum Başvurusu.
class WelcomeScreen extends StatelessWidget {
  const WelcomeScreen({super.key});

  void _open(BuildContext context, Widget page) =>
      Navigator.of(context).push(MaterialPageRoute<void>(builder: (_) => page));

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Scaffold(
      body: FormCard(
        maxWidth: 420,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Icon(Icons.local_hospital, size: 56, color: theme.colorScheme.primary),
            const SizedBox(height: 12),
            Text('Hastane Randevu Sistemi', textAlign: TextAlign.center, style: theme.textTheme.headlineSmall),
            const SizedBox(height: 24),
            _MenuButton(
              icon: Icons.person,
              label: 'Hasta Girişi',
              onTap: () => _open(context, const LoginScreen(kind: LoginKind.patient)),
            ),
            _MenuButton(
              icon: Icons.person_add,
              label: 'Hasta Kaydı',
              onTap: () => _open(context, const RegisterScreen()),
            ),
            _MenuButton(
              icon: Icons.medical_services,
              label: 'Doktor Girişi',
              onTap: () => _open(context, const LoginScreen(kind: LoginKind.doctor)),
            ),
            _MenuButton(
              icon: Icons.admin_panel_settings,
              label: 'Yönetici Girişi',
              onTap: () => _open(context, const LoginScreen(kind: LoginKind.admin)),
            ),
            const Divider(height: 32),
            _MenuButton(
              icon: Icons.apartment,
              label: 'Kurum Başvurusu',
              outlined: true,
              onTap: () => _open(context, const InstitutionApplicationScreen()),
            ),
          ],
        ),
      ),
    );
  }
}

class _MenuButton extends StatelessWidget {
  const _MenuButton({required this.icon, required this.label, required this.onTap, this.outlined = false});

  final IconData icon;
  final String label;
  final VoidCallback onTap;
  final bool outlined;

  @override
  Widget build(BuildContext context) {
    final child = Row(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [Icon(icon), const SizedBox(width: 8), Text(label)],
    );
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: SizedBox(
        height: 48,
        child: outlined
            ? OutlinedButton(onPressed: onTap, child: child)
            : FilledButton.tonal(onPressed: onTap, child: child),
      ),
    );
  }
}
