class ColaboradorModel {
  int? id;
  String? nome;
  String? apelido;
  String cpf;
  String? rg;
  String? funcao;
  String? telefone;
  String? celular;
  String? email;
  String? endereco;
  String? numero;
  String? bairro;
  String? cep;
  String status; // 'A' = Ativo, 'I' = Inativo
  DateTime? dataCadastro;
  DateTime? dataAtualizacao;

  ColaboradorModel({
    this.id,
    required this.nome,
    this.apelido,
    required this.cpf,
    this.rg,
    this.funcao,
    this.telefone,
    this.celular,
    this.email,
    this.endereco,
    this.numero,
    this.bairro,
    this.cep,
    this.status = 'A',
    this.dataCadastro,
    this.dataAtualizacao,
  });

  factory ColaboradorModel.fromJson(Map<String, dynamic> json) {
    return ColaboradorModel(
      id: json['PES_ID'] as int?,
      nome: json['PES_RSOCIAL_NOME'] as String?,
      apelido: json['PES_FANTASIA_APELIDO'] as String?,
      cpf: json['PES_CNPJ_CPF'] as String? ?? '',
      rg: json['PES_IE_RG'] as String?,
      funcao: json['PES_FUNCAO'] as String?,
      telefone: json['PES_TELEFONE'] as String?,
      celular: json['PES_CELULAR'] as String?,
      email: json['PES_EMAIL'] as String?,
      endereco: json['PES_ENDERECO'] as String?,
      numero: json['PES_NUMERO'] as String?,
      bairro: json['PES_BAIRRO'] as String?,
      cep: json['PES_CEP'] as String?,
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
      'PES_FUNCAO': funcao,
      'PES_TELEFONE': telefone,
      'PES_CELULAR': celular,
      'PES_EMAIL': email,
      'PES_ENDERECO': endereco,
      'PES_NUMERO': numero,
      'PES_BAIRRO': bairro,
      'PES_CEP': cep,
      'PES_STATUS': status,
      'PES_DT_CADASTRO': dataCadastro?.toIso8601String(),
      'PES_DT_ATUALIZACAO': dataAtualizacao?.toIso8601String(),
    };
  }

  ColaboradorModel copyWith({
    int? id,
    String? nome,
    String? apelido,
    String? cpf,
    String? rg,
    String? funcao,
    String? telefone,
    String? celular,
    String? email,
    String? endereco,
    String? numero,
    String? bairro,
    String? cep,
    String? status,
    DateTime? dataCadastro,
    DateTime? dataAtualizacao,
  }) {
    return ColaboradorModel(
      id: id ?? this.id,
      nome: nome ?? this.nome,
      apelido: apelido ?? this.apelido,
      cpf: cpf ?? this.cpf,
      rg: rg ?? this.rg,
      funcao: funcao ?? this.funcao,
      telefone: telefone ?? this.telefone,
      celular: celular ?? this.celular,
      email: email ?? this.email,
      endereco: endereco ?? this.endereco,
      numero: numero ?? this.numero,
      bairro: bairro ?? this.bairro,
      cep: cep ?? this.cep,
      status: status ?? this.status,
      dataCadastro: dataCadastro ?? this.dataCadastro,
      dataAtualizacao: dataAtualizacao ?? this.dataAtualizacao,
    );
  }
}
