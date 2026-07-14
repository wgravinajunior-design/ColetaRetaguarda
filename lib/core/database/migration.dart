import 'package:flutter/foundation.dart';
import 'package:sqflite/sqflite.dart';

/// Define uma migração de banco de dados
abstract class Migration {
  /// Versão desta migração
  int get version;

  /// Descrição da migração
  String get description;

  /// Executa a migração (upgrade)
  Future<void> up(Database db);

  /// Reverte a migração (downgrade)
  Future<void> down(Database db);
}

/// Migração 1: Criação de tabelas iniciais
class Migration001CreateInitialTables implements Migration {
  @override
  int get version => 1;

  @override
  String get description => 'Create initial tables (TB_PESSOA, TB_MOTORISTA, etc)';

  @override
  Future<void> up(Database db) async {
    // Tabela de pessoas (produtores, motoristas, colaboradores)
    await db.execute('''
      CREATE TABLE IF NOT EXISTS TB_PESSOA (
        PES_ID INTEGER PRIMARY KEY AUTOINCREMENT,
        PES_RAZAO_SOCIAL TEXT NOT NULL,
        PES_CNPJ_CPF TEXT,
        PES_TIPO TEXT, -- 'P'=Produtor, 'M'=Motorista, 'C'=Colaborador, 'T'=Transportador
        PES_ENDERECO TEXT,
        PES_NUMERO TEXT,
        PES_BAIRRO TEXT,
        PES_CEP TEXT,
        PES_TELEFONE TEXT,
        PES_STATUS TEXT DEFAULT 'A', -- 'A'=Ativo, 'I'=Inativo
        PES_DATA_CADASTRO DATETIME DEFAULT CURRENT_TIMESTAMP
      )
    ''');

    // Tabela de motoristas
    await db.execute('''
      CREATE TABLE IF NOT EXISTS TB_MOTORISTA (
        MOT_ID INTEGER PRIMARY KEY AUTOINCREMENT,
        MOT_NOME TEXT NOT NULL,
        MOT_CPF TEXT UNIQUE,
        MOT_RG TEXT,
        MOT_CNH TEXT,
        MOT_TELEFONE TEXT,
        MOT_STATUS TEXT DEFAULT 'A',
        MOT_DATA_CADASTRO DATETIME DEFAULT CURRENT_TIMESTAMP
      )
    ''');

    // Tabela de movimentações financeiras
    await db.execute('''
      CREATE TABLE IF NOT EXISTS TB_MOVIMENTO (
        MOV_ID INTEGER PRIMARY KEY AUTOINCREMENT,
        MOV_TIPO TEXT NOT NULL, -- 'C'=Crédito (Receita), 'D'=Débito (Despesa)
        MOV_DESCRICAO TEXT,
        MOV_VALOR REAL NOT NULL,
        MOV_DATA_MOV DATETIME,
        MOV_STATUS TEXT DEFAULT 'P', -- 'P'=Pendente, 'C'=Compensado
        MOV_CONTA INTEGER,
        MOV_DATA_CADASTRO DATETIME DEFAULT CURRENT_TIMESTAMP
      )
    ''');

    // Tabela de rotas de coleta
    await db.execute('''
      CREATE TABLE IF NOT EXISTS TB_ROTA (
        ROT_ID INTEGER PRIMARY KEY AUTOINCREMENT,
        ROT_DESCRICAO TEXT NOT NULL,
        ROT_MOTORISTA_ID INTEGER,
        ROT_VEICULO_ID INTEGER,
        ROT_STATUS TEXT DEFAULT 'A',
        ROT_DATA_CADASTRO DATETIME DEFAULT CURRENT_TIMESTAMP
      )
    ''');

    // Tabela de paradas (fazendas em uma rota)
    await db.execute('''
      CREATE TABLE IF NOT EXISTS TB_PARADA (
        PAR_ID INTEGER PRIMARY KEY AUTOINCREMENT,
        PAR_ROTA_ID INTEGER,
        PAR_PESSOA_ID INTEGER,
        PAR_STATUS TEXT DEFAULT 'P', -- 'P'=Pendente, 'A'=Andamento, 'S'=Sucesso, 'R'=Recusada
        PAR_TEMPERATURA REAL,
        PAR_VOLUME REAL,
        PAR_LATITUDE REAL,
        PAR_LONGITUDE REAL,
        PAR_DATA_CADASTRO DATETIME DEFAULT CURRENT_TIMESTAMP
      )
    ''');
  }

