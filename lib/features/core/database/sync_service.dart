import 'dart:async';
import 'dart:convert';
import '../../../core/api/http_client.dart';
import '../services/connectivity_service.dart';
import 'daos/sync_queue_dao.dart';

class SyncService {
  final SyncQueueDao _queueDao = SyncQueueDao();
  final ApiClient _apiClient = ApiClient();
  final ConnectivityService _connectivity = ConnectivityService();

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

  /// Inicializa auto-sync quando volta online
  void setupAutoSync() {
    _connectivity.onConnectivityChanged.listen((isOnline) {
      if (isOnline) {
        // Delay pequeno para garantir que a conexão está estável
        Future.delayed(Duration(seconds: 1), () {
          syncPendingItems();
        });
      }
    });
  }

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
    final endpoint = _getEndpoint(item.tabela);
    final dados = jsonDecode(item.dados);

    switch (item.operacao.toUpperCase()) {
      case 'CREATE':
        await _apiClient.post(endpoint, body: dados);
        break;
      case 'UPDATE':
        if (item.registroId != null) {
          await _apiClient.put('$endpoint/${item.registroId}', body: dados);
        }
        break;
      case 'DELETE':
        if (item.registroId != null) {
          await _apiClient.delete('$endpoint/${item.registroId}');
        }
        break;
    }
  }

  String _getEndpoint(String tabela) {
    return switch (tabela) {
      'tb_pessoa' => '/coleta/pessoas',
      'tb_motorista' => '/coleta/motoristas',
      'tb_veiculo' => '/coleta/veiculos',
      'tb_rota' => '/coleta/rotas',
      'tb_movimento_conta' => '/coleta/movimento-conta',
      _ => '/coleta/$tabela',
    };
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
