import 'package:flutter/material.dart';

import 'app/app_scope.dart';
import 'core/theme/app_theme.dart';
import 'features/auth/login_page.dart';

void main() {
  runApp(const AppointmentApp());
}

class AppointmentApp extends StatelessWidget {
  const AppointmentApp({super.key});

  @override
  Widget build(BuildContext context) {
    return AppScope.create(
      child: MaterialApp(
        title: 'Hastane Randevu Sistemi',
        debugShowCheckedModeBanner: false,
        theme: AppTheme.light,
        home: const LoginPage(),
      ),
    );
  }
}
