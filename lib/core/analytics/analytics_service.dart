import '../logging/app_logger.dart';

/// Evento de analytics
class AnalyticsEvent {
  final String name;
  final Map<String, dynamic>? parameters;
  final DateTime timestamp;

  AnalyticsEvent({
    required this.name,
    this.parameters,
    DateTime? timestamp,
  }) : timestamp = timestamp ?? DateTime.now();

  @override
  String toString() => 'AnalyticsEvent($name, params: $parameters)';
}

/// Rastreamento de eventos de usuário
class AnalyticsService {
  static final AnalyticsService _instance = AnalyticsService._internal();

  factory AnalyticsService() {
    return _instance;
  }

  AnalyticsService._internal();

  final AppLogger _logger = AppLogger();
  final List<AnalyticsEvent> _history = [];
  bool _enabled = true;
  Function(AnalyticsEvent)? _onEvent;

  /// Registra callback para novos eventos
  void setOnEvent(Function(AnalyticsEvent) callback) {
    _onEvent = callback;
  }

  /// Habilita/desabilita analytics
  void setEnabled(bool enabled) {
    _enabled = enabled;
    _logger.info(
      'AnalyticsService',
      'Analytics ${enabled ? 'enabled' : 'disabled'}',
    );
  }

  /// Rastreia evento
  void trackEvent(
    String eventName, {
    Map<String, dynamic>? parameters,
  }) {
    if (!_enabled) return;

    final event = AnalyticsEvent(
      name: eventName,
      parameters: parameters,
    );

    _history.add(event);
    _onEvent?.call(event);

    _logger.debug(
      'AnalyticsService',
      'Event tracked: $eventName${parameters != null ? ' - $parameters' : ''}',
    );
  }

  /// Rastreia navegação
  void trackScreenView(String screenName) {
    trackEvent(
      'screen_view',
      parameters: {'screen_name': screenName},
    );
  }

  /// Rastreia clique de botão
  void trackButtonClick(String buttonName, {String? screenName}) {
    trackEvent(
      'button_click',
      parameters: {
        'button_name': buttonName,
        if (screenName != null) 'screen_name': screenName,
      },
    );
  }

  /// Rastreia submissão de formulário
  void trackFormSubmit(String formName, {Map<String, dynamic>? fields}) {
    trackEvent(
      'form_submit',
      parameters: {
        'form_name': formName,
        if (fields != null) 'field_count': fields.length,
      },
    );
  }

  /// Rastreia erro
  void trackError(
    String errorCode, {
    String? errorMessage,
    String? screenName,
  }) {
    trackEvent(
      'error',
      parameters: {
        'error_code': errorCode,
        if (errorMessage != null) 'error_message': errorMessage,
        if (screenName != null) 'screen_name': screenName,
      },
    );
  }

  /// Rastreia busca
  void trackSearch(
    String query, {
    int? resultCount,
    int? duration,
  }) {
    trackEvent(
      'search',
      parameters: {
        'search_query': query,
        if (resultCount != null) 'result_count': resultCount,
        if (duration != null) 'duration_ms': duration,
      },
    );
  }

  /// Rastreia compra/transação
  void trackTransaction(
    String transactionId, {
    required double amount,
    required String currency,
    Map<String, dynamic>? items,
  }) {
    trackEvent(
      'transaction',
      parameters: {
        'transaction_id': transactionId,
        'amount': amount,
        'currency': currency,
        if (items != null) 'item_count': items.length,
      },
    );
  }

  /// Retorna histórico de eventos
  List<AnalyticsEvent> getHistory() => List.from(_history);

  /// Limpa histórico
  void clearHistory() {
    _history.clear();
  }

  /// Retorna resumo de eventos
  String generateSummary() {
    if (_history.isEmpty) return 'No events tracked';

    final eventCounts = <String, int>{};
    for (final event in _history) {
      eventCounts[event.name] = (eventCounts[event.name] ?? 0) + 1;
    }

    final buffer = StringBuffer();
    buffer.writeln('=== Analytics Summary ===\n');
    buffer.writeln('Total events: ${_history.length}');
    buffer.writeln('\nEvent breakdown:');

    eventCounts.entries.toList()
      ..sort((a, b) => b.value.compareTo(a.value))
      ..forEach((e) {
        buffer.writeln('  ${e.key}: ${e.value}');
      });

    return buffer.toString();
  }
}
