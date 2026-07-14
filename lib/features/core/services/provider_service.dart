import 'package:flutter/foundation.dart';
import 'connectivity_service.dart';
import '../database/sqlite_service.dart';

class ProviderService extends ChangeNotifier {
  late ConnectivityService _connectivityService;
  late SqliteService _sqliteService;

  ConnectivityService get connectivityService => _connectivityService;
  SqliteService get sqliteService => _sqliteService;

  Future<void> initialize() async {
    try {
      print('[Services] Inicializando SQLite...');
      _sqliteService = SqliteService();

      print('[Services] Inicializando ConnectivityService...');
      _connectivityService = ConnectivityService();
      await _connectivityService.init();

      print('[Services] Todos os serviços inicializados com sucesso');
      notifyListeners();
    } catch (e) {
      print('[Services] Erro ao inicializar serviços: $e');
      rethrow;
    }
  }

  Future<void> dispose() async {
    print('[Services] Finalizando serviços...');
    _connectivityService.dispose();
    await _sqliteService.close();
  }
}
