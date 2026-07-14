import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:go_router/go_router.dart';
import '../viewmodels/colaborador_viewmodel.dart';

class ColaboradorListScreen extends StatefulWidget {
  const ColaboradorListScreen({super.key});

  @override
  State<ColaboradorListScreen> createState() => _ColaboradorListScreenState();
}

class _ColaboradorListScreenState extends State<ColaboradorListScreen> {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      context.read<ColaboradorViewModel>().fetchColaboradores();
    });
  }

  @override
  Widget build(BuildContext context) {
    final viewModel = context.watch<ColaboradorViewModel>();

    return Scaffold(
      appBar: AppBar(
        title: const Text('Gestão de Colaboradores'),
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh),
            onPressed: () => viewModel.fetchColaboradores(),
          ),
        ],
      ),
      floatingActionButton: FloatingActionButton(
        onPressed: () => context.go('/colaboradores/novo'),
        child: const Icon(Icons.add),
      ),
      body: viewModel.isLoading
          ? const Center(child: CircularProgressIndicator())
          : _buildBody(viewModel),
    );
  }

  Widget _buildBody(ColaboradorViewModel viewModel) {
    if (viewModel.errorMessage != null) {
      return Center(
        child: Text(
          viewModel.errorMessage!,
          style: const TextStyle(color: Colors.red),
        ),
      );
    }

    if (viewModel.colaboradores.isEmpty) {
      return const Center(child: Text('Nenhum colaborador encontrado.'));
    }

    return SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      child: ConstrainedBox(
        constraints: BoxConstraints(minWidth: MediaQuery.of(context).size.width),
        child: DataTable(
          columns: const [
            DataColumn(label: Text('ID')),
            DataColumn(label: Text('Nome')),
            DataColumn(label: Text('CPF')),
            DataColumn(label: Text('Setor / Cargo')),
            DataColumn(label: Text('Status')),
            DataColumn(label: Text('Ações')),
          ],
          rows: viewModel.colaboradores.map((colab) {
            return DataRow(cells: [
              DataCell(Text(colab.id?.toString() ?? '-')),
              DataCell(Text(colab.rSocialNome)),
              DataCell(Text(colab.cnpjCpf)),
              DataCell(Text(colab.fantasiaApelido)), // Usado como cargo
              DataCell(Text(colab.status == 'A' ? 'Ativo' : 'Inativo')),
              DataCell(Row(
                children: [
                  IconButton(
                    icon: const Icon(Icons.edit, color: Colors.blue),
                    onPressed: () => context.go('/colaboradores/editar', extra: colab),
                  ),
                  IconButton(
                    icon: const Icon(Icons.delete, color: Colors.red),
                    onPressed: () async {
                      final confirm = await showDialog<bool>(
                        context: context,
                        builder: (context) => AlertDialog(
                          title: const Text('Excluir?'),
                          content: Text('Tem certeza que deseja excluir ${colab.rSocialNome}?'),
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
                      if (confirm == true && colab.id != null) {
                        viewModel.deleteColaborador(colab.id!);
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
