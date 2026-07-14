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
      appBar: AppBar(
        title: const Text('Fluxo de Caixa'),
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh),
            onPressed: () => viewModel.fetchMovimentos(),
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
                _buildDashboard(viewModel),
                Expanded(child: _buildList(viewModel)),
              ],
            ),
    );
  }

  Widget _buildDashboard(FinanceiroViewModel viewModel) {
    return Padding(
      padding: const EdgeInsets.all(16.0),
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
          const SizedBox(width: 16),
          Expanded(
            child: _SummaryCard(
              title: 'Despesas',
              value: viewModel.totalDespesas,
              color: Colors.red,
              icon: Icons.arrow_downward,
            ),
          ),
          const SizedBox(width: 16),
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
      return Center(child: Text(viewModel.errorMessage!, style: const TextStyle(color: Colors.red)));
    }
    if (viewModel.items.isEmpty) {
      return const Center(child: Text('Nenhum movimento encontrado.'));
    }

    return SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      child: SingleChildScrollView(
        child: ConstrainedBox(
          constraints: BoxConstraints(minWidth: MediaQuery.of(context).size.width),
          child: DataTable(
            columns: const [
              DataColumn(label: Text('ID')),
              DataColumn(label: Text('Data')),
              DataColumn(label: Text('Histórico')),
              DataColumn(label: Text('Conta')),
              DataColumn(label: Text('Tipo')),
              DataColumn(label: Text('Valor', textAlign: TextAlign.right)),
              DataColumn(label: Text('Status')),
              DataColumn(label: Text('Ações')),
            ],
            rows: viewModel.items.map((mov) {
              final isReceita = mov.tipo == 'C';
              return DataRow(cells: [
                DataCell(Text(mov.id?.toString() ?? '-')),
                DataCell(Text(mov.dtEmissao)),
                DataCell(Text(mov.historico)),
                DataCell(Text(mov.contaNome ?? 'Conta ${mov.conta}')),
                DataCell(
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                    decoration: BoxDecoration(
                      color: isReceita ? Colors.green.withOpacity(0.2) : Colors.red.withOpacity(0.2),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Text(
                      isReceita ? 'RECEITA' : 'DESPESA',
                      style: TextStyle(color: isReceita ? Colors.green[800] : Colors.red[800], fontWeight: FontWeight.bold),
                    ),
                  ),
                ),
                DataCell(Text(formatCurrency.format(mov.valor))),
                DataCell(Text(mov.status == 'P' ? 'Pendente' : (mov.status == 'C' ? 'Cancelado' : 'Finalizado'))),
                DataCell(Row(
                  children: [
                    IconButton(
                      icon: const Icon(Icons.delete, color: Colors.red),
                      onPressed: () async {
                        if (mov.id != null) {
                          final confirm = await showDialog<bool>(
                            context: context,
                            builder: (context) => AlertDialog(
                              title: const Text('Excluir?'),
                              content: const Text('Excluir este lançamento?'),
                              actions: [
                                TextButton(onPressed: () => Navigator.pop(context, false), child: const Text('Não')),
                                TextButton(onPressed: () => Navigator.pop(context, true), child: const Text('Sim')),
                              ],
                            ),
                          );
                          if (confirm == true) viewModel.deleteMovimento(mov.id!);
                        }
                      },
                    ),
                  ],
                )),
              ]);
            }).toList(),
          ),
        ),
      ),
    );
  }
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
    final formatCurrency = NumberFormat.currency(locale: 'pt_BR', symbol: 'R\$');
    
    return Card(
      elevation: 2,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: Padding(
        padding: const EdgeInsets.all(20.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(icon, color: color, size: 28),
                const SizedBox(width: 8),
                Text(title, style: TextStyle(color: Colors.grey[700], fontSize: 16, fontWeight: FontWeight.w500)),
              ],
            ),
            const SizedBox(height: 16),
            Text(
              formatCurrency.format(value),
              style: TextStyle(fontSize: 28, fontWeight: FontWeight.bold, color: color),
            ),
          ],
        ),
      ),
    );
  }
}
