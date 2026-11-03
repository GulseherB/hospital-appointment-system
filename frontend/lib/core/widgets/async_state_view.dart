import 'package:flutter/material.dart';

class AsyncStateView<T> extends StatelessWidget {
  const AsyncStateView({
    required this.future,
    required this.builder,
    this.emptyMessage,
    super.key,
  });

  final Future<T> future;
  final Widget Function(BuildContext context, T value) builder;
  final String? emptyMessage;

  @override
  Widget build(BuildContext context) {
    return FutureBuilder<T>(
      future: future,
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Center(child: CircularProgressIndicator());
        }
        if (snapshot.hasError) {
          return _MessageCard(
            icon: Icons.error_outline,
            message: 'Veri yüklenemedi. Lütfen tekrar deneyin.',
          );
        }
        final value = snapshot.data;
        if (value is Iterable && value.isEmpty) {
          return _MessageCard(
            icon: Icons.inbox_outlined,
            message: emptyMessage ?? 'Henüz kayıt bulunmuyor.',
          );
        }
        return builder(context, value as T);
      },
    );
  }
}

class _MessageCard extends StatelessWidget {
  const _MessageCard({required this.icon, required this.message});

  final IconData icon;
  final String message;

  @override
  Widget build(BuildContext context) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, size: 40),
            const SizedBox(height: 12),
            Text(message, textAlign: TextAlign.center),
          ],
        ),
      ),
    );
  }
}
