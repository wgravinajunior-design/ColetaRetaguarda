import 'package:sqflite/sqflite.dart';
import '../base_dao.dart';

class SyncQueueItem {
  int? id;
  String tabela;
  String operacao;
  int? registroId;
  String dados;
  String status;
  int tentativas;
  String dataCriacao;
  String? dataUltimoTentativa;

  SyncQueueItem({
    this.id,
    required this.tabela,
    required this.operacao,
    this.registroId,
    required this.dados,
    this.status = 'P',
    this.tentativas = 0,
    required this.dataCriacao,
    this.dataUltimoTentativa,
  });
}

class SyncQueueDao extends BaseDao<SyncQueueItem> {
  @override
  String get tableName => 'tb_sync_queue';

  @override
  SyncQueueItem fromMap(Map<String, dynamic> map) {
    return SyncQueueItem(
      id: map['id'] as int?,
      tabela: map['tabela'] as String? ?? '',
      operacao: map['operacao'] as String? ?? '',
      registroId: map['registro_id'] as int?,
      dados: map['dados'] as String? ?? '',
      status: map['status'] as String? ?? 'P',
      tentativas: map['tentativas'] as int? ?? 0,
      dataCriacao: map['data_criacao'] as String? ?? '',
      dataUltimoTentativa: map['data_ultimo_tentativa'] as String?,
    );
  }

  @override
  Map<String, dynamic> toMap(SyncQueueItem obj) {
    return {
      'id': obj.id,
      'tabela': obj.tabela,
      'operacao': obj.operacao,
      'registro_id': obj.registroId,
      'dados': obj.dados,
      'status': obj.status,
      'tentativas': obj.tentativas,
      'data_criacao': obj.dataCriacao,
      'data_ultimo_tentativa': obj.dataUltimoTentativa,
    };
  }

  Future<List<SyncQueueItem>> getPendingItems() async {
    final db = await database;
    final maps = await db.query(
      tableName,
      where: 'status = ?',
      whereArgs: ['P'],
      orderBy: 'data_criacao ASC',
    );
    return List.generate(maps.length, (i) => fromMap(maps[i]));
  }

  Future<void> markAsSuccess(int id) async {
    final db = await database;
    await db.update(
      tableName,
      {
        'status': 'S',
        'data_ultimo_tentativa': DateTime.now().toIso8601String(),
      },
      where: 'id = ?',
      whereArgs: [id],
    );
  }

  Future<void> incrementTentativas(int id) async {
    final db = await database;
    await db.rawUpdate(
      'UPDATE $tableName SET tentativas = tentativas + 1, data_ultimo_tentativa = ? WHERE id = ?',
      [DateTime.now().toIso8601String(), id],
    );
  }

  Future<void> markAsError(int id) async {
    final db = await database;
    await db.update(
      tableName,
      {
        'status': 'E',
        'data_ultimo_tentativa': DateTime.now().toIso8601String(),
      },
      where: 'id = ?',
      whereArgs: [id],
    );
  }

  Future<int> countPending() async {
    final db = await database;
    final result = await db.rawQuery(
      'SELECT COUNT(*) as count FROM $tableName WHERE status = ?',
      ['P'],
    );
    return Sqflite.firstIntValue(result) ?? 0;
  }

  Future<int> countByStatus(String status) async {
    final db = await database;
    final result = await db.rawQuery(
      'SELECT COUNT(*) as count FROM $tableName WHERE status = ?',
      [status],
    );
    return Sqflite.firstIntValue(result) ?? 0;
  }

  /// Retorna todos os itens da fila, mais recentes primeiro.
  Future<List<SyncQueueItem>> getAllOrdered() async {
    final db = await database;
    final maps = await db.query(tableName, orderBy: 'data_criacao DESC');
    return List.generate(maps.length, (i) => fromMap(maps[i]));
  }

  /// Reenfileira itens com erro (status E → P, zera tentativas).
  Future<int> resetErros() async {
    final db = await database;
    return db.update(
      tableName,
      {'status': 'P', 'tentativas': 0},
      where: 'status = ?',
      whereArgs: ['E'],
    );
  }

  /// Remove itens já sincronizados com sucesso.
  Future<int> limparSincronizados() async {
    final db = await database;
    return db.delete(tableName, where: 'status = ?', whereArgs: ['S']);
  }
}
