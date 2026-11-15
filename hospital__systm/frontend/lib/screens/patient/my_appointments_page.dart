import 'package:flutter/material.dart';

import '../../app_scope.dart';
import '../../models/appointment.dart';
import '../../models/role.dart';
import '../../services/appointment_service.dart';
import '../../widgets/appointment_card.dart';
import '../../widgets/async_list.dart';

/// Hastanın randevuları (yeniden eskiye). Aktif randevu, başlangıca en az 2 saat varsa iptal edilebilir.
class MyAppointmentsPage extends StatefulWidget {
  const MyAppointmentsPage({super.key, this.now});

  final DateTime Function()? now;

  @override
  State<MyAppointmentsPage> createState() => _MyAppointmentsPageState();
}

class _MyAppointmentsPageState extends State<MyAppointmentsPage> {
  bool _onlyActive = true;

  @override
  Widget build(BuildContext context) {
    final service = PatientService(AppScope.of(context).api);
    final onlyActive = _onlyActive;
    return AsyncListView<Appointment>(
      key: ValueKey(onlyActive),
      load: () async {
        final list = await service.myAppointments();
        return onlyActive ? list.where((a) => a.status.isActive).toList() : list;
      },
      emptyText: onlyActive ? 'Aktif randevunuz yok.' : 'Henüz randevunuz yok.',
      header: Padding(
        padding: const EdgeInsets.fromLTRB(12, 12, 12, 0),
        child: Wrap(
          spacing: 8,
          children: [
            ChoiceChip(
              label: const Text('Aktif'),
              selected: _onlyActive,
              onSelected: (_) => setState(() => _onlyActive = true),
            ),
            ChoiceChip(
              label: const Text('Tümü'),
              selected: !_onlyActive,
              onSelected: (_) => setState(() => _onlyActive = false),
            ),
          ],
        ),
      ),
      itemBuilder: (context, a, reload) {
        final now = (widget.now ?? DateTime.now)();
        final canCancel = a.canBeCancelledBy(UserRole.patient, now);
        return AppointmentCard(
          appointment: a,
          viewer: UserRole.patient,
          actions: [
            if (a.status.isActive && !canCancel)
              const Text('Randevuya 2 saatten az kaldığı için iptal edilemez.', style: TextStyle(fontSize: 12)),
            if (canCancel)
              OutlinedButton(
                onPressed: () => runAppointmentAction(
                  context,
                  title: 'Randevuyu iptal et',
                  message: '${a.serviceName} randevunuz iptal edilecek. Bu işlem geri alınamaz.',
                  confirmLabel: 'İptal Et',
                  successMessage: 'Randevunuz iptal edildi.',
                  action: () => service.cancel(a.id),
                  reload: reload,
                ),
                child: const Text('İptal Et'),
              ),
          ],
        );
      },
    );
  }
}
