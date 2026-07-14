class PessoaModel {
  int? id;
  String tipoPessoa;
  String rSocialNome;
  String fantasiaApelido;
  String cnpjCpf;
  String ieRg;
  String endereco;
  String numero;
  String complemento;
  String bairro;
  String cep;
  String telefone;
  String celular;
  String email;
  String contato;
  String referencia;
  String status;
  String cliente;
  String transportador;
  String contribuinte;
  // Campos de Coleta de Leite (produtor)
  double? latitude;
  double? longitude;
  String? horarioColeta; // "HH:mm"
  double? km;
  double? volumeMedio;
  int? resfriadorId;
  String? resfriadorNome;

  PessoaModel({
    this.id,
    required this.tipoPessoa,
    required this.rSocialNome,
    this.fantasiaApelido = '',
    required this.cnpjCpf,
    this.ieRg = '',
    this.endereco = '',
    this.numero = '',
    this.complemento = '',
    this.bairro = '',
    this.cep = '',
    this.telefone = '',
    this.celular = '',
    this.email = '',
    this.contato = '',
    this.referencia = '',
    this.status = 'A',
    this.cliente = 'N',
    this.transportador = 'N',
    this.contribuinte = 'N',
    this.latitude,
    this.longitude,
    this.horarioColeta,
    this.km,
    this.volumeMedio,
    this.resfriadorId,
    this.resfriadorNome,
  });

  factory PessoaModel.fromJson(Map<String, dynamic> json) {
    return PessoaModel(
      id: json['PES_ID'] as int?,
      tipoPessoa: json['PES_TIPO_PESSOA'] as String? ?? 'F',
      rSocialNome: json['PES_RSOCIAL_NOME'] as String? ?? '',
      fantasiaApelido: json['PES_FANTASIA_APELIDO'] as String? ?? '',
      cnpjCpf: json['PES_CNPJ_CPF'] as String? ?? '',
      ieRg: json['PES_IE_RG'] ?? json['PES_RG_IE'] ?? '',
      endereco: json['PES_ENDERECO'] as String? ?? '',
      numero: json['PES_NUMERO'] as String? ?? '',
      complemento: json['PES_COMPLEMENTO'] as String? ?? '',
      bairro: json['PES_BAIRRO'] as String? ?? '',
      cep: json['PES_CEP'] as String? ?? '',
      telefone: json['PES_TELEFONE'] as String? ?? '',
      celular: json['PES_CELULAR'] as String? ?? '',
      email: json['PES_EMAIL'] as String? ?? '',
      contato: json['PES_CONTATO'] as String? ?? '',
      referencia: json['PES_REFERENCIA'] as String? ?? '',
      status: json['PES_STATUS'] as String? ?? 'A',
      cliente: json['PES_CLIENTE'] as String? ?? 'N',
      transportador: json['PES_TRANSPORTADOR'] as String? ?? 'N',
      contribuinte: json['PES_CONTRIBUINTE'] as String? ?? 'N',
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'PES_ID': id,
      'PES_TIPO_PESSOA': tipoPessoa,
      'PES_RSOCIAL_NOME': rSocialNome,
      'PES_FANTASIA_APELIDO': fantasiaApelido,
      'PES_CNPJ_CPF': cnpjCpf,
      'PES_IE_RG': ieRg,
      'PES_ENDERECO': endereco,
      'PES_NUMERO': numero,
      'PES_COMPLEMENTO': complemento,
      'PES_BAIRRO': bairro,
      'PES_CEP': cep,
      'PES_TELEFONE': telefone,
      'PES_CELULAR': celular,
      'PES_EMAIL': email,
      'PES_CONTATO': contato,
      'PES_REFERENCIA': referencia,
      'PES_STATUS': status,
      'PES_CLIENTE': cliente,
      'PES_TRANSPORTADOR': transportador,
      'PES_CONTRIBUINTE': contribuinte,
    };
  }

  PessoaModel copyWith({
    int? id,
    String? tipoPessoa,
    String? rSocialNome,
    String? fantasiaApelido,
    String? cnpjCpf,
    String? ieRg,
    String? endereco,
    String? numero,
    String? complemento,
    String? bairro,
    String? cep,
    String? telefone,
    String? celular,
    String? email,
    String? contato,
    String? referencia,
    String? status,
    String? cliente,
    String? transportador,
    String? contribuinte,
    double? latitude,
    double? longitude,
    String? horarioColeta,
    double? km,
    double? volumeMedio,
    int? resfriadorId,
    String? resfriadorNome,
  }) {
    return PessoaModel(
      id: id ?? this.id,
      tipoPessoa: tipoPessoa ?? this.tipoPessoa,
      rSocialNome: rSocialNome ?? this.rSocialNome,
      fantasiaApelido: fantasiaApelido ?? this.fantasiaApelido,
      cnpjCpf: cnpjCpf ?? this.cnpjCpf,
      ieRg: ieRg ?? this.ieRg,
      endereco: endereco ?? this.endereco,
      numero: numero ?? this.numero,
      complemento: complemento ?? this.complemento,
      bairro: bairro ?? this.bairro,
      cep: cep ?? this.cep,
      telefone: telefone ?? this.telefone,
      celular: celular ?? this.celular,
      email: email ?? this.email,
      contato: contato ?? this.contato,
      referencia: referencia ?? this.referencia,
      status: status ?? this.status,
      cliente: cliente ?? this.cliente,
      transportador: transportador ?? this.transportador,
      contribuinte: contribuinte ?? this.contribuinte,
      latitude: latitude ?? this.latitude,
      longitude: longitude ?? this.longitude,
      horarioColeta: horarioColeta ?? this.horarioColeta,
      km: km ?? this.km,
      volumeMedio: volumeMedio ?? this.volumeMedio,
      resfriadorId: resfriadorId ?? this.resfriadorId,
      resfriadorNome: resfriadorNome ?? this.resfriadorNome,
    );
  }
}
