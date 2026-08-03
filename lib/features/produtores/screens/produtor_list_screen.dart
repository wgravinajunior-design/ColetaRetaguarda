import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:go_router/go_router.dart';
import '../viewmodels/produtor_viewmodel.dart';

class ProdutorListScreen extends StatefulWidget {
  const ProdutorListScreen({super.key});

  @override
  State<ProdutorListScreen> createState() => _ProdutorListScreenState();
}

class _ProdutorListScreenState extends State<ProdutorListScreen> {
  /// Um controlador para cada sentido, porque a barra de rolagem só se desenha
  /// antes da primeira rolagem quando sabe a posição (ver RolagemSempreVisivel).
  /// Com muitos produtores a lista passa da tela, e sem a barra não havia como
  /// perceber que existia mais coisa abaixo.
  final _rolagemVertical = ScrollController();
  final _rolagemHorizontal = ScrollController();

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      context.read<ProdutorViewModel>().loadProdutores();
    });
  }

  @override
  void dispose() {
    _rolagemVertical.dispose();
    _rolagemHorizontal.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final viewModel = context.watch<ProdutorViewModel>();

    return Scaffold(
      backgroundColor: const Color(0xFFF3F5F4),
      appBar: AppBar(
        title: const Text('Gestão de Produtores'),
        elevation: 0,
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh),
            tooltip: 'Atualizar',
            onPressed: () => viewModel.loadProdutores(),
          ),
        ],
      ),
      floatingActionButton: FloatingActionButton(
        onPressed: () => context.go('/produtores/novo'),
        tooltip: 'Novo produtor',
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

  Widget _buildFiltros(ProdutorViewModel viewModel) {
    const filtros = [('A', 'Ativos'), ('I', 'Inativos'), (null, 'Todos')];
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 12, 16, 4),
      child: Row(
        children: [
          Text(
            'Status',
            style: TextStyle(
              fontWeight: FontWeight.w600,
              fontSize: 12,
              color: Colors.grey[600],
            ),
          ),
          const SizedBox(width: 10),
          ...filtros.map((f) {
            final selecionado = viewModel.filtroStatus == f.$1;
            return Padding(
              padding: const EdgeInsets.only(right: 6),
              child: ChoiceChip(
                label: Text(f.$2, style: const TextStyle(fontSize: 12)),
                selected: selecionado,
                showCheckmark: false,
                visualDensity: VisualDensity.compact,
                padding: const EdgeInsets.symmetric(horizontal: 8),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(20),
                  side: BorderSide(
                    color: selecionado
                        ? Colors.green.shade700
                        : Colors.grey.shade300,
                  ),
                ),
                selectedColor: Colors.green.shade50,
                labelStyle: TextStyle(
                  color: selecionado
                      ? Colors.green.shade800
                      : Colors.grey[700],
                  fontWeight: selecionado ? FontWeight.w600 : FontWeight.w400,
                ),
                backgroundColor: Colors.white,
                onSelected: (_) => viewModel.aplicarFiltroStatus(f.$1),
              ),
            );
          }),
        ],
      ),
    );
  }

  Widget _buildBody(ProdutorViewModel viewModel) {
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
        child: Text(
          'Nenhum produtor encontrado.',
          style: TextStyle(color: Colors.grey[600], fontSize: 13),
        ),
      );
    }

    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 4, 16, 16),
      child: Card(
        elevation: 0,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(12),
          side: BorderSide(color: Colors.grey.shade200),
        ),
        clipBehavior: Clip.antiAlias,
        child: SingleChildScrollView(
          controller: _rolagemVertical,
          child: SingleChildScrollView(
            controller: _rolagemHorizontal,
            scrollDirection: Axis.horizontal,
            child: ConstrainedBox(
              constraints: BoxConstraints(
                minWidth: MediaQuery.of(context).size.width - 32,
              ),
              child: DataTable(
                headingRowHeight: 40,
                dataRowMinHeight: 40,
                dataRowMaxHeight: 44,
                horizontalMargin: 16,
                columnSpacing: 24,
                dividerThickness: 0.5,
                headingRowColor: WidgetStateProperty.all(
                  Colors.grey.shade50,
                ),
                headingTextStyle: TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.w600,
                  color: Colors.grey[700],
                ),
                dataTextStyle: const TextStyle(fontSize: 13),
                columns: const [
                  DataColumn(label: Text('ID')),
                  DataColumn(label: Text('Nome/Razão Social')),
                  DataColumn(label: Text('CPF/CNPJ')),
                  DataColumn(label: Text('Cidade')),
                  DataColumn(label: Text('Telefone')),
                  DataColumn(label: Text('Ações')),
                ],
                rows: viewModel.items.asMap().entries.map((entry) {
                  final index = entry.key;
                  final prod = entry.value;
                  return DataRow(
                    color: WidgetStateProperty.all(
                      index.isEven ? Colors.white : Colors.grey.shade50,
                    ),
                    cells: [
                      DataCell(
                        Text(
                          prod.id?.toString() ?? '-',
                          style: TextStyle(color: Colors.grey[600]),
                        ),
                      ),
                      DataCell(
                        Text(
                          prod.rSocialNome,
                          style: const TextStyle(fontWeight: FontWeight.w500),
                        ),
                      ),
                      DataCell(Text(prod.cnpjCpf)),
                      DataCell(Text(prod.bairro)),
                      DataCell(Text(prod.telefone)),
                      DataCell(
                        Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            IconButton(
                              icon: const Icon(Icons.edit_outlined, size: 18),
                              color: Colors.blueGrey[600],
                              visualDensity: VisualDensity.compact,
                              tooltip: 'Editar',
                              onPressed: () => context.go(
                                '/produtores/editar',
                                extra: prod,
                              ),
                            ),
                            IconButton(
                              icon: const Icon(
                                Icons.delete_outline,
                                size: 18,
                              ),
                              color: Colors.red[300],
                              visualDensity: VisualDensity.compact,
                              tooltip: 'Excluir',
                              onPressed: () async {
                                final messenger = ScaffoldMessenger.of(
                                  context,
                                );
                                final confirm = await showDialog<bool>(
                                  context: context,
                                  builder: (context) => AlertDialog(
                                    title: const Text('Excluir?'),
                                    content: Text(
                                      'Tem certeza que deseja excluir ${prod.rSocialNome}?',
                                    ),
                                    actions: [
                                      TextButton(
                                        onPressed: () =>
                                            Navigator.pop(context, false),
                                        child: const Text('Cancelar'),
                                      ),
                                      TextButton(
                                        onPressed: () =>
                                            Navigator.pop(context, true),
                                        child: const Text('Excluir'),
                                      ),
                                    ],
                                  ),
                                );
                                if (confirm == true && prod.id != null) {
                                  final ok = await viewModel.deleteProdutor(
                                    prod.id!,
                                  );
                                  if (!context.mounted) return;
                                  messenger.showSnackBar(
                                    SnackBar(
                                      content: Text(
                                        ok
                                            ? 'Produtor inativado.'
                                            : (viewModel.errorMessage ??
                                                  'Não foi possível excluir.'),
                                      ),
                                      backgroundColor: ok
                                          ? Colors.green
                                          : Colors.red,
                                    ),
                                  );
                                }
                              },
                            ),
                          ],
                        ),
                      ),
                    ],
                  );
                }).toList(),
              ),
            ),
          ),
        ),
      ),
    );
  }
}
