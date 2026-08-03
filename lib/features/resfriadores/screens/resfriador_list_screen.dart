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
      backgroundColor: const Color(0xFFF3F5F4),
      appBar: AppBar(
        title: const Text('Resfriadores'),
        elevation: 0,
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh),
            tooltip: 'Atualizar',
            onPressed: () => vm.load(),
          ),
        ],
      ),
      floatingActionButton: FloatingActionButton(
        onPressed: () => context.go('/resfriadores/novo'),
        tooltip: 'Novo resfriador',
        child: const Icon(Icons.add),
      ),
      body: vm.isLoading
          ? const Center(child: CircularProgressIndicator())
          : vm.errorMessage != null
          ? Center(
              child: Text(
                vm.errorMessage!,
                style: const TextStyle(color: Colors.red),
              ),
            )
          : vm.items.isEmpty
          ? Center(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(Icons.ac_unit, size: 56, color: Colors.grey[350]),
                  const SizedBox(height: 12),
                  Text(
                    'Nenhum resfriador cadastrado.',
                    style: TextStyle(color: Colors.grey[600], fontSize: 13),
                  ),
                ],
              ),
            )
          : ListView.builder(
              padding: const EdgeInsets.fromLTRB(16, 12, 16, 16),
              itemCount: vm.items.length,
              itemBuilder: (context, i) {
                final r = vm.items[i];
                final cor = _corStatus(r.status);
                return Card(
                  elevation: 0,
                  margin: const EdgeInsets.only(bottom: 8),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                    side: BorderSide(color: Colors.grey.shade200),
                  ),
                  child: ListTile(
                    visualDensity: VisualDensity.compact,
                    leading: Container(
                      width: 38,
                      height: 38,
                      decoration: BoxDecoration(
                        color: cor.withValues(alpha: 0.1),
                        borderRadius: BorderRadius.circular(9),
                      ),
                      child: Icon(Icons.ac_unit, color: cor, size: 20),
                    ),
                    title: Text(
                      '${r.numeroId} • ${r.marcaModelo}',
                      style: const TextStyle(
                        fontWeight: FontWeight.w600,
                        fontSize: 14,
                      ),
                    ),
                    subtitle: Row(
                      children: [
                        Expanded(
                          child: Text(
                            '${r.capacidadeLitros.toStringAsFixed(0)} L'
                            '${r.anoFabricacao != null ? ' • ${r.anoFabricacao}' : ''}',
                            style: const TextStyle(fontSize: 12),
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                        Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 8,
                            vertical: 2,
                          ),
                          decoration: BoxDecoration(
                            color: cor.withValues(alpha: 0.1),
                            borderRadius: BorderRadius.circular(20),
                          ),
                          child: Text(
                            r.status,
                            style: TextStyle(
                              fontSize: 10,
                              color: cor,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        ),
                      ],
                    ),
                    trailing: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        IconButton(
                          icon: const Icon(Icons.edit_outlined, size: 18),
                          color: Colors.blueGrey[600],
                          visualDensity: VisualDensity.compact,
                          tooltip: 'Editar',
                          onPressed: () =>
                              context.go('/resfriadores/editar', extra: r),
                        ),
                        IconButton(
                          icon: const Icon(Icons.delete_outline, size: 18),
                          color: Colors.red[300],
                          visualDensity: VisualDensity.compact,
                          tooltip: 'Excluir',
                          onPressed: () async {
                            final ok = await showDialog<bool>(
                              context: context,
                              builder: (c) => AlertDialog(
                                title: const Text('Excluir?'),
                                content: Text(
                                  'Excluir o resfriador ${r.numeroId}?',
                                ),
                                actions: [
                                  TextButton(
                                    onPressed: () => Navigator.pop(c, false),
                                    child: const Text('Cancelar'),
                                  ),
                                  TextButton(
                                    onPressed: () => Navigator.pop(c, true),
                                    child: const Text('Excluir'),
                                  ),
                                ],
                              ),
                            );
                            if (ok == true && r.id != null) {
                              final sucesso = await vm.delete(r.id!);
                              if (context.mounted) {
                                ScaffoldMessenger.of(context).showSnackBar(
                                  SnackBar(
                                    content: Text(
                                      sucesso
                                          ? 'Resfriador excluído.'
                                          : (vm.errorMessage ??
                                                'Não foi possível excluir.'),
                                    ),
                                    backgroundColor: sucesso
                                        ? Colors.green
                                        : Colors.red,
                                  ),
                                );
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
