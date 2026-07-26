class RotaModel {
  int? id;
  String descricao;
  String? regiao;
  int? motoristaId;
  int? veiculoId;
  String status; // 'A'=Ativo, 'P'=Parada, 'I'=Inativo
  String? dataPrevista;
  String? dataInicio;
  String? dataFim;
  int? paradas;

  /// Paradas já confirmadas, para mostrar o andamento da rota na lista.
  int? paradasFeitas;
  double? kmEstimado;
  double? kmRealizado;
  DateTime? dataCadastro;

  RotaModel({
    this.id,
    required this.descricao,
    this.regiao,
    this.motoristaId,
    this.veiculoId,
    this.status = 'A',
    this.dataPrevista,
    this.dataInicio,
    this.dataFim,
    this.paradas = 0,
    this.paradasFeitas = 0,
    this.kmEstimado = 0.0,
    this.kmRealizado = 0.0,
    this.dataCadastro,
  });

  factory RotaModel.fromJson(Map<String, dynamic> json) {
    return RotaModel(
      id: json['ROT_ID'] as int?,
      descricao: json['ROT_DESCRICAO'] as String? ?? '',
      regiao: json['ROT_REGIAO'] as String?,
      motoristaId: json['ROT_MOTORISTA_ID'] as int?,
      veiculoId: json['ROT_VEICULO_ID'] as int?,
      status: json['ROT_STATUS'] as String? ?? 'A',
      dataPrevista: json['ROT_DATA_PREVISTA'] as String?,
      dataInicio: json['ROT_DATA_INICIO'] as String?,
      dataFim: json['ROT_DATA_FIM'] as String?,
      paradas: json['ROT_PARADAS'] as int? ?? 0,
      kmEstimado: (json['ROT_KM_ESTIMADO'] as num?)?.toDouble() ?? 0.0,
      kmRealizado: (json['ROT_KM_REALIZADO'] as num?)?.toDouble() ?? 0.0,
      dataCadastro: json['ROT_DT_CADASTRO'] != null
          ? DateTime.tryParse(json['ROT_DT_CADASTRO'] as String)
          : null,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'ROT_ID': id,
      'ROT_DESCRICAO': descricao,
      'ROT_REGIAO': regiao,
      'ROT_MOTORISTA_ID': motoristaId,
      'ROT_VEICULO_ID': veiculoId,
      'ROT_STATUS': status,
      'ROT_DATA_PREVISTA': dataPrevista,
      'ROT_DATA_INICIO': dataInicio,
      'ROT_DATA_FIM': dataFim,
      'ROT_PARADAS': paradas,
      'ROT_KM_ESTIMADO': kmEstimado,
      'ROT_KM_REALIZADO': kmRealizado,
      'ROT_DT_CADASTRO': dataCadastro?.toIso8601String(),
    };
  }
}
