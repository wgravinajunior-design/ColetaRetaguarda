class MovimentoModel {
  final int? id;
  final String tipo; // 'C' para Credito (Receita), 'D' para Debito (Despesa)
  final String status;
  final String compensado;
  final String origem;
  final int? idOrigem;
  final int conta;
  final String? contaNome;
  final double valor;
  final String dtEmissao;
  final String? dtAgendado;
  final String? dtCompensado;
  final String historico;
  final String? dtLancamento;

  MovimentoModel({
    this.id,
    required this.tipo,
    this.status = 'P',
    this.compensado = 'S',
    this.origem = 'MANUAL',
    this.idOrigem,
    this.conta = 1,
    this.contaNome,
    required this.valor,
    required this.dtEmissao,
    this.dtAgendado,
    this.dtCompensado,
    required this.historico,
    this.dtLancamento,
  });

  factory MovimentoModel.fromJson(Map<String, dynamic> json) {
    return MovimentoModel(
      id: json['mov_id'],
      tipo: json['mov_tipo'] ?? 'C',
      status: json['mov_status'] ?? 'P',
      compensado: json['mov_compensado'] ?? 'S',
      origem: json['mov_origem'] ?? '',
      idOrigem: json['mov_id_origem'],
      conta: json['mov_conta'] ?? 1,
      contaNome: json['conta_nome'],
      valor: (json['mov_valor'] ?? 0).toDouble(),
      dtEmissao: json['mov_dt_emissao'] ?? '',
      dtAgendado: json['mov_dt_agendado'],
      dtCompensado: json['mov_dt_compensado'],
      historico: json['mov_historico'] ?? '',
      dtLancamento: json['mov_dt_lancamento'],
    );
  }

  Map<String, dynamic> toJson() {
    return {
      if (id != null) 'mov_id': id,
      'mov_tipo': tipo,
      'mov_status': status,
      'mov_compensado': compensado,
      'mov_origem': origem,
      if (idOrigem != null) 'mov_id_origem': idOrigem,
      'mov_conta': conta,
      'mov_valor': valor,
      'mov_dt_emissao': dtEmissao,
      if (dtAgendado != null) 'mov_dt_agendado': dtAgendado,
      if (dtCompensado != null) 'mov_dt_compensado': dtCompensado,
      'mov_historico': historico,
    };
  }
}
