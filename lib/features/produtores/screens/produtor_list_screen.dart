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
  /// A lista de produtores pode passar da altura da tela, e sem uma barra
  /// visível não havia como perceber que existia mais coisa abaixo.
  final _rolagemVertical = ScrollController();

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
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final viewModel = context.watch<ProdutorViewModel>();

    return Scaffold(
      backgroundColor: const Color(0xFFF3F5F4),
      appBar: AppBar(
        title: const Text('Gestão de Produtores'),
        elevation: 0,
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh),
            tooltip: 'Atualizar',
            onPressed: () => viewModel.loadProdutores(),
          ),
        ],
      ),
      floatingActionButton: FloatingActionButton(
        onPressed: () => context.go('/produtores/novo'),
        tooltip: 'Novo produtor',
        child: const Icon(Icons.add),
      ),
      body: Column(
        children: [
          _buildFiltros(viewModel),
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
      padding: const EdgeInsets.fromLTRB(16, 12, 16, 4),
      child: Row(
        children: [
          Text(
            'Status',
            style: TextStyle(
              fontWeight: FontWeight.w600,
              fontSize: 12,
              color: Colors.grey[600],
            ),
          ),
          const SizedBox(width: 10),
          ...filtros.map((f) {
            final selecionado = viewModel.filtroStatus == f.$1;
            return Padding(
              padding: const EdgeInsets.only(right: 6),
              child: ChoiceChip(
                label: Text(f.$2, style: const TextStyle(fontSize: 12)),
                selected: selecionado,
                showCheckmark: false,
                visualDensity: VisualDensity.compact,
                padding: const EdgeInsets.symmetric(horizontal: 8),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(20),
                  side: BorderSide(
                    color: selecionado
                        ? Colors.green.shade700
                        : Colors.grey.shade300,
                  ),
                ),
                selectedColor: Colors.green.shade50,
                labelStyle: TextStyle(
                  color: selecionado
                      ? Colors.green.shade800
                      : Colors.grey[700],
                  fontWeight: selecionado ? FontWeight.w600 : FontWeight.w400,
                ),
                backgroundColor: Colors.white,
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
      return Center(
        child: Text(
          'Nenhum produtor encontrado.',
          style: TextStyle(color: Colors.grey[600], fontSize: 13),
        ),
      );
    }

    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 4, 16, 16),
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
                _CelulaTabela('Nome/Razão Social', flex: 4),
                _CelulaTabela('CPF/CNPJ', flex: 2),
                _CelulaTabela('Cidade', flex: 2),
                _CelulaTabela('Telefone', flex: 2),
              ],
            ),
            Expanded(
              child: ListView.builder(
                controller: _rolagemVertical,
                itemCount: viewModel.items.length,
                itemBuilder: (context, index) {
                  final prod = viewModel.items[index];
                  return Container(
                    color: index.isEven ? Colors.white : Colors.grey.shade50,
                    child: _linhaTabela(
                      celulas: [
                        _CelulaTabela(
                          prod.id?.toString() ?? '-',
                          flex: 1,
                          cor: Colors.grey[600],
                        ),
                        _CelulaTabela(
                          prod.rSocialNome,
                          flex: 4,
                          peso: FontWeight.w500,
                        ),
                        _CelulaTabela(prod.cnpjCpf, flex: 2),
                        _CelulaTabela(prod.bairro, flex: 2),
                        _CelulaTabela(prod.telefone, flex: 2),
                      ],
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
                                context.go('/produtores/editar', extra: prod),
                          ),
                          IconButton(
                            icon: const Icon(Icons.delete_outline, size: 18),
                            color: Colors.red[300],
                            visualDensity: VisualDensity.compact,
                            tooltip: 'Excluir',
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

class _CelulaTabela {
  final String texto;
  final int flex;
  final Color? cor;
  final FontWeight? peso;

  const _CelulaTabela(this.texto, {required this.flex, this.cor, this.peso});
}
