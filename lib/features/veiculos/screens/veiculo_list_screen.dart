import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:go_router/go_router.dart';
import '../viewmodels/veiculo_viewmodel.dart';

class VeiculoListScreen extends StatefulWidget {
  const VeiculoListScreen({super.key});

  @override
  State<VeiculoListScreen> createState() => _VeiculoListScreenState();
}

class _VeiculoListScreenState extends State<VeiculoListScreen> {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      context.read<VeiculoViewModel>().loadVeiculos();
    });
  }

  @override
  Widget build(BuildContext context) {
    final viewModel = context.watch<VeiculoViewModel>();

    return Scaffold(
      appBar: AppBar(
        title: const Text('Gestão de Veículos'),
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh),
            onPressed: () => viewModel.loadVeiculos(),
          ),
        ],
      ),
      floatingActionButton: FloatingActionButton(
        onPressed: () => context.go('/veiculos/novo'),
        child: const Icon(Icons.add),
      ),
      body: viewModel.isLoading
          ? const Center(child: CircularProgressIndicator())
          : _buildBody(viewModel),
    );
  }

  Widget _buildBody(VeiculoViewModel viewModel) {
    if (viewModel.errorMessage != null) {
      return Center(child: Text(viewModel.errorMessage!));
    }

    if (viewModel.items.isEmpty) {
      return const Center(child: Text('Nenhum veículo encontrado.'));
    }

    return ListView.builder(
      itemCount: viewModel.items.length,
      itemBuilder: (context, index) {
        final v = viewModel.items[index];
        return ListTile(
          title: Text(v.placa),
          subtitle: Text('${v.marca} ${v.modelo} - ${v.ano}'),
          trailing: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              IconButton(
                icon: const Icon(Icons.edit),
                onPressed: () => context.go('/veiculos/editar', extra: v),
              ),
              IconButton(
                icon: const Icon(Icons.delete),
                onPressed: () async {
                  if (await showDialog(
                    context: context,
                    builder: (c) => AlertDialog(
                      title: const Text('Confirmar'),
                      content: const Text('Deletar veículo?'),
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
                    if (v.id != null) viewModel.deleteVeiculo(v.id!);
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
