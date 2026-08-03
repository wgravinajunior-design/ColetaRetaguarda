import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';
import '../viewmodels/financeiro_viewmodel.dart';

class FinanceiroListScreen extends StatefulWidget {
  const FinanceiroListScreen({super.key});

  @override
  State<FinanceiroListScreen> createState() => _FinanceiroListScreenState();
}

class _FinanceiroListScreenState extends State<FinanceiroListScreen> {
  final formatCurrency = NumberFormat.currency(locale: 'pt_BR', symbol: 'R\$');

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      context.read<FinanceiroViewModel>().loadMovimentos();
    });
  }

  @override
  Widget build(BuildContext context) {
    final viewModel = context.watch<FinanceiroViewModel>();

    return Scaffold(
      backgroundColor: const Color(0xFFF3F5F4),
      appBar: AppBar(
        title: const Text('Fluxo de Caixa'),
        elevation: 0,
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh),
            tooltip: 'Atualizar',
            onPressed: () => viewModel.loadMovimentos(),
          ),
        ],
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () => context.go('/financeiro/novo'),
        icon: const Icon(Icons.add),
        label: const Text('Novo Lançamento'),
      ),
      body: viewModel.isLoading
          ? const Center(child: CircularProgressIndicator())
          : Column(
              children: [
                _buildContaSelector(viewModel),
                _buildSaldosPorConta(viewModel),
                _buildDashboard(viewModel),
                Expanded(child: _buildList(viewModel)),
              ],
            ),
    );
  }

  Widget _buildSaldosPorConta(FinanceiroViewModel viewModel) {
    if (viewModel.saldos.isEmpty) return const SizedBox.shrink();
    return SizedBox(
      height: 84,
      child: ListView.separated(
        scrollDirection: Axis.horizontal,
        padding: const EdgeInsets.fromLTRB(16, 8, 16, 4),
        itemCount: viewModel.saldos.length,
        separatorBuilder: (_, _) => const SizedBox(width: 10),
        itemBuilder: (context, i) {
          final s = viewModel.saldos[i];
          final cor = s.isBanco ? Colors.indigo : Colors.teal;
          final saldoNeg = s.saldo < 0;
          return Container(
            width: 168,
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(10),
              border: Border.all(color: Colors.grey.shade200),
            ),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisAlignment: MainAxisAlignment.spaceEvenly,
              children: [
                Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(
                      s.isBanco ? Icons.account_balance : Icons.point_of_sale,
                      size: 13,
                      color: cor,
                    ),
                    const SizedBox(width: 4),
                    Flexible(
                      child: Text(
                        s.descricao,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(
                          fontWeight: FontWeight.w600,
                          fontSize: 11,
                        ),
                      ),
                    ),
                  ],
                ),
                Text(
                  s.isBanco ? 'Banco' : 'Caixa',
                  style: TextStyle(fontSize: 9, color: Colors.grey[500]),
                ),
                Text(
                  formatCurrency.format(s.saldo),
                  style: TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.bold,
                    color: saldoNeg ? Colors.red : Colors.green[800],
                  ),
                ),
              ],
            ),
          );
        },
      ),
    );
  }

  Widget _buildContaSelector(FinanceiroViewModel viewModel) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 12, 16, 0),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(10),
          border: Border.all(color: Colors.grey.shade200),
        ),
        child: Row(
          children: [
            Icon(Icons.account_balance, size: 18, color: Colors.grey[600]),
            const SizedBox(width: 8),
            Text(
              'Conta',
              style: TextStyle(
                fontWeight: FontWeight.w600,
                fontSize: 12,
                color: Colors.grey[600],
              ),
            ),
            const SizedBox(width: 8),
            Expanded(
              child: DropdownButtonFormField<int?>(
                initialValue: viewModel.contaFiltro,
                isExpanded: true,
                style: const TextStyle(fontSize: 13, color: Colors.black87),
                decoration: const InputDecoration(
                  border: InputBorder.none,
                  isDense: true,
                  contentPadding: EdgeInsets.symmetric(vertical: 10),
                ),
                items: [
                  const DropdownMenuItem<int?>(
                    value: null,
                    child: Text('Todas as contas'),
                  ),
                  ...viewModel.contas.map(
                    (c) => DropdownMenuItem<int?>(
                      value: c.id,
                      child: Row(
                        children: [
                          Icon(
                            c.isBanco
                                ? Icons.account_balance
                                : Icons.point_of_sale,
                            size: 16,
                            color: c.isBanco ? Colors.indigo : Colors.teal,
                          ),
                          const SizedBox(width: 6),
                          Flexible(
                            child: Text(
                              c.descricao,
                              overflow: TextOverflow.ellipsis,
                            ),
                          ),
                          const SizedBox(width: 6),
                          Text(
                            '(${c.isBanco ? 'Banco' : 'Caixa'})',
                            style: TextStyle(
                              fontSize: 11,
                              color: Colors.grey[600],
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ],
                onChanged: (v) => viewModel.aplicarFiltroConta(v),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildDashboard(FinanceiroViewModel viewModel) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 12, 16, 4),
      child: Row(
        children: [
          Expanded(
            child: _SummaryCard(
              title: 'Receitas',
              value: viewModel.totalReceitas,
              color: Colors.green,
              icon: Icons.arrow_upward,
            ),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: _SummaryCard(
              title: 'Despesas',
              value: viewModel.totalDespesas,
              color: Colors.red,
              icon: Icons.arrow_downward,
            ),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: _SummaryCard(
              title: 'Saldo Final',
              value: viewModel.saldoFinal,
              color: viewModel.saldoFinal >= 0 ? Colors.blue : Colors.orange,
              icon: Icons.account_balance_wallet,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildList(FinanceiroViewModel viewModel) {
    if (viewModel.errorMessage != null) {
      return Center(
        child: Text(
          viewModel.errorMessage!,
          style: const TextStyle(color: Colors.red),
        ),
      );
    }
    if (viewModel.items.isEmpty) {
      return Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              Icons.receipt_long_outlined,
              size: 56,
              color: Colors.grey[350],
            ),
            const SizedBox(height: 12),
            Text(
              'Nenhum movimento encontrado.',
              style: TextStyle(color: Colors.grey[600], fontSize: 13),
            ),
          ],
        ),
      );
    }

    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 8, 16, 16),
      child: Card(
        elevation: 0,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(12),
          side: BorderSide(color: Colors.grey.shade200),
        ),
        clipBehavior: Clip.antiAlias,
        child: Column(
          children: [
            _linhaTabela(
              isCabecalho: true,
              celulas: const [
                _CelulaTabela('Data', flex: 2),
                _CelulaTabela('Histórico', flex: 4),
                _CelulaTabela('Conta', flex: 2),
                _CelulaTabela('Tipo', flex: 2),
                _CelulaTabela('Valor', flex: 2),
                _CelulaTabela('Status', flex: 2),
              ],
            ),
            Expanded(
              child: ListView.builder(
                itemCount: viewModel.items.length,
                itemBuilder: (context, index) {
                  final mov = viewModel.items[index];
                  final isReceita = mov.tipo == 'C';
                  final corTipo = isReceita ? Colors.green : Colors.red;
                  final statusLabel = mov.status == 'P'
                      ? 'Pendente'
                      : (mov.status == 'C' ? 'Cancelado' : 'Finalizado');
                  final corStatus = mov.status == 'P'
                      ? Colors.orange
                      : (mov.status == 'C' ? Colors.grey : Colors.blue);

                  return Container(
                    color: index.isEven ? Colors.white : Colors.grey.shade50,
                    child: _linhaTabela(
                      celulas: [
                        _CelulaTabela(mov.dtEmissao, flex: 2),
                        _CelulaTabela(
                          mov.historico,
                          flex: 4,
                          peso: FontWeight.w500,
                        ),
                        _CelulaTabela(
                          mov.contaNome ?? 'Conta ${mov.conta}',
                          flex: 2,
                          cor: Colors.grey[600],
                        ),
                        _CelulaTabela.chip(
                          isReceita ? 'RECEITA' : 'DESPESA',
                          corTipo,
                          flex: 2,
                        ),
                        _CelulaTabela(
                          formatCurrency.format(mov.valor),
                          flex: 2,
                          peso: FontWeight.w600,
                          cor: corTipo.shade700,
                        ),
                        _CelulaTabela.chip(statusLabel, corStatus, flex: 2),
                      ],
                      acoes: IconButton(
                        icon: const Icon(Icons.delete_outline, size: 18),
                        color: Colors.red[300],
                        visualDensity: VisualDensity.compact,
                        tooltip: 'Excluir',
                        onPressed: () async {
                          if (mov.id != null) {
                            final confirm = await showDialog<bool>(
                              context: context,
                              builder: (context) => AlertDialog(
                                title: const Text('Excluir?'),
                                content: const Text(
                                  'Excluir este lançamento?',
                                ),
                                actions: [
                                  TextButton(
                                    onPressed: () =>
                                        Navigator.pop(context, false),
                                    child: const Text('Não'),
                                  ),
                                  TextButton(
                                    onPressed: () =>
                                        Navigator.pop(context, true),
                                    child: const Text('Sim'),
                                  ),
                                ],
                              ),
                            );
                            if (confirm == true) {
                              viewModel.deleteMovimento(mov.id!);
                            }
                          }
                        },
                      ),
                    ),
                  );
                },
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _linhaTabela({
    required List<_CelulaTabela> celulas,
    Widget? acoes,
    bool isCabecalho = false,
  }) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
      decoration: BoxDecoration(
        color: isCabecalho ? Colors.grey.shade50 : null,
        border: Border(
          bottom: BorderSide(
            color: Colors.grey.shade200,
            width: isCabecalho ? 1 : 0.5,
          ),
        ),
      ),
      child: Row(
        children: [
          for (final celula in celulas)
            Expanded(
              flex: celula.flex,
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 4),
                child: isCabecalho
                    ? Text(
                        celula.texto,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(
                          fontSize: 12,
                          fontWeight: FontWeight.w600,
                          color: Colors.grey[700],
                        ),
                      )
                    : celula.isChip
                    ? Align(
                        alignment: Alignment.centerLeft,
                        child: Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 8,
                            vertical: 2,
                          ),
                          decoration: BoxDecoration(
                            color: celula.corChip!.withValues(alpha: 0.1),
                            borderRadius: BorderRadius.circular(20),
                          ),
                          child: Text(
                            celula.texto,
                            style: TextStyle(
                              fontSize: 10,
                              fontWeight: FontWeight.w600,
                              color: celula.corChip!.shade700,
                            ),
                          ),
                        ),
                      )
                    : Text(
                        celula.texto,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(
                          fontSize: 13,
                          fontWeight: celula.peso,
                          color: celula.cor,
                        ),
                      ),
              ),
            ),
          SizedBox(
            width: 40,
            child: isCabecalho
                ? const SizedBox.shrink()
                : (acoes ?? const SizedBox.shrink()),
          ),
        ],
      ),
    );
  }
}

class _CelulaTabela {
  final String texto;
  final int flex;
  final Color? cor;
  final FontWeight? peso;
  final MaterialColor? corChip;

  const _CelulaTabela(this.texto, {required this.flex, this.cor, this.peso})
    : corChip = null;

  const _CelulaTabela.chip(this.texto, this.corChip, {required this.flex})
    : cor = null,
      peso = null;

  bool get isChip => corChip != null;
}

class _SummaryCard extends StatelessWidget {
  final String title;
  final double value;
  final Color color;
  final IconData icon;

  const _SummaryCard({
    required this.title,
    required this.value,
    required this.color,
    required this.icon,
  });

  @override
  Widget build(BuildContext context) {
    final formatCurrency = NumberFormat.currency(
      locale: 'pt_BR',
      symbol: 'R\$',
    );

    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.grey.shade200),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                padding: const EdgeInsets.all(6),
                decoration: BoxDecoration(
                  color: color.withValues(alpha: 0.1),
                  shape: BoxShape.circle,
                ),
                child: Icon(icon, color: color, size: 16),
              ),
              const SizedBox(width: 8),
              Flexible(
                child: Text(
                  title,
                  style: TextStyle(
                    color: Colors.grey[600],
                    fontSize: 12,
                    fontWeight: FontWeight.w500,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          Text(
            formatCurrency.format(value),
            style: TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.bold,
              color: color,
            ),
          ),
        ],
      ),
    );
  }
}
