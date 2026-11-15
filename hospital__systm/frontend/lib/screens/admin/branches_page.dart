import 'package:flutter/material.dart';

import '../../app_scope.dart';
import '../../core/validators.dart';
import '../../models/institution.dart';
import '../../services/manage_service.dart';
import '../../widgets/async_list.dart';
import '../../widgets/common.dart';
import 'weekly_schedule_editor.dart';

/// Kurum yöneticisi: şubeler, şube ekleme ve çalışma saatleri.
class BranchesPage extends StatefulWidget {
  const BranchesPage({super.key});

  @override
  State<BranchesPage> createState() => _BranchesPageState();
}

class _BranchesPageState extends State<BranchesPage> {
  final _listKey = GlobalKey<AsyncListViewState<Branch>>();

  Future<void> _create(ManageService service) async {
    final created = await showDialog<Branch>(
      context: context,
      builder: (_) => _BranchDialog(service: service),
    );
    if (created != null && mounted) {
      showMessage(context, '"${created.name}" şubesi eklendi. Çalışma saatlerini girmeyi unutmayın.');
      _listKey.currentState?.reload();
    }
  }

  Future<void> _edit(ManageService service, Branch branch) async {
    final updated = await showDialog<Branch>(
      context: context,
      builder: (_) => _BranchDialog(service: service, existing: branch),
    );
    if (updated != null && mounted) {
      showMessage(context, '"${updated.name}" şubesi güncellendi.');
      _listKey.currentState?.reload();
    }
  }

  @override
  Widget build(BuildContext context) {
    final service = ManageService(AppScope.of(context).api);
    return AsyncListView<Branch>(
      key: _listKey,
      load: service.listBranches,
      header: Padding(
        padding: const EdgeInsets.fromLTRB(12, 12, 12, 0),
        child: Align(
          alignment: Alignment.centerRight,
          child: FilledButton.icon(
            onPressed: () => _create(service),
            icon: const Icon(Icons.add),
            label: const Text('Şube Ekle'),
          ),
        ),
      ),
      itemBuilder: (context, branch, _) => Card(
        child: ListTile(
          leading: const Icon(Icons.apartment),
          title: Text(branch.name),
          subtitle: Text([branch.address, branch.phone].where((s) => s.isNotEmpty).join(' · ')),
          trailing: Wrap(
            spacing: 8,
            crossAxisAlignment: WrapCrossAlignment.center,
            children: [
              StatusChip(
                label: branch.isActive ? 'Aktif' : 'Pasif',
                color: branch.isActive ? Colors.green : Colors.grey,
              ),
              OutlinedButton.icon(
                icon: const Icon(Icons.edit),
                label: const Text('Düzenle'),
                onPressed: () => _edit(service, branch),
              ),
              OutlinedButton.icon(
                icon: const Icon(Icons.schedule),
                label: const Text('Çalışma saatleri'),
                onPressed: () => Navigator.of(context).push(
                  MaterialPageRoute<void>(
                    builder: (_) => WeeklyScheduleEditor(
                      title: '${branch.name} · Çalışma saatleri',
                      hint: 'Listede olmayan günler kapalıdır. Her gün için tek bir açılış–kapanış aralığı girilir.',
                      onePerDay: true,
                      load: () => service.workingHours(branch.id),
                      save: (items) => service.setWorkingHours(branch.id, items),
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// Şube ekleme ([existing] null) veya düzenleme penceresi.
class _BranchDialog extends StatefulWidget {
  const _BranchDialog({required this.service, this.existing});

  final ManageService service;
  final Branch? existing;

  @override
  State<_BranchDialog> createState() => _BranchDialogState();
}

class _BranchDialogState extends State<_BranchDialog> {
  final _formKey = GlobalKey<FormState>();
  late final _name = TextEditingController(text: widget.existing?.name);
  late final _address = TextEditingController(text: widget.existing?.address);
  late final _phone = TextEditingController(text: widget.existing?.phone);
  late bool _isActive = widget.existing?.isActive ?? true;
  bool _loading = false;
  String? _error;

  @override
  void dispose() {
    _name.dispose();
    _address.dispose();
    _phone.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    if (!_formKey.currentState!.validate()) return;
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final existing = widget.existing;
      final branch = existing == null
          ? await widget.service.createBranch(name: _name.text, address: _address.text, phone: _phone.text)
          : await widget.service.updateBranch(
              existing.id,
              name: _name.text,
              address: _address.text,
              phone: _phone.text,
              isActive: _isActive,
            );
      if (mounted) Navigator.of(context).pop(branch);
    } catch (e) {
      if (mounted) setState(() => _error = errorText(e));
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: Text(widget.existing == null ? 'Şube Ekle' : 'Şubeyi Düzenle'),
      content: SizedBox(
        width: 400,
        child: Form(
          key: _formKey,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              if (_error != null) ErrorBanner(_error!),
              LabeledField(
                controller: _name,
                label: 'Şube adı',
                validator: (v) => Validators.requiredText(v, 'Şube adı'),
              ),
              LabeledField(controller: _address, label: 'Adres (isteğe bağlı)'),
              LabeledField(
                controller: _phone,
                label: 'Telefon (isteğe bağlı)',
                keyboardType: TextInputType.phone,
                validator: (v) => (v == null || v.trim().isEmpty) ? null : Validators.phone(v),
              ),
              if (widget.existing != null)
                SwitchListTile(
                  contentPadding: EdgeInsets.zero,
                  title: const Text('Aktif'),
                  subtitle: const Text(
                    'Pasif şube hastalara görünmez. İleri tarihli aktif randevusu olan şube pasifleştirilemez.',
                  ),
                  value: _isActive,
                  onChanged: (v) => setState(() => _isActive = v),
                ),
            ],
          ),
        ),
      ),
      actions: [
        TextButton(onPressed: () => Navigator.of(context).pop(), child: const Text('Vazgeç')),
        FilledButton(onPressed: _loading ? null : _submit, child: Text(widget.existing == null ? 'Ekle' : 'Kaydet')),
      ],
    );
  }
}
