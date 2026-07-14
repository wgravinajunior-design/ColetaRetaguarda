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
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      context.read<ProdutorViewModel>().fetchProdutores();
    });
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
            onPressed: () => viewModel.fetchProdutores(),
          ),
        ],
      ),
      floatingActionButton: FloatingActionButton(
        onPressed: () => context.go('/produtores/novo'),
        child: const Icon(Icons.add),
      ),
      body: viewModel.isLoading
          ? const Center(child: CircularProgressIndicator())
          : _buildBody(viewModel),
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

    if (viewModel.produtores.isEmpty) {
      return const Center(child: Text('Nenhum produtor encontrado.'));
    }

    return SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      child: ConstrainedBox(
        constraints: BoxConstraints(minWidth: MediaQuery.of(context).size.width),
        child: DataTable(
          columns: const [
            DataColumn(label: Text('ID')),
            DataColumn(label: Text('Nome/Razão Social')),
            DataColumn(label: Text('CPF/CNPJ')),
            DataColumn(label: Text('Cidade')),
            DataColumn(label: Text('Telefone')),
            DataColumn(label: Text('Ações')),
          ],
          rows: viewModel.produtores.map((prod) {
            return DataRow(cells: [
              DataCell(Text(prod.id?.toString() ?? '-')),
              DataCell(Text(prod.rSocialNome)),
              DataCell(Text(prod.cnpjCpf)),
              DataCell(Text(prod.bairro)),
              DataCell(Text(prod.telefone)),
              DataCell(Row(
                children: [
                  IconButton(
                    icon: const Icon(Icons.edit, color: Colors.blue),
                    onPressed: () => context.go('/produtores/editar', extra: prod),
                  ),
                  IconButton(
                    icon: const Icon(Icons.delete, color: Colors.red),
                    onPressed: () async {
                      final confirm = await showDialog<bool>(
                        context: context,
                        builder: (context) => AlertDialog(
                          title: const Text('Excluir?'),
                          content: Text('Tem certeza que deseja excluir ${prod.rSocialNome}?'),
                          actions: [
                            TextButton(
                              onPressed: () => Navigator.pop(context, false),
                              child: const Text('Cancelar'),
                            ),
                            TextButton(
                              onPressed: () => Navigator.pop(context, true),
                              child: const Text('Excluir'),
                            ),
                          ],
                        ),
                      );
                      if (confirm == true && prod.id != null) {
                        viewModel.deleteProdutor(prod.id!);
                      }
                    },
                  ),
                ],
              )),
            ]);
          }).toList(),
        ),
      ),
    );
  }
}
