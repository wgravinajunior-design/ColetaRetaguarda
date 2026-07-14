import 'package:fbdb/fbdb.dart';
import '../config/config_service.dart';

class DbConnection {
  static final DbConnection _instance = DbConnection._internal();
  factory DbConnection() => _instance;
  DbConnection._internal();

  FbDb? _db;

  Future<FbDb> get db async {
    if (_db != null) {
      return _db!;
    }
    
    final config = ConfigService();
    
    _db = await FbDb.attach(
      host: config.host.isEmpty ? 'localhost' : config.host,
      port: int.tryParse(config.porta) ?? 3050,
      database: config.caminhoBase,
      user: 'SYSDBA',
      password: 'masterkey',
    );
    
    return _db!;
  }

  Future<void> disconnect() async {
    if (_db != null) {
      await _db!.detach();
      _db = null;
    }
  }
}
