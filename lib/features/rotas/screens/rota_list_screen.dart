import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:go_router/go_router.dart';
import '../viewmodels/rota_viewmodel.dart';
import 'rota_detalhe_screen.dart';

class RotaListScreen extends StatefulWidget {
  const RotaListScreen({super.key});

  @override
  State<RotaListScreen> createState() => _RotaListScreenState();
}

class _RotaListScreenState extends State<RotaListScreen> {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      context.read<RotaViewModel>().loadRotas();
    });
  }

  @override
  Widget build(BuildContext context) {
    final viewModel = context.watch<RotaViewModel>();

    return Scaffold(
      appBar: AppBar(
        title: const Text('Gestão de Rotas'),
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh),
            onPressed: () => viewModel.loadRotas(),
          ),
        ],
      ),
      floatingActionButton: FloatingActionButton(
        onPressed: () => context.go('/rotas/novo'),
        child: const Icon(Icons.add),
      ),
      body: Column(
        children: [
          _buildFiltros(viewModel),
          const Divider(height: 1),
          Expanded(
            child: viewModel.isLoading
                ? const Center(child: CircularProgressIndicator())
                : _buildBody(viewModel),
          ),
        ],
      ),
    );
  }

  /// Recorte por situação e por data da rota.
  Widget _buildFiltros(RotaViewModel vm) {
    const situacoes = {
      null: 'Todas',
      'PENDENTE': 'Pendentes',
      'EM_ANDAMENTO': 'Em andamento',
      'CONCLUIDA': 'Concluídas',
    };

    String rotulo(DateTime? d) {
      if (d == null) return '—';
      final hoje = DateTime.now();
      if (d.year == hoje.year && d.month == hoje.month && d.day == hoje.day) {
        return 'Hoje';
      }
      String dois(int n) => n.toString().padLeft(2, '0');
      return '${dois(d.day)}/${dois(d.month)}/${d.year}';
    }

    Future<void> escolher({required bool ehInicio}) async {
      final hoje = DateTime.now();
      final d = await showDatePicker(
        context: context,
        initialDate: (ehInicio ? vm.inicio : vm.fim) ?? hoje,
        firstDate: DateTime(hoje.year - 5),
        lastDate: DateTime(hoje.year + 1),
      );
      if (d == null) return;
      vm.aplicarPeriodo(ehInicio ? d : vm.inicio, ehInicio ? vm.fim : d);
    }

    return Container(
      color: Colors.grey.shade50,
      padding: const EdgeInsets.fromLTRB(12, 10, 12, 10),
      child: Wrap(
        spacing: 8,
        runSpacing: 8,
        crossAxisAlignment: WrapCrossAlignment.center,
        children: [
          SizedBox(
            width: 190,
            child: DropdownButtonFormField<String?>(
              initialValue: vm.filtroStatus,
              isExpanded: true,
              decoration: const InputDecoration(
                labelText: 'Situação',
                isDense: true,
                contentPadding: EdgeInsets.symmetric(
                  horizontal: 10,
                  vertical: 10,
                ),
                border: OutlineInputBorder(),
              ),
              items: situacoes.entries
                  .map(
                    (e) => DropdownMenuItem(value: e.key, child: Text(e.value)),
                  )
                  .toList(),
              onChanged: vm.aplicarFiltroStatus,
            ),
          ),
          SizedBox(
            width: 160,
            child: OutlinedButton.icon(
              icon: const Icon(Icons.event, size: 15),
              label: Text(
                'De: ${rotulo(vm.inicio)}',
                overflow: TextOverflow.ellipsis,
              ),
              onPressed: () => escolher(ehInicio: true),
            ),
          ),
          SizedBox(
            width: 160,
            child: OutlinedButton.icon(
              icon: const Icon(Icons.event, size: 15),
              label: Text(
                'Até: ${rotulo(vm.fim)}',
                overflow: TextOverflow.ellipsis,
              ),
              onPressed: () => escolher(ehInicio: false),
            ),
          ),
          if (vm.inicio != null || vm.fim != null || vm.filtroStatus != null)
            TextButton.icon(
              icon: const Icon(Icons.filter_alt_off, size: 16),
              label: const Text('Limpar'),
              onPressed: () {
                vm.aplicarPeriodo(null, null);
                vm.aplicarFiltroStatus(null);
              },
            ),
        ],
      ),
    );
  }

  /// Cor e rótulo da situação, no vocabulário que o ERP grava.
  static (String, Color) _situacao(String status) => switch (status) {
    'CONCLUIDA' => ('Concluída', Colors.green),
    'EM_ANDAMENTO' => ('Em andamento', Colors.orange),
    'PENDENTE' => ('Pendente', Colors.blueGrey),
    _ => (status, Colors.grey),
  };

  Widget _buildBody(RotaViewModel viewModel) {
    if (viewModel.errorMessage != null) {
      return Center(child: Text(viewModel.errorMessage!));
    }

    if (viewModel.items.isEmpty) {
      return const Center(child: Text('Nenhuma rota encontrada.'));
    }

    return ListView.builder(
      itemCount: viewModel.items.length,
      padding: const EdgeInsets.all(8),
      itemBuilder: (context, index) {
        final r = viewModel.items[index];
        return Card(
          child: Padding(
            padding: const EdgeInsets.all(8),
            child: ListTile(
              title: Row(
                children: [
                  Expanded(
                    child: Text(
                      r.descricao,
                      style: const TextStyle(fontWeight: FontWeight.bold),
                    ),
                  ),
                  _Etiqueta(status: r.status),
                ],
              ),
              subtitle: Text(
                '${_dataCurta(r.dataPrevista)} • '
                '${r.paradasFeitas ?? 0}/${r.paradas ?? 0} coletas • '
                '${r.kmEstimado?.toStringAsFixed(1) ?? '0'} km',
              ),
              trailing: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  IconButton(
                    icon: const Icon(Icons.edit),
                    onPressed: () => context.go('/rotas/editar', extra: r),
                  ),
                  IconButton(
                    icon: const Icon(Icons.delete),
                    onPressed: () async {
                      if (await showDialog(
                        context: context,
                        builder: (c) => AlertDialog(
                          title: const Text('Confirmar'),
                          content: const Text('Deletar rota?'),
                          actions: [
                            TextButton(
                              onPressed: () => Navigator.pop(c, false),
                              child: const Text('Cancelar'),
                            ),
                            TextButton(
                              onPressed: () => Navigator.pop(c, true),
                              child: const Text('Deletar'),
                            ),
                          ],
                        ),
                      )) {
                        if (r.id != null) {
                          final ok = await viewModel.deleteRota(r.id!);
                          if (context.mounted) {
                            ScaffoldMessenger.of(context).showSnackBar(
                              SnackBar(
                                content: Text(
                                  ok
                                      ? 'Rota excluída.'
                                      : (viewModel.errorMessage ??
                                            'Não foi possível excluir.'),
                                ),
                                backgroundColor: ok ? Colors.green : Colors.red,
                              ),
                            );
                          }
                        }
                      }
                    },
                  ),
                ],
              ),
              onTap: () {
                Navigator.of(context).push(
                  MaterialPageRoute(
                    builder: (context) => RotaDetalheScreen(rota: r),
                  ),
                );
              },
            ),
          ),
        );
      },
    );
  }
}

/// Data da rota em formato curto; a base devolve texto ISO.
String _dataCurta(String? iso) {
  if (iso == null || iso.isEmpty) return 'sem data';
  final d = DateTime.tryParse(iso);
  if (d == null) return iso.split(' ').first;
  String dois(int n) => n.toString().padLeft(2, '0');
  return '${dois(d.day)}/${dois(d.month)}/${d.year}';
}

/// Etiqueta colorida com a situação da rota.
class _Etiqueta extends StatelessWidget {
  const _Etiqueta({required this.status});

  final String status;

  @override
  Widget build(BuildContext context) {
    final (rotulo, cor) = _RotaListScreenState._situacao(status);
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 3),
      decoration: BoxDecoration(
        color: cor.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: cor.withValues(alpha: 0.4)),
      ),
      child: Text(
        rotulo,
        style: TextStyle(fontSize: 11, color: cor, fontWeight: FontWeight.w600),
      ),
    );
  }
}
