import 'package:flutter/material.dart';

import '../core/date_utils.dart';
import '../models/appointment.dart';

/// Randevu listeleri için durum ve gün filtresi. Seçimler üst widget'ta tutulur.
class AppointmentFilterBar extends StatelessWidget {
  const AppointmentFilterBar({
    super.key,
    required this.status,
    required this.date,
    required this.onStatusChanged,
    required this.onDateChanged,
    this.extra,
  });

  final AppointmentStatus? status;
  final DateTime? date;
  final ValueChanged<AppointmentStatus?> onStatusChanged;
  final ValueChanged<DateTime?> onDateChanged;

  /// Ek filtre (ör. yönetici için doktor seçimi).
  final Widget? extra;

  Future<void> _pickDate(BuildContext context) async {
    final now = DateTime.now();
    final picked = await showDatePicker(
      context: context,
      initialDate: date ?? now,
      firstDate: DateTime(now.year - 1),
      lastDate: DateTime(now.year + 1, 12, 31),
      helpText: 'Gün seçin',
      cancelText: 'Vazgeç',
      confirmText: 'Seç',
    );
    if (picked != null) onDateChanged(picked);
  }

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(12, 12, 12, 0),
      child: Wrap(
        spacing: 8,
        runSpacing: 8,
        crossAxisAlignment: WrapCrossAlignment.center,
        children: [
          for (final s in [null, ...AppointmentStatus.values])
            ChoiceChip(label: Text(s?.label ?? 'Tümü'), selected: status == s, onSelected: (_) => onStatusChanged(s)),
          OutlinedButton.icon(
            onPressed: () => _pickDate(context),
            icon: const Icon(Icons.calendar_today, size: 18),
            label: Text(date == null ? 'Tüm günler' : ApiDate.displayDate(date!)),
          ),
          if (date != null)
            IconButton(
              tooltip: 'Gün filtresini kaldır',
              onPressed: () => onDateChanged(null),
              icon: const Icon(Icons.clear),
            ),
          ?extra,
        ],
      ),
    );
  }
}
