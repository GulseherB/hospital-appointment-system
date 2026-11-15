import 'package:flutter/material.dart';

import '../../app_scope.dart';
import '../../core/validators.dart';
import '../../models/institution.dart';
import '../../services/manage_service.dart';
import '../../widgets/async_list.dart';
import '../../widgets/common.dart';

/// Kurum yöneticisi: hizmetler (süre ve ücret) ve hizmet ekleme.
class ServicesPage extends StatefulWidget {
  const ServicesPage({super.key});

  @override
  State<ServicesPage> createState() => _ServicesPageState();
}

class _ServiceRow {
  _ServiceRow(this.service, this.departmentLabel);

  final Service service;
  final String departmentLabel;
}

/// "Bölüm (Şube)" etiketleri.
Future<Map<int, String>> departmentLabels(ManageService service, {bool onlyActive = false}) async {
  final branches = {for (final b in await service.listBranches()) b.id: b};
  final departments = await service.listDepartments();
  return {
    for (final d in departments)
      if (!onlyActive || (d.isActive && (branches[d.branchId]?.isActive ?? false)))
        d.id: '${d.name} (${branches[d.branchId]?.name ?? '-'})',
  };
}

class _ServicesPageState extends State<ServicesPage> {
  final _listKey = GlobalKey<AsyncListViewState<_ServiceRow>>();

  Future<List<_ServiceRow>> _load(ManageService service) async {
    final labels = await departmentLabels(service);
    final services = await service.listServices();
    return [for (final s in services) _ServiceRow(s, labels[s.departmentId] ?? '-')];
  }

  Future<void> _create(ManageService service) async {
    final labels = await departmentLabels(service, onlyActive: true);
    if (!mounted) return;
    if (labels.isEmpty) {
      showMessage(context, 'Önce aktif bir bölüm ekleyin.');
      return;
    }
    final created = await showDialog<Service>(
      context: context,
      builder: (_) => _ServiceDialog(service: service, departments: labels),
    );
    if (created != null && mounted) {
      showMessage(context, '"${created.name}" hizmeti eklendi.');
      _listKey.currentState?.reload();
    }
  }

  @override
  Widget build(BuildContext context) {
    final service = ManageService(AppScope.of(context).api);
    return AsyncListView<_ServiceRow>(
      key: _listKey,
      load: () => _load(service),
      emptyText: 'Henüz hizmet yok.',
      header: Padding(
        padding: const EdgeInsets.fromLTRB(12, 12, 12, 0),
        child: Align(
          alignment: Alignment.centerRight,
          child: FilledButton.icon(
            onPressed: () => _create(service),
            icon: const Icon(Icons.add),
            label: const Text('Hizmet Ekle'),
          ),
        ),
      ),
      itemBuilder: (context, row, _) => Card(
        child: ListTile(
          leading: const Icon(Icons.medical_information),
          title: Text(row.service.name),
          subtitle: Text('${row.departmentLabel} · ${row.service.durationMin} dk · ${row.service.priceLabel}'),
          trailing: Wrap(
            spacing: 8,
            crossAxisAlignment: WrapCrossAlignment.center,
            children: [
              StatusChip(
                label: row.service.isActive ? 'Aktif' : 'Pasif',
                color: row.service.isActive ? Colors.green : Colors.grey,
              ),
              OutlinedButton.icon(
                icon: const Icon(Icons.edit),
                label: const Text('Düzenle'),
                onPressed: () => _edit(service, row),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Future<void> _edit(ManageService service, _ServiceRow row) async {
    final updated = await showDialog<Service>(
      context: context,
      builder: (_) => _ServiceDialog(
        service: service,
        departments: {row.service.departmentId!: row.departmentLabel},
        existing: row.service,
      ),
    );
    if (updated != null && mounted) {
      showMessage(context, '"${updated.name}" hizmeti güncellendi.');
      _listKey.currentState?.reload();
    }
  }
}

/// Hizmet ekleme ([existing] null) veya düzenleme penceresi. Düzenlemede bölüm değişmez.
class _ServiceDialog extends StatefulWidget {
  const _ServiceDialog({required this.service, required this.departments, this.existing});

  final ManageService service;
  final Map<int, String> departments;
  final Service? existing;

  @override
  State<_ServiceDialog> createState() => _ServiceDialogState();
}

class _ServiceDialogState extends State<_ServiceDialog> {
  final _formKey = GlobalKey<FormState>();
  late final _name = TextEditingController(text: widget.existing?.name);
  late final _duration = TextEditingController(text: '${widget.existing?.durationMin ?? 15}');
  late final _price = TextEditingController(text: widget.existing?.price);
  late int _departmentId = widget.departments.keys.first;
  late bool _isActive = widget.existing?.isActive ?? true;
  bool _loading = false;
  String? _error;

  @override
  void dispose() {
    _name.dispose();
    _duration.dispose();
    _price.dispose();
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
      final duration = int.parse(_duration.text.trim());
      final price = _price.text.trim().replaceAll(',', '.');
      final s = existing == null
          ? await widget.service.createService(
              departmentId: _departmentId,
              name: _name.text,
              durationMin: duration,
              price: price,
            )
          : await widget.service.updateService(
              existing.id,
              name: _name.text,
              durationMin: duration,
              price: price,
              isActive: _isActive,
            );
      if (mounted) Navigator.of(context).pop(s);
    } catch (e) {
      if (mounted) setState(() => _error = errorText(e));
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: Text(widget.existing == null ? 'Hizmet Ekle' : 'Hizmeti Düzenle'),
      content: SizedBox(
        width: 420,
        child: Form(
          key: _formKey,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              if (_error != null) ErrorBanner(_error!),
              Padding(
                padding: const EdgeInsets.only(bottom: 12),
                child: DropdownButtonFormField<int>(
                  initialValue: _departmentId,
                  isExpanded: true,
                  decoration: const InputDecoration(labelText: 'Bölüm', border: OutlineInputBorder()),
                  items: [
                    for (final e in widget.departments.entries) DropdownMenuItem(value: e.key, child: Text(e.value)),
                  ],
                  onChanged: (v) => setState(() => _departmentId = v!),
                ),
              ),
              LabeledField(
                controller: _name,
                label: 'Hizmet adı',
                validator: (v) => Validators.requiredText(v, 'Hizmet adı'),
              ),
              LabeledField(
                controller: _duration,
                label: 'Süre (dakika)',
                keyboardType: TextInputType.number,
                validator: (v) => Validators.durationMin(int.tryParse(v?.trim() ?? '')),
              ),
              LabeledField(
                controller: _price,
                label: 'Ücret (₺, ör. 750 veya 750.50)',
                keyboardType: const TextInputType.numberWithOptions(decimal: true),
                validator: (v) => Validators.price(v?.trim().replaceAll(',', '.')),
              ),
              Text(
                widget.existing == null
                    ? 'Randevu slotları 15 dakikalık ızgarada başlar; süre slot uzunluğunu belirler.'
                    : 'Süre ve ücret değişikliği yalnızca yeni randevuları etkiler; alınmış randevular eski değerlerle kalır.',
                style: const TextStyle(fontSize: 12),
              ),
              if (widget.existing != null)
                SwitchListTile(
                  contentPadding: EdgeInsets.zero,
                  title: const Text('Aktif'),
                  subtitle: const Text(
                    'Pasif hizmete randevu alınamaz. İleri tarihli aktif randevusu olan hizmet pasifleştirilemez.',
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
