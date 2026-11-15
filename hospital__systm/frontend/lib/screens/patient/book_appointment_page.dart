import 'package:flutter/material.dart';

import '../../app_scope.dart';
import '../../core/date_utils.dart';
import '../../models/appointment.dart';
import '../../models/institution.dart';
import '../../services/api_client.dart';
import '../../services/appointment_service.dart';
import '../../widgets/async_list.dart';
import '../../widgets/common.dart';

/// Hasta randevu alma akışı: kurum → şube → bölüm → hizmet → (isteğe bağlı doktor) → gün → saat.
/// Hasta saat yazmaz; yalnızca sunucunun ürettiği slotlardan birini seçer.
class BookAppointmentPage extends StatefulWidget {
  const BookAppointmentPage({super.key, this.onBooked, this.now});

  /// Randevu oluşturulduktan sonra çağrılır (ör. "Randevularım" sayfasına geçmek için).
  final VoidCallback? onBooked;

  /// Testler için saat kaynağı; verilmezse cihaz saati.
  final DateTime Function()? now;

  @override
  State<BookAppointmentPage> createState() => _BookAppointmentPageState();
}

class _BookAppointmentPageState extends State<BookAppointmentPage> {
  late final PatientService _service = PatientService(AppScope.of(context).api);

  List<Institution>? _institutions;
  List<Branch>? _branches;
  List<Department>? _departments;
  List<Service>? _services;
  List<AppointmentSlot>? _slots;

  Institution? _institution;
  Branch? _branch;
  Department? _department;
  Service? _serviceItem;
  int? _doctorId;
  DateTime? _day;

  bool _loading = false;
  bool _booking = false;
  String? _error;

  DateTime _now() => (widget.now ?? DateTime.now)();

