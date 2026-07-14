class ResfriadorModel {
  int? id;
  String numeroId; // RES_NUMERO_ID (ex: RES-001)
  String marcaModelo; // RES_MARCA_MODELO
  double capacidadeLitros; // RES_CAPACIDADE_LITROS
  int? anoFabricacao; // RES_ANO_FABRICACAO
  String? ultimaManutencao; // RES_ULTIMA_MANUTENCAO (yyyy-MM-dd)
  String status; // ATIVO | INATIVO | MANUTENCAO

  ResfriadorModel({
    this.id,
    this.numeroId = '',
    this.marcaModelo = '',
    this.capacidadeLitros = 0,
    this.anoFabricacao,
    this.ultimaManutencao,
    this.status = 'ATIVO',
  });

  ResfriadorModel copyWith({
    int? id,
    String? numeroId,
    String? marcaModelo,
    double? capacidadeLitros,
    int? anoFabricacao,
    String? ultimaManutencao,
    String? status,
  }) {
    return ResfriadorModel(
      id: id ?? this.id,
      numeroId: numeroId ?? this.numeroId,
      marcaModelo: marcaModelo ?? this.marcaModelo,
      capacidadeLitros: capacidadeLitros ?? this.capacidadeLitros,
      anoFabricacao: anoFabricacao ?? this.anoFabricacao,
      ultimaManutencao: ultimaManutencao ?? this.ultimaManutencao,
      status: status ?? this.status,
    );
  }
}
