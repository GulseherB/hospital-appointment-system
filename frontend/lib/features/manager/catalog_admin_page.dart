import 'package:flutter/material.dart';

import '../../app/app_scope.dart';
import '../../core/error/api_exception.dart';
import '../../repository/models/department_model.dart';
import '../../repository/models/hospital_model.dart';

class CatalogAdminPage extends StatefulWidget {
  const CatalogAdminPage({this.allowHospitalCreation = false, super.key});

  final bool allowHospitalCreation;

  @override
  State<CatalogAdminPage> createState() => _CatalogAdminPageState();
}

class _CatalogAdminPageState extends State<CatalogAdminPage> {
  final _name = TextEditingController();
  final _address = TextEditingController();
  final _description = TextEditingController();
  final _city = TextEditingController();
  final _district = TextEditingController();
  final _phone = TextEditingController();
  final _email = TextEditingController();
  final _departmentName = TextEditingController();
  final _serviceName = TextEditingController();
  final _serviceDuration = TextEditingController(text: '30');
  final _serviceFee = TextEditingController(text: '0');

  Future<List<HospitalModel>>? _hospitalsFuture;
  List<HospitalModel> _hospitals = [];
  List<DepartmentModel> _departments = [];
  int? _hospitalId;
  int? _departmentId;
  bool _busy = false;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    _hospitalsFuture ??= _refreshHospitals();
  }

  Future<List<HospitalModel>> _refreshHospitals() async {
    final items = await AppScope.of(context).catalogRepository.hospitals();
    if (mounted) {
      setState(() {
        _hospitals = items;
        if (_hospitalId != null &&
            !items.any((hospital) => hospital.id == _hospitalId)) {
          _hospitalId = null;
          _departments = [];
        }
      });
    }
    return items;
  }

  @override
  void dispose() {
    for (final controller in [
      _name,
      _address,
      _description,
      _city,
      _district,
      _phone,
      _email,
      _departmentName,
      _serviceName,
      _serviceDuration,
      _serviceFee,
    ]) {
      controller.dispose();
    }
    super.dispose();
  }

  Future<void> _createHospital() async {
    await _perform(() async {
      final hospital = await AppScope.of(context).catalogRepository
          .createAdminHospital(
            _name.text.trim(),
            _address.text.trim(),
            description: _description.text.trim(),
            city: _city.text.trim(),
            district: _district.text.trim(),
            phone: _phone.text.trim(),
            email: _email.text.trim(),
          );
      _hospitalId = hospital.id;
      await _refreshHospitals();
      if (!mounted) return;
      await _loadDepartments();
      _show('Hastane oluşturuldu. ID: ${hospital.id}');
    });
  }

  Future<void> _loadDepartments() async {
    if (_hospitalId == null) return;
    final repository = AppScope.of(context).catalogRepository;
    final branches = await repository.branches(_hospitalId!);
    if (!mounted) return;
    if (branches.isEmpty) return;
    final departments = await repository.departments(branches.first.id);
    if (mounted) {
      setState(() {
        _departments = departments;
        _departmentId = departments.isEmpty ? null : departments.first.id;
      });
    }
  }

  Future<void> _createDepartment() async {
    if (_hospitalId == null) {
      _show('Önce bir hastane seçin.');
      return;
    }
    await _perform(() async {
      final department = await AppScope.of(context).catalogRepository
          .createHospitalDepartment(_hospitalId!, _departmentName.text.trim());
      await _loadDepartments();
      _departmentId = department.id;
      _show('Bölüm oluşturuldu. ID: ${department.id}');
    });
  }

  Future<void> _createService() async {
    if (_departmentId == null) {
      _show('Önce bir bölüm seçin.');
      return;
    }
    await _perform(() async {
      await AppScope.of(context).catalogRepository.createService(
        _departmentId!,
        _serviceName.text.trim(),
        int.parse(_serviceDuration.text),
        double.parse(_serviceFee.text.replaceAll(',', '.')),
      );
      _show('Hizmet oluşturuldu.');
    });
  }

  Future<void> _perform(Future<void> Function() action) async {
    if (_busy) return;
    setState(() => _busy = true);
    try {
      await action();
    } catch (error) {
      _show(error is ApiException ? error.message : 'İşlem başarısız oldu.');
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  void _show(String message) {
    if (!mounted) return;
    ScaffoldMessenger.of(
      context,
    ).showSnackBar(SnackBar(content: Text(message)));
  }

  @override
  Widget build(BuildContext context) => Scaffold(
    appBar: AppBar(title: const Text('Hastane ve klinik yönetimi')),
    body: ListView(
      padding: const EdgeInsets.all(20),
      children: [
        _hospitalForm(),
        const SizedBox(height: 16),
        _selectionCard(),
        const SizedBox(height: 16),
        _departmentForm(),
        const SizedBox(height: 16),
        _serviceForm(),
      ],
    ),
  );

  Widget _hospitalForm() => _card(
    title: '1. Hastane bilgileri',
    children: [
      _field(_name, 'Hastane adı'),
      _field(_address, 'Adres'),
      _field(_description, 'Açıklama'),
      Row(
        children: [
          Expanded(child: _field(_city, 'Şehir')),
          const SizedBox(width: 8),
          Expanded(child: _field(_district, 'İlçe')),
        ],
      ),
      Row(
        children: [
          Expanded(child: _field(_phone, 'Telefon')),
          const SizedBox(width: 8),
          Expanded(child: _field(_email, 'E-posta')),
        ],
      ),
      _button('Hastaneyi kaydet', _createHospital),
    ],
  );

  Widget _selectionCard() => _card(
    title: '2. Hastane seçimi',
    children: [
      FutureBuilder<List<HospitalModel>>(
        future: _hospitalsFuture,
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const LinearProgressIndicator();
          }
          if (snapshot.hasError) {
            return Text('Hastaneler yüklenemedi: ${snapshot.error}');
          }
          return DropdownButtonFormField<int>(
            initialValue: _hospitalId,
            decoration: const InputDecoration(labelText: 'Hastane'),
            items: _hospitals
                .map(
                  (hospital) => DropdownMenuItem(
                    value: hospital.id,
                    child: Text('${hospital.name} (ID: ${hospital.id})'),
                  ),
                )
                .toList(),
            onChanged: (value) async {
              setState(() => _hospitalId = value);
              await _loadDepartments();
            },
          );
        },
      ),
      if (_hospitalId != null) _readOnlyId('Seçili hastane ID', _hospitalId!),
    ],
  );

  Widget _departmentForm() => _card(
    title: '3. Bölüm / poliklinik ekle',
    children: [
      const Text('Örnek: Göz, Nöroloji, Kardiyoloji, Ortopedi'),
      _field(_departmentName, 'Bölüm adı'),
      _button('Bölüm ekle', _createDepartment),
      if (_departments.isNotEmpty)
        DropdownButtonFormField<int>(
          initialValue: _departmentId,
          decoration: const InputDecoration(labelText: 'Hizmet için bölüm seç'),
          items: _departments
              .map(
                (department) => DropdownMenuItem(
                  value: department.id,
                  child: Text('${department.name} (ID: ${department.id})'),
                ),
              )
              .toList(),
          onChanged: (value) => setState(() => _departmentId = value),
        ),
    ],
  );

  Widget _serviceForm() => _card(
    title: '4. Sağlık hizmeti ekle',
    children: [
      _field(_serviceName, 'Hizmet adı'),
      Row(
        children: [
          Expanded(
            child: _field(_serviceDuration, 'Süre (dakika)', number: true),
          ),
          const SizedBox(width: 8),
          Expanded(child: _field(_serviceFee, 'Ücret (TL)', number: true)),
        ],
      ),
      _button('Hizmet ekle', _createService),
    ],
  );

  Widget _card({required String title, required List<Widget> children}) => Card(
    child: Padding(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(title, style: Theme.of(context).textTheme.titleMedium),
          const SizedBox(height: 8),
          ...children,
        ],
      ),
    ),
  );

  Widget _field(
    TextEditingController controller,
    String label, {
    bool number = false,
  }) => Padding(
    padding: const EdgeInsets.only(top: 8),
    child: TextField(
      controller: controller,
      keyboardType: number
          ? const TextInputType.numberWithOptions(decimal: true)
          : null,
      decoration: InputDecoration(labelText: label),
    ),
  );

  Widget _readOnlyId(String label, int id) => Padding(
    padding: const EdgeInsets.only(top: 8),
    child: TextFormField(
      initialValue: id.toString(),
      readOnly: true,
      decoration: InputDecoration(labelText: label),
    ),
  );

  Widget _button(String label, VoidCallback action) => Padding(
    padding: const EdgeInsets.only(top: 12),
    child: FilledButton(onPressed: _busy ? null : action, child: Text(label)),
  );
}
