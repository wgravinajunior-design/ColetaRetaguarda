import 'dart:async';
import 'dart:convert';
import 'package:flutter/foundation.dart';
import '../logging/app_logger.dart';
import '../database/migration.dart';

/// Tipos de requisição para fila offline
enum OfflineRequestMethod { post, put, delete }

/// Modelo de requisição offline
class OfflineRequest {
  final String id;
  final OfflineRequestMethod method;
  final String endpoint;
  final Map<String, dynamic>? body;
  final int priority; // 1 = highest, 10 = lowest
  final DateTime createdAt;
  final int retryCount;
  final DateTime? lastRetryAt;
  final bool isProcessing;

  OfflineRequest({
    required this.id,
    required this.method,
    required this.endpoint,
    this.body,
    this.priority = 5,
    DateTime? createdAt,
    this.retryCount = 0,
    this.lastRetryAt,
    this.isProcessing = false,
  }) : createdAt = createdAt ?? DateTime.now();

  Map<String, dynamic> toJson() => {
    'id': id,
    'method': method.toString().split('.').last,
    'endpoint': endpoint,
    'body': body != null ? jsonEncode(body) : null,
    'priority': priority,
    'createdAt': createdAt.toIso8601String(),
    'retryCount': retryCount,
    'lastRetryAt': lastRetryAt?.toIso8601String(),
    'isProcessing': isProcessing ? 1 : 0,
  };

  factory OfflineRequest.fromJson(Map<String, dynamic> json) => OfflineRequest(
    id: json['id'] as String,
    method: OfflineRequestMethod.values.firstWhere(
      (m) => m.toString().split('.').last == json['method'],
    ),
    endpoint: json['endpoint'] as String,
    body: json['body'] != null ? jsonDecode(json['body']) : null,
    priority: json['priority'] as int? ?? 5,
    createdAt: DateTime.parse(json['createdAt'] as String),
    retryCount: json['retryCount'] as int? ?? 0,
    lastRetryAt: json['lastRetryAt'] != null
        ? DateTime.parse(json['lastRetryAt'] as String)
        : null,
    isProcessing: (json['isProcessing'] as int? ?? 0) == 1,
  );

  OfflineRequest copyWith({
    String? id,
    OfflineRequestMethod? method,
    String? endpoint,
    Map<String, dynamic>? body,
    int? priority,
    DateTime? createdAt,
    int? retryCount,
    DateTime? lastRetryAt,
    bool? isProcessing,
  }) =>
      OfflineRequest(
        id: id ?? this.id,
        method: method ?? this.method,
        endpoint: endpoint ?? this.endpoint,
        body: body ?? this.body,
        priority: priority ?? this.priority,
        createdAt: createdAt ?? this.createdAt,
        retryCount: retryCount ?? this.retryCount,
        lastRetryAt: lastRetryAt ?? this.lastRetryAt,
        isProcessing: isProcessing ?? this.isProcessing,
      );
}

/// Callback para processar requisição offline
typedef ProcessOfflineRequest = Future<bool> Function(OfflineRequest request);

/// Gerenciador de fila de requisições offline
class OfflineRequestQueue extends ChangeNotifier {
  static final OfflineRequestQueue _instance =
      OfflineRequestQueue._internal();

  factory OfflineRequestQueue() => _instance;

  OfflineRequestQueue._internal();

  final AppLogger _logger = AppLogger();
  final List<OfflineRequest> _queue = [];
  ProcessOfflineRequest? _processCallback;
  Timer? _syncTimer;
  bool _syncing = false;
  int _maxRetries = 3;
  final Duration _retryDelay = const Duration(seconds: 30);

  List<OfflineRequest> get queue => List.unmodifiable(_queue);
  bool get syncing => _syncing;
  int get pendingCount => _queue.length;

  /// Inicializa gerenciador com callback
  void init({
    required ProcessOfflineRequest processCallback,
    int maxRetries = 3,
  }) {
    _processCallback = processCallback;
    _maxRetries = maxRetries;
    _logger.info('OfflineRequestQueue', 'Initialized');
  }

