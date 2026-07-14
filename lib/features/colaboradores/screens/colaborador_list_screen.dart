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
      context.read<ColaboradorViewModel>().loadColaboradores();
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
            onPressed: () => viewModel.loadColaboradores(),
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

    if (viewModel.items.isEmpty) {
      return const Center(child: Text('Nenhum colaborador encontrado.'));
    }

    return ListView.builder(
      itemCount: viewModel.items.length,
      itemBuilder: (context, index) {
        final colab = viewModel.items[index];
        return ListTile(
          title: Text(colab.nome ?? '-'),
          subtitle: Text(colab.cpf),
          trailing: Row(
            mainAxisSize: MainAxisSize.min,
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
                    builder: (c) => AlertDialog(
                      title: const Text('Confirmar'),
                      content: const Text('Deletar colaborador?'),
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
                  );
                  if (confirm == true && colab.id != null) {
                    viewModel.deleteColaborador(colab.id!);
                  }
                },
              ),
            ],
          ),
        );
      },
    );
  }
}
