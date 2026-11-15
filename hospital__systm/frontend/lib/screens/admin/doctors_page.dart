import 'package:flutter/material.dart';

import '../../app_scope.dart';
import '../../core/validators.dart';
import '../../models/institution.dart';
import '../../services/manage_service.dart';
import '../../widgets/async_list.dart';
import '../../widgets/common.dart';
import '../../widgets/temp_password_dialog.dart';
import 'services_page.dart';
import 'weekly_schedule_editor.dart';

/// Kurum yöneticisi: doktorlar, doktor ekleme ve düzenleme (geçici şifre), hizmet atama, uygunluk, şifre sıfırlama.
class DoctorsPage extends StatefulWidget {
  const DoctorsPage({super.key});

  @override
  State<DoctorsPage> createState() => _DoctorsPageState();
}

class _DoctorRow {
  _DoctorRow(this.record, this.departmentLabel);

  final DoctorRecord record;
  final String departmentLabel;
}

class _DoctorsPageState extends State<DoctorsPage> {
  final _listKey = GlobalKey<AsyncListViewState<_DoctorRow>>();

  Future<List<_DoctorRow>> _load(ManageService service) async {
    final labels = await departmentLabels(service);
    final doctors = await service.listDoctors();
    return [for (final d in doctors) _DoctorRow(d, labels[d.doctor.departmentId] ?? '-')];
  }

  /// Ekleme ve düzenleme penceresi için şube ve bölümler. Düzenlemede doktorun mevcut (pasif olabilir) kayıtları da listede kalır.
  Future<({List<Branch> branches, List<Department> departments})> _choices(
    ManageService service, [
    DoctorRecord? current,
  ]) async {
    final branches = (await service.listBranches())
        .where((b) => b.isActive || b.id == current?.doctor.branchId)
        .toList();
    final departments = (await service.listDepartments())
        .where((d) => d.isActive || d.id == current?.doctor.departmentId)
        .toList();
    return (branches: branches, departments: departments);
  }

  Future<void> _create(ManageService service) async {
    final choices = await _choices(service);
    if (!mounted) return;
    if (choices.branches.isEmpty || choices.departments.isEmpty) {
      showMessage(context, 'Önce aktif bir şube ve bölüm ekleyin.');
      return;
    }
    final created = await showDialog<CreatedDoctor>(
      context: context,
      builder: (_) => _DoctorDialog(service: service, branches: choices.branches, departments: choices.departments),
    );
    if (created == null || !mounted) return;
    _listKey.currentState?.reload();
    await TempPasswordDialog.show(
      context,
      title: 'Doktor hesabı açıldı',
      name: created.doctor.doctor.displayName,
      email: created.doctor.doctor.email,
      password: created.temporaryPassword,
      recipient: 'Doktora',
    );
  }

  Future<void> _edit(ManageService service, DoctorRecord record) async {
    final choices = await _choices(service, record);
    if (!mounted) return;
    final result = await showDialog<DoctorUpdateResult>(
      context: context,
      builder: (_) => _DoctorDialog(
        service: service,
        branches: choices.branches,
        departments: choices.departments,
        existing: record,
      ),
    );
    if (result == null || !mounted) return;
    final notes = [
      'Doktor güncellendi.',
      if (result.removedServiceIds.isNotEmpty)
        '${result.removedServiceIds.length} hizmet ataması yeni bölüme uymadığı için kaldırıldı.',
      if (result.availabilityCleared) 'Uygunluk yeni şubenin saatlerine uymadığı için silindi; yeniden girin.',
    ];
    showMessage(context, notes.join(' '));
    _listKey.currentState?.reload();
  }

  Future<void> _resetPassword(ManageService service, DoctorRecord record) async {
    final ok = await confirmAction(
      context,
      title: 'Şifreyi sıfırla',
      message:
          '${record.doctor.displayName} için yeni bir geçici şifre üretilecek. Eski şifre geçersiz olur; '
          'doktor ilk girişte şifresini değiştirmek zorunda kalır.',
      confirmLabel: 'Sıfırla',
    );
    if (!ok || !mounted) return;
    try {
      final reset = await service.resetDoctorPassword(record.doctor.id);
      if (!mounted) return;
      await TempPasswordDialog.show(
        context,
        title: 'Şifre sıfırlandı',
        name: reset.doctor.doctor.displayName,
        email: reset.doctor.doctor.email,
        password: reset.temporaryPassword,
        recipient: 'Doktora',
      );
    } catch (e) {
      if (mounted) showMessage(context, errorText(e));
    }
  }

