import 'package:flutter/material.dart';
import '../../../core/widgets/pdf_preview_screen.dart';
import '../../core/database/firebird_service.dart';
import '../models/relatorio.dart';
import '../services/relatorio_pdf_service.dart';
import '../services/relatorio_service.dart';

/// Tela única que atende todos os relatórios: monta os filtros a partir da
/// definição, executa a consulta e exibe o resultado com exportação.
class RelatorioDetalheScreen extends StatefulWidget {
  const RelatorioDetalheScreen({required this.def, super.key});

  final DefinicaoRelatorio def;

  @override
  State<RelatorioDetalheScreen> createState() => _RelatorioDetalheScreenState();
}

class _RelatorioDetalheScreenState extends State<RelatorioDetalheScreen> {
  final _service = RelatorioService();
  final _firebird = FirebirdService();

  late ValoresFiltro _filtros;
  ResultadoRelatorio? _resultado;
  List<ContaRef> _contas = [];
  bool _carregando = false;
  String? _erro;

  @override
  void initState() {
    super.initState();
    // Mês corrente é o recorte que o usuário quer ver na maioria das vezes.
    final hoje = DateTime.now();
    _filtros = ValoresFiltro(
      inicio: widget.def.filtros.periodo
          ? DateTime(hoje.year, hoje.month, 1)
          : null,
      fim: widget.def.filtros.periodo ? hoje : null,
      status: widget.def.filtros.statusCadastro ? 'A' : null,
    );
    if (widget.def.filtros.conta) _carregarContas();
    WidgetsBinding.instance.addPostFrameCallback((_) => _gerar());
  }

  Future<void> _carregarContas() async {
    try {
      final c = await _firebird.getContas();
      if (mounted) setState(() => _contas = c);
    } catch (_) {
      // Sem a lista, o filtro de conta simplesmente fica vazio.
    }
  }

  Future<void> _gerar() async {
    setState(() {
      _carregando = true;
      _erro = null;
    });
    try {
      final r = await _service.executar(widget.def, _filtros);
      if (mounted) setState(() => _resultado = r);
    } catch (e) {
      if (mounted) setState(() => _erro = '$e');
    } finally {
      if (mounted) setState(() => _carregando = false);
    }
  }

  Future<void> _escolherData({required bool inicio}) async {
    final hoje = DateTime.now();
    final atual = inicio ? _filtros.inicio : _filtros.fim;
    final d = await showDatePicker(
      context: context,
      initialDate: atual ?? hoje,
      firstDate: DateTime(hoje.year - 5),
      lastDate: DateTime(hoje.year + 1),
    );
    if (d == null) return;
    setState(() {
      if (inicio) {
        _filtros.inicio = d;
      } else {
        _filtros.fim = d;
      }
    });
    await _gerar();
  }

  /// Abre o PDF na tela, de onde dá para imprimir, salvar ou compartilhar.
  Future<void> _exportarPdf() async {
    final r = _resultado;
    if (r == null) return;
    await PdfPreviewScreen.abrir(
      context,
      titulo: widget.def.nome,
      nomeArquivo: widget.def.id,
      gerar: () => RelatorioPdfService.gerar(widget.def, r),
      aoEnviarWhatsApp: _enviarWhatsApp,
    );
  }

