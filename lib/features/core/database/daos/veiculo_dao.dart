import '../base_dao.dart';
import '../../../veiculos/models/veiculo_model.dart';

class VeiculoDao extends BaseDao<VeiculoModel> {
  @override
  String get tableName => 'tb_veiculo';

  @override
  VeiculoModel fromMap(Map<String, dynamic> map) {
    return VeiculoModel(
      id: map['id'] as int?,
      placa: map['placa'] as String? ?? '',
      marca: map['marca'] as String?,
      modelo: map['modelo'] as String?,
      cor: map['cor'] as String?,
      ano: map['ano'] as String?,
      tipo: map['tipo'] as String?,
      renavam: map['renavam'] as String?,
      chassi: map['chassi'] as String?,
      status: map['status'] as String? ?? 'A',
    );
  }

  @override
  Map<String, dynamic> toMap(VeiculoModel obj) {
    return {
      'id': obj.id,
      'placa': obj.placa,
      'marca': obj.marca,
      'modelo': obj.modelo,
      'cor': obj.cor,
      'ano': obj.ano,
      'tipo': obj.tipo,
      'renavam': obj.renavam,
      'chassi': obj.chassi,
      'status': obj.status,
      'data_atualizacao': DateTime.now().toIso8601String(),
    };
  }

  Future<VeiculoModel?> getByPlaca(String placa) async {
    final db = await database;
    final maps = await db.query(
      tableName,
      where: 'placa = ?',
      whereArgs: [placa],
    );
    if (maps.isNotEmpty) {
      return fromMap(maps.first);
    }
    return null;
  }
}
