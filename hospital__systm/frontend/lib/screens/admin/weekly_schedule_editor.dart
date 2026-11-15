import 'package:flutter/material.dart';

import '../../core/date_utils.dart';
import '../../models/clock_time.dart';
import '../../widgets/common.dart';

/// Haftalık saat aralığı düzenleyici (şube çalışma saatleri ve doktor uygunluğu için ortak).
/// [onePerDay] true ise her gün en fazla bir aralık girilebilir (çalışma saati).
class WeeklyScheduleEditor extends StatefulWidget {
  const WeeklyScheduleEditor({
    super.key,
    required this.title,
    required this.load,
    required this.save,
    required this.onePerDay,
    this.hint,
  });

  final String title;
  final Future<List<WeeklyTimeRange>> Function() load;
  final Future<List<WeeklyTimeRange>> Function(List<WeeklyTimeRange>) save;
  final bool onePerDay;
  final String? hint;

  @override
  State<WeeklyScheduleEditor> createState() => _WeeklyScheduleEditorState();
}

class _Row {
  _Row(this.weekday, this.start, this.end);

  int weekday;
  ClockTime start;
  ClockTime end;
}

class _WeeklyScheduleEditorState extends State<WeeklyScheduleEditor> {
  List<_Row>? _rows;
  String? _error;
  bool _saving = false;

  @override
  void initState() {
    super.initState();
    _reload();
  }

  Future<void> _reload() async {
    try {
      final items = await widget.load();
      setState(() => _rows = [for (final r in items) _Row(r.weekday, r.start, r.end)]);
    } catch (e) {
      setState(() {
        _rows = [];
        _error = errorText(e);
      });
    }
  }

  /// Kayıttan önce istemci tarafı doğrulama (asıl doğrulama sunucudadır).
  List<WeeklyTimeRange>? _validated() {
    final ranges = <WeeklyTimeRange>[];
    for (final r in _rows!) {
      if (!r.start.isBefore(r.end)) {
        setState(() => _error = '${ApiDate.weekdayName(r.weekday)}: bitiş saati başlangıçtan sonra olmalıdır.');
        return null;
      }
      final range = WeeklyTimeRange(weekday: r.weekday, start: r.start, end: r.end);
      for (final other in ranges) {
        if (other.weekday != range.weekday) continue;
        if (widget.onePerDay) {
          setState(() => _error = '${ApiDate.weekdayName(r.weekday)} günü birden fazla kez girilmiş.');
          return null;
        }
        if (other.overlaps(range)) {
          setState(() => _error = '${ApiDate.weekdayName(r.weekday)}: aralıklar çakışıyor.');
          return null;
        }
      }
      ranges.add(range);
    }
    return ranges;
  }

  Future<void> _save() async {
    final ranges = _validated();
    if (ranges == null) return;
    setState(() {
      _saving = true;
      _error = null;
    });
    try {
      final saved = await widget.save(ranges);
      if (!mounted) return;
      setState(() => _rows = [for (final r in saved) _Row(r.weekday, r.start, r.end)]);
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Kaydedildi.')));
    } catch (e) {
      if (mounted) setState(() => _error = errorText(e));
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  Future<void> _pickTime(_Row row, bool isStart) async {
    final current = isStart ? row.start : row.end;
    final picked = await showTimePicker(
      context: context,
      initialTime: TimeOfDay(hour: current.hour, minute: current.minute),
      builder: (context, child) =>
          MediaQuery(data: MediaQuery.of(context).copyWith(alwaysUse24HourFormat: true), child: child!),
    );
    if (picked == null) return;
    setState(() {
      final t = ClockTime(picked.hour, picked.minute);
      isStart ? row.start = t : row.end = t;
    });
  }

  void _addRow() {
    final used = _rows!.map((r) => r.weekday).toSet();
    final day = List.generate(7, (i) => i + 1).firstWhere((d) => !used.contains(d), orElse: () => 1);
    setState(() => _rows!.add(_Row(day, ClockTime(9, 0), ClockTime(17, 0))));
  }

  @override
  Widget build(BuildContext context) {
    final rows = _rows;
    return Scaffold(
      appBar: AppBar(title: Text(widget.title)),
      body: rows == null
          ? const Center(child: CircularProgressIndicator())
          : ListView(
              padding: const EdgeInsets.all(16),
              children: [
                if (widget.hint != null) Padding(padding: const EdgeInsets.only(bottom: 12), child: Text(widget.hint!)),
                if (_error != null) ErrorBanner(_error!),
                if (rows.isEmpty)
                  const Padding(padding: EdgeInsets.all(8), child: Text('Kayıt yok (tüm günler kapalı).')),
                for (final row in rows)
                  Card(
                    child: Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
                      child: Row(
                        children: [
                          DropdownButton<int>(
                            value: row.weekday,
                            items: [
                              for (var d = 1; d <= 7; d++)
                                DropdownMenuItem(value: d, child: Text(ApiDate.weekdayName(d))),
                            ],
                            onChanged: (d) => setState(() => row.weekday = d!),
                          ),
                          const Spacer(),
                          TextButton(onPressed: () => _pickTime(row, true), child: Text('${row.start}')),
                          const Text('–'),
                          TextButton(onPressed: () => _pickTime(row, false), child: Text('${row.end}')),
                          IconButton(
                            tooltip: 'Sil',
                            icon: const Icon(Icons.delete_outline),
                            onPressed: () => setState(() => rows.remove(row)),
                          ),
                        ],
                      ),
                    ),
                  ),
                const SizedBox(height: 8),
                Row(
                  children: [
                    OutlinedButton.icon(
                      onPressed: _addRow,
                      icon: const Icon(Icons.add),
                      label: const Text('Satır ekle'),
                    ),
                    const Spacer(),
                    FilledButton(
                      onPressed: _saving ? null : _save,
                      child: _saving
                          ? const SizedBox(width: 18, height: 18, child: CircularProgressIndicator(strokeWidth: 2))
                          : const Text('Kaydet'),
                    ),
                  ],
                ),
              ],
            ),
    );
  }
}
