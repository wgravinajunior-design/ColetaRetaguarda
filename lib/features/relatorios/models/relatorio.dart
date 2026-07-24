import 'package:flutter/material.dart';

/// Como um valor deve ser alinhado e formatado na tabela e no PDF.
enum TipoColuna { texto, numero, dinheiro, data }

class ColunaRelatorio {
  final String titulo;
  final TipoColuna tipo;

  /// Peso da coluna na largura total. Colunas de texto longo pedem mais.
  final int flex;

  const ColunaRelatorio(
    this.titulo, {
    this.tipo = TipoColuna.texto,
    this.flex = 1,
  });

  bool get alinhaDireita =>
      tipo == TipoColuna.numero || tipo == TipoColuna.dinheiro;
}

/// Resultado pronto para exibir e exportar.
///
/// Todos os relatórios produzem esta mesma estrutura, então uma única tela e um
/// único gerador de PDF atendem a todos — em vez de uma tela por relatório.
class ResultadoRelatorio {
  final List<ColunaRelatorio> colunas;
  final List<List<String>> linhas;

  /// Rodapé de totais: rótulo → valor já formatado.
  final Map<String, String> totais;

  /// Filtros aplicados, para constar no cabeçalho do PDF.
  final String descricaoFiltros;

  const ResultadoRelatorio({
    required this.colunas,
    required this.linhas,
    this.totais = const {},
    this.descricaoFiltros = '',
  });

  bool get vazio => linhas.isEmpty;
}

/// Filtros que um relatório aceita. A tela monta os controles a partir disto.
class FiltrosRelatorio {
  final bool periodo;
  final bool statusColeta;
  final bool statusRota;
  final bool conta;
  final bool tipoMovimento;
  final bool statusCadastro;

  const FiltrosRelatorio({
    this.periodo = false,
    this.statusColeta = false,
    this.statusRota = false,
    this.conta = false,
    this.tipoMovimento = false,
    this.statusCadastro = false,
  });
}

/// Valores escolhidos pelo usuário nos filtros.
class ValoresFiltro {
  DateTime? inicio;
  DateTime? fim;
  String? status;
  int? contaId;
  String? tipoMovimento;

  ValoresFiltro({
    this.inicio,
    this.fim,
    this.status,
    this.contaId,
    this.tipoMovimento,
  });
}

/// Definição de um relatório disponível no menu.
class DefinicaoRelatorio {
  final String id;
  final String nome;
  final String descricao;
  final IconData icone;
  final ModuloRelatorio modulo;
  final FiltrosRelatorio filtros;

  const DefinicaoRelatorio({
    required this.id,
    required this.nome,
    required this.descricao,
    required this.icone,
    required this.modulo,
    this.filtros = const FiltrosRelatorio(),
  });
}

enum ModuloRelatorio { coleta, financeiro, cadastros }

extension ModuloRelatorioX on ModuloRelatorio {
  String get titulo => switch (this) {
    ModuloRelatorio.coleta => 'Coleta',
    ModuloRelatorio.financeiro => 'Financeiro',
    ModuloRelatorio.cadastros => 'Cadastros',
  };

  IconData get icone => switch (this) {
    ModuloRelatorio.coleta => Icons.local_shipping,
    ModuloRelatorio.financeiro => Icons.attach_money,
    ModuloRelatorio.cadastros => Icons.folder_shared,
  };

  Color get cor => switch (this) {
    ModuloRelatorio.coleta => Colors.blue,
    ModuloRelatorio.financeiro => Colors.green,
    ModuloRelatorio.cadastros => Colors.deepPurple,
  };
}

/// Catálogo dos relatórios disponíveis.
const List<DefinicaoRelatorio> relatoriosDisponiveis = [
  // ── Coleta ────────────────────────────────────────────────────────────
  DefinicaoRelatorio(
    id: 'coletas_periodo',
    nome: 'Coletas por período',
    descricao: 'Cada coleta com volume, temperatura e situação',
    icone: Icons.list_alt,
    modulo: ModuloRelatorio.coleta,
    filtros: FiltrosRelatorio(periodo: true, statusColeta: true),
  ),
  DefinicaoRelatorio(
    id: 'producao_produtor',
    nome: 'Produção por produtor',
    descricao: 'Litros e temperatura média de cada produtor no período',
    icone: Icons.groups,
    modulo: ModuloRelatorio.coleta,
    filtros: FiltrosRelatorio(periodo: true),
  ),
  DefinicaoRelatorio(
    id: 'rotas_realizadas',
    nome: 'Rotas realizadas',
    descricao: 'Rotas com motorista, veículo, paradas e litros coletados',
    icone: Icons.route,
    modulo: ModuloRelatorio.coleta,
    filtros: FiltrosRelatorio(periodo: true, statusRota: true),
  ),
  DefinicaoRelatorio(
    id: 'qualidade_temperatura',
    nome: 'Alertas de temperatura',
    descricao: 'Coletas acima de 7°C, fora do padrão de conservação',
    icone: Icons.thermostat,
    modulo: ModuloRelatorio.coleta,
    filtros: FiltrosRelatorio(periodo: true),
  ),

  // ── Financeiro ────────────────────────────────────────────────────────
  DefinicaoRelatorio(
    id: 'movimentacoes',
    nome: 'Movimentações',
    descricao: 'Lançamentos do período com entradas, saídas e resultado',
    icone: Icons.swap_vert,
    modulo: ModuloRelatorio.financeiro,
    filtros: FiltrosRelatorio(periodo: true, conta: true, tipoMovimento: true),
  ),
  DefinicaoRelatorio(
    id: 'saldos_conta',
    nome: 'Saldos por conta',
    descricao: 'Posição atual de cada caixa e conta bancária',
    icone: Icons.account_balance_wallet,
    modulo: ModuloRelatorio.financeiro,
  ),
  DefinicaoRelatorio(
    id: 'resumo_plano_contas',
    nome: 'Resumo por plano de contas',
    descricao: 'Total movimentado em cada conta no período',
    icone: Icons.pie_chart,
    modulo: ModuloRelatorio.financeiro,
    filtros: FiltrosRelatorio(periodo: true),
  ),

  // ── Cadastros ─────────────────────────────────────────────────────────
  DefinicaoRelatorio(
    id: 'produtores',
    nome: 'Produtores',
    descricao: 'Cadastro com contato, volume médio e horário de coleta',
    icone: Icons.person_pin,
    modulo: ModuloRelatorio.cadastros,
    filtros: FiltrosRelatorio(statusCadastro: true),
  ),
  DefinicaoRelatorio(
    id: 'frota',
    nome: 'Motoristas e veículos',
    descricao: 'Frota com placa, CNH e situação',
    icone: Icons.badge,
    modulo: ModuloRelatorio.cadastros,
    filtros: FiltrosRelatorio(statusCadastro: true),
  ),
];
