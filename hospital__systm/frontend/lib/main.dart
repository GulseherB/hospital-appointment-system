import 'package:flutter/material.dart';

import 'app_scope.dart';
import 'screens/change_password_screen.dart';
import 'screens/home_shell.dart';
import 'screens/welcome_screen.dart';
import 'services/api_client.dart';
import 'services/auth_service.dart';
import 'services/token_storage.dart';
import 'state/session_controller.dart';

void main() {
  final api = ApiClient();
  final session = SessionController(authService: AuthService(api), storage: PreferencesTokenStorage());
  api.tokenProvider = () => session.token;
  api.onUnauthorized = session.handleUnauthorized;
  session.restore();
  runApp(HospitalApp(api: api, session: session));
}

/// Uygulama kökü: oturum durumuna göre açılış, zorunlu şifre değişimi veya rol paneli gösterilir.
class HospitalApp extends StatelessWidget {
  const HospitalApp({super.key, required this.api, required this.session});

  final ApiClient api;
  final SessionController session;

  @override
  Widget build(BuildContext context) {
    return AppScope(
      api: api,
      session: session,
      child: MaterialApp(
        title: 'Hastane Randevu Sistemi',
        debugShowCheckedModeBanner: false,
        theme: ThemeData(colorScheme: ColorScheme.fromSeed(seedColor: Colors.teal), useMaterial3: true),
        home: ListenableBuilder(
          listenable: session,
          builder: (context, _) {
            if (session.isRestoring) {
              return const Scaffold(body: Center(child: CircularProgressIndicator()));
            }
            final user = session.user;
            if (user == null || !session.isLoggedIn) {
              return const WelcomeScreen();
            }
            if (session.mustChangePassword) {
              return const ChangePasswordScreen(forced: true);
            }
            // Kullanıcı değişince panel sıfırdan kurulur.
            return HomeShell(key: ValueKey(user.id), user: user);
          },
        ),
      ),
    );
  }
}
