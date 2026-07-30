/// Modelo de Pagamento Estruturado
/// Controla depósitos do laticínio e repassos aos produtores

class PagamentoModel {
  final int? id;
  final String tipo; // 'DEPOSITO' ou 'FOLHA_PAGAMENTO'
  final double valorTotal;
  final String dtPagamento;
  final String status; // 'P'=Pendente, 'C'=Confirmado
  final String? observacoes;
  final List<ItemPagamentoModel> itens;

  PagamentoModel({
    this.id,
    required this.tipo,
    required this.valorTotal,
    required this.dtPagamento,
    this.status = 'P',
    this.observacoes,
    this.itens = const [],
  });

  factory PagamentoModel.fromJson(Map<String, dynamic> json) {
    return PagamentoModel(
      id: json['pag_id'],
      tipo: json['pag_tipo'] ?? 'DEPOSITO',
      valorTotal: (json['pag_valor_total'] ?? 0).toDouble(),
      dtPagamento: json['pag_dt_pagamento'] ?? '',
      status: json['pag_status'] ?? 'P',
      observacoes: json['pag_observacoes'],
      itens: (json['itens'] as List?)
          ?.map((i) => ItemPagamentoModel.fromJson(i))
          .toList() ??
          [],
    );
  }

  Map<String, dynamic> toJson() {
    return {
      if (id != null) 'pag_id': id,
      'pag_tipo': tipo,
      'pag_valor_total': valorTotal,
      'pag_dt_pagamento': dtPagamento,
      'pag_status': status,
      if (observacoes != null) 'pag_observacoes': observacoes,
      'itens': itens.map((i) => i.toJson()).toList(),
    };
  }
}

/// Item de Pagamento (detalhe de cada produtor/desconto)
class ItemPagamentoModel {
  final int? id;
  final int pagamentoId;
  final int produtorId;
  final String produtorNome;
  final String tipoItem; // 'VALOR_LEITE' ou 'DESCONTO' ou 'REPASSE'
  final double valor;
  final String? descricao;

  ItemPagamentoModel({
    this.id,
    required this.pagamentoId,
    required this.produtorId,
    required this.produtorNome,
    required this.tipoItem,
    required this.valor,
    this.descricao,
  });

  factory ItemPagamentoModel.fromJson(Map<String, dynamic> json) {
    return ItemPagamentoModel(
      id: json['pag_item_id'],
      pagamentoId: json['pag_id'] ?? 0,
      produtorId: json['pes_id'] ?? 0,
      produtorNome: json['pes_nome'] ?? '',
      tipoItem: json['pag_item_tipo'] ?? 'VALOR_LEITE',
      valor: (json['pag_item_valor'] ?? 0).toDouble(),
      descricao: json['pag_item_descricao'],
    );
  }

  Map<String, dynamic> toJson() {
    return {
      if (id != null) 'pag_item_id': id,
      'pag_id': pagamentoId,
      'pes_id': produtorId,
      'pag_item_tipo': tipoItem,
      'pag_item_valor': valor,
      if (descricao != null) 'pag_item_descricao': descricao,
    };
  }

  double get valorPositivo => valor.abs();
}
