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
      body: viewModel.isLoading
          ? const Center(child: CircularProgressIndicator())
          : _buildBody(viewModel),
    );
  }

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
              title: Text(r.descricao, style: const TextStyle(fontWeight: FontWeight.bold)),
              subtitle: Text('${r.paradas} paradas • ${r.kmEstimado?.toStringAsFixed(1) ?? '0'} km'),
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
                                content: Text(ok
                                    ? 'Rota excluída.'
                                    : (viewModel.errorMessage ?? 'Não foi possível excluir.')),
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