  Future<void> _enviarWhatsApp() async {
    final r = _resultado;
    if (r == null) return;
    try {
      final arquivo = await RelatorioPdfService.salvar(widget.def, r);
      await RelatorioPdfService.revelarNaPasta(arquivo);
      await RelatorioPdfService.abrirWhatsApp(
        texto: RelatorioPdfService.mensagemWhatsApp(widget.def, r),
      );
      if (!mounted) return;
      showDialog(
        context: context,
        builder: (_) => AlertDialog(
          title: const Text('Pronto para enviar'),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text(
                'O WhatsApp abriu com o resumo já escrito e a pasta do PDF '
                'apareceu com o arquivo selecionado.',
              ),
              const SizedBox(height: 10),
              const Text(
                'Arraste o arquivo para a conversa para anexá-lo — o WhatsApp '
                'não permite anexar por link.',
                style: TextStyle(fontSize: 12.5),
              ),
              const SizedBox(height: 12),
              SelectableText(
                arquivo.path,
                style: TextStyle(fontSize: 11, color: Colors.grey[700]),
              ),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(context).pop(),
              child: const Text('Fechar'),
            ),
          ],
        ),
      );
    } catch (e) {
      _avisar('Não foi possível preparar o envio: $e', erro: true);
    }
  }

  Future<void> _salvarPdf() async {
    final r = _resultado;
    if (r == null) return;
    try {
      final arquivo = await RelatorioPdfService.salvar(widget.def, r);
      await RelatorioPdfService.abrir(arquivo);
      _avisar('Salvo em ${arquivo.path}');
    } catch (e) {
      _avisar('Não foi possível salvar: $e', erro: true);
    }
  }

  void _avisar(String msg, {bool erro = false}) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(msg), backgroundColor: erro ? Colors.red : null),
    );
  }

  @override
  Widget build(BuildContext context) {
    final r = _resultado;
    final temDados = r != null && !r.vazio;

    return Scaffold(
      appBar: AppBar(
        title: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(widget.def.nome, style: const TextStyle(fontSize: 17)),
            Text(
              widget.def.modulo.titulo,
              style: const TextStyle(fontSize: 11, color: Colors.white70),
            ),
          ],
        ),
        elevation: 0,
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh),
            tooltip: 'Recarregar',
            onPressed: _carregando ? null : _gerar,
          ),
        ],
      ),
      body: Column(
        children: [
          _buildFiltros(),
          const Divider(height: 1),
          if (r != null && r.totais.isNotEmpty) _buildTotais(r),
          Expanded(child: _buildConteudo()),
        ],
      ),
      bottomNavigationBar: Padding(
        padding: const EdgeInsets.all(12),
        child: Row(
          children: [
            Expanded(
              child: OutlinedButton.icon(
                icon: const Icon(Icons.picture_as_pdf),
                label: const Text('Visualizar PDF'),
                onPressed: temDados ? _exportarPdf : null,
              ),
            ),
            const SizedBox(width: 8),
            Expanded(
              child: OutlinedButton.icon(
                icon: const Icon(Icons.save_alt),
                label: const Text('Salvar PDF'),
                onPressed: temDados ? _salvarPdf : null,
              ),
            ),
            const SizedBox(width: 8),
            Expanded(
              child: ElevatedButton.icon(
                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFF25D366),
                  foregroundColor: Colors.white,
                ),
                icon: const Icon(Icons.chat),
                label: const Text('WhatsApp'),
                onPressed: temDados ? _enviarWhatsApp : null,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildFiltros() {
    final f = widget.def.filtros;
    final controles = <Widget>[];

    if (f.periodo) {
      controles.add(
        _botaoData('De', _filtros.inicio, () => _escolherData(inicio: true)),
      );
      controles.add(
        _botaoData('Até', _filtros.fim, () => _escolherData(inicio: false)),
      );
    }
    if (f.statusColeta) {
      controles.add(
        _dropdown<String>('Situação', _filtros.status, const {
          null: 'Todas',
          'CONFIRMADO': 'Confirmadas',
          'RECUSADO': 'Recusadas',
          'ADIADO': 'Adiadas',
          'CANCELADO': 'Canceladas',
          'PENDENTE': 'Pendentes',
        }, (v) => setState(() => _filtros.status = v)),
      );
    }
    if (f.statusRota) {
      controles.add(
        _dropdown<String>('Situação', _filtros.status, const {
          null: 'Todas',
          'PENDENTE': 'Pendentes',
          'EM_ANDAMENTO': 'Em andamento',
          'CONCLUIDA': 'Concluídas',
        }, (v) => setState(() => _filtros.status = v)),
      );
    }
    if (f.statusCadastro) {
      controles.add(
        _dropdown<String>('Situação', _filtros.status, const {
          null: 'Todos',
          'A': 'Ativos',
          'I': 'Inativos',
        }, (v) => setState(() => _filtros.status = v)),
      );
    }
    if (f.tipoMovimento) {
      controles.add(
        _dropdown<String>(
          'Tipo',
          _filtros.tipoMovimento,
          const {null: 'Todos', 'C': 'Entradas', 'D': 'Saídas'},
          (v) => setState(() => _filtros.tipoMovimento = v),
        ),
      );
    }
    if (f.conta) {
      controles.add(
        _dropdown<int>('Conta', _filtros.contaId, {
          null: 'Todas',
          for (final c in _contas) c.id: c.descricao,
        }, (v) => setState(() => _filtros.contaId = v)),
      );
    }

    if (controles.isEmpty) return const SizedBox(height: 8);

    return Container(
      color: Colors.grey.shade50,
      padding: const EdgeInsets.fromLTRB(16, 12, 16, 12),
      child: Row(
        children: [
          Expanded(
            child: Wrap(spacing: 10, runSpacing: 10, children: controles),
          ),
          const SizedBox(width: 12),
          FilledButton.icon(
            icon: const Icon(Icons.search, size: 18),
            label: const Text('Aplicar'),
            onPressed: _carregando ? null : _gerar,
          ),
        ],
      ),
    );
  }

  Widget _botaoData(String rotulo, DateTime? valor, VoidCallback aoTocar) {
    return SizedBox(
      width: 165,
      child: OutlinedButton.icon(
        icon: const Icon(Icons.calendar_today, size: 15),
        label: Text(
          '$rotulo: ${valor == null ? '—' : RelatorioService.data(valor)}',
          overflow: TextOverflow.ellipsis,
        ),
        onPressed: aoTocar,
      ),
    );
  }

  Widget _dropdown<T>(
    String rotulo,
    T? valor,
    Map<T?, String> opcoes,
    ValueChanged<T?> aoMudar,
  ) {
    return SizedBox(
      width: 190,
      child: DropdownButtonFormField<T?>(
        initialValue: valor,
        isExpanded: true,
        decoration: InputDecoration(
          labelText: rotulo,
          isDense: true,
          contentPadding: const EdgeInsets.symmetric(
            horizontal: 10,
            vertical: 10,
          ),
          border: const OutlineInputBorder(),
        ),
        items: opcoes.entries
            .map(
              (e) => DropdownMenuItem<T?>(value: e.key, child: Text(e.value)),
            )
            .toList(),
        onChanged: aoMudar,
      ),
    );
  }

  Widget _buildTotais(ResultadoRelatorio r) {
    return Container(
      width: double.infinity,
      color: Colors.blue.shade50,
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
      child: Wrap(
        spacing: 28,
        runSpacing: 6,
        children: r.totais.entries
            .map(
              (e) => Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    '${e.key}: ',
                    style: TextStyle(fontSize: 12, color: Colors.grey[700]),
                  ),
                  Text(
                    e.value,
                    style: const TextStyle(
                      fontSize: 13,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ],
              ),
            )
            .toList(),
      ),
    );
  }

  Widget _buildConteudo() {
    if (_carregando) return const Center(child: CircularProgressIndicator());

    if (_erro != null) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(32),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(Icons.error_outline, size: 56, color: Colors.red.shade300),
              const SizedBox(height: 12),
              const Text('Não foi possível gerar o relatório'),
              const SizedBox(height: 8),
              SelectableText(
                _erro!,
                textAlign: TextAlign.center,
                style: TextStyle(fontSize: 12, color: Colors.grey[600]),
              ),
            ],
          ),
        ),
      );
    }

    final r = _resultado;
    if (r == null) return const SizedBox();

    if (r.vazio) {
      return Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.inbox_outlined, size: 56, color: Colors.grey[400]),
            const SizedBox(height: 12),
            Text(
              'Nenhum registro para os filtros informados',
              style: TextStyle(color: Colors.grey[600]),
            ),
          ],
        ),
      );
    }

    // Rolagem nos dois eixos: relatórios largos não cabem na janela.
    //
    // Sem Scrollbar explícito aqui: o app inteiro já ganha barra pelo
    // scrollBehavior (core/ui/rolagem.dart), e embrulhar de novo desenharia
    // duas barras sobrepostas.
    return SingleChildScrollView(
      child: SingleChildScrollView(
        scrollDirection: Axis.horizontal,
        child: ConstrainedBox(
          constraints: BoxConstraints(
            minWidth: MediaQuery.of(context).size.width - 32,
          ),
          child: DataTable(
            headingRowColor: WidgetStatePropertyAll(Colors.blueGrey.shade50),
            columnSpacing: 26,
            headingRowHeight: 40,
            dataRowMinHeight: 34,
            dataRowMaxHeight: 44,
            columns: r.colunas
                .map(
                  (c) => DataColumn(
                    numeric: c.alinhaDireita,
                    label: Text(
                      c.titulo,
                      style: const TextStyle(
                        fontWeight: FontWeight.bold,
                        fontSize: 12.5,
                      ),
                    ),
                  ),
                )
                .toList(),
            rows: r.linhas
                .map(
                  (linha) => DataRow(
                    cells: [
                      for (var i = 0; i < linha.length; i++)
                        DataCell(
                          Text(
                            linha[i],
                            style: const TextStyle(fontSize: 12.5),
                          ),
                        ),
                    ],
                  ),
                )
                .toList(),
          ),
        ),
      ),
    );
  }
}
