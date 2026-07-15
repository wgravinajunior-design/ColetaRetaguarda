import 'dart:async';
import 'package:connectivity_plus/connectivity_plus.dart';
import 'package:flutter/foundation.dart';
import '../database/sync_service.dart';
import '../database/daos/sync_queue_dao.dart';

class ConnectivityService extends ChangeNotifier {
  final Connectivity _connectivity = Connectivity();
  final SyncService _syncService = SyncService();
  final SyncQueueDao _queueDao = SyncQueueDao();

  bool _isOnline = true;
  bool get isOnline => _isOnline;

  int _pendingCount = 0;
  int get pendingCount => _pendingCount;

  bool _isSyncing = false;
  bool get isSyncing => _isSyncing;

  StreamSubscription? _subscription;
  Timer? _periodicTimer;

  /// Intervalo do retry periódico da fila (rede pode estar "online" mas o
  /// Firebird momentaneamente indisponível — o timer garante nova tentativa
  /// mesmo sem mudança de conectividade).
  static const Duration _periodicInterval = Duration(seconds: 60);

  Future<void> init() async {
    // Verifica status inicial
    final result = await _connectivity.checkConnectivity();
    _isOnline = result != ConnectivityResult.none;
    await _updatePendingCount();
    notifyListeners();

    // Monitora mudanças de conectividade
    _subscription = _connectivity.onConnectivityChanged.listen(_handleConnectivityChange);

    // Retry periódico enquanto houver pendências
    _periodicTimer = Timer.periodic(_periodicInterval, (_) => _autoSync());

    // Tenta escoar o que já estava pendente ao abrir
    await _autoSync();
  }

  Future<void> _handleConnectivityChange(ConnectivityResult result) async {
    final wasOnline = _isOnline;
    _isOnline = result != ConnectivityResult.none;

    if (_isOnline != wasOnline) {
      notifyListeners();
      // Acabou de voltar online: sincroniza imediatamente.
      if (_isOnline) {
        await _autoSync();
      }
    }
  }

  /// Sincronização automática: atualiza a contagem real e, se online e houver
  /// pendências, dispara o processamento. Não depende de contagem em cache.
  Future<void> _autoSync() async {
    if (!_isOnline || _isSyncing) return;
    await _updatePendingCount();
    if (_pendingCount > 0) {
      await syncPending();
    } else {
      notifyListeners();
    }
  }

  /// Atualiza a contagem de pendências (para o badge) sem sincronizar.
  Future<void> refreshPendingCount() async {
    await _updatePendingCount();
    notifyListeners();
  }

  Future<void> syncPending() async {
    if (_isSyncing || !_isOnline) return;

    _isSyncing = true;
    notifyListeners();

    try {
      debugPrint('[Sync] Iniciando sincronização de $pendingCount itens pendentes...');
      await _syncService.syncPendingItems();
      debugPrint('[Sync] Sincronização concluída com sucesso');

      await _updatePendingCount();
    } catch (e) {
      debugPrint('[Sync] Erro durante sincronização: $e');
    } finally {
      _isSyncing = false;
      notifyListeners();
    }
  }

  Future<void> _updatePendingCount() async {
    try {
      _pendingCount = await _queueDao.countPending();
    } catch (e) {
      debugPrint('Erro ao contar itens pendentes: $e');
      _pendingCount = 0;
    }
  }

  @override
  void dispose() {
    _subscription?.cancel();
    _periodicTimer?.cancel();
    super.dispose();
  }
}
