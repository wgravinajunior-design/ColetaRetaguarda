import 'package:flutter/material.dart';
import '../notifications/local_notification_service.dart';

/// Widget para exibir notificações em tempo real
class NotificationToast extends StatefulWidget {
  final Widget child;

  const NotificationToast({
    required this.child,
    super.key,
  });

  @override
  State<NotificationToast> createState() => _NotificationToastState();
}

class _NotificationToastState extends State<NotificationToast> {
  final LocalNotificationService _notificationService = LocalNotificationService();
  final List<LocalNotification> _visibleNotifications = [];

  @override
  void initState() {
    super.initState();
    _notificationService.setOnNotification(_handleNotification);
  }

  void _handleNotification(LocalNotification notification) {
    setState(() {
      _visibleNotifications.add(notification);
    });

    Future.delayed(const Duration(seconds: 4), () {
      if (mounted) {
        setState(() {
          _visibleNotifications.remove(notification);
        });
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    return Directionality(
      textDirection: TextDirection.ltr,
      child: Stack(
        children: [
          widget.child,
          Positioned(
            bottom: 16,
            right: 16,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.end,
              children: _visibleNotifications.map((notification) {
                return Padding(
                  padding: const EdgeInsets.only(top: 8.0),
                  child: _NotificationCard(notification: notification),
                );
              }).toList(),
            ),
          ),
        ],
      ),
    );
  }
}

class _NotificationCard extends StatelessWidget {
  final LocalNotification notification;

  const _NotificationCard({
    required this.notification,
  });

  Color _getBackgroundColor(NotificationType type) {
    switch (type) {
      case NotificationType.info:
        return Colors.blue;
      case NotificationType.success:
        return Colors.green;
      case NotificationType.warning:
        return Colors.orange;
      case NotificationType.error:
        return Colors.red;
    }
  }

  IconData _getIcon(NotificationType type) {
    switch (type) {
      case NotificationType.info:
        return Icons.info;
      case NotificationType.success:
        return Icons.check_circle;
      case NotificationType.warning:
        return Icons.warning;
      case NotificationType.error:
        return Icons.error;
    }
  }

  @override
  Widget build(BuildContext context) {
    final backgroundColor = _getBackgroundColor(notification.type);
    final icon = _getIcon(notification.type);

    return Material(
      borderRadius: BorderRadius.circular(8),
      color: backgroundColor,
      child: Padding(
        padding: const EdgeInsets.all(12.0),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, color: Colors.white, size: 20),
            const SizedBox(width: 12),
            Flexible(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    notification.title,
                    style: const TextStyle(
                      color: Colors.white,
                      fontWeight: FontWeight.bold,
                      fontSize: 14,
                    ),
                  ),
                  if (notification.message.isNotEmpty)
                    Padding(
                      padding: const EdgeInsets.only(top: 4.0),
                      child: Text(
                        notification.message,
                        style: const TextStyle(
                          color: Colors.white70,
                          fontSize: 12,
                        ),
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}
