import 'dart:async';
import 'dart:convert';
import 'daos/sync_queue_dao.dart';

/// Handler que reexecuta uma operação enfileirada contra a fonte de verdade
/// (repository → Firebird). Recebe a operação, o id do registro (quando houver)
/// e os dados. Retorna true se a operação foi aplicada com sucesso.
typedef SyncOperationHandler = Future<bool> Function(
  String operacao,
  int? registroId,
  Map<String, dynamic> dados,
);

/// Fila de sincronização única e persistida (tb_sync_queue).
///
/// Singleton: handlers registrados uma vez valem para todas as instâncias
/// (viewmodels, repositories e connectivity_service compartilham o estado).
///
/// O replay NÃO é feito por HTTP — cada entidade registra um handler que
/// reexecuta a escrita no repository/Firebird correspondente. Assim uma
/// operação feita offline é realmente reaplicada quando a base volta.
class SyncService {
  static final SyncService _instance = SyncService._internal();
  factory SyncService() => _instance;
  SyncService._internal();

  final SyncQueueDao _queueDao = SyncQueueDao();

  /// Handlers de replay por entidade (chave = tabela usada em queueOperation).
  final Map<String, SyncOperationHandler> _handlers = {};

  // Callbacks para notificar UI
  final _onSyncStart = StreamController<void>.broadcast();
  final _onSyncComplete = StreamController<SyncResult>.broadcast();
  final _onSyncError = StreamController<String>.broadcast();

  // Control de sincronização em progresso
  bool _isSyncing = false;
  Timer? _retryTimer;

  Stream<void> get onSyncStart => _onSyncStart.stream;
  Stream<SyncResult> get onSyncComplete => _onSyncComplete.stream;
  Stream<String> get onSyncError => _onSyncError.stream;
  bool get isSyncing => _isSyncing;

  /// Registra o handler de replay de uma entidade. Chamado no bootstrap
  /// (registerSyncHandlers) para cada repository.
  void registerHandler(String tabela, SyncOperationHandler handler) {
    _handlers[tabela] = handler;
  }

  /// Compat: no modelo atual o auto-sync é disparado pelo ConnectivityService
  /// (ao voltar online) e no bootstrap. Mantido como no-op para chamadas legadas.
  void setupAutoSync() {}

  /// Fila uma operação para sincronizar depois
  Future<void> queueOperation({
    required String tabela,
    required String operacao,
    int? registroId,
    required Map<String, dynamic> dados,
  }) async {
    final item = SyncQueueItem(
      tabela: tabela,
      operacao: operacao,
      registroId: registroId,
      dados: jsonEncode(dados),
      status: 'P',
      dataCriacao: DateTime.now().toIso8601String(),
    );

    await _queueDao.insert(item);
  }

  /// Sincroniza todos os items pendentes
  Future<void> syncPendingItems() async {
    if (_isSyncing) return;

    _isSyncing = true;
    _onSyncStart.add(null);

    try {
      final pendingItems = await _queueDao.getPendingItems();

      if (pendingItems.isEmpty) {
        _onSyncComplete.add(SyncResult(success: true, itemsCount: 0));
        return;
      }

      int successCount = 0;
      int errorCount = 0;

      for (var item in pendingItems) {
        try {
          await _syncItemWithRetry(item);
          await _queueDao.markAsSuccess(item.id!);
          successCount++;
        } catch (e) {
          await _queueDao.incrementTentativas(item.id!);

          if (item.tentativas >= 3) {
            await _queueDao.markAsError(item.id!);
          }
          errorCount++;
          _onSyncError.add('Erro ao sincronizar: $e');
        }
      }

      _onSyncComplete.add(SyncResult(
        success: errorCount == 0,
        itemsCount: successCount,
        errorsCount: errorCount,
      ));
    } finally {
      _isSyncing = false;
    }
  }

  /// Sincroniza com retry automático (exponential backoff)
  Future<void> _syncItemWithRetry(SyncQueueItem item, {int attempt = 0}) async {
    try {
      await _syncItem(item);
    } catch (e) {
      if (attempt < 3) {
        // Exponential backoff: 1s, 2s, 4s
        final delaySeconds = 1 << attempt;
        await Future.delayed(Duration(seconds: delaySeconds));
        await _syncItemWithRetry(item, attempt: attempt + 1);
      } else {
        rethrow;
      }
    }
  }

  Future<void> _syncItem(SyncQueueItem item) async {
    final handler = _handlers[item.tabela];
    if (handler == null) {
      throw StateError('Sem handler de replay para "${item.tabela}"');
    }

    final dados = (item.dados.isNotEmpty)
        ? jsonDecode(item.dados) as Map<String, dynamic>
        : <String, dynamic>{};

    final ok = await handler(
      item.operacao.toUpperCase(),
      item.registroId,
      dados,
    );

    if (!ok) {
      throw Exception(
        'Replay recusado: ${item.tabela}/${item.operacao} (id ${item.registroId})',
      );
    }
  }

  Future<int> getPendingCount() => _queueDao.countPending();
  Future<int> getErrorCount() => _queueDao.countByStatus('E');
  Future<List<SyncQueueItem>> getAllItems() => _queueDao.getAllOrdered();
  Future<int> retryFailed() => _queueDao.resetErros();
  Future<int> clearSynced() => _queueDao.limparSincronizados();

  /// Limpa recursos
  void dispose() {
    _retryTimer?.cancel();
    _onSyncStart.close();
    _onSyncComplete.close();
    _onSyncError.close();
  }
}

/// Resultado da sincronização
class SyncResult {
  final bool success;
  final int itemsCount;
  final int errorsCount;

  SyncResult({
    required this.success,
    required this.itemsCount,
    this.errorsCount = 0,
  });
}
