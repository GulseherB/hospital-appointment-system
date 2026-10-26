import 'package:flutter/material.dart';
import 'core/theme/app_theme.dart';

void main() {
  runApp(const AppointmentApp());
}

class AppointmentApp extends StatelessWidget {
  const AppointmentApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Hastane Randevu Sistemi',
      debugShowCheckedModeBanner: false,
      theme: AppTheme.light,
      home: const Scaffold(
        body: Center(child: Text('Hastane Randevu Sistemi')),
      ),
    );
  }
}
