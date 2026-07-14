import '../logging/app_logger.dart';
import '../analytics/analytics_service.dart';

/// Tipos de notificações
enum NotificationType {
  info,
  success,
  warning,
  error,
}

/// Modelo de notificação local
class LocalNotification {
  final String id;
  final String title;
  final String message;
  final NotificationType type;
  final DateTime timestamp;
  final Map<String, dynamic>? data;

  LocalNotification({
    required this.id,
    required this.title,
    required this.message,
    required this.type,
    this.data,
    DateTime? timestamp,
  }) : timestamp = timestamp ?? DateTime.now();

  @override
  String toString() => 'LocalNotification($id, $title)';
}

/// Gerencia notificações locais da aplicação
class LocalNotificationService {
  static final LocalNotificationService _instance = LocalNotificationService._internal();

  factory LocalNotificationService() {
    return _instance;
  }

  LocalNotificationService._internal();

  final AppLogger _logger = AppLogger();
  final AnalyticsService _analytics = AnalyticsService();
  final List<LocalNotification> _notifications = [];
  Function(LocalNotification)? _onNotification;

  static int _idCounter = 0;

  /// Registra callback para novas notificações
  void setOnNotification(Function(LocalNotification) callback) {
    _onNotification = callback;
  }

  /// Exibe notificação de informação
  void showInfo(String title, String message, {Map<String, dynamic>? data}) {
    _addNotification(
      title: title,
      message: message,
      type: NotificationType.info,
      data: data,
    );
  }

  /// Exibe notificação de sucesso
  void showSuccess(String title, String message, {Map<String, dynamic>? data}) {
    _addNotification(
      title: title,
      message: message,
      type: NotificationType.success,
      data: data,
    );
    _analytics.trackEvent('notification_success', parameters: {'title': title});
  }

  /// Exibe notificação de aviso
  void showWarning(String title, String message, {Map<String, dynamic>? data}) {
    _addNotification(
      title: title,
      message: message,
      type: NotificationType.warning,
      data: data,
    );
    _analytics.trackEvent('notification_warning', parameters: {'title': title});
  }

  /// Exibe notificação de erro
  void showError(String title, String message, {Map<String, dynamic>? data}) {
    _addNotification(
      title: title,
      message: message,
      type: NotificationType.error,
      data: data,
    );
    _analytics.trackEvent('notification_error', parameters: {'title': title});
  }

  void _addNotification({
    required String title,
    required String message,
    required NotificationType type,
    Map<String, dynamic>? data,
  }) {
    final notification = LocalNotification(
      id: 'notif_${_idCounter++}',
      title: title,
      message: message,
      type: type,
      data: data,
    );

    _notifications.add(notification);
    _onNotification?.call(notification);

    _logger.info(
      'LocalNotificationService',
      'Notification: ${type.name} - $title: $message',
    );
  }

  /// Retorna histórico de notificações
  List<LocalNotification> getHistory() => List.from(_notifications);

  /// Retorna notificações de um tipo específico
  List<LocalNotification> getByType(NotificationType type) {
    return _notifications.where((n) => n.type == type).toList();
  }

  /// Limpa histórico de notificações
  void clearHistory() {
    _notifications.clear();
    _logger.debug('LocalNotificationService', 'Notification history cleared');
  }

  /// Remove notificação específica
  void removeNotification(String notificationId) {
    _notifications.removeWhere((n) => n.id == notificationId);
  }

  /// Retorna resumo de notificações
  String generateSummary() {
    if (_notifications.isEmpty) return 'No notifications';

    final counts = <NotificationType, int>{};
    for (final notif in _notifications) {
      counts[notif.type] = (counts[notif.type] ?? 0) + 1;
    }

    final buffer = StringBuffer();
    buffer.writeln('=== Notification Summary ===\n');
    buffer.writeln('Total notifications: ${_notifications.length}');
    buffer.writeln('\nBreakdown:');

    for (final type in NotificationType.values) {
      if (counts[type] != null) {
        buffer.writeln('  ${type.name}: ${counts[type]}');
      }
    }

    return buffer.toString();
  }
}
