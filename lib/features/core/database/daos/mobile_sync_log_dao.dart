import 'package:sqflite/sqflite.dart';
import '../base_dao.dart';

/// Uma requisição do app mobile ao servidor embutido.
class MobileSyncLogItem {
  int? id;
  String dataHora;
  String metodo;
  String rota;

  /// Nome amigável da operação, para a tela ("Produtores", "Envio de coletas").
  String descricao;
  int statusHttp;

  /// Quantos registros a resposta devolveu, quando aplicável.
  int? registros;
  int? duracaoMs;
  String? clienteIp;
  String? erro;

  MobileSyncLogItem({
    this.id,
    required this.dataHora,
    required this.metodo,
    required this.rota,
    required this.descricao,
    required this.statusHttp,
    this.registros,
    this.duracaoMs,
    this.clienteIp,
    this.erro,
  });

  bool get sucesso => statusHttp >= 200 && statusHttp < 300;
}

class MobileSyncLogDao extends BaseDao<MobileSyncLogItem> {
  @override
  String get tableName => 'tb_mobile_sync_log';

  @override
  MobileSyncLogItem fromMap(Map<String, dynamic> map) {
    return MobileSyncLogItem(
      id: map['id'] as int?,
      dataHora: map['data_hora'] as String? ?? '',
      metodo: map['metodo'] as String? ?? '',
      rota: map['rota'] as String? ?? '',
      descricao: map['descricao'] as String? ?? '',
      statusHttp: map['status_http'] as int? ?? 0,
      registros: map['registros'] as int?,
      duracaoMs: map['duracao_ms'] as int?,
      clienteIp: map['cliente_ip'] as String?,
      erro: map['erro'] as String?,
    );
  }

  @override
  Map<String, dynamic> toMap(MobileSyncLogItem obj) {
    return {
      'id': obj.id,
      'data_hora': obj.dataHora,
      'metodo': obj.metodo,
      'rota': obj.rota,
      'descricao': obj.descricao,
      'status_http': obj.statusHttp,
      'registros': obj.registros,
      'duracao_ms': obj.duracaoMs,
      'cliente_ip': obj.clienteIp,
      'erro': obj.erro,
    };
  }

  /// Últimas requisições, mais recentes primeiro.
  Future<List<MobileSyncLogItem>> ultimos({int limite = 200}) async {
    final db = await database;
    final maps = await db.query(
      tableName,
      orderBy: 'id DESC',
      limit: limite,
    );
    return List.generate(maps.length, (i) => fromMap(maps[i]));
  }

  Future<int> contarComErro() async {
    final db = await database;
    final r = await db.rawQuery(
      'SELECT COUNT(*) as count FROM $tableName WHERE status_http >= 400',
    );
    return Sqflite.firstIntValue(r) ?? 0;
  }

  /// Data/hora da última requisição registrada, ou null se nunca houve.
  Future<String?> ultimaAtividade() async {
    final db = await database;
    final r = await db.rawQuery(
      'SELECT data_hora FROM $tableName ORDER BY id DESC LIMIT 1',
    );
    if (r.isEmpty) return null;
    return r.first['data_hora'] as String?;
  }

  Future<int> limpar() async {
    final db = await database;
    return db.delete(tableName);
  }

  /// Descarta o histórico antigo para o arquivo não crescer sem limite.
  /// Cada sync do mobile grava ~8 linhas, então o teto é generoso.
  Future<void> aparar({int manter = 2000}) async {
    final db = await database;
    await db.rawDelete(
      'DELETE FROM $tableName WHERE id NOT IN '
      '(SELECT id FROM $tableName ORDER BY id DESC LIMIT ?)',
      [manter],
    );
  }
}
