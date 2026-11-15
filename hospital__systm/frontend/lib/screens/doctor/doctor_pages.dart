import 'package:flutter/material.dart';

import '../../app_scope.dart';
import '../../models/appointment.dart';
import '../../models/role.dart';
import '../../services/appointment_service.dart';
import '../../widgets/appointment_card.dart';
import '../../widgets/appointment_filters.dart';
import '../../widgets/async_list.dart';

/// Doktor: onay bekleyen randevular. Onay, başlangıca en az 12 saat varken yapılabilir;
/// sonrasında randevu sistem tarafından otomatik iptal edilir.
class DoctorPendingPage extends StatelessWidget {
  const DoctorPendingPage({super.key, this.now});

  final DateTime Function()? now;

  static const approvalDeadline = Duration(hours: 12);

  @override
  Widget build(BuildContext context) {
    final service = DoctorService(AppScope.of(context).api);
    return AsyncListView<Appointment>(
      load: () => service.appointments(status: AppointmentStatus.pending),
      emptyText: 'Onay bekleyen randevu yok.',
      itemBuilder: (context, a, reload) {
        final canApprove = a.canBeDecided && a.startAt.difference((now ?? DateTime.now)()) >= approvalDeadline;
        return AppointmentCard(
          appointment: a,
          viewer: UserRole.doctor,
          actions: [
            if (!canApprove)
              const Text('Onay süresi doldu; randevu otomatik iptal edilecek.', style: TextStyle(fontSize: 12)),
            OutlinedButton(
              onPressed: () => runAppointmentAction(
                context,
                title: 'Randevuyu reddet',
                message: '${a.patientName} adlı hastanın talebi reddedilecek ve hastaya bildirim gidecek.',
                confirmLabel: 'Reddet',
                successMessage: 'Randevu reddedildi.',
                action: () => service.reject(a.id),
                reload: reload,
              ),
              child: const Text('Reddet'),
            ),
            if (canApprove)
              FilledButton(
                onPressed: () => runAppointmentAction(
                  context,
                  title: 'Randevuyu onayla',
                  message: '${a.patientName} adlı hastanın randevusu onaylanacak ve hastaya bildirim gidecek.',
                  confirmLabel: 'Onayla',
                  successMessage: 'Randevu onaylandı.',
                  action: () => service.approve(a.id),
                  reload: reload,
                ),
                child: const Text('Onayla'),
              ),
          ],
        );
      },
    );
  }
}

/// Doktor: tüm randevular (durum ve gün filtresi). Onaylanmış randevu 2 saat kalana kadar iptal edilebilir.
class DoctorAppointmentsPage extends StatefulWidget {
  const DoctorAppointmentsPage({super.key, this.now});

  final DateTime Function()? now;

  @override
  State<DoctorAppointmentsPage> createState() => _DoctorAppointmentsPageState();
}

class _DoctorAppointmentsPageState extends State<DoctorAppointmentsPage> {
  AppointmentStatus? _status;
  DateTime? _date;

  @override
  Widget build(BuildContext context) {
    final service = DoctorService(AppScope.of(context).api);
    final status = _status;
    final date = _date;
    return AsyncListView<Appointment>(
      key: ValueKey('$status-$date'),
      load: () => service.appointments(status: status, date: date),
      emptyText: 'Bu filtreye uyan randevu yok.',
      header: AppointmentFilterBar(
        status: status,
        date: date,
        onStatusChanged: (s) => setState(() => _status = s),
        onDateChanged: (d) => setState(() => _date = d),
      ),
      itemBuilder: (context, a, reload) => AppointmentCard(
        appointment: a,
        viewer: UserRole.doctor,
        actions: [
          if (a.canBeCancelledBy(UserRole.doctor, (widget.now ?? DateTime.now)()))
            OutlinedButton(
              onPressed: () => runAppointmentAction(
                context,
                title: 'Randevuyu iptal et',
                message: '${a.patientName} adlı hastanın onaylı randevusu iptal edilecek ve hastaya bildirim gidecek.',
                confirmLabel: 'İptal Et',
                successMessage: 'Randevu iptal edildi.',
                action: () => service.cancel(a.id),
                reload: reload,
              ),
              child: const Text('İptal Et'),
            ),
        ],
      ),
    );
  }
}
