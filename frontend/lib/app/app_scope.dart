import 'package:flutter/widgets.dart';

import '../core/auth/token_manager.dart';
import '../repository/auth_repository.dart';
import '../repository/appointment_repository.dart';
import '../repository/catalog_repository.dart';
import '../repository/dio_client.dart';

class AppScope extends InheritedWidget {
  const AppScope({
    required this.authRepository,
    required this.appointmentRepository,
    required this.catalogRepository,
    required this.tokenManager,
    required super.child,
    super.key,
  });

  final AuthRepository authRepository;
  final AppointmentRepository appointmentRepository;
  final CatalogRepository catalogRepository;
  final TokenManager tokenManager;

  static AppScope of(BuildContext context) {
    final scope = context.dependOnInheritedWidgetOfExactType<AppScope>();
    assert(scope != null, 'AppScope is missing from the widget tree');
    return scope!;
  }

  factory AppScope.create({required Widget child}) {
    final tokenManager = TokenManager();
    final client = DioClient(tokenManager: tokenManager);
    return AppScope(
      authRepository: AuthRepository(client, tokenManager),
      appointmentRepository: AppointmentRepository(client),
      catalogRepository: CatalogRepository(client),
      tokenManager: tokenManager,
      child: child,
    );
  }

  @override
  bool updateShouldNotify(AppScope oldWidget) => false;
}
