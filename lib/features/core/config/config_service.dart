import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:ini/ini.dart';
import 'package:path/path.dart' as p;

class ConfigService extends ChangeNotifier {
  static final ConfigService _instance = ConfigService._internal();
  factory ConfigService() => _instance;
  ConfigService._internal();

  String host = 'localhost';
  String porta = '3000';
  String caminhoBase = 'C:\\Dados\\COLETA\\DADOS.FDB';
  String logoPath = '';

  bool _initialized = false;
  bool get isInitialized => _initialized;

  Future<void> loadConfig() async {
    final file = File('conf.ini');
    if (await file.exists()) {
      final lines = await file.readAsLines();
      final config = Config.fromStrings(lines);
      
      host = config.get('Database', 'Host') ?? 'localhost';
      porta = config.get('Database', 'Porta') ?? '3000';
      caminhoBase = config.get('Database', 'CaminhoBase') ?? 'C:\\Dados\\COLETA\\DADOS.FDB';
      logoPath = config.get('App', 'LogoPath') ?? '';
    } else {
      await saveConfig();
    }
    _initialized = true;
    notifyListeners();
  }

  Future<void> saveConfig() async {
    final config = Config();
    config.addSection('Database');
    config.set('Database', 'Host', host);
    config.set('Database', 'Porta', porta);
    config.set('Database', 'CaminhoBase', caminhoBase);
    
    config.addSection('App');
    config.set('App', 'LogoPath', logoPath);
    
    final file = File('conf.ini');
    await file.writeAsString(config.toString());
    notifyListeners();
  }

  // Helper method to format API URL
  String get apiUrl => 'http://$host:$porta';
}
