import '../base_dao.dart';
import '../../../financeiro/models/movimento_model.dart';

class MovimentoDao extends BaseDao<MovimentoModel> {
  @override
  String get tableName => 'tb_movimento_conta';

  @override
  MovimentoModel fromMap(Map<String, dynamic> map) {
    return MovimentoModel(
      id: map['id'] as int?,
      tipo: map['tipo'] as String? ?? '',
      status: map['status'] as String?,
      conta: map['conta'] as int?,
      contaNome: map['conta_nome'] as String?,
      valor: (map['valor'] as num?)?.toDouble() ?? 0.0,
      dtEmissao: map['dt_emissao'] as String? ?? '',
      dtCompensado: map['dt_compensado'] as String?,
      historico: map['historico'] as String? ?? '',
    );
  }

  @override
  Map<String, dynamic> toMap(MovimentoModel obj) {
    return {
      'id': obj.id,
      'tipo': obj.tipo,
      'status': obj.status,
      'conta': obj.conta,
      'conta_nome': obj.contaNome,
      'valor': obj.valor,
      'dt_emissao': obj.dtEmissao,
      'dt_compensado': obj.dtCompensado,
      'historico': obj.historico,
      'data_atualizacao': DateTime.now().toIso8601String(),
    };
  }

  Future<List<MovimentoModel>> getByTipo(String tipo) async {
    final db = await database;
    final maps = await db.query(
      tableName,
      where: 'tipo = ?',
      whereArgs: [tipo],
    );
    return List.generate(maps.length, (i) => fromMap(maps[i]));
  }

  Future<double> getTotalByTipo(String tipo) async {
    final db = await database;
    final result = await db.rawQuery(
      'SELECT SUM(valor) as total FROM $tableName WHERE tipo = ?',
      [tipo],
    );
    if (result.isNotEmpty && result.first['total'] != null) {
      return (result.first['total'] as num).toDouble();
    }
    return 0.0;
  }
}
