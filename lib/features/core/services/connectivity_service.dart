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

  Future<void> init() async {
    // Verifica status inicial
    final result = await _connectivity.checkConnectivity();
    _isOnline = result != ConnectivityResult.none;
    await _updatePendingCount();
    notifyListeners();

    // Monitora mudanças de conectividade
    _subscription = _connectivity.onConnectivityChanged.listen(_handleConnectivityChange);
  }

  Future<void> _handleConnectivityChange(ConnectivityResult result) async {
    final wasOnline = _isOnline;
    _isOnline = result != ConnectivityResult.none;

    if (_isOnline != wasOnline) {
      notifyListeners();
    }

    // Se voltou online e tem itens pendentes, sincroniza
    if (_isOnline && _pendingCount > 0) {
      await syncPending();
    }
  }

  Future<void> syncPending() async {
    if (_isSyncing || !_isOnline) return;

    _isSyncing = true;
    notifyListeners();

    try {
      print('[Sync] Iniciando sincronização de $pendingCount itens pendentes...');
      await _syncService.syncPendingItems();
      print('[Sync] Sincronização concluída com sucesso');

      await _updatePendingCount();
    } catch (e) {
      print('[Sync] Erro durante sincronização: $e');
    } finally {
      _isSyncing = false;
      notifyListeners();
    }
  }

  Future<void> _updatePendingCount() async {
    try {
      _pendingCount = await _queueDao.countPending();
    } catch (e) {
      print('Erro ao contar itens pendentes: $e');
      _pendingCount = 0;
    }
  }

  @override
  void dispose() {
    _subscription?.cancel();
    super.dispose();
  }
}