  Future<void> _editServices(ManageService service, DoctorRecord record) async {
    final services = (await service.listServices(
      departmentId: record.doctor.departmentId,
    )).where((s) => s.isActive).toList();
    if (!mounted) return;
    final saved = await showDialog<bool>(
      context: context,
      builder: (_) => _DoctorServicesDialog(service: service, record: record, services: services),
    );
    if (saved == true && mounted) {
      showMessage(context, 'Hizmetler güncellendi.');
      _listKey.currentState?.reload();
    }
  }

  @override
  Widget build(BuildContext context) {
    final service = ManageService(AppScope.of(context).api);
    return AsyncListView<_DoctorRow>(
      key: _listKey,
      load: () => _load(service),
      emptyText: 'Henüz doktor yok.',
      header: Padding(
        padding: const EdgeInsets.fromLTRB(12, 12, 12, 0),
        child: Align(
          alignment: Alignment.centerRight,
          child: FilledButton.icon(
            onPressed: () => _create(service),
            icon: const Icon(Icons.person_add),
            label: const Text('Doktor Ekle'),
          ),
        ),
      ),
      itemBuilder: (context, row, _) {
        final d = row.record.doctor;
        return Card(
          child: Padding(
            padding: const EdgeInsets.all(12),
            child: Wrap(
              alignment: WrapAlignment.spaceBetween,
              crossAxisAlignment: WrapCrossAlignment.center,
              runSpacing: 8,
              children: [
                ConstrainedBox(
                  constraints: const BoxConstraints(minWidth: 280),
                  child: ListTile(
                    contentPadding: EdgeInsets.zero,
                    leading: const Icon(Icons.badge),
                    title: Text(d.displayName),
                    subtitle: Text(
                      '${row.departmentLabel}${d.specialty.isNotEmpty ? ' · ${d.specialty}' : ''}\n'
                      '${d.email} · ${row.record.phone} · ${row.record.serviceIds.length} hizmet',
                    ),
                    isThreeLine: true,
                  ),
                ),
                Wrap(
                  spacing: 8,
                  runSpacing: 8,
                  crossAxisAlignment: WrapCrossAlignment.center,
                  children: [
                    StatusChip(label: d.isActive ? 'Aktif' : 'Pasif', color: d.isActive ? Colors.green : Colors.grey),
                    OutlinedButton.icon(
                      icon: const Icon(Icons.edit),
                      label: const Text('Düzenle'),
                      onPressed: () => _edit(service, row.record),
                    ),
                    OutlinedButton.icon(
                      icon: const Icon(Icons.medical_information),
                      label: const Text('Hizmetler'),
                      onPressed: () => _editServices(service, row.record),
                    ),
                    OutlinedButton.icon(
                      icon: const Icon(Icons.schedule),
                      label: const Text('Uygunluk'),
                      onPressed: () => Navigator.of(context).push(
                        MaterialPageRoute<void>(
                          builder: (_) => WeeklyScheduleEditor(
                            title: '${d.displayName} · Uygunluk',
                            hint:
                                'Dilimler şubenin çalışma saatleri içinde olmalıdır. 12:00–13:00 öğle arası '
                                'randevu üretiminde otomatik kesilir; aralığa dahil edebilirsiniz.',
                            onePerDay: false,
                            load: () => service.availability(d.id),
                            save: (items) => service.setAvailability(d.id, items),
                          ),
                        ),
                      ),
                    ),
                    TextButton.icon(
                      icon: const Icon(Icons.key),
                      label: const Text('Şifre Sıfırla'),
                      onPressed: () => _resetPassword(service, row.record),
                    ),
                  ],
                ),
              ],
            ),
          ),
        );
      },
    );
  }
}

