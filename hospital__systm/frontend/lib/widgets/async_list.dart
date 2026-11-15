import 'package:flutter/material.dart';

import 'common.dart';

/// Bir listeyi yükleyen, hata ve boş durumlarını gösteren, yenilenebilen ortak sayfa iskeleti.
class AsyncListView<T> extends StatefulWidget {
  const AsyncListView({
    super.key,
    required this.load,
    required this.itemBuilder,
    this.emptyText = 'Kayıt bulunamadı.',
    this.header,
  });

  final Future<List<T>> Function() load;
  final Widget Function(BuildContext context, T item, VoidCallback reload) itemBuilder;
  final String emptyText;

  /// Listenin üstünde gösterilen alan (filtre, ekleme butonu vb.).
  final Widget? header;

  @override
  State<AsyncListView<T>> createState() => AsyncListViewState<T>();
}

class AsyncListViewState<T> extends State<AsyncListView<T>> {
  late Future<List<T>> _future;

  @override
  void initState() {
    super.initState();
    _future = widget.load();
  }

  /// Listeyi yeniden yükler.
  void reload() {
    // setState içindeki kapanış Future döndürmemeli; atama ayrı bir blokta yapılır.
    setState(() {
      _future = widget.load();
    });
  }

  // Not: üst widget yeniden çizildiğinde (her seferinde yeni bir load kapanışı gelir) liste yeniden
  // yüklenmez. Filtre değişince yeniden yükleme için AsyncListView'a filtreye bağlı bir key verilir.

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        ?widget.header,
        Expanded(
          child: FutureBuilder<List<T>>(
            future: _future,
            builder: (context, snapshot) {
              if (snapshot.connectionState != ConnectionState.done) {
                return const Center(child: CircularProgressIndicator());
              }
              if (snapshot.hasError) {
                return Center(
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Padding(padding: const EdgeInsets.all(16), child: ErrorBanner(errorText(snapshot.error!))),
                      OutlinedButton(onPressed: reload, child: const Text('Tekrar dene')),
                    ],
                  ),
                );
              }
              final items = snapshot.data!;
              if (items.isEmpty) return Center(child: Text(widget.emptyText));
              return RefreshIndicator(
                onRefresh: () async => reload(),
                child: ListView.builder(
                  padding: const EdgeInsets.all(12),
                  itemCount: items.length,
                  itemBuilder: (context, i) => widget.itemBuilder(context, items[i], reload),
                ),
              );
            },
          ),
        ),
      ],
    );
  }
}

/// İşlem öncesi onay penceresi. Onaylanırsa true döner.
Future<bool> confirmAction(
  BuildContext context, {
  required String title,
  required String message,
  String confirmLabel = 'Evet',
}) async {
  final result = await showDialog<bool>(
    context: context,
    builder: (context) => AlertDialog(
      title: Text(title),
      content: Text(message),
      actions: [
        TextButton(onPressed: () => Navigator.of(context).pop(false), child: const Text('Vazgeç')),
        FilledButton(onPressed: () => Navigator.of(context).pop(true), child: Text(confirmLabel)),
      ],
    ),
  );
  return result ?? false;
}

/// Kısa bilgi mesajı gösterir.
void showMessage(BuildContext context, String message) {
  ScaffoldMessenger.of(context)
    ..hideCurrentSnackBar()
    ..showSnackBar(SnackBar(content: Text(message)));
}

/// Durum etiketi.
class StatusChip extends StatelessWidget {
  const StatusChip({super.key, required this.label, required this.color});

  final String label;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      decoration: BoxDecoration(color: color.withValues(alpha: 0.15), borderRadius: BorderRadius.circular(12)),
      child: Text(
        label,
        style: TextStyle(color: color, fontWeight: FontWeight.w600, fontSize: 12),
      ),
    );
  }
}
