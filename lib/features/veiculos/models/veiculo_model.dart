class VeiculoModel {
  int? id;
  String placa;

  /// Nome pelo qual o carro é conhecido no dia a dia ("Caminhão 1", "Toco
  /// branco"). Grava em VEI_DESCRICAO, coluna que a base do ERP já traz.
  String descricao;
  String marca;
  String modelo;
  String cor;
  String ano;
  String tipo; // 'C'=Caminhão, 'F'=Frigorífico, etc
  String renavam;
  String? chassi;
  String status;
  DateTime? dataCadastro;
  DateTime? dataAtualizacao;

  VeiculoModel({
    this.id,
    required this.placa,
    this.descricao = '',
    this.marca = '',
    this.modelo = '',
    this.cor = '',
    this.ano = '',
    this.tipo = 'C',
    this.renavam = '',
    this.chassi,
    this.status = 'A',
    this.dataCadastro,
    this.dataAtualizacao,
  });

  factory VeiculoModel.fromJson(Map<String, dynamic> json) {
    return VeiculoModel(
      id: json['VEI_ID'] as int?,
      placa: json['VEI_PLACA'] as String? ?? '',
      descricao: json['VEI_DESCRICAO'] as String? ?? '',
      marca: json['VEI_MARCA'] as String? ?? '',
      modelo: json['VEI_MODELO'] as String? ?? '',
      cor: json['VEI_COR'] as String? ?? '',
      ano: json['VEI_ANO'] as String? ?? '',
      tipo: json['VEI_TIPO'] as String? ?? 'C',
      renavam: json['VEI_RENAVAM'] as String? ?? '',
      chassi: json['VEI_CHASSI'] as String?,
      status: json['VEI_STATUS'] as String? ?? 'A',
      dataCadastro: json['VEI_DT_CADASTRO'] != null
          ? DateTime.tryParse(json['VEI_DT_CADASTRO'] as String)
          : null,
      dataAtualizacao: json['VEI_DT_ATUALIZACAO'] != null
          ? DateTime.tryParse(json['VEI_DT_ATUALIZACAO'] as String)
          : null,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'VEI_ID': id,
      'VEI_PLACA': placa,
      'VEI_DESCRICAO': descricao,
      'VEI_MARCA': marca,
      'VEI_MODELO': modelo,
      'VEI_COR': cor,
      'VEI_ANO': ano,
      'VEI_TIPO': tipo,
      'VEI_RENAVAM': renavam,
      'VEI_CHASSI': chassi,
      'VEI_STATUS': status,
      'VEI_DT_CADASTRO': dataCadastro?.toIso8601String(),
      'VEI_DT_ATUALIZACAO': dataAtualizacao?.toIso8601String(),
    };
  }

  VeiculoModel copyWith({
    int? id,
    String? placa,
    String? descricao,
    String? marca,
    String? modelo,
    String? cor,
    String? ano,
    String? tipo,
    String? renavam,
    String? chassi,
    String? status,
    DateTime? dataCadastro,
    DateTime? dataAtualizacao,
  }) {
    return VeiculoModel(
      id: id ?? this.id,
      placa: placa ?? this.placa,
      descricao: descricao ?? this.descricao,
      marca: marca ?? this.marca,
      modelo: modelo ?? this.modelo,
      cor: cor ?? this.cor,
      ano: ano ?? this.ano,
      tipo: tipo ?? this.tipo,
      renavam: renavam ?? this.renavam,
      chassi: chassi ?? this.chassi,
      status: status ?? this.status,
      dataCadastro: dataCadastro ?? this.dataCadastro,
      dataAtualizacao: dataAtualizacao ?? this.dataAtualizacao,
    );
  }
}
