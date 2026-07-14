import 'package:flutter/foundation.dart';
import '../logging/app_logger.dart';

/// Rota deep link
class DeepLink {
  final String path;
  final Map<String, String> queryParams;
  final Map<String, dynamic> args;
  final DateTime createdAt;

  DeepLink({
    required this.path,
    this.queryParams = const {},
    this.args = const {},
    DateTime? createdAt,
  }) : createdAt = createdAt ?? DateTime.now();

  /// Cria DeepLink a partir de URI
  factory DeepLink.fromUri(Uri uri) {
    return DeepLink(
      path: uri.path,
      queryParams: uri.queryParameters,
    );
  }

  /// Retorna se o deep link é válido
  bool get isValid => path.isNotEmpty && path.startsWith('/');

  /// Extrai o ID da rota (ex: /produtores/123 -> 123)
  String? getIdFromPath() {
    final parts = path.split('/');
    if (parts.length > 2) {
      return parts.last;
    }
    return null;
  }

  @override
  String toString() => 'DeepLink(path: $path, params: $queryParams)';
}

/// Mapeamento de deep links para rotas
typedef DeepLinkHandler = Future<bool> Function(DeepLink link);

/// Serviço para gerenciar deep linking
class DeepLinkService extends ChangeNotifier {
  static final DeepLinkService _instance = DeepLinkService._internal();

  factory DeepLinkService() => _instance;

  DeepLinkService._internal();

  final AppLogger _logger = AppLogger();
  final Map<String, DeepLinkHandler> _handlers = {};
  final List<DeepLink> _deepLinkHistory = [];
  DeepLink? _currentDeepLink;

  DeepLink? get currentDeepLink => _currentDeepLink;
  List<DeepLink> get history => List.unmodifiable(_deepLinkHistory);

  /// Registra um handler para uma rota
  void registerHandler(String pattern, DeepLinkHandler handler) {
    _handlers[pattern] = handler;
    _logger.debug('DeepLinkService', 'Handler registered: $pattern');
  }

  /// Registra múltiplos handlers
  void registerHandlers(Map<String, DeepLinkHandler> handlers) {
    _handlers.addAll(handlers);
    _logger.info('DeepLinkService', 'Registered ${handlers.length} handlers');
  }

  /// Processa um deep link
  Future<bool> handle(DeepLink link) async {
    if (!link.isValid) {
      _logger.warning('DeepLinkService', 'Invalid deep link: ${link.path}');
      return false;
    }

    _currentDeepLink = link;
    _deepLinkHistory.add(link);

    try {
      // Tenta encontrar handler exato
      if (_handlers.containsKey(link.path)) {
        final result = await _handlers[link.path]!(link);
        _logger.info('DeepLinkService', 'Handled: ${link.path}');
        notifyListeners();
        return result;
      }

      // Tenta encontrar handler por padrão
      for (final pattern in _handlers.keys) {
        if (_matchesPattern(link.path, pattern)) {
          final result = await _handlers[pattern]!(link);
          _logger.info('DeepLinkService', 'Handled by pattern $pattern: ${link.path}');
          notifyListeners();
          return result;
        }
      }

      _logger.warning('DeepLinkService', 'No handler found for: ${link.path}');
      return false;
    } catch (e) {
      _logger.error('DeepLinkService', 'Error handling deep link: $e');
      return false;
    }
  }

  /// Processa uma URI
  Future<bool> handleUri(Uri uri) async {
    return handle(DeepLink.fromUri(uri));
  }

  /// Processa uma string de URI
  Future<bool> handleUriString(String uriString) async {
    try {
      final uri = Uri.parse(uriString);
      return handleUri(uri);
    } catch (e) {
      _logger.error('DeepLinkService', 'Invalid URI string: $uriString');
      return false;
    }
  }

  /// Verifica se um path corresponde a um padrão
  bool _matchesPattern(String path, String pattern) {
    // Suporta wildcards simples: /produtores/* para /produtores/123
    if (pattern.endsWith('/*')) {
      final prefix = pattern.substring(0, pattern.length - 2);
      return path.startsWith(prefix);
    }
    return path == pattern;
  }

  /// Cria uma URI para navegar
  Uri createUri(String path, {Map<String, String>? queryParams}) {
    final query = queryParams?.isNotEmpty ?? false ? queryParams : null;
    return Uri(path: path, queryParameters: query);
  }

  /// Retorna histórico de deep links
  List<DeepLink> getHistoryByPath(String path) {
    return _deepLinkHistory.where((link) => link.path == path).toList();
  }

  /// Limpa histórico
  void clearHistory() {
    _deepLinkHistory.clear();
    _logger.debug('DeepLinkService', 'Deep link history cleared');
  }

  /// Reseta o serviço completamente (para testes)
  void reset() {
    _handlers.clear();
    _deepLinkHistory.clear();
    _currentDeepLink = null;
    _logger.debug('DeepLinkService', 'Service reset');
  }

  /// Retorna lista de padrões registrados
  List<String> getRegisteredPatterns() {
    return List.unmodifiable(_handlers.keys);
  }

  /// Retorna informações de debug
  Map<String, dynamic> getDebugInfo() {
    return {
      'currentDeepLink': _currentDeepLink?.toString() ?? 'none',
      'historyCount': _deepLinkHistory.length,
      'registeredPatterns': _handlers.keys.toList(),
      'recentDeepLinks': _deepLinkHistory.take(5).map((d) => d.path).toList(),
    };
  }
}