  @override
  void initState() {
    super.initState();
    // İlk yükleme ilk çizimden sonra başlar (AppScope'a ve setState'e güvenle erişmek için).
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) _fetch(() async => _institutions = await _service.institutions());
    });
  }

  Future<void> _fetch(Future<void> Function() load) async {
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      await load();
    } catch (e) {
      _error = errorText(e);
    }
    if (mounted) setState(() => _loading = false);
  }

  void _selectInstitution(Institution? i) {
    setState(() {
      _institution = i;
      _branch = _department = _serviceItem = null;
      _branches = _departments = _services = _slots = null;
    });
    if (i != null) _fetch(() async => _branches = await _service.branches(i.id));
  }

  void _selectBranch(Branch? b) {
    setState(() {
      _branch = b;
      _department = _serviceItem = null;
      _departments = _services = _slots = null;
    });
    if (b != null) _fetch(() async => _departments = await _service.departments(b.id));
  }

  void _selectDepartment(Department? d) {
    setState(() {
      _department = d;
      _serviceItem = null;
      _services = _slots = null;
    });
    if (d != null) _fetch(() async => _services = await _service.services(d.id));
  }

  void _selectService(Service? s) {
    setState(() {
      _serviceItem = s;
      _slots = null;
      _doctorId = null;
      _day = null;
    });
    if (s != null) _loadSlots();
  }

  /// Slotları sunucudan alır ve arayüz kurallarıyla (öğle arası, 24 saat, 7 gün) bir kez daha süzer.
  Future<void> _loadSlots() async {
    final service = _serviceItem;
    if (service == null) return;
    await _fetch(() async {
      final now = _now();
      final slots = await _service.slots(service.id);
      _slots = slots.where((s) => BookingRules.allows(s, now)).toList();
      final days = _days();
      if (_day == null || !days.contains(_day)) _day = days.isEmpty ? null : days.first;
    });
  }

  List<AppointmentSlot> get _filteredSlots =>
      (_slots ?? const []).where((s) => _doctorId == null || s.doctorId == _doctorId).toList();

  static DateTime _dateOf(DateTime t) => DateTime(t.year, t.month, t.day);

  List<DateTime> _days() {
    final days = <DateTime>{for (final s in _filteredSlots) _dateOf(s.startAt)}.toList()..sort();
    return days;
  }

  Future<void> _book(AppointmentSlot slot) async {
    final service = _serviceItem!;
    final ok = await confirmAction(
      context,
      title: 'Randevuyu onayla',
      message:
          '${_institution!.name} · ${_branch!.name}\n'
          '${_department!.name} · ${service.name} (${service.durationMin} dk)\n'
          'Dr. ${slot.doctorName}\n'
          '${ApiDate.display(slot.startAt)} (${ApiDate.weekdayName(slot.startAt.weekday)})\n'
          'Ücret: ${service.priceLabel} (bilgi amaçlıdır, ödeme alınmaz)\n\n'
          'Randevunuz doktor onayına gönderilecek. Doktor başlangıçtan 12 saat öncesine kadar onaylamazsa '
          'randevu otomatik iptal edilir.',
      confirmLabel: 'Randevu Al',
    );
    if (!ok || !mounted) return;
    setState(() => _booking = true);
    try {
      await _service.book(serviceId: service.id, slot: slot);
      if (!mounted) return;
      showMessage(context, 'Randevu talebiniz alındı. Doktor onayını "Randevularım" sayfasından izleyebilirsiniz.');
      widget.onBooked?.call();
    } on ApiException catch (e) {
      if (!mounted) return;
      showMessage(context, e.message);
    } catch (e) {
      if (mounted) showMessage(context, errorText(e));
    }
    if (!mounted) return;
    setState(() => _booking = false);
    await _loadSlots(); // dolan slotun listeden düşmesi için
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        Card(
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('1. Hizmet seçimi', style: theme.textTheme.titleMedium),
                const SizedBox(height: 12),
                _Picker<Institution>(
                  label: 'Kurum',
                  items: _institutions,
                  value: _institution,
                  itemLabel: (i) => '${i.name} (${i.type.label})',
                  onChanged: _selectInstitution,
                  emptyText: 'Randevu alınabilecek kurum yok.',
                ),
                _Picker<Branch>(
                  key: ValueKey('branch-${_institution?.id}'),
                  label: 'Şube',
                  items: _branches,
                  value: _branch,
                  itemLabel: (b) => b.name,
                  onChanged: _selectBranch,
                  emptyText: 'Bu kurumda aktif şube yok.',
                ),
                _Picker<Department>(
                  key: ValueKey('department-${_branch?.id}'),
                  label: 'Bölüm',
                  items: _departments,
                  value: _department,
                  itemLabel: (d) => d.name,
                  onChanged: _selectDepartment,
                  emptyText: 'Bu şubede aktif bölüm yok.',
                ),
                _Picker<Service>(
                  key: ValueKey('service-${_department?.id}'),
                  label: 'Hizmet',
                  items: _services,
                  value: _serviceItem,
                  itemLabel: (s) => '${s.name} · ${s.durationMin} dk · ${s.priceLabel}',
                  onChanged: _selectService,
                  emptyText: 'Bu bölümde aktif hizmet yok.',
                ),
              ],
            ),
          ),
        ),
        if (_error != null) Padding(padding: const EdgeInsets.only(top: 12), child: ErrorBanner(_error!)),
        if (_loading)
          const Padding(
            padding: EdgeInsets.all(24),
            child: Center(child: CircularProgressIndicator()),
          ),
        if (_serviceItem != null && _slots != null && !_loading) _slotSection(theme),
      ],
    );
  }

  Widget _slotSection(ThemeData theme) {
    final slots = _slots!;
    final doctors = <int, String>{for (final s in slots) s.doctorId: s.doctorName};
    final days = _days();
    final day = _day;
    final daySlots = _filteredSlots.where((s) => day != null && _dateOf(s.startAt) == day).toList();
    final byDoctor = <int, List<AppointmentSlot>>{};
    for (final s in daySlots) {
      byDoctor.putIfAbsent(s.doctorId, () => []).add(s);
    }

    return Card(
      margin: const EdgeInsets.only(top: 12),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('2. Uygun saatler', style: theme.textTheme.titleMedium),
            const SizedBox(height: 4),
            Text(
              'Saatler en erken 24 saat sonrası ve en fazla 7 gün sonrası için listelenir. '
              '12:00–13:00 öğle arasıdır.',
              style: theme.textTheme.bodySmall,
            ),
            const SizedBox(height: 12),
            if (slots.isEmpty)
              const Text('Bu hizmet için önümüzdeki 7 günde boş saat yok.')
            else ...[
              if (doctors.length > 1)
                Padding(
                  padding: const EdgeInsets.only(bottom: 12),
                  child: DropdownButtonFormField<int?>(
                    initialValue: _doctorId,
                    decoration: const InputDecoration(labelText: 'Doktor', border: OutlineInputBorder()),
                    items: [
                      const DropdownMenuItem<int?>(value: null, child: Text('Tüm doktorlar')),
                      for (final e in doctors.entries)
                        DropdownMenuItem<int?>(value: e.key, child: Text('Dr. ${e.value}')),
                    ],
                    onChanged: (v) => setState(() {
                      _doctorId = v;
                      final d = _days();
                      if (!d.contains(_day)) _day = d.isEmpty ? null : d.first;
                    }),
                  ),
                ),
              Wrap(
                spacing: 8,
                runSpacing: 8,
                children: [
                  for (final d in days)
                    ChoiceChip(
                      label: Text(
                        '${ApiDate.weekdayName(d.weekday).substring(0, 3)} ${ApiDate.displayDate(d).substring(0, 5)}',
                      ),
                      selected: d == day,
                      onSelected: (_) => setState(() => _day = d),
                    ),
                ],
              ),
              const Divider(height: 24),
              for (final entry in byDoctor.entries) ...[
                Text('Dr. ${doctors[entry.key]}', style: theme.textTheme.titleSmall),
                const SizedBox(height: 8),
                Wrap(
                  spacing: 8,
                  runSpacing: 8,
                  children: [
                    for (final s in entry.value)
                      ActionChip(
                        avatar: const Icon(Icons.schedule, size: 16),
                        label: Text(ApiDate.display(s.startAt).substring(11)),
                        onPressed: _booking ? null : () => _book(s),
                      ),
                  ],
                ),
                const SizedBox(height: 16),
              ],
            ],
          ],
        ),
      ),
    );
  }
}

/// Bağımlı seçim kutusu. [items] null ise üst seçim yapılmamıştır (pasif).
class _Picker<T> extends StatelessWidget {
  const _Picker({
    super.key,
    required this.label,
    required this.items,
    required this.value,
    required this.itemLabel,
    required this.onChanged,
    required this.emptyText,
  });

  final String label;
  final List<T>? items;
  final T? value;
  final String Function(T) itemLabel;
  final ValueChanged<T?> onChanged;
  final String emptyText;

  @override
  Widget build(BuildContext context) {
    final list = items;
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: DropdownButtonFormField<T>(
        initialValue: value,
        isExpanded: true,
        decoration: InputDecoration(
          labelText: label,
          border: const OutlineInputBorder(),
          helperText: list != null && list.isEmpty ? emptyText : null,
        ),
        items: [for (final i in list ?? <T>[]) DropdownMenuItem<T>(value: i, child: Text(itemLabel(i)))],
        onChanged: list == null || list.isEmpty ? null : onChanged,
      ),
    );
  }
}
