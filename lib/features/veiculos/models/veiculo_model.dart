class VeiculoModel {
  int? id;
  String placa;
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
    required this.marca,
    required this.modelo,
    required this.cor,
    required this.ano,
    required this.tipo,
    required this.renavam,
    this.chassi,
    this.status = 'A',
    this.dataCadastro,
    this.dataAtualizacao,
  });

  factory VeiculoModel.fromJson(Map<String, dynamic> json) {
    return VeiculoModel(
      id: json['VEI_ID'] as int?,
      placa: json['VEI_PLACA'] as String? ?? '',
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
}
