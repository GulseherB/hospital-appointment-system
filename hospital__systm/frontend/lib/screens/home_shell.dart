import 'dart:async';

import 'package:flutter/material.dart';

import '../app_scope.dart';
import '../models/role.dart';
import '../models/user.dart';
import '../services/appointment_service.dart';
import 'admin/appointments_page.dart';
import 'admin/branches_page.dart';
import 'admin/departments_page.dart';
import 'admin/doctors_page.dart';
import 'admin/services_page.dart';
import 'change_password_screen.dart';
import 'doctor/doctor_pages.dart';
import 'patient/book_appointment_page.dart';
import 'patient/my_appointments_page.dart';
import 'patient/notifications_page.dart';
import 'super_admin/applications_page.dart';
import 'super_admin/institutions_page.dart';

/// Rol paneli. Menü, kullanıcının [User.menuItems] çağrısından kurulur (çok biçimlilik):
/// ekran rolü bilmez, yalnızca modelin döndürdüğü öğeleri gösterir.
class HomeShell extends StatefulWidget {
  const HomeShell({super.key, required this.user});

  final User user;

  @override
  State<HomeShell> createState() => _HomeShellState();
}

class _HomeShellState extends State<HomeShell> {
  static const _notificationsRoute = 'patient/notifications';
  static const _unreadRefreshInterval = Duration(minutes: 1);

  int _index = 0;

  /// Hastanın okunmamış bildirim sayısı (menü rozeti).
  int _unread = 0;
  Timer? _unreadTimer;

  bool get _hasNotifications => widget.user.menuItems().any((m) => m.route == _notificationsRoute);

  @override
  void initState() {
    super.initState();
    if (_hasNotifications) {
      WidgetsBinding.instance.addPostFrameCallback((_) => _refreshUnread());
      _unreadTimer = Timer.periodic(_unreadRefreshInterval, (_) => _refreshUnread());
    }
  }

  @override
  void dispose() {
    _unreadTimer?.cancel();
    super.dispose();
  }

  Future<void> _refreshUnread() async {
    if (!mounted) return;
    try {
      final page = await NotificationService(AppScope.of(context).api).list(unreadOnly: true);
      if (mounted) setState(() => _unread = page.unreadCount);
    } catch (_) {
      // Rozet yardımcı bilgidir; hata olursa bir sonraki denemede güncellenir.
    }
  }

  void _goTo(String route) {
    final i = widget.user.menuItems().indexWhere((m) => m.route == route);
    if (i >= 0) setState(() => _index = i);
  }

  Widget _icon(MenuItem item) {
    final icon = Icon(_icons[item.route] ?? Icons.circle);
    if (item.route != _notificationsRoute) return icon;
    return Badge(label: Text('$_unread'), isLabelVisible: _unread > 0, child: icon);
  }

  static const Map<String, IconData> _icons = {
    'patient/book': Icons.event_available,
    'patient/appointments': Icons.calendar_month,
    'patient/notifications': Icons.notifications,
    'doctor/pending': Icons.pending_actions,
    'doctor/appointments': Icons.calendar_month,
    'admin/branches': Icons.apartment,
    'admin/departments': Icons.category,
    'admin/services': Icons.medical_information,
    'admin/doctors': Icons.badge,
    'admin/appointments': Icons.calendar_month,
    'super/applications': Icons.assignment,
    'super/institutions': Icons.domain,
  };

  /// Menü anahtarını sayfaya eşler. Bilinmeyen anahtar "hazırlanıyor" gösterir.
  Widget _pageFor(MenuItem item) {
    return switch (item.route) {
      'patient/book' => BookAppointmentPage(onBooked: () => _goTo('patient/appointments')),
      'patient/appointments' => const MyAppointmentsPage(),
      _notificationsRoute => NotificationsPage(onUnreadChanged: (n) => setState(() => _unread = n)),
      'doctor/pending' => const DoctorPendingPage(),
      'doctor/appointments' => const DoctorAppointmentsPage(),
      'admin/appointments' => const AdminAppointmentsPage(),
      'admin/branches' => const BranchesPage(),
      'admin/departments' => const DepartmentsPage(),
      'admin/services' => const ServicesPage(),
      'admin/doctors' => const DoctorsPage(),
      'super/applications' => const ApplicationsPage(),
      'super/institutions' => const InstitutionsPage(),
      _ => _PendingPage(title: item.title),
    };
  }

  @override
  Widget build(BuildContext context) {
    final session = AppScope.of(context).session;
    final items = widget.user.menuItems();
    final index = _index.clamp(0, items.length - 1);
    final current = items[index];
    final wide = MediaQuery.sizeOf(context).width >= 800;

    final appBar = AppBar(
      title: Text(current.title),
      actions: [
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 8),
          child: Center(child: Text('${widget.user.displayName} · ${widget.user.role.label}')),
        ),
        PopupMenuButton<String>(
          tooltip: 'Hesap',
          icon: const Icon(Icons.account_circle),
          onSelected: (value) {
            if (value == 'password') {
              Navigator.of(context).push(MaterialPageRoute<void>(builder: (_) => const ChangePasswordScreen()));
            } else if (value == 'logout') {
              session.logout();
            }
          },
          itemBuilder: (_) => const [
            PopupMenuItem(value: 'password', child: Text('Şifre Değiştir')),
            PopupMenuItem(value: 'logout', child: Text('Çıkış Yap')),
          ],
        ),
      ],
    );

    void select(int i) => setState(() => _index = i);

    if (wide) {
      return Scaffold(
        appBar: appBar,
        body: Row(
          children: [
            NavigationRail(
              selectedIndex: index,
              onDestinationSelected: select,
              labelType: NavigationRailLabelType.all,
              destinations: [
                for (final item in items) NavigationRailDestination(icon: _icon(item), label: Text(item.title)),
              ],
            ),
            const VerticalDivider(width: 1),
            Expanded(child: _pageFor(current)),
          ],
        ),
      );
    }

    return Scaffold(
      appBar: appBar,
      drawer: NavigationDrawer(
        selectedIndex: index,
        onDestinationSelected: (i) {
          select(i);
          Navigator.of(context).pop();
        },
        children: [
          const SizedBox(height: 16),
          for (final item in items) NavigationDrawerDestination(icon: _icon(item), label: Text(item.title)),
        ],
      ),
      body: _pageFor(current),
    );
  }
}

class _PendingPage extends StatelessWidget {
  const _PendingPage({required this.title});

  final String title;

  @override
  Widget build(BuildContext context) {
    return Center(child: Text('$title sayfası hazırlanıyor.'));
  }
}
