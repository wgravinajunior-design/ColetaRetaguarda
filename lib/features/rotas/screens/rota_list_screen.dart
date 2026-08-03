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
      backgroundColor: const Color(0xFFF3F5F4),
      appBar: AppBar(
        title: const Text('Gestão de Rotas'),
        elevation: 0,
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh),
            tooltip: 'Atualizar',
            onPressed: () => viewModel.loadRotas(),
          ),
        ],
      ),
      floatingActionButton: FloatingActionButton(
        onPressed: () => context.go('/rotas/novo'),
        tooltip: 'Nova rota',
        child: const Icon(Icons.add),
      ),
      body: Column(
        children: [
          _buildFiltros(viewModel),
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

    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 12, 16, 8),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: Colors.grey.shade200),
        ),
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
                style: const TextStyle(fontSize: 13, color: Colors.black87),
                decoration: InputDecoration(
                  labelText: 'Situação',
                  labelStyle: const TextStyle(fontSize: 12),
                  isDense: true,
                  contentPadding: const EdgeInsets.symmetric(
                    horizontal: 10,
                    vertical: 8,
                  ),
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(8),
                    borderSide: BorderSide(color: Colors.grey.shade300),
                  ),
                ),
                items: situacoes.entries
                    .map(
                      (e) => DropdownMenuItem(
                        value: e.key,
                        child: Text(e.value, style: const TextStyle(fontSize: 13)),
                      ),
                    )
                    .toList(),
                onChanged: vm.aplicarFiltroStatus,
              ),
            ),
            SizedBox(
              width: 150,
              child: OutlinedButton.icon(
                style: OutlinedButton.styleFrom(
                  visualDensity: VisualDensity.compact,
                  side: BorderSide(color: Colors.grey.shade300),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(8),
                  ),
                ),
                icon: const Icon(Icons.event, size: 15),
                label: Text(
                  'De: ${rotulo(vm.inicio)}',
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(fontSize: 12),
                ),
                onPressed: () => escolher(ehInicio: true),
              ),
            ),
            SizedBox(
              width: 150,
              child: OutlinedButton.icon(
                style: OutlinedButton.styleFrom(
                  visualDensity: VisualDensity.compact,
                  side: BorderSide(color: Colors.grey.shade300),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(8),
                  ),
                ),
                icon: const Icon(Icons.event, size: 15),
                label: Text(
                  'Até: ${rotulo(vm.fim)}',
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(fontSize: 12),
                ),
                onPressed: () => escolher(ehInicio: false),
              ),
            ),
            if (vm.inicio != null || vm.fim != null || vm.filtroStatus != null)
              TextButton.icon(
                style: TextButton.styleFrom(
                  visualDensity: VisualDensity.compact,
                ),
                icon: const Icon(Icons.filter_alt_off, size: 16),
                label: const Text('Limpar', style: TextStyle(fontSize: 12)),
                onPressed: () {
                  vm.aplicarPeriodo(null, null);
                  vm.aplicarFiltroStatus(null);
                },
              ),
          ],
        ),
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
      return Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.route_outlined, size: 56, color: Colors.grey[350]),
            const SizedBox(height: 12),
            Text(
              'Nenhuma rota encontrada.',
              style: TextStyle(color: Colors.grey[600], fontSize: 13),
            ),
          ],
        ),
      );
    }

    return ListView.builder(
      itemCount: viewModel.items.length,
      padding: const EdgeInsets.fromLTRB(16, 4, 16, 16),
      itemBuilder: (context, index) {
        final r = viewModel.items[index];
        return Card(
          elevation: 0,
          margin: const EdgeInsets.only(bottom: 8),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12),
            side: BorderSide(color: Colors.grey.shade200),
          ),
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 4),
            child: ListTile(
              visualDensity: VisualDensity.compact,
              title: Row(
                children: [
                  Expanded(
                    child: Text(
                      r.descricao,
                      style: const TextStyle(
                        fontWeight: FontWeight.w600,
                        fontSize: 14,
                      ),
                    ),
                  ),
                  _Etiqueta(status: r.status),
                ],
              ),
              subtitle: Text(
                '${_dataCurta(r.dataPrevista)} • '
                '${r.paradasFeitas ?? 0}/${r.paradas ?? 0} coletas • '
                '${r.kmEstimado?.toStringAsFixed(1) ?? '0'} km',
                style: const TextStyle(fontSize: 12),
              ),
              trailing: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  IconButton(
                    icon: const Icon(Icons.edit_outlined, size: 18),
                    color: Colors.blueGrey[600],
                    visualDensity: VisualDensity.compact,
                    tooltip: 'Editar',
                    onPressed: () => context.go('/rotas/editar', extra: r),
                  ),
                  IconButton(
                    icon: const Icon(Icons.delete_outline, size: 18),
                    color: Colors.red[300],
                    visualDensity: VisualDensity.compact,
                    tooltip: 'Excluir',
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
              onTap: () async {
                await Navigator.of(context).push(
                  MaterialPageRoute(
                    builder: (context) => RotaDetalheScreen(rota: r),
                  ),
                );
                // A rota pode ter sido finalizada ou reaberta lá dentro; sem
                // recarregar, a lista mostraria a situação anterior.
                if (context.mounted) viewModel.loadRotas();
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
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
      decoration: BoxDecoration(
        color: cor.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(20),
      ),
      child: Text(
        rotulo,
        style: TextStyle(fontSize: 11, color: cor, fontWeight: FontWeight.w600),
      ),
    );
  }
}