/// Doktor ekleme ([existing] null) veya düzenleme penceresi.
/// Ekleme sonucu [CreatedDoctor], düzenleme sonucu [DoctorUpdateResult] döner.
class _DoctorDialog extends StatefulWidget {
  const _DoctorDialog({required this.service, required this.branches, required this.departments, this.existing});

  final ManageService service;
  final List<Branch> branches;
  final List<Department> departments;
  final DoctorRecord? existing;

  @override
  State<_DoctorDialog> createState() => _DoctorDialogState();
}

class _DoctorDialogState extends State<_DoctorDialog> {
  final _formKey = GlobalKey<FormState>();
  late final _firstName = TextEditingController(text: widget.existing?.doctor.firstName);
  late final _lastName = TextEditingController(text: widget.existing?.doctor.lastName);
  late final _email = TextEditingController(text: widget.existing?.doctor.email);
  late final _phone = TextEditingController(text: widget.existing?.phone);
  late final _specialty = TextEditingController(text: widget.existing?.doctor.specialty);
  late int _branchId = widget.existing?.doctor.branchId ?? widget.branches.first.id;
  int? _departmentId;
  late bool _isActive = widget.existing?.doctor.isActive ?? true;
  bool _loading = false;
  String? _error;

  bool get _editing => widget.existing != null;

  List<Department> get _branchDepartments => widget.departments.where((d) => d.branchId == _branchId).toList();

  @override
  void initState() {
    super.initState();
    _departmentId = widget.existing?.doctor.departmentId ?? _branchDepartments.firstOrNull?.id;
  }

  @override
  void dispose() {
    for (final c in [_firstName, _lastName, _email, _phone, _specialty]) {
      c.dispose();
    }
    super.dispose();
  }

  Future<void> _submit() async {
    if (!_formKey.currentState!.validate()) return;
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final Object result;
      final existing = widget.existing;
      if (existing != null) {
        result = await widget.service.updateDoctor(
          existing.doctor.id,
          branchId: _branchId,
          departmentId: _departmentId!,
          firstName: _firstName.text,
          lastName: _lastName.text,
          phone: _phone.text,
          specialty: _specialty.text,
          isActive: _isActive,
        );
      } else {
        result = await widget.service.createDoctor(
          branchId: _branchId,
          departmentId: _departmentId!,
          firstName: _firstName.text,
          lastName: _lastName.text,
          email: _email.text,
          phone: _phone.text,
          specialty: _specialty.text,
        );
      }
      if (mounted) Navigator.of(context).pop(result);
    } catch (e) {
      if (mounted) setState(() => _error = errorText(e));
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final departments = _branchDepartments;
    final existing = widget.existing?.doctor;
    final moving = existing != null && (existing.branchId != _branchId || existing.departmentId != _departmentId);
    return AlertDialog(
      title: Text(_editing ? 'Doktoru Düzenle' : 'Doktor Ekle'),
      content: SizedBox(
        width: 440,
        child: SingleChildScrollView(
          child: Form(
            key: _formKey,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                if (_error != null) ErrorBanner(_error!),
                Padding(
                  padding: const EdgeInsets.only(bottom: 12),
                  child: DropdownButtonFormField<int>(
                    initialValue: _branchId,
                    decoration: const InputDecoration(labelText: 'Şube', border: OutlineInputBorder()),
                    items: [
                      for (final b in widget.branches)
                        DropdownMenuItem(value: b.id, child: Text(b.isActive ? b.name : '${b.name} (pasif)')),
                    ],
                    onChanged: (v) => setState(() {
                      _branchId = v!;
                      _departmentId = _branchDepartments.firstOrNull?.id;
                    }),
                  ),
                ),
                Padding(
                  padding: const EdgeInsets.only(bottom: 12),
                  child: DropdownButtonFormField<int>(
                    key: ValueKey(_branchId),
                    initialValue: _departmentId,
                    decoration: const InputDecoration(labelText: 'Bölüm', border: OutlineInputBorder()),
                    items: [
                      for (final d in departments)
                        DropdownMenuItem(value: d.id, child: Text(d.isActive ? d.name : '${d.name} (pasif)')),
                    ],
                    validator: (v) => v == null ? 'Bu şubede bölüm yok; önce bölüm ekleyin.' : null,
                    onChanged: (v) => setState(() => _departmentId = v),
                  ),
                ),
                if (moving)
                  const Padding(
                    padding: EdgeInsets.only(bottom: 12),
                    child: Text(
                      'Şube veya bölüm değişirse yeni bölüme ait olmayan hizmet atamaları kaldırılır; yeni şubenin '
                      'saatlerine uymayan uygunluk silinir. İleri tarihli aktif randevusu olan doktor taşınamaz.',
                      style: TextStyle(fontSize: 12),
                    ),
                  ),
                LabeledField(controller: _firstName, label: 'Ad', validator: (v) => Validators.requiredText(v, 'Ad')),
                LabeledField(
                  controller: _lastName,
                  label: 'Soyad',
                  validator: (v) => Validators.requiredText(v, 'Soyad'),
                ),
                if (!_editing)
                  LabeledField(
                    controller: _email,
                    label: 'E-posta (giriş için)',
                    keyboardType: TextInputType.emailAddress,
                    validator: Validators.email,
                  ),
                LabeledField(
                  controller: _phone,
                  label: 'Telefon',
                  keyboardType: TextInputType.phone,
                  validator: Validators.phone,
                ),
                LabeledField(controller: _specialty, label: 'Uzmanlık (isteğe bağlı)'),
                if (_editing)
                  SwitchListTile(
                    contentPadding: EdgeInsets.zero,
                    title: const Text('Aktif'),
                    subtitle: const Text(
                      'Pasif doktora randevu alınamaz. İleri tarihli randevusu varsa pasifleştirilemez.',
                    ),
                    value: _isActive,
                    onChanged: (v) => setState(() => _isActive = v),
                  )
                else
                  const Text(
                    'Sistem rastgele bir geçici şifre üretir; doktor ilk girişte değiştirir.',
                    style: TextStyle(fontSize: 12),
                  ),
              ],
            ),
          ),
        ),
      ),
      actions: [
        TextButton(onPressed: () => Navigator.of(context).pop(), child: const Text('Vazgeç')),
        FilledButton(onPressed: _loading ? null : _submit, child: Text(_editing ? 'Kaydet' : 'Ekle')),
      ],
    );
  }
}

