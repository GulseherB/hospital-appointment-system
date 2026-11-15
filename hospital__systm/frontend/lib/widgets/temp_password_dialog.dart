import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import 'async_list.dart';

/// Geçici şifreyi yalnızca bir kez gösteren pencere (doktor hesabı, doktor ve yönetici şifre sıfırlama).
class TempPasswordDialog extends StatelessWidget {
  const TempPasswordDialog({
    super.key,
    required this.title,
    required this.name,
    required this.email,
    required this.password,
    required this.recipient,
  });

  final String title;
  final String name;
  final String email;
  final String password;

  /// Şifrenin iletileceği kişi (ör. "Doktora", "Kurum yöneticisine").
  final String recipient;

  /// Pencereyi kapatılamaz biçimde açar.
  static Future<void> show(
    BuildContext context, {
    required String title,
    required String name,
    required String email,
    required String password,
    required String recipient,
  }) => showDialog<void>(
    context: context,
    barrierDismissible: false,
    builder: (_) =>
        TempPasswordDialog(title: title, name: name, email: email, password: password, recipient: recipient),
  );

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: Text(title),
      content: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('$name ($email)'),
          const SizedBox(height: 12),
          const Text('Geçici şifre:'),
          SelectableText(password, style: Theme.of(context).textTheme.headlineSmall),
          const SizedBox(height: 12),
          Text(
            'Bu şifre yalnızca şimdi gösterilir. $recipient iletin; ilk girişte değiştirmesi istenecek.',
            style: const TextStyle(fontWeight: FontWeight.w600),
          ),
        ],
      ),
      actions: [
        TextButton.icon(
          icon: const Icon(Icons.copy),
          label: const Text('Kopyala'),
          onPressed: () async {
            await Clipboard.setData(ClipboardData(text: password));
            if (context.mounted) showMessage(context, 'Şifre kopyalandı.');
          },
        ),
        FilledButton(onPressed: () => Navigator.of(context).pop(), child: const Text('Tamam')),
      ],
    );
  }
}
