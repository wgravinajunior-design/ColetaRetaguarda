import '../base_dao.dart';
import '../../../rotas/models/rota_model.dart';

class RotaDao extends BaseDao<RotaModel> {
  @override
  String get tableName => 'tb_rota';

  @override
  RotaModel fromMap(Map<String, dynamic> map) {
    return RotaModel(
      id: map['id'] as int?,
      descricao: (map['descricao'] as String?) ?? '',
      regiao: map['regiao'] as String? ?? '',
      motoristaId: map['motorista_id'] as int?,
      veiculoId: map['veiculo_id'] as int?,
      status: (map['status'] as String?) ?? 'A',
      dataPrevista: map['data_prevista'] as String? ?? '',
      dataInicio: map['data_inicio'] as String? ?? '',
      dataFim: map['data_fim'] as String? ?? '',
      paradas: map['paradas'] as int?,
      kmEstimado: (map['km_estimado'] as num?)?.toDouble(),
      kmRealizado: (map['km_realizado'] as num?)?.toDouble(),
    );
  }

  @override
  Map<String, dynamic> toMap(RotaModel obj) {
    return {
      'id': obj.id,
      'descricao': obj.descricao,
      'regiao': obj.regiao,
      'motorista_id': obj.motoristaId,
      'veiculo_id': obj.veiculoId,
      'status': obj.status,
      'data_prevista': obj.dataPrevista,
      'data_inicio': obj.dataInicio,
      'data_fim': obj.dataFim,
      'paradas': obj.paradas,
      'km_estimado': obj.kmEstimado,
      'km_realizado': obj.kmRealizado,
      'data_atualizacao': DateTime.now().toIso8601String(),
    };
  }
}
