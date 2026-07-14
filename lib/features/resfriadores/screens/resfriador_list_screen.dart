import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:go_router/go_router.dart';
import '../viewmodels/resfriador_viewmodel.dart';

class ResfriadorListScreen extends StatefulWidget {
  const ResfriadorListScreen({super.key});

  @override
  State<ResfriadorListScreen> createState() => _ResfriadorListScreenState();
}

class _ResfriadorListScreenState extends State<ResfriadorListScreen> {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      context.read<ResfriadorViewModel>().load();
    });
  }

  Color _corStatus(String s) {
    switch (s.toUpperCase()) {
      case 'ATIVO':
        return Colors.green;
      case 'MANUTENCAO':
        return Colors.orange;
      default:
        return Colors.grey;
    }
  }

  @override
  Widget build(BuildContext context) {
    final vm = context.watch<ResfriadorViewModel>();
    return Scaffold(
      appBar: AppBar(
        title: const Text('Resfriadores'),
        actions: [
          IconButton(icon: const Icon(Icons.refresh), onPressed: () => vm.load()),
        ],
      ),
      floatingActionButton: FloatingActionButton(
        onPressed: () => context.go('/resfriadores/novo'),
        child: const Icon(Icons.add),
      ),
      body: vm.isLoading
          ? const Center(child: CircularProgressIndicator())
          : vm.errorMessage != null
              ? Center(child: Text(vm.errorMessage!, style: const TextStyle(color: Colors.red)))
              : vm.items.isEmpty
                  ? const Center(child: Text('Nenhum resfriador cadastrado.'))
                  : ListView.separated(
                      padding: const EdgeInsets.all(8),
                      itemCount: vm.items.length,
                      separatorBuilder: (_, _) => const SizedBox(height: 4),
                      itemBuilder: (context, i) {
                        final r = vm.items[i];
                        final cor = _corStatus(r.status);
                        return Card(
                          child: ListTile(
                            leading: CircleAvatar(
                              backgroundColor: cor.withValues(alpha: 0.15),
                              child: Icon(Icons.ac_unit, color: cor),
                            ),
                            title: Text('${r.numeroId} • ${r.marcaModelo}',
                                style: const TextStyle(fontWeight: FontWeight.bold)),
                            subtitle: Text(
                                '${r.capacidadeLitros.toStringAsFixed(0)} L'
                                '${r.anoFabricacao != null ? ' • ${r.anoFabricacao}' : ''} • ${r.status}'),
                            trailing: Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                IconButton(
                                  icon: const Icon(Icons.edit, color: Colors.blue),
                                  onPressed: () => context.go('/resfriadores/editar', extra: r),
                                ),
                                IconButton(
                                  icon: const Icon(Icons.delete, color: Colors.red),
                                  onPressed: () async {
                                    final ok = await showDialog<bool>(
                                      context: context,
                                      builder: (c) => AlertDialog(
                                        title: const Text('Excluir?'),
                                        content: Text('Excluir o resfriador ${r.numeroId}?'),
                                        actions: [
                                          TextButton(onPressed: () => Navigator.pop(c, false), child: const Text('Cancelar')),
                                          TextButton(onPressed: () => Navigator.pop(c, true), child: const Text('Excluir')),
                                        ],
                                      ),
                                    );
                                    if (ok == true && r.id != null) {
                                      final sucesso = await vm.delete(r.id!);
                                      if (context.mounted) {
                                        ScaffoldMessenger.of(context).showSnackBar(SnackBar(
                                          content: Text(sucesso
                                              ? 'Resfriador excluído.'
                                              : (vm.errorMessage ?? 'Não foi possível excluir.')),
                                          backgroundColor: sucesso ? Colors.green : Colors.red,
                                        ));
                                      }
                                    }
                                  },
                                ),
                              ],
                            ),
                          ),
                        );
                      },
                    ),
    );
  }
}
