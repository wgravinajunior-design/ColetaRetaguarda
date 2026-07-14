import 'dart:async';
import '../logging/app_logger.dart';

/// Modelo de item em cache
class CacheItem<T> {
  final T data;
  final DateTime timestamp;
  final Duration ttl;

  CacheItem({
    required this.data,
    required this.ttl,
    DateTime? timestamp,
  }) : timestamp = timestamp ?? DateTime.now();

  /// Verifica se o cache expirou
  bool get isExpired {
    final age = DateTime.now().difference(timestamp);
    return age > ttl;
  }

  /// Retorna tempo restante até expiração
  Duration get timeUntilExpiry {
    final age = DateTime.now().difference(timestamp);
    final remaining = ttl - age;
    return remaining.isNegative ? Duration.zero : remaining;
  }

  @override
  String toString() => 'CacheItem(age: ${DateTime.now().difference(timestamp).inSeconds}s, ttl: ${ttl.inSeconds}s, expired: $isExpired)';
}

/// Gerenciador centralizado de cache
class CacheManager {
  static final CacheManager _instance = CacheManager._internal();

  factory CacheManager() {
    return _instance;
  }

  CacheManager._internal();

  final AppLogger _logger = AppLogger();
  final Map<String, CacheItem> _cache = {};
  Timer? _cleanupTimer;
  bool _enabled = true;

  /// Inicia o gerenciador de cache
  void init() {
    _startCleanupTimer();
    _logger.info('CacheManager', 'Initialized');
  }

  /// Define se cache está habilitado
  void setEnabled(bool enabled) {
    _enabled = enabled;
    if (!enabled) {
      _cache.clear();
      _logger.info('CacheManager', 'Cache disabled and cleared');
    }
  }

  /// Salva um item em cache
  void put<T>(String key, T data, {Duration? ttl}) {
    if (!_enabled) return;

    final cacheTtl = ttl ?? const Duration(minutes: 5);
    _cache[key] = CacheItem(data: data, ttl: cacheTtl);

    _logger.debug(
      'CacheManager',
      'Cache PUT: $key (ttl: ${cacheTtl.inSeconds}s)',
    );
  }

  /// Obtém um item do cache
  T? get<T>(String key) {
    if (!_enabled) return null;

    final item = _cache[key];
    if (item == null) {
      _logger.debug('CacheManager', 'Cache MISS: $key');
      return null;
    }

    if (item.isExpired) {
      _cache.remove(key);
      _logger.debug('CacheManager', 'Cache EXPIRED: $key');
      return null;
    }

    _logger.debug('CacheManager', 'Cache HIT: $key');
    return item.data as T;
  }

  /// Remove um item do cache
  void remove(String key) {
    _cache.remove(key);
    _logger.debug('CacheManager', 'Cache REMOVED: $key');
  }

  /// Remove itens do cache por padrão
  void removePattern(String pattern) {
    final keysToRemove = _cache.keys
        .where((key) => key.contains(pattern))
        .toList();

    for (final key in keysToRemove) {
      _cache.remove(key);
    }

    _logger.debug('CacheManager', 'Removed ${keysToRemove.length} items matching: $pattern');
  }

  /// Limpa todo o cache
  void clear() {
    _cache.clear();
    _logger.info('CacheManager', 'Cache cleared');
  }

  /// Retorna estatísticas do cache
  String getStats() {
    final validItems = _cache.entries
        .where((e) => !e.value.isExpired)
        .length;
    final totalSize = _cache.length;

    return '''
=== Cache Statistics ===
Total items: $totalSize
Valid items: $validItems
Expired items: ${totalSize - validItems}
Enabled: $_enabled
    ''';
  }

  /// Inicia timer de limpeza de itens expirados
  void _startCleanupTimer() {
    _cleanupTimer?.cancel();
    _cleanupTimer = Timer.periodic(
      const Duration(minutes: 1),
      (_) => _cleanupExpired(),
    );
  }

  /// Remove itens expirados
  void _cleanupExpired() {
    int removedCount = 0;
    final expiredKeys = <String>[];

    for (final entry in _cache.entries) {
      if (entry.value.isExpired) {
        expiredKeys.add(entry.key);
        removedCount++;
      }
    }

    for (final key in expiredKeys) {
      _cache.remove(key);
    }

    if (removedCount > 0) {
      _logger.debug('CacheManager', 'Cleanup: removed $removedCount expired items');
    }
  }

  /// Desabilita o gerenciador
  void dispose() {
    _cleanupTimer?.cancel();
    _cache.clear();
    _logger.info('CacheManager', 'Disposed');
  }
}

/// Extension para facilitar cache em strings
extension CacheKeyExtension on String {
  /// Gera chave de cache com prefixo
  String cacheKey(String prefix) => '$prefix:$this';

  /// Chave para cache de GET /endpoint
  String apiGetCacheKey() => 'api:get:$this';

  /// Chave para cache de lista
  String listCacheKey() => 'list:$this';

  /// Chave para cache de detalhe
  String detailsCacheKey() => 'detail:$this';
}
