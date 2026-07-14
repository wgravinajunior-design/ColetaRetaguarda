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

  PessoaModel({
    this.id,
    required this.tipoPessoa,
    required this.rSocialNome,
    required this.fantasiaApelido,
    required this.cnpjCpf,
    required this.ieRg,
    required this.endereco,
    required this.numero,
    required this.complemento,
    required this.bairro,
    required this.cep,
    required this.telefone,
    required this.celular,
    required this.email,
    required this.contato,
    required this.referencia,
    required this.status,
    required this.cliente,
    required this.transportador,
    required this.contribuinte,
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
}
