import 'package:flutter/material.dart';

import '../../app_scope.dart';
import '../../core/date_utils.dart';
import '../../models/institution_application.dart';
import '../../services/institution_service.dart';
import '../../widgets/async_list.dart';
import '../../widgets/common.dart';

/// Süper admin: kurum başvurularını listeler, bekleyenleri onaylar veya reddeder.
class ApplicationsPage extends StatefulWidget {
  const ApplicationsPage({super.key});

  @override
  State<ApplicationsPage> createState() => _ApplicationsPageState();
}

class _ApplicationsPageState extends State<ApplicationsPage> {
  ApplicationStatus? _filter = ApplicationStatus.pending;

  Future<void> _decide(BuildContext context, InstitutionApplication app, bool approve, VoidCallback reload) async {
    final ok = await confirmAction(
      context,
      title: approve ? 'Başvuruyu onayla' : 'Başvuruyu reddet',
      message: approve
          ? '"${app.institutionName}" kurumu ve yönetici hesabı oluşturulacak, "Merkez" şubesi açılacak.'
          : '"${app.institutionName}" başvurusu reddedilecek.',
      confirmLabel: approve ? 'Onayla' : 'Reddet',
    );
    if (!ok || !context.mounted) return;
    final service = InstitutionService(AppScope.of(context).api);
    try {
      approve ? await service.approve(app.id) : await service.reject(app.id);
      if (context.mounted) showMessage(context, approve ? 'Başvuru onaylandı.' : 'Başvuru reddedildi.');
    } catch (e) {
      if (context.mounted) showMessage(context, errorText(e));
    }
    reload();
  }

  @override
  Widget build(BuildContext context) {
    final service = InstitutionService(AppScope.of(context).api);
    final filter = _filter;
    return AsyncListView<InstitutionApplication>(
      key: ValueKey(filter),
      load: () => service.listApplications(status: filter),
      emptyText: 'Bu durumda başvuru yok.',
      header: Padding(
        padding: const EdgeInsets.fromLTRB(12, 12, 12, 0),
        child: Wrap(
          spacing: 8,
          children: [
            for (final s in [...ApplicationStatus.values, null])
              ChoiceChip(
                label: Text(s?.label ?? 'Tümü'),
                selected: _filter == s,
                onSelected: (_) => setState(() => _filter = s),
              ),
          ],
        ),
      ),
      itemBuilder: (context, app, reload) => _ApplicationCard(
        app: app,
        onApprove: () => _decide(context, app, true, reload),
        onReject: () => _decide(context, app, false, reload),
      ),
    );
  }
}

class _ApplicationCard extends StatelessWidget {
  const _ApplicationCard({required this.app, required this.onApprove, required this.onReject});

  final InstitutionApplication app;
  final VoidCallback onApprove;
  final VoidCallback onReject;

  Color _statusColor() => switch (app.status) {
    ApplicationStatus.pending => Colors.orange,
    ApplicationStatus.approved => Colors.green,
    ApplicationStatus.rejected => Colors.red,
  };

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Expanded(child: Text(app.institutionName, style: theme.textTheme.titleMedium)),
                StatusChip(label: app.status.label, color: _statusColor()),
              ],
            ),
            const SizedBox(height: 8),
            Text('${app.institutionType.label} · ${app.institutionAddress}'),
            Text('Kurum: ${app.institutionPhone} · ${app.institutionEmail}'),
            Text('Yönetici: ${app.adminFullName} · ${app.adminEmail} · ${app.adminPhone}'),
            Text(
              'Başvuru: ${ApiDate.display(app.createdAt)}'
              '${app.decidedAt != null ? ' · Karar: ${ApiDate.display(app.decidedAt!)}' : ''}',
              style: theme.textTheme.bodySmall,
            ),
            if (app.canBeDecided) ...[
              const SizedBox(height: 12),
              Row(
                mainAxisAlignment: MainAxisAlignment.end,
                children: [
                  OutlinedButton(onPressed: onReject, child: const Text('Reddet')),
                  const SizedBox(width: 8),
                  FilledButton(onPressed: onApprove, child: const Text('Onayla')),
                ],
              ),
            ],
          ],
        ),
      ),
    );
  }
}