  /// Adiciona requisição à fila
  Future<void> enqueue(
    OfflineRequestMethod method,
    String endpoint, {
    Map<String, dynamic>? body,
    int priority = 5,
  }) async {
    final request = OfflineRequest(
      id: DateTime.now().millisecondsSinceEpoch.toString(),
      method: method,
      endpoint: endpoint,
      body: body,
      priority: priority,
    );

    _queue.add(request);
    _queue.sort((a, b) => a.priority.compareTo(b.priority));

    _logger.info(
      'OfflineRequestQueue',
      'Enqueued: $method $endpoint (${_queue.length} pending)',
    );

    notifyListeners();
  }

  /// Remove requisição da fila
  Future<void> remove(String requestId) async {
    _queue.removeWhere((r) => r.id == requestId);
    _logger.info('OfflineRequestQueue', 'Removed: $requestId');
    notifyListeners();
  }

  /// Sincroniza fila (processa todas as requisições)
  Future<void> sync() async {
    if (_syncing || _processCallback == null) return;
    if (_queue.isEmpty) return;

    _syncing = true;
    notifyListeners();

    _logger.info('OfflineRequestQueue', 'Starting sync (${_queue.length} pending)');

    final processed = <String>[];
    final failed = <String>[];

    for (final request in List.from(_queue)) {
      if (request.retryCount >= _maxRetries) {
        _logger.warning(
          'OfflineRequestQueue',
          'Max retries exceeded: ${request.endpoint}',
        );
        failed.add(request.id);
        continue;
      }

      try {
        final updatedRequest = request.copyWith(isProcessing: true);
        final index = _queue.indexWhere((r) => r.id == request.id);
        if (index >= 0) {
          _queue[index] = updatedRequest;
        }

        final success = await _processCallback!(request);

        if (success) {
          processed.add(request.id);
          _queue.removeWhere((r) => r.id == request.id);
          _logger.info(
            'OfflineRequestQueue',
            'Processed: ${request.method} ${request.endpoint}',
          );
        } else {
          final retryRequest = request.copyWith(
            retryCount: request.retryCount + 1,
            lastRetryAt: DateTime.now(),
            isProcessing: false,
          );
          final index = _queue.indexWhere((r) => r.id == request.id);
          if (index >= 0) {
            _queue[index] = retryRequest;
          }
          _logger.debug(
            'OfflineRequestQueue',
            'Retry needed: ${request.endpoint} (attempt ${request.retryCount + 1})',
          );
        }
      } catch (e) {
        _logger.error(
          'OfflineRequestQueue',
          'Error processing ${request.endpoint}: $e',
        );
        final retryRequest = request.copyWith(
          retryCount: request.retryCount + 1,
          lastRetryAt: DateTime.now(),
          isProcessing: false,
        );
        final index = _queue.indexWhere((r) => r.id == request.id);
        if (index >= 0) {
          _queue[index] = retryRequest;
        }
      }
    }

    _syncing = false;
    notifyListeners();

    _logger.info(
      'OfflineRequestQueue',
      'Sync complete: ${processed.length} processed, ${failed.length} failed',
    );
  }

  /// Inicia sincronização periódica
  void startAutoSync({Duration interval = const Duration(minutes: 1)}) {
    _syncTimer?.cancel();
    _syncTimer = Timer.periodic(interval, (_) => sync());
    _logger.info('OfflineRequestQueue', 'Auto-sync started');
  }

  /// Para sincronização periódica
  void stopAutoSync() {
    _syncTimer?.cancel();
    _syncTimer = null;
    _logger.info('OfflineRequestQueue', 'Auto-sync stopped');
  }

  /// Limpa fila
  Future<void> clear() async {
    _queue.clear();
    _logger.info('OfflineRequestQueue', 'Queue cleared');
    notifyListeners();
  }

  /// Retorna requisições falhas (max retries exceeded)
  List<OfflineRequest> get failedRequests =>
      _queue.where((r) => r.retryCount >= _maxRetries).toList();

  /// Retorna requisições em retry
  List<OfflineRequest> get retryingRequests =>
      _queue.where((r) => r.retryCount > 0).toList();

  /// Desabilita gerenciador
  void dispose() {
    stopAutoSync();
    _logger.info('OfflineRequestQueue', 'Disposed');
    super.dispose();
  }
}
