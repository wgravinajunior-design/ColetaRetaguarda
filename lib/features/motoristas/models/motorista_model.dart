class MotoristaModel {
  int? id;
  String? nome;
  String? apelido;
  String cpf;
  String rg;
  String? telefone;
  String? celular;
  String? email;
  String? endereco;
  String? numero;
  String? complemento;
  String? bairro;
  String? cidade;
  int? cidadeId; // FK → TB_CIDADE.CID_ID
  String? cidadeNome; // nome da cidade (para exibição)
  String? cep;
  String? cnh;
  String? cnhValidade;
  String status; // 'A' = Ativo, 'I' = Inativo
  DateTime? dataCadastro;
  DateTime? dataAtualizacao;

  MotoristaModel({
    this.id,
    required this.nome,
    this.apelido,
    required this.cpf,
    required this.rg,
    this.telefone,
    this.celular,
    this.email,
    this.endereco,
    this.numero,
    this.complemento,
    this.bairro,
    this.cidade,
    this.cidadeId,
    this.cidadeNome,
    this.cep,
    this.cnh,
    this.cnhValidade,
    this.status = 'A',
    this.dataCadastro,
    this.dataAtualizacao,
  });

  factory MotoristaModel.fromJson(Map<String, dynamic> json) {
    return MotoristaModel(
      id: json['PES_ID'] as int?,
      nome: json['PES_RSOCIAL_NOME'] as String?,
      apelido: json['PES_FANTASIA_APELIDO'] as String?,
      cpf: json['PES_CNPJ_CPF'] as String? ?? '',
      rg: json['PES_IE_RG'] as String? ?? '',
      telefone: json['PES_TELEFONE'] as String?,
      celular: json['PES_CELULAR'] as String?,
      email: json['PES_EMAIL'] as String?,
      endereco: json['PES_ENDERECO'] as String?,
      numero: json['PES_NUMERO'] as String?,
      complemento: json['PES_COMPLEMENTO'] as String?,
      bairro: json['PES_BAIRRO'] as String?,
      cidade: json['PES_CIDADE'] as String?,
      cep: json['PES_CEP'] as String?,
      cnh: json['PES_CNH'] as String?,
      cnhValidade: json['PES_CNH_VALIDADE'] as String?,
      status: json['PES_STATUS'] as String? ?? 'A',
      dataCadastro: json['PES_DT_CADASTRO'] != null
          ? DateTime.tryParse(json['PES_DT_CADASTRO'] as String)
          : null,
      dataAtualizacao: json['PES_DT_ATUALIZACAO'] != null
          ? DateTime.tryParse(json['PES_DT_ATUALIZACAO'] as String)
          : null,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'PES_ID': id,
      'PES_RSOCIAL_NOME': nome,
      'PES_FANTASIA_APELIDO': apelido,
      'PES_CNPJ_CPF': cpf,
      'PES_IE_RG': rg,
      'PES_TELEFONE': telefone,
      'PES_CELULAR': celular,
      'PES_EMAIL': email,
      'PES_ENDERECO': endereco,
      'PES_NUMERO': numero,
      'PES_COMPLEMENTO': complemento,
      'PES_BAIRRO': bairro,
      'PES_CIDADE': cidade,
      'PES_CEP': cep,
      'PES_CNH': cnh,
      'PES_CNH_VALIDADE': cnhValidade,
      'PES_STATUS': status,
      'PES_DT_CADASTRO': dataCadastro?.toIso8601String(),
      'PES_DT_ATUALIZACAO': dataAtualizacao?.toIso8601String(),
    };
  }

  MotoristaModel copyWith({
    int? id,
    String? nome,
    String? apelido,
    String? cpf,
    String? rg,
    String? telefone,
    String? celular,
    String? email,
    String? endereco,
    String? numero,
    String? complemento,
    String? bairro,
    String? cidade,
    int? cidadeId,
    String? cidadeNome,
    String? cep,
    String? cnh,
    String? cnhValidade,
    String? status,
    DateTime? dataCadastro,
    DateTime? dataAtualizacao,
  }) {
    return MotoristaModel(
      id: id ?? this.id,
      nome: nome ?? this.nome,
      apelido: apelido ?? this.apelido,
      cpf: cpf ?? this.cpf,
      rg: rg ?? this.rg,
      telefone: telefone ?? this.telefone,
      celular: celular ?? this.celular,
      email: email ?? this.email,
      endereco: endereco ?? this.endereco,
      numero: numero ?? this.numero,
      complemento: complemento ?? this.complemento,
      bairro: bairro ?? this.bairro,
      cidade: cidade ?? this.cidade,
      cidadeId: cidadeId ?? this.cidadeId,
      cidadeNome: cidadeNome ?? this.cidadeNome,
      cep: cep ?? this.cep,
      cnh: cnh ?? this.cnh,
      cnhValidade: cnhValidade ?? this.cnhValidade,
      status: status ?? this.status,
      dataCadastro: dataCadastro ?? this.dataCadastro,
      dataAtualizacao: dataAtualizacao ?? this.dataAtualizacao,
    );
  }
}
