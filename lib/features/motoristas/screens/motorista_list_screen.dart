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
  final _rolagemVertical = ScrollController();

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      context.read<MotoristaViewModel>().loadMotoristas();
    });
  }

  @override
  void dispose() {
    _rolagemVertical.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final viewModel = context.watch<MotoristaViewModel>();

    return Scaffold(
      backgroundColor: const Color(0xFFF3F5F4),
      appBar: AppBar(
        title: const Text('Gestão de Motoristas'),
        elevation: 0,
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh),
            tooltip: 'Atualizar',
            onPressed: () => viewModel.loadMotoristas(),
          ),
        ],
      ),
      floatingActionButton: FloatingActionButton(
        onPressed: () => context.go('/motoristas/novo'),
        tooltip: 'Novo motorista',
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
      return Center(
        child: Text(
          'Nenhum motorista encontrado.',
          style: TextStyle(color: Colors.grey[600], fontSize: 13),
        ),
      );
    }

    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 12, 16, 16),
      child: Card(
        elevation: 0,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(12),
          side: BorderSide(color: Colors.grey.shade200),
        ),
        clipBehavior: Clip.antiAlias,
        child: Column(
          children: [
            _linhaTabela(
              isCabecalho: true,
              celulas: const [
                _CelulaTabela('ID', flex: 1),
                _CelulaTabela('Nome', flex: 3),
                _CelulaTabela('CPF', flex: 2),
                _CelulaTabela('Celular', flex: 2),
                _CelulaTabela('Status', flex: 1),
              ],
            ),
            Expanded(
              child: ListView.builder(
                controller: _rolagemVertical,
                itemCount: viewModel.items.length,
                itemBuilder: (context, index) {
                  final mot = viewModel.items[index];
                  final ativo = mot.status == 'A';
                  return Container(
                    color: index.isEven ? Colors.white : Colors.grey.shade50,
                    child: _linhaTabela(
                      celulas: [
                        _CelulaTabela(
                          mot.id?.toString() ?? '-',
                          flex: 1,
                          cor: Colors.grey[600],
                        ),
                        _CelulaTabela(
                          mot.nome ?? '-',
                          flex: 3,
                          peso: FontWeight.w500,
                        ),
                        _CelulaTabela(mot.cpf, flex: 2),
                        _CelulaTabela(mot.celular ?? '-', flex: 2),
                      ],
                      statusWidget: _StatusChip(ativo: ativo),
                      acoes: Row(
                        mainAxisSize: MainAxisSize.min,
                        mainAxisAlignment: MainAxisAlignment.end,
                        children: [
                          IconButton(
                            icon: const Icon(Icons.edit_outlined, size: 18),
                            color: Colors.blueGrey[600],
                            visualDensity: VisualDensity.compact,
                            tooltip: 'Editar',
                            onPressed: () =>
                                context.go('/motoristas/editar', extra: mot),
                          ),
                          IconButton(
                            icon: const Icon(Icons.delete_outline, size: 18),
                            color: Colors.red[300],
                            visualDensity: VisualDensity.compact,
                            tooltip: 'Excluir',
                            onPressed: () async {
                              final confirm = await showDialog<bool>(
                                context: context,
                                builder: (context) => AlertDialog(
                                  title: const Text('Excluir?'),
                                  content: Text(
                                    'Tem certeza que deseja excluir ${mot.nome}?',
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
                              if (confirm == true && mot.id != null) {
                                viewModel.deleteMotorista(mot.id!);
                              }
                            },
                          ),
                        ],
                      ),
                    ),
                  );
                },
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _linhaTabela({
    required List<_CelulaTabela> celulas,
    Widget? statusWidget,
    Widget? acoes,
    bool isCabecalho = false,
  }) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
      decoration: BoxDecoration(
        color: isCabecalho ? Colors.grey.shade50 : null,
        border: Border(
          bottom: BorderSide(
            color: Colors.grey.shade200,
            width: isCabecalho ? 1 : 0.5,
          ),
        ),
      ),
      child: Row(
        children: [
          for (final celula in celulas)
            Expanded(
              flex: celula.flex,
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 4),
                child: Text(
                  celula.texto,
                  overflow: TextOverflow.ellipsis,
                  style: isCabecalho
                      ? TextStyle(
                          fontSize: 12,
                          fontWeight: FontWeight.w600,
                          color: Colors.grey[700],
                        )
                      : TextStyle(
                          fontSize: 13,
                          fontWeight: celula.peso,
                          color: celula.cor,
                        ),
                ),
              ),
            ),
          Expanded(
            flex: 1,
            child: isCabecalho
                ? Text(
                    'Status',
                    style: TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.w600,
                      color: Colors.grey[700],
                    ),
                  )
                : (statusWidget ?? const SizedBox.shrink()),
          ),
          Expanded(
            flex: 1,
            child: isCabecalho
                ? const Text(
                    'Ações',
                    textAlign: TextAlign.right,
                    style: TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.w600,
                      color: Colors.grey,
                    ),
                  )
                : (acoes ?? const SizedBox.shrink()),
          ),
        ],
      ),
    );
  }
}

class _StatusChip extends StatelessWidget {
  final bool ativo;

  const _StatusChip({required this.ativo});

  @override
  Widget build(BuildContext context) {
    final MaterialColor cor = ativo ? Colors.green : Colors.grey;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
      decoration: BoxDecoration(
        color: cor.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(20),
      ),
      child: Text(
        ativo ? 'Ativo' : 'Inativo',
        style: TextStyle(
          fontSize: 11,
          fontWeight: FontWeight.w600,
          color: cor.shade700,
        ),
      ),
    );
  }
}

class _CelulaTabela {
  final String texto;
  final int flex;
  final Color? cor;
  final FontWeight? peso;

  const _CelulaTabela(this.texto, {required this.flex, this.cor, this.peso});
}
