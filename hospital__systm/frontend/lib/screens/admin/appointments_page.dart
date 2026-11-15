import 'package:flutter/material.dart';

import '../../app_scope.dart';
import '../../models/appointment.dart';
import '../../models/role.dart';
import '../../services/manage_service.dart';
import '../../widgets/appointment_card.dart';
import '../../widgets/appointment_filters.dart';
import '../../widgets/async_list.dart';

/// Kurum yöneticisi: kurumun randevuları (gün, doktor, durum filtresi). Aktif randevu 2 saat kalana kadar iptal edilebilir.
class AdminAppointmentsPage extends StatefulWidget {
  const AdminAppointmentsPage({super.key, this.now});

  final DateTime Function()? now;

  @override
  State<AdminAppointmentsPage> createState() => _AdminAppointmentsPageState();
}

class _AdminAppointmentsPageState extends State<AdminAppointmentsPage> {
  AppointmentStatus? _status;
  DateTime? _date;
  int? _doctorId;
  List<DoctorRecord> _doctors = const [];

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) async {
      if (!mounted) return;
      try {
        final doctors = await ManageService(AppScope.of(context).api).listDoctors();
        if (mounted) setState(() => _doctors = doctors);
      } catch (_) {
        // Doktor filtresi isteğe bağlıdır; liste alınamazsa yalnızca filtre gösterilmez.
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    final service = ManageService(AppScope.of(context).api);
    final status = _status;
    final date = _date;
    final doctorId = _doctorId;
    return AsyncListView<Appointment>(
      key: ValueKey('$status-$date-$doctorId'),
      load: () => service.listAppointments(date: date, doctorId: doctorId, status: status),
      emptyText: 'Bu filtreye uyan randevu yok.',
      header: AppointmentFilterBar(
        status: status,
        date: date,
        onStatusChanged: (s) => setState(() => _status = s),
        onDateChanged: (d) => setState(() => _date = d),
        extra: _doctors.isEmpty
            ? null
            : SizedBox(
                width: 240,
                child: DropdownButtonFormField<int?>(
                  initialValue: doctorId,
                  isExpanded: true,
                  decoration: const InputDecoration(labelText: 'Doktor', border: OutlineInputBorder(), isDense: true),
                  items: [
                    const DropdownMenuItem<int?>(value: null, child: Text('Tüm doktorlar')),
                    for (final d in _doctors)
                      DropdownMenuItem<int?>(value: d.doctor.id, child: Text(d.doctor.displayName)),
                  ],
                  onChanged: (v) => setState(() => _doctorId = v),
                ),
              ),
      ),
      itemBuilder: (context, a, reload) => AppointmentCard(
        appointment: a,
        viewer: UserRole.institutionAdmin,
        actions: [
          if (a.canBeCancelledBy(UserRole.institutionAdmin, (widget.now ?? DateTime.now)()))
            OutlinedButton(
              onPressed: () => runAppointmentAction(
                context,
                title: 'Randevuyu iptal et',
                message: '${a.patientName} adlı hastanın randevusu iptal edilecek ve hastaya bildirim gidecek.',
                confirmLabel: 'İptal Et',
                successMessage: 'Randevu iptal edildi.',
                action: () => service.cancelAppointment(a.id),
                reload: reload,
              ),
              child: const Text('İptal Et'),
            ),
        ],
      ),
    );
  }
}
