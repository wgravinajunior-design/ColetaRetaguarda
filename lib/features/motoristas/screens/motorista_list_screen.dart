import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:go_router/go_router.dart';
import '../viewmodels/motorista_viewmodel.dart';

class MotoristaListScreen extends StatefulWidget {
  const MotoristaListScreen({super.key});

  @override
  State<MotoristaListScreen> createState() => _MotoristaListScreenState();
}

class _MotoristaListScreenState extends State<MotoristaListScreen> {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      context.read<MotoristaViewModel>().loadMotoristas();
    });
  }

  @override
  Widget build(BuildContext context) {
    final viewModel = context.watch<MotoristaViewModel>();

    return Scaffold(
      appBar: AppBar(
        title: const Text('Gestão de Motoristas'),
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh),
            onPressed: () => viewModel.loadMotoristas(),
          ),
        ],
      ),
      floatingActionButton: FloatingActionButton(
        onPressed: () => context.go('/motoristas/novo'),
        child: const Icon(Icons.add),
      ),
      body: viewModel.isLoading
          ? const Center(child: CircularProgressIndicator())
          : _buildBody(viewModel),
    );
  }

  Widget _buildBody(MotoristaViewModel viewModel) {
    if (viewModel.errorMessage != null) {
      return Center(
        child: Text(
          viewModel.errorMessage!,
          style: const TextStyle(color: Colors.red),
        ),
      );
    }

    if (viewModel.items.isEmpty) {
      return const Center(child: Text('Nenhum motorista encontrado.'));
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
            DataColumn(label: Text('Celular')),
            DataColumn(label: Text('Status')),
            DataColumn(label: Text('Ações')),
          ],
          rows: viewModel.items.map((mot) {
            return DataRow(cells: [
              DataCell(Text(mot.id?.toString() ?? '-')),
              DataCell(Text(mot.nome ?? '-')),
              DataCell(Text(mot.cpf)),
              DataCell(Text(mot.celular ?? '-')),
              DataCell(Text(mot.status == 'A' ? 'Ativo' : 'Inativo')),
              DataCell(Row(
                children: [
                  IconButton(
                    icon: const Icon(Icons.edit, color: Colors.blue),
                    onPressed: () => context.go('/motoristas/editar', extra: mot),
                  ),
                  IconButton(
                    icon: const Icon(Icons.delete, color: Colors.red),
                    onPressed: () async {
                      final confirm = await showDialog<bool>(
                        context: context,
                        builder: (context) => AlertDialog(
                          title: const Text('Excluir?'),
                          content: Text('Tem certeza que deseja excluir ${mot.nome}?'),
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
                      if (confirm == true && mot.id != null) {
                        viewModel.deleteMotorista(mot.id!);
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
