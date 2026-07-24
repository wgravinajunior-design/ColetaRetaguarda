import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:ini/ini.dart';
import '../../../core/paths/app_paths.dart';

class ConfigService extends ChangeNotifier {
  static final ConfigService _instance = ConfigService._internal();
  factory ConfigService() => _instance;
  ConfigService._internal();

  String host = 'localhost';
  String porta = '3050';
  String caminhoBase = 'C:\\Dados\\COLETA\\DADOS.FDB';
  String logoPath = '';

  /// Credenciais do Firebird. Ficam no conf.ini, e não no código, porque o
  /// repositório é público — os valores abaixo são só o padrão de instalação
  /// do Firebird e devem ser trocados em produção.
  String dbUsuario = 'SYSDBA';
  String dbSenha = 'masterkey';

  bool _initialized = false;
  bool get isInitialized => _initialized;

  Future<void> loadConfig() async {
    final file = AppPaths.configFile;
    if (await file.exists()) {
      final lines = await file.readAsLines();
      final config = Config.fromStrings(lines);

      host = config.get('Database', 'Host') ?? 'localhost';
      porta = config.get('Database', 'Porta') ?? '3050';
      caminhoBase = config.get('Database', 'CaminhoBase') ?? 'C:\\Dados\\COLETA\\DADOS.FDB';
      dbUsuario = config.get('Database', 'Usuario') ?? 'SYSDBA';
      dbSenha = config.get('Database', 'Senha') ?? 'masterkey';
      logoPath = config.get('App', 'LogoPath') ?? '';
    } else {
      // Sem config ainda: grava os padrões, mas nunca deixa uma falha de
      // escrita impedir a abertura do app — a tela de config resolve depois.
      try {
        await saveConfig();
      } on FileSystemException catch (e) {
        debugPrint('Não foi possível gravar ${file.path}: $e');
      }
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
    config.set('Database', 'Usuario', dbUsuario);
    config.set('Database', 'Senha', dbSenha);
    
    config.addSection('App');
    config.set('App', 'LogoPath', logoPath);
    
    final file = AppPaths.configFile;
    await file.writeAsString(config.toString());
    notifyListeners();
  }

  // Helper method to format API URL
  String get apiUrl => 'http://$host:$porta';
}
