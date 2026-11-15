import 'package:flutter/material.dart';

import '../../app_scope.dart';
import '../../core/validators.dart';
import '../../models/institution.dart';
import '../../services/manage_service.dart';
import '../../widgets/async_list.dart';
import '../../widgets/common.dart';

/// Kurum yöneticisi: bölümler (şubeye bağlı) ve bölüm ekleme.
class DepartmentsPage extends StatefulWidget {
  const DepartmentsPage({super.key});

  @override
  State<DepartmentsPage> createState() => _DepartmentsPageState();
}

class _DepartmentsPageState extends State<DepartmentsPage> {
  final _listKey = GlobalKey<AsyncListViewState<_DepartmentRow>>();

  Future<List<_DepartmentRow>> _load(ManageService service) async {
    final branches = {for (final b in await service.listBranches()) b.id: b};
    final departments = await service.listDepartments();
    return [for (final d in departments) _DepartmentRow(d, branches[d.branchId]?.name ?? '-')];
  }

  Future<void> _create(ManageService service) async {
    final branches = (await service.listBranches()).where((b) => b.isActive).toList();
    if (!mounted) return;
    if (branches.isEmpty) {
      showMessage(context, 'Önce aktif bir şube ekleyin.');
      return;
    }
    final created = await showDialog<Department>(
      context: context,
      builder: (_) => _DepartmentDialog(service: service, branches: branches),
    );
    if (created != null && mounted) {
      showMessage(context, '"${created.name}" bölümü eklendi.');
      _listKey.currentState?.reload();
    }
  }

  @override
  Widget build(BuildContext context) {
    final service = ManageService(AppScope.of(context).api);
    return AsyncListView<_DepartmentRow>(
      key: _listKey,
      load: () => _load(service),
      emptyText: 'Henüz bölüm yok.',
      header: Padding(
        padding: const EdgeInsets.fromLTRB(12, 12, 12, 0),
        child: Align(
          alignment: Alignment.centerRight,
          child: FilledButton.icon(
            onPressed: () => _create(service),
            icon: const Icon(Icons.add),
            label: const Text('Bölüm Ekle'),
          ),
        ),
      ),
      itemBuilder: (context, row, _) => Card(
        child: ListTile(
          leading: const Icon(Icons.category),
          title: Text(row.department.name),
          subtitle: Text('Şube: ${row.branchName}'),
          trailing: Wrap(
            spacing: 8,
            crossAxisAlignment: WrapCrossAlignment.center,
            children: [
              StatusChip(
                label: row.department.isActive ? 'Aktif' : 'Pasif',
                color: row.department.isActive ? Colors.green : Colors.grey,
              ),
              OutlinedButton.icon(
                icon: const Icon(Icons.edit),
                label: const Text('Düzenle'),
                onPressed: () => _edit(service, row.department),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Future<void> _edit(ManageService service, Department department) async {
    final updated = await showDialog<Department>(
      context: context,
      builder: (_) => _DepartmentEditDialog(service: service, department: department),
    );
    if (updated != null && mounted) {
      showMessage(context, '"${updated.name}" bölümü güncellendi.');
      _listKey.currentState?.reload();
    }
  }
}

/// Bölüm düzenleme: ad ve aktiflik (bölümün şubesi değişmez).
class _DepartmentEditDialog extends StatefulWidget {
  const _DepartmentEditDialog({required this.service, required this.department});

  final ManageService service;
  final Department department;

  @override
  State<_DepartmentEditDialog> createState() => _DepartmentEditDialogState();
}

class _DepartmentEditDialogState extends State<_DepartmentEditDialog> {
  final _formKey = GlobalKey<FormState>();
  late final _name = TextEditingController(text: widget.department.name);
  late bool _isActive = widget.department.isActive;
  bool _loading = false;
  String? _error;

  @override
  void dispose() {
    _name.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    if (!_formKey.currentState!.validate()) return;
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final d = await widget.service.updateDepartment(widget.department.id, name: _name.text, isActive: _isActive);
      if (mounted) Navigator.of(context).pop(d);
    } catch (e) {
      if (mounted) setState(() => _error = errorText(e));
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: const Text('Bölümü Düzenle'),
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
                label: 'Bölüm adı',
                validator: (v) => Validators.requiredText(v, 'Bölüm adı'),
              ),
              SwitchListTile(
                contentPadding: EdgeInsets.zero,
                title: const Text('Aktif'),
                subtitle: const Text(
                  'Pasif bölüm ve hizmetleri hastalara görünmez. İleri tarihli aktif randevusu olan bölüm '
                  'pasifleştirilemez.',
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
        FilledButton(onPressed: _loading ? null : _submit, child: const Text('Kaydet')),
      ],
    );
  }
}

class _DepartmentRow {
  _DepartmentRow(this.department, this.branchName);

  final Department department;
  final String branchName;
}

class _DepartmentDialog extends StatefulWidget {
  const _DepartmentDialog({required this.service, required this.branches});

  final ManageService service;
  final List<Branch> branches;

  @override
  State<_DepartmentDialog> createState() => _DepartmentDialogState();
}

class _DepartmentDialogState extends State<_DepartmentDialog> {
  final _formKey = GlobalKey<FormState>();
  final _name = TextEditingController();
  late int _branchId = widget.branches.first.id;
  bool _loading = false;
  String? _error;

  @override
  void dispose() {
    _name.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    if (!_formKey.currentState!.validate()) return;
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final d = await widget.service.createDepartment(branchId: _branchId, name: _name.text);
      if (mounted) Navigator.of(context).pop(d);
    } catch (e) {
      if (mounted) setState(() => _error = errorText(e));
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: const Text('Bölüm Ekle'),
      content: SizedBox(
        width: 400,
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
                  items: [for (final b in widget.branches) DropdownMenuItem(value: b.id, child: Text(b.name))],
                  onChanged: (v) => setState(() => _branchId = v!),
                ),
              ),
              LabeledField(
                controller: _name,
                label: 'Bölüm adı',
                validator: (v) => Validators.requiredText(v, 'Bölüm adı'),
              ),
            ],
          ),
        ),
      ),
      actions: [
        TextButton(onPressed: () => Navigator.of(context).pop(), child: const Text('Vazgeç')),
        FilledButton(onPressed: _loading ? null : _submit, child: const Text('Ekle')),
      ],
    );
  }
}