class _DoctorServicesDialog extends StatefulWidget {
  const _DoctorServicesDialog({required this.service, required this.record, required this.services});

  final ManageService service;
  final DoctorRecord record;
  final List<Service> services;

  @override
  State<_DoctorServicesDialog> createState() => _DoctorServicesDialogState();
}

class _DoctorServicesDialogState extends State<_DoctorServicesDialog> {
  late final Set<int> _selected = {...widget.record.serviceIds};
  bool _loading = false;
  String? _error;

  Future<void> _save() async {
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      // Pasif hizmetlerin mevcut atamaları korunur (listede görünmeseler de).
      final activeIds = widget.services.map((s) => s.id).toSet();
      final kept = widget.record.serviceIds.where((id) => !activeIds.contains(id));
      await widget.service.setDoctorServices(widget.record.doctor.id, {..._selected, ...kept}.toList()..sort());
      if (mounted) Navigator.of(context).pop(true);
    } catch (e) {
      if (mounted) setState(() => _error = errorText(e));
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: Text('${widget.record.doctor.displayName} · Hizmetler'),
      content: SizedBox(
        width: 420,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            if (_error != null) ErrorBanner(_error!),
            if (widget.services.isEmpty)
              const Text('Doktorun bölümünde aktif hizmet yok. Önce "Hizmetler" sayfasından ekleyin.'),
            for (final s in widget.services)
              CheckboxListTile(
                value: _selected.contains(s.id),
                title: Text(s.name),
                subtitle: Text('${s.durationMin} dk · ${s.priceLabel}'),
                onChanged: (v) => setState(() => v! ? _selected.add(s.id) : _selected.remove(s.id)),
              ),
          ],
        ),
      ),
      actions: [
        TextButton(onPressed: () => Navigator.of(context).pop(false), child: const Text('Vazgeç')),
        FilledButton(onPressed: _loading ? null : _save, child: const Text('Kaydet')),
      ],
    );
  }
}
