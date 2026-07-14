import '../logging/app_logger.dart';

/// Mock Sentry service para crash reporting
/// Em produção, seria integrado com Sentry.io
class SentryService {
  static final SentryService _instance = SentryService._internal();

  factory SentryService() {
    return _instance;
  }

  SentryService._internal();

  final AppLogger _logger = AppLogger();
  bool _initialized = false;
  String? _dsn;
  String? _environment;
  Map<String, dynamic>? _tags;
  Map<String, dynamic>? _userContext;

  /// Inicializa Sentry (mock ou real)
  Future<void> init({
    required String dsn,
    String environment = 'production',
  }) async {
    _dsn = dsn;
    _environment = environment;
    _initialized = true;

    _logger.info(
      'SentryService',
      'Initialized for $environment environment',
    );
  }

  /// Configura tags para agrupar erros
  void setTags(Map<String, dynamic> tags) {
    _tags = tags;
    _logger.debug('SentryService', 'Tags configured: ${tags.keys.join(", ")}');
  }

  /// Define contexto de usuário
  void setUserContext({
    required String id,
    String? email,
    String? username,
  }) {
    _userContext = {
      'id': id,
      if (email != null) 'email': email,
      if (username != null) 'username': username,
    };
    _logger.debug('SentryService', 'User context set for $username ($id)');
  }

  /// Captura exceção
  Future<void> captureException(
    Object error, [
    StackTrace? stackTrace,
    String? breadcrumb,
  ]) async {
    if (!_initialized) {
      _logger.warning(
        'SentryService',
        'captureException called before init()',
      );
      return;
    }

    _logger.error(
      'SentryService',
      'Exception captured${breadcrumb != null ? ': $breadcrumb' : ''}',
      error,
      stackTrace,
    );

    // Mock: Em produção, seria:
    // await Sentry.captureException(error, stackTrace: stackTrace);
  }

  /// Captura mensagem
  Future<void> captureMessage(
    String message, {
    String level = 'info',
  }) async {
    if (!_initialized) return;

    _logger.info('SentryService', '[${level.toUpperCase()}] $message');

    // Mock: Em produção, seria:
    // await Sentry.captureMessage(message, level: _getSentryLevel(level));
  }

  /// Adiciona breadcrumb (trilha de eventos)
  void addBreadcrumb({
    required String message,
    String category = 'default',
    String level = 'info',
    Map<String, dynamic>? data,
  }) {
    _logger.debug(
      'SentryService',
      '[$category] $message${data != null ? ' - $data' : ''}',
    );

    // Mock: Em produção, seria:
    // Sentry.addBreadcrumb(SentryBreadcrumb(
    //   message: message,
    //   category: category,
    //   level: _getSentryLevel(level),
    //   data: data,
    // ));
  }

  /// Captura navegação
  void captureNavigation(String screenName) {
    addBreadcrumb(
      message: 'Navigated to $screenName',
      category: 'navigation',
    );
  }

  /// Captura ação de usuário
  void captureUserAction(String action, {Map<String, dynamic>? data}) {
    addBreadcrumb(
      message: action,
      category: 'user-action',
      data: data,
    );
  }

  /// Captura request HTTP
  void captureHttpRequest(
    String method,
    String url, {
    int? statusCode,
    int? duration,
  }) {
    addBreadcrumb(
      message: '$method $url',
      category: 'http',
      level: statusCode != null && statusCode >= 500 ? 'error' : 'info',
      data: {
        if (statusCode != null) 'status_code': statusCode,
        if (duration != null) 'duration_ms': duration,
      },
    );
  }

  /// Retorna status de inicialização
  bool get isInitialized => _initialized;

  /// Retorna DSN (para testes)
  String? get dsn => _dsn;

  /// Retorna ambiente
  String? get environment => _environment;

  /// Retorna tags (para testes)
  Map<String, dynamic>? get tags => _tags;

  /// Retorna contexto de usuário (para testes)
  Map<String, dynamic>? get userContext => _userContext;
}
