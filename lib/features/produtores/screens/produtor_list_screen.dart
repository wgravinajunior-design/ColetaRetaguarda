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
      appBar: AppBar(
        title: const Text('Gestão de Produtores'),
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh),
            onPressed: () => viewModel.loadProdutores(),
          ),
        ],
      ),
      floatingActionButton: FloatingActionButton(
        onPressed: () => context.go('/produtores/novo'),
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

  Widget _buildFiltros(ProdutorViewModel viewModel) {
    const filtros = [('A', 'Ativos'), ('I', 'Inativos'), (null, 'Todos')];
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      child: Row(
        children: [
          const Text('Status: ', style: TextStyle(fontWeight: FontWeight.w500)),
          const SizedBox(width: 8),
          ...filtros.map((f) {
            final selecionado = viewModel.filtroStatus == f.$1;
            return Padding(
              padding: const EdgeInsets.symmetric(horizontal: 4),
              child: ChoiceChip(
                label: Text(f.$2),
                selected: selecionado,
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
      return const Center(child: Text('Nenhum produtor encontrado.'));
    }

    return SingleChildScrollView(
      controller: _rolagemVertical,
      child: SingleChildScrollView(
        controller: _rolagemHorizontal,
        scrollDirection: Axis.horizontal,
        child: ConstrainedBox(
          constraints: BoxConstraints(
            minWidth: MediaQuery.of(context).size.width,
          ),
          child: DataTable(
            columns: const [
              DataColumn(label: Text('ID')),
              DataColumn(label: Text('Nome/Razão Social')),
              DataColumn(label: Text('CPF/CNPJ')),
              DataColumn(label: Text('Cidade')),
              DataColumn(label: Text('Telefone')),
              DataColumn(label: Text('Ações')),
            ],
            rows: viewModel.items.map((prod) {
              return DataRow(
                cells: [
                  DataCell(Text(prod.id?.toString() ?? '-')),
                  DataCell(Text(prod.rSocialNome)),
                  DataCell(Text(prod.cnpjCpf)),
                  DataCell(Text(prod.bairro)),
                  DataCell(Text(prod.telefone)),
                  DataCell(
                    Row(
                      children: [
                        IconButton(
                          icon: const Icon(Icons.edit, color: Colors.blue),
                          onPressed: () =>
                              context.go('/produtores/editar', extra: prod),
                        ),
                        IconButton(
                          icon: const Icon(Icons.delete, color: Colors.red),
                          onPressed: () async {
                            final messenger = ScaffoldMessenger.of(context);
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
    );
  }
}