  @override
  Future<void> down(Database db) async {
    await db.execute('DROP TABLE IF EXISTS TB_PARADA');
    await db.execute('DROP TABLE IF EXISTS TB_ROTA');
    await db.execute('DROP TABLE IF EXISTS TB_MOVIMENTO');
    await db.execute('DROP TABLE IF EXISTS TB_MOTORISTA');
    await db.execute('DROP TABLE IF EXISTS TB_PESSOA');
  }
}

/// Migração 2: Adiciona índices para performance
class Migration002AddIndexes implements Migration {
  @override
  int get version => 2;

  @override
  String get description => 'Add database indexes for better performance';

  @override
  Future<void> up(Database db) async {
    await db.execute('CREATE INDEX IF NOT EXISTS idx_pessoa_status ON TB_PESSOA(PES_STATUS)');
    await db.execute('CREATE INDEX IF NOT EXISTS idx_pessoa_tipo ON TB_PESSOA(PES_TIPO)');
    await db.execute('CREATE INDEX IF NOT EXISTS idx_parada_rota ON TB_PARADA(PAR_ROTA_ID)');
    await db.execute('CREATE INDEX IF NOT EXISTS idx_parada_status ON TB_PARADA(PAR_STATUS)');
    await db.execute('CREATE INDEX IF NOT EXISTS idx_rota_motorista ON TB_ROTA(ROT_MOTORISTA_ID)');
  }

  @override
  Future<void> down(Database db) async {
    await db.execute('DROP INDEX IF EXISTS idx_pessoa_status');
    await db.execute('DROP INDEX IF EXISTS idx_pessoa_tipo');
    await db.execute('DROP INDEX IF EXISTS idx_parada_rota');
    await db.execute('DROP INDEX IF EXISTS idx_parada_status');
    await db.execute('DROP INDEX IF EXISTS idx_rota_motorista');
  }
}

/// Gerenciador de migrações
class MigrationManager {
  static final List<Migration> _migrations = [
    Migration001CreateInitialTables(),
    Migration002AddIndexes(),
  ];

  /// Executa todas as migrações pendentes
  static Future<void> migrate(Database db) async {
    // Obtém versão atual do banco
    final result = await db.rawQuery('PRAGMA user_version');
    final currentVersion = (result.isNotEmpty ? result[0]['user_version'] : 0) as int;

    // Executa migrações pendentes
    for (final migration in _migrations) {
      if (migration.version > currentVersion) {
        debugPrint('[Migration] Executing v${migration.version}: ${migration.description}');
        await migration.up(db);

        // Atualiza versão do banco
        await db.rawUpdate('PRAGMA user_version = ${migration.version}');
      }
    }
  }

  /// Reverte última migração (para testes/desenvolvimento)
  static Future<void> rollback(Database db) async {
    final result = await db.rawQuery('PRAGMA user_version');
    final currentVersion = (result.isNotEmpty ? result[0]['user_version'] : 0) as int;

    if (currentVersion > 0) {
      final migration = _migrations.firstWhere(
        (m) => m.version == currentVersion,
        orElse: () => throw Exception('Migration v$currentVersion not found'),
      );

      debugPrint('[Migration] Rolling back v${migration.version}');
      await migration.down(db);

      // Reduz versão
      await db.rawUpdate('PRAGMA user_version = ${currentVersion - 1}');
    }
  }

  /// Retorna versão atual do banco
  static Future<int> getCurrentVersion(Database db) async {
    final result = await db.rawQuery('PRAGMA user_version');
    return (result.isNotEmpty ? result[0]['user_version'] : 0) as int;
  }

  /// Retorna versão alvo (máxima)
  static int getTargetVersion() => _migrations.isNotEmpty ? _migrations.last.version : 0;
}

