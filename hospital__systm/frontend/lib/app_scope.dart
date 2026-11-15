import 'package:flutter/widgets.dart';

import 'services/api_client.dart';
import 'state/session_controller.dart';

/// Uygulama genelindeki bağımlılıkları (API istemcisi, oturum) ekranlara sağlar.
class AppScope extends InheritedWidget {
  const AppScope({super.key, required this.api, required this.session, required super.child});

  final ApiClient api;
  final SessionController session;

  static AppScope of(BuildContext context) {
    final scope = context.dependOnInheritedWidgetOfExactType<AppScope>();
    assert(scope != null, 'AppScope bulunamadı');
    return scope!;
  }

  @override
  bool updateShouldNotify(AppScope oldWidget) => api != oldWidget.api || session != oldWidget.session;
}
