import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:sqflite/sqflite.dart';
import 'package:path/path.dart';
import '../../../core/paths/app_paths.dart';
import 'db_migration.dart';

class SqliteService {
  static final SqliteService _instance = SqliteService._internal();
  Database? _database;

  factory SqliteService() {
    return _instance;
  }

  SqliteService._internal();

  Future<Database> get database async {
    _database ??= await _initDatabase();
    return _database!;
  }

  Future<Database> _initDatabase() async {
    return openDatabase(
      await getDbPath(),
      version: dbVersion,
      onCreate: _onCreate,
      onUpgrade: _onUpgrade,
    );
  }

  Future<void> _onCreate(Database db, int version) async {
    for (String migration in getMigrations()) {
      await db.execute(migration);
    }
  }

  Future<void> _onUpgrade(Database db, int oldVersion, int newVersion) async {
    if (oldVersion < newVersion) {
      // Cria tabelas que ainda não existem
      for (String migration in getMigrations()) {
        try {
          await db.execute(migration);
        } catch (e) {
          debugPrint('Migration error (table may exist): $e');
        }
      }
      // Aplica alterações incrementais (novas colunas em tabelas existentes)
      for (String alteracao in getAlteracoes()) {
        try {
          await db.execute(alteracao);
        } catch (e) {
          debugPrint('Alteracao ignorada (coluna pode existir): $e');
        }
      }
    }
  }

  Future<void> close() async {
    await _database?.close();
    _database = null;
  }

  /// Caminho real do arquivo do banco local.
  ///
  /// Precisa ser a mesma conta que [_initDatabase] faz, senão a tela de
  /// diagnóstico mostra um caminho onde o arquivo não está: no desktop o padrão
  /// do sqflite_ffi é relativo ao diretório atual, que em Program Files não é
  /// gravável — por isso o banco fica na pasta de dados do usuário.
  Future<String> getDbPath() async {
    final dir = (Platform.isWindows || Platform.isLinux || Platform.isMacOS)
        ? AppPaths.dataDir.path
        : await getDatabasesPath();
    return join(dir, 'coleta_erp.db');
  }

  /// Lista todas as tabelas do banco (exceto internas do SQLite).
  Future<List<String>> listarTabelas() async {
    final db = await database;
    final result = await db.rawQuery(
      "SELECT name FROM sqlite_master WHERE type='table' AND name NOT LIKE 'sqlite_%' AND name NOT LIKE 'android_%' ORDER BY name",
    );
    return result.map((r) => r['name'] as String).toList();
  }

  /// Retorna os campos (colunas) de uma tabela: nome, tipo, notnull, pk.
  Future<List<Map<String, dynamic>>> listarCampos(String tabela) async {
    final db = await database;
    return db.rawQuery('PRAGMA table_info($tabela)');
  }

  /// Conta os registros de uma tabela.
  Future<int> contarRegistros(String tabela) async {
    final db = await database;
    final result = await db.rawQuery('SELECT COUNT(*) as total FROM $tabela');
    return Sqflite.firstIntValue(result) ?? 0;
  }

  /// Versão atual do schema gravada no banco.
  Future<int> versaoAtual() async {
    final db = await database;
    return await db.getVersion();
  }

  /// Atualiza o schema de forma ADITIVA e não destrutiva:
  /// - cria tabelas que ainda não existem (CREATE IF NOT EXISTS);
  /// - adiciona colunas novas que faltam (ALTER TABLE ADD COLUMN).
  /// NUNCA dá DROP em tabelas ou campos originais — nenhum dado é perdido.
  Future<void> atualizarSchema() async {
    final db = await database;

    // Cria tabelas que ainda não existem
    for (final migration in getMigrations()) {
      try {
        await db.execute(migration);
      } catch (_) {
        // tabela já existe — ignora
      }
    }

    // Adiciona colunas novas (se já existirem, o ALTER falha e é ignorado)
    for (final alteracao in getAlteracoes()) {
      try {
        await db.execute(alteracao);
      } catch (_) {
        // coluna já existe — ignora
      }
    }

    // Atualiza a versão do schema gravada no banco
    await db.setVersion(dbVersion);
  }
}
