import 'package:flutter/material.dart';

import '../../app_scope.dart';
import '../../models/institution.dart';
import '../../services/institution_service.dart';
import '../../widgets/async_list.dart';
import '../../widgets/common.dart';
import '../../widgets/temp_password_dialog.dart';

/// Süper admin: tüm kurumlar; kurumu aktifleştirme/pasifleştirme ve yönetici şifresini sıfırlama.
class InstitutionsPage extends StatelessWidget {
  const InstitutionsPage({super.key});

  Future<void> _toggleActive(
    BuildContext context,
    InstitutionService service,
    Institution inst,
    VoidCallback reload,
  ) async {
    final deactivate = inst.isActive;
    final ok = await confirmAction(
      context,
      title: deactivate ? 'Kurumu pasifleştir' : 'Kurumu aktifleştir',
      message: deactivate
          ? '"${inst.name}" hastalara görünmeyecek ve yeni randevu alınamayacak. Mevcut randevular ve girişler etkilenmez.'
          : '"${inst.name}" yeniden hastalara görünecek.',
      confirmLabel: deactivate ? 'Pasifleştir' : 'Aktifleştir',
    );
    if (!ok || !context.mounted) return;
    try {
      await service.setInstitutionActive(inst.id, !deactivate);
      if (context.mounted) showMessage(context, deactivate ? 'Kurum pasifleştirildi.' : 'Kurum aktifleştirildi.');
    } catch (e) {
      if (context.mounted) showMessage(context, errorText(e));
    }
    reload();
  }

  Future<void> _resetAdminPassword(BuildContext context, InstitutionService service, Institution inst) async {
    final ok = await confirmAction(
      context,
      title: 'Yönetici şifresini sıfırla',
      message:
          '"${inst.name}" yöneticisi için yeni bir geçici şifre üretilecek. Eski şifre geçersiz olur; '
          'yönetici ilk girişte şifresini değiştirmek zorunda kalır.',
      confirmLabel: 'Sıfırla',
    );
    if (!ok || !context.mounted) return;
    try {
      final reset = await service.resetAdminPassword(inst.id);
      if (!context.mounted) return;
      await TempPasswordDialog.show(
        context,
        title: 'Yönetici şifresi sıfırlandı',
        name: reset.adminName,
        email: reset.adminEmail,
        password: reset.temporaryPassword,
        recipient: 'Kurum yöneticisine',
      );
    } catch (e) {
      if (context.mounted) showMessage(context, errorText(e));
    }
  }

  @override
  Widget build(BuildContext context) {
    final service = InstitutionService(AppScope.of(context).api);
    return AsyncListView<Institution>(
      load: service.listAllInstitutions,
      emptyText: 'Henüz kurum yok.',
      itemBuilder: (context, inst, reload) => Card(
        child: Padding(
          padding: const EdgeInsets.all(12),
          child: Wrap(
            alignment: WrapAlignment.spaceBetween,
            crossAxisAlignment: WrapCrossAlignment.center,
            runSpacing: 8,
            children: [
              ConstrainedBox(
                constraints: const BoxConstraints(minWidth: 280, maxWidth: 520),
                child: ListTile(
                  contentPadding: EdgeInsets.zero,
                  leading: Icon(inst.type == InstitutionType.hospital ? Icons.local_hospital : Icons.medical_services),
                  title: Text(inst.name),
                  subtitle: Text('${inst.type.label} · ${inst.address}\n${inst.phone} · ${inst.email}'),
                  isThreeLine: true,
                ),
              ),
              Wrap(
                spacing: 8,
                runSpacing: 8,
                crossAxisAlignment: WrapCrossAlignment.center,
                children: [
                  StatusChip(
                    label: inst.isActive ? 'Aktif' : 'Pasif',
                    color: inst.isActive ? Colors.green : Colors.grey,
                  ),
                  OutlinedButton(
                    onPressed: () => _toggleActive(context, service, inst, reload),
                    child: Text(inst.isActive ? 'Pasifleştir' : 'Aktifleştir'),
                  ),
                  TextButton.icon(
                    icon: const Icon(Icons.key),
                    label: const Text('Yönetici Şifresini Sıfırla'),
                    onPressed: () => _resetAdminPassword(context, service, inst),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}
