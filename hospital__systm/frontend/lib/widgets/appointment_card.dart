import 'package:flutter/material.dart';

import '../core/date_utils.dart';
import '../models/appointment.dart';
import '../models/role.dart';
import 'async_list.dart';
import 'common.dart';

/// Randevu durumunun rengi.
Color appointmentStatusColor(AppointmentStatus status) => switch (status) {
  AppointmentStatus.pending => Colors.orange,
  AppointmentStatus.approved => Colors.green,
  AppointmentStatus.rejected => Colors.red,
  AppointmentStatus.cancelled => Colors.grey,
  AppointmentStatus.completed => Colors.blue,
};

/// Hasta, doktor ve yönetici ekranlarında ortak randevu kartı. [viewer] hangi bilgilerin öne çıkacağını belirler:
/// hasta doktoru ve kurumu, doktor hastayı, yönetici ikisini de görür.
class AppointmentCard extends StatelessWidget {
  const AppointmentCard({super.key, required this.appointment, required this.viewer, this.actions = const []});

  final Appointment appointment;
  final UserRole viewer;
  final List<Widget> actions;

  @override
  Widget build(BuildContext context) {
    final a = appointment;
    final theme = Theme.of(context);
    final small = theme.textTheme.bodySmall;
    final title = switch (viewer) {
      UserRole.doctor => a.patientName,
      _ => '${a.serviceName} · Dr. ${a.doctorName}',
    };
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Expanded(child: Text(title, style: theme.textTheme.titleMedium)),
                StatusChip(label: a.status.label, color: appointmentStatusColor(a.status)),
              ],
            ),
            const SizedBox(height: 8),
            Row(
              children: [
                const Icon(Icons.schedule, size: 18),
                const SizedBox(width: 6),
                Text(
                  '${ApiDate.display(a.startAt)} – ${ApiDate.display(a.endAt).substring(11)} '
                  '(${ApiDate.weekdayName(a.startAt.weekday)})',
                ),
              ],
            ),
            if (viewer == UserRole.doctor) Text('${a.serviceName} · ${a.durationMin} dk'),
            if (viewer == UserRole.institutionAdmin) Text('Hasta: ${a.patientName}'),
            if (viewer != UserRole.doctor) Text('${a.institutionName} · ${a.branchName}'),
            Text('Ücret: ${a.priceLabel} (bilgi amaçlı, ödeme sistemde yapılmaz)', style: small),
            if (a.cancelledBy != null)
              Text(
                'İptal eden: ${a.cancelledBy!.label}'
                '${a.cancelledAt != null ? ' · ${ApiDate.display(a.cancelledAt!)}' : ''}',
                style: small,
              ),
            if (actions.isNotEmpty) ...[
              const SizedBox(height: 12),
              Wrap(alignment: WrapAlignment.end, spacing: 8, runSpacing: 8, children: actions),
            ],
          ],
        ),
      ),
    );
  }
}

/// İptal/onay gibi randevu işlemlerini onay penceresiyle çalıştırır, sonucu bildirir ve listeyi yeniler.
Future<void> runAppointmentAction(
  BuildContext context, {
  required String title,
  required String message,
  required String confirmLabel,
  required String successMessage,
  required Future<Object?> Function() action,
  required VoidCallback reload,
}) async {
  final ok = await confirmAction(context, title: title, message: message, confirmLabel: confirmLabel);
  if (!ok || !context.mounted) return;
  try {
    await action();
    if (context.mounted) showMessage(context, successMessage);
  } catch (e) {
    if (context.mounted) showMessage(context, errorText(e));
  }
  reload();
}
