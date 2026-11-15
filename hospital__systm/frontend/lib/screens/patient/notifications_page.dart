import 'package:flutter/material.dart';

import '../../app_scope.dart';
import '../../core/date_utils.dart';
import '../../models/app_notification.dart';
import '../../services/appointment_service.dart';
import '../../widgets/async_list.dart';
import '../../widgets/common.dart';

/// Hastanın bildirim paneli: randevu onayı, reddi ve iptalleri. Okunmamışlar vurgulanır.
class NotificationsPage extends StatefulWidget {
  const NotificationsPage({super.key, this.onUnreadChanged});

  /// Okunmamış sayısı değiştiğinde (rozet için) çağrılır.
  final ValueChanged<int>? onUnreadChanged;

  @override
  State<NotificationsPage> createState() => _NotificationsPageState();
}

class _NotificationsPageState extends State<NotificationsPage> {
  final _listKey = GlobalKey<AsyncListViewState<AppNotification>>();
  int _unread = 0;

  void _setUnread(int value) {
    if (value == _unread) return;
    // Liste yüklenirken (çizim sırasında) çağrılabilir; durum güncellemesi çizimden sonra yapılır.
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      setState(() => _unread = value);
      widget.onUnreadChanged?.call(value);
    });
  }

  @override
  Widget build(BuildContext context) {
    final service = NotificationService(AppScope.of(context).api);
    return AsyncListView<AppNotification>(
      key: _listKey,
      load: () async {
        final page = await service.list();
        _setUnread(page.unreadCount);
        return page.items;
      },
      emptyText: 'Bildiriminiz yok.',
      header: Padding(
        padding: const EdgeInsets.fromLTRB(16, 12, 16, 0),
        child: Row(
          children: [
            Expanded(child: Text(_unread == 0 ? 'Tüm bildirimler okundu.' : '$_unread okunmamış bildirim')),
            TextButton.icon(
              onPressed: _unread == 0
                  ? null
                  : () async {
                      try {
                        await service.markAllRead();
                      } catch (e) {
                        if (context.mounted) showMessage(context, errorText(e));
                      }
                      _listKey.currentState?.reload();
                    },
              icon: const Icon(Icons.done_all),
              label: const Text('Tümünü okundu işaretle'),
            ),
          ],
        ),
      ),
      itemBuilder: (context, n, reload) => _NotificationTile(
        notification: n,
        onTap: n.isRead
            ? null
            : () async {
                try {
                  await service.markRead(n.id);
                } catch (e) {
                  if (context.mounted) showMessage(context, errorText(e));
                }
                reload();
              },
      ),
    );
  }
}

class _NotificationTile extends StatelessWidget {
  const _NotificationTile({required this.notification, this.onTap});

  final AppNotification notification;
  final VoidCallback? onTap;

  IconData _icon() => switch (notification.type) {
    NotificationType.approved => Icons.check_circle,
    NotificationType.rejected => Icons.cancel,
    NotificationType.cancelledByDoctor || NotificationType.cancelledByAdmin => Icons.event_busy,
    NotificationType.cancelledAuto => Icons.timer_off,
  };

  @override
  Widget build(BuildContext context) {
    final n = notification;
    final color = n.type.isPositive ? Colors.green : Colors.red;
    return Card(
      color: n.isRead ? null : Theme.of(context).colorScheme.primaryContainer.withValues(alpha: 0.35),
      child: ListTile(
        leading: Icon(_icon(), color: color),
        title: Text(n.message, style: TextStyle(fontWeight: n.isRead ? FontWeight.normal : FontWeight.w600)),
        subtitle: Text('${ApiDate.display(n.createdAt)}${n.isRead ? '' : ' · Okundu işaretlemek için dokunun'}'),
        trailing: n.isRead ? null : const Icon(Icons.circle, size: 10, color: Colors.blue),
        onTap: onTap,
      ),
    );
  }
}
