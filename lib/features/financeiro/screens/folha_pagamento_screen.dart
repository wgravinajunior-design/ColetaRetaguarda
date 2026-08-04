import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../pagamento_service.dart';
import '../../produtores/models/pessoa_model.dart';
import '../../produtores/repositories/pessoa_repository.dart';

/// Fechamento do leite: monta a folha do período (litros confirmados ×
/// preço por litro do produtor, menos descontos em aberto), permite lançar
/// descontos avulsos e consultar o histórico já fechado.
///
/// Deliberadamente simples: sem CCS/CBT, bonificação por faixa, Funrural ou
/// contra-nota fiscal — isso continua sendo resolvido no ERP. Aqui é só o
/// "quanto cada produtor tem a receber", a parte que a coleta já tem os
/// dados para calcular sozinha.
class FolhaPagamentoScreen extends StatefulWidget {
  const FolhaPagamentoScreen({super.key});

  @override
  State<FolhaPagamentoScreen> createState() => _FolhaPagamentoScreenState();
}

class _FolhaPagamentoScreenState extends State<FolhaPagamentoScreen>
    with SingleTickerProviderStateMixin {
  final _service = PagamentoService();
  final _formatMoeda = NumberFormat.currency(locale: 'pt_BR', symbol: 'R\$');
  late final TabController _tabs;

  DateTime _inicio = DateTime(DateTime.now().year, DateTime.now().month, 1);
  DateTime _fim = DateTime.now();
  List<LinhaFolha>? _folha;
  bool _montando = false;
  bool _fechando = false;

  List<DescontoModel> _descontos = [];
  bool _carregandoDescontos = true;

  List<PagamentoResumo> _historico = [];
  bool _carregandoHistorico = true;

  @override
  void initState() {
    super.initState();
    _tabs = TabController(length: 3, vsync: this);
    _carregarDescontos();
    _carregarHistorico();
  }

  @override
  void dispose() {
    _tabs.dispose();
    super.dispose();
  }

  Future<void> _carregarDescontos() async {
    setState(() => _carregandoDescontos = true);
    try {
      final lista = await _service.descontos();
      if (mounted) setState(() => _descontos = lista);
    } finally {
      if (mounted) setState(() => _carregandoDescontos = false);
    }
  }

  Future<void> _carregarHistorico() async {
    setState(() => _carregandoHistorico = true);
    try {
      final lista = await _service.historico();
      if (mounted) setState(() => _historico = lista);
    } finally {
      if (mounted) setState(() => _carregandoHistorico = false);
    }
  }

  Future<void> _montarFolha() async {
    setState(() {
      _montando = true;
      _folha = null;
    });
    try {
      final linhas = await _service.montarFolha(_inicio, _fim);
      if (mounted) setState(() => _folha = linhas);
    } catch (e) {
      if (mounted) _erro('Não foi possível montar a folha: $e');
    } finally {
      if (mounted) setState(() => _montando = false);
    }
  }

  Future<void> _fecharFolha() async {
    final folha = _folha;
    if (folha == null || folha.isEmpty) return;

    final confirmar = await showDialog<bool>(
      context: context,
      builder: (c) => AlertDialog(
        title: const Text('Fechar folha?'),
        content: Text(
          'Isto grava o pagamento de ${folha.length} produtor(es), totalizando '
          '${_formatMoeda.format(folha.fold<double>(0, (s, l) => s + l.liquido))}, '
          'e abate os descontos em aberto até ${_dataFmt(_fim)}. Não é possível desfazer.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(c, false),
            child: const Text('Cancelar'),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(c, true),
            style: ElevatedButton.styleFrom(backgroundColor: const Color(0xFF2E7D4F)),
            child: const Text('Fechar folha', style: TextStyle(color: Colors.white)),
          ),
        ],
      ),
    );
    if (confirmar != true) return;

    setState(() => _fechando = true);
    try {
      await _service.salvarFolha(inicio: _inicio, fim: _fim, linhas: folha);
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Folha fechada com sucesso!'), backgroundColor: Colors.green),
      );
      setState(() => _folha = null);
      await Future.wait([_carregarDescontos(), _carregarHistorico()]);
    } catch (e) {
      if (mounted) _erro('Não foi possível fechar a folha: $e');
    } finally {
      if (mounted) setState(() => _fechando = false);
    }
  }

  void _erro(String msg) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(msg), backgroundColor: Colors.red),
    );
  }

  String _dataFmt(DateTime d) {
    String dois(int n) => n.toString().padLeft(2, '0');
    return '${dois(d.day)}/${dois(d.month)}/${d.year}';
  }

  Future<void> _selecionarData({required bool ehInicio}) async {
    final d = await showDatePicker(
      context: context,
      initialDate: ehInicio ? _inicio : _fim,
      firstDate: DateTime(DateTime.now().year - 5),
      lastDate: DateTime(DateTime.now().year + 1),
    );
    if (d == null) return;
    setState(() {
      if (ehInicio) {
        _inicio = d;
      } else {
        _fim = d;
      }
      _folha = null;
    });
  }

  Future<void> _novoDesconto() async {
    final salvou = await showDialog<bool>(
      context: context,
      builder: (_) => const _DescontoDialog(),
    );
    if (salvou == true) await _carregarDescontos();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF3F5F4),
      appBar: AppBar(
        title: const Text('Pagamento aos Produtores'),
        elevation: 0,
        bottom: TabBar(
          controller: _tabs,
          labelColor: Colors.white,
          unselectedLabelColor: Colors.white70,
          indicatorColor: Colors.white,
          indicatorWeight: 3,
          tabs: const [
            Tab(icon: Icon(Icons.request_quote_outlined), text: 'Fechar folha'),
            Tab(icon: Icon(Icons.remove_circle_outline), text: 'Descontos'),
            Tab(icon: Icon(Icons.history), text: 'Histórico'),
          ],
        ),
      ),
      body: TabBarView(
        controller: _tabs,
        children: [_abaFolha(), _abaDescontos(), _abaHistorico()],
      ),
    );
  }

  // ─────────────────────────────────────────────── Folha

  Widget _abaFolha() {
    final folha = _folha;
    final total = folha?.fold<double>(0, (s, l) => s + l.liquido) ?? 0;

    return Column(
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 12, 16, 4),
          child: Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: Colors.grey.shade200),
            ),
            child: Row(
              children: [
                Expanded(
                  child: OutlinedButton.icon(
                    style: OutlinedButton.styleFrom(
                      visualDensity: VisualDensity.compact,
                      padding: const EdgeInsets.symmetric(vertical: 10),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                    ),
                    icon: const Icon(Icons.event, size: 15),
                    label: Text('De: ${_dataFmt(_inicio)}', style: const TextStyle(fontSize: 12)),
                    onPressed: () => _selecionarData(ehInicio: true),
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: OutlinedButton.icon(
                    style: OutlinedButton.styleFrom(
                      visualDensity: VisualDensity.compact,
                      padding: const EdgeInsets.symmetric(vertical: 10),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                    ),
                    icon: const Icon(Icons.event, size: 15),
                    label: Text('Até: ${_dataFmt(_fim)}', style: const TextStyle(fontSize: 12)),
                    onPressed: () => _selecionarData(ehInicio: false),
                  ),
                ),
                const SizedBox(width: 8),
                ElevatedButton.icon(
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFF2E7D4F),
                    padding: const EdgeInsets.symmetric(vertical: 10, horizontal: 14),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                  ),
                  icon: _montando
                      ? const SizedBox(
                          width: 14,
                          height: 14,
                          child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
                        )
                      : const Icon(Icons.calculate_outlined, size: 16, color: Colors.white),
                  label: const Text('Montar', style: TextStyle(color: Colors.white, fontSize: 12)),
                  onPressed: _montando ? null : _montarFolha,
                ),
              ],
            ),
          ),
        ),
        Expanded(
          child: folha == null
              ? Center(
                  child: Text(
                    'Escolha o período e toque em "Montar" para calcular a folha.',
                    textAlign: TextAlign.center,
                    style: TextStyle(color: Colors.grey[600], fontSize: 13),
                  ),
                )
              : folha.isEmpty
                  ? Center(
                      child: Text(
                        'Nenhuma coleta confirmada neste período.',
                        style: TextStyle(color: Colors.grey[600], fontSize: 13),
                      ),
                    )
                  : Padding(
                      padding: const EdgeInsets.fromLTRB(16, 8, 16, 16),
                      child: Card(
                        elevation: 0,
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12),
                          side: BorderSide(color: Colors.grey.shade200),
                        ),
                        clipBehavior: Clip.antiAlias,
                        child: Column(
                          children: [
                            _linhaFolha(
                              isCabecalho: true,
                              produtor: 'Produtor',
                              litros: 'Litros',
                              precoLitro: 'R\$/L',
                              descontos: 'Descontos',
                              liquido: 'Líquido',
                            ),
                            Expanded(
                              child: ListView.builder(
                                itemCount: folha.length,
                                itemBuilder: (context, i) {
                                  final l = folha[i];
                                  return Container(
                                    color: i.isEven ? Colors.white : Colors.grey.shade50,
                                    child: _linhaFolha(
                                      produtor: l.produtorNome,
                                      litros: l.litros.toStringAsFixed(0),
                                      precoLitro: l.semPreco ? '—' : l.precoLitro.toStringAsFixed(2),
                                      descontos: l.descontos > 0 ? _formatMoeda.format(l.descontos) : '—',
                                      liquido: _formatMoeda.format(l.liquido),
                                      alerta: l.semPreco,
                                    ),
                                  );
                                },
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
        ),
        if (folha != null && folha.isNotEmpty)
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: Colors.white,
              border: Border(top: BorderSide(color: Colors.grey.shade200)),
            ),
            child: Row(
              children: [
                Expanded(
                  child: Text(
                    'Total líquido: ${_formatMoeda.format(total)}',
                    style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 14),
                  ),
                ),
                ElevatedButton.icon(
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFF2E7D4F),
                    padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 18),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                  ),
                  icon: _fechando
                      ? const SizedBox(
                          width: 16,
                          height: 16,
                          child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
                        )
                      : const Icon(Icons.lock_outline, size: 18, color: Colors.white),
                  label: const Text('Fechar folha', style: TextStyle(color: Colors.white)),
                  onPressed: _fechando ? null : _fecharFolha,
                ),
              ],
            ),
          ),
      ],
    );
  }

  Widget _linhaFolha({
    required String produtor,
    required String litros,
    required String precoLitro,
    required String descontos,
    required String liquido,
    bool isCabecalho = false,
    bool alerta = false,
  }) {
    final estiloCabecalho = TextStyle(
      fontSize: 12,
      fontWeight: FontWeight.w600,
      color: Colors.grey[700],
    );
    final estiloDado = TextStyle(
      fontSize: 13,
      color: alerta ? Colors.red[700] : null,
    );
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
      decoration: BoxDecoration(
        color: isCabecalho ? Colors.grey.shade50 : null,
        border: Border(
          bottom: BorderSide(color: Colors.grey.shade200, width: isCabecalho ? 1 : 0.5),
        ),
      ),
      child: Row(
        children: [
          Expanded(
            flex: 4,
            child: Text(
              produtor,
              overflow: TextOverflow.ellipsis,
              style: isCabecalho
                  ? estiloCabecalho
                  : estiloDado.copyWith(fontWeight: FontWeight.w500),
            ),
          ),
          Expanded(
            flex: 2,
            child: Text(litros, style: isCabecalho ? estiloCabecalho : estiloDado),
          ),
          Expanded(
            flex: 2,
            child: Text(precoLitro, style: isCabecalho ? estiloCabecalho : estiloDado),
          ),
          Expanded(
            flex: 2,
            child: Text(descontos, style: isCabecalho ? estiloCabecalho : estiloDado),
          ),
          Expanded(
            flex: 2,
            child: Text(
              liquido,
              style: isCabecalho
                  ? estiloCabecalho
                  : estiloDado.copyWith(fontWeight: FontWeight.w700),
            ),
          ),
        ],
      ),
    );
  }

  // ─────────────────────────────────────────────── Descontos

  Widget _abaDescontos() {
    return Scaffold(
      backgroundColor: Colors.transparent,
      floatingActionButton: FloatingActionButton(
        onPressed: _novoDesconto,
        tooltip: 'Novo desconto',
        child: const Icon(Icons.add),
      ),
      body: _carregandoDescontos
          ? const Center(child: CircularProgressIndicator())
          : _descontos.isEmpty
              ? Center(
                  child: Text(
                    'Nenhum desconto em aberto.',
                    style: TextStyle(color: Colors.grey[600], fontSize: 13),
                  ),
                )
              : ListView.builder(
                  padding: const EdgeInsets.fromLTRB(16, 12, 16, 80),
                  itemCount: _descontos.length,
                  itemBuilder: (context, i) {
                    final d = _descontos[i];
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
                          width: 36,
                          height: 36,
                          decoration: BoxDecoration(
                            color: Colors.red.withValues(alpha: 0.1),
                            borderRadius: BorderRadius.circular(9),
                          ),
                          child: const Icon(Icons.remove_circle_outline, color: Colors.red, size: 18),
                        ),
                        title: Text(
                          d.produtorNome,
                          style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 13),
                        ),
                        subtitle: Text(
                          '${d.descricao.isEmpty ? 'Desconto' : d.descricao} • ${d.data}',
                          style: const TextStyle(fontSize: 11),
                        ),
                        trailing: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Text(
                              _formatMoeda.format(d.valor),
                              style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 13, color: Colors.red),
                            ),
                            IconButton(
                              icon: const Icon(Icons.delete_outline, size: 18),
                              color: Colors.red[300],
                              visualDensity: VisualDensity.compact,
                              tooltip: 'Excluir',
                              onPressed: () async {
                                if (d.id == null) return;
                                await _service.excluirDesconto(d.id!);
                                await _carregarDescontos();
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

  // ─────────────────────────────────────────────── Histórico

  Widget _abaHistorico() {
    if (_carregandoHistorico) {
      return const Center(child: CircularProgressIndicator());
    }
    if (_historico.isEmpty) {
      return Center(
        child: Text(
          'Nenhuma folha fechada ainda.',
          style: TextStyle(color: Colors.grey[600], fontSize: 13),
        ),
      );
    }
    return ListView.builder(
      padding: const EdgeInsets.fromLTRB(16, 12, 16, 16),
      itemCount: _historico.length,
      itemBuilder: (context, i) {
        final p = _historico[i];
        final cor = p.ehDeposito ? Colors.indigo : const Color(0xFF2E7D4F);
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
              child: Icon(
                p.ehDeposito ? Icons.local_shipping_outlined : Icons.request_quote_outlined,
                color: cor,
                size: 18,
              ),
            ),
            title: Text(
              p.ehDeposito ? 'Depósito do laticínio' : 'Folha de pagamento',
              style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 13),
            ),
            subtitle: Text(
              p.ehDeposito
                  ? '${p.dtInicio} • ${p.observacao}'
                  : '${p.dtInicio} a ${p.dtFim}',
              style: const TextStyle(fontSize: 11),
            ),
            trailing: Text(
              _formatMoeda.format(p.valorTotal),
              style: TextStyle(fontWeight: FontWeight.w700, fontSize: 13, color: cor),
            ),
            onTap: p.ehDeposito ? null : () => _verFolha(p),
          ),
        );
      },
    );
  }

  Future<void> _verFolha(PagamentoResumo p) async {
    final itens = await _service.itensDaFolha(p.id);
    if (!mounted) return;
    await showDialog(
      context: context,
      builder: (_) => Dialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 480, maxHeight: 560),
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Folha ${p.dtInicio} a ${p.dtFim}',
                  style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w600),
                ),
                const SizedBox(height: 12),
                Expanded(
                  child: ListView.separated(
                    itemCount: itens.length,
                    separatorBuilder: (_, _) => const Divider(height: 1),
                    itemBuilder: (context, i) {
                      final l = itens[i];
                      return ListTile(
                        dense: true,
                        title: Text(l.produtorNome, style: const TextStyle(fontSize: 13)),
                        subtitle: Text(
                          '${l.litros.toStringAsFixed(0)} L × R\$ ${l.precoLitro.toStringAsFixed(2)}'
                          '${l.descontos > 0 ? ' • desc. ${_formatMoeda.format(l.descontos)}' : ''}',
                          style: const TextStyle(fontSize: 11),
                        ),
                        trailing: Text(
                          _formatMoeda.format(l.liquido),
                          style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 13),
                        ),
                      );
                    },
                  ),
                ),
                const SizedBox(height: 8),
                Align(
                  alignment: Alignment.centerRight,
                  child: TextButton(
                    onPressed: () => Navigator.pop(context),
                    child: const Text('Fechar'),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _DescontoDialog extends StatefulWidget {
  const _DescontoDialog();

  @override
  State<_DescontoDialog> createState() => _DescontoDialogState();
}

class _DescontoDialogState extends State<_DescontoDialog> {
  final _formKey = GlobalKey<FormState>();
  final _service = PagamentoService();
  final _pessoaRepository = PessoaRepository();
  final _valorController = TextEditingController();
  final _descricaoController = TextEditingController();

  PessoaModel? _produtor;
  DateTime _data = DateTime.now();
  bool _salvando = false;
  String? _erro;

  @override
  void dispose() {
    _valorController.dispose();
    _descricaoController.dispose();
    super.dispose();
  }

  Future<void> _selecionarData() async {
    final d = await showDatePicker(
      context: context,
      initialDate: _data,
      firstDate: DateTime(DateTime.now().year - 5),
      lastDate: DateTime(DateTime.now().year + 1),
    );
    if (d != null) setState(() => _data = d);
  }

  Future<void> _salvar() async {
    if (_produtor == null) {
      setState(() => _erro = 'Selecione o produtor');
      return;
    }
    final valor = double.tryParse(_valorController.text.replaceAll(',', '.'));
    if (valor == null || valor <= 0) {
      setState(() => _erro = 'Informe um valor válido');
      return;
    }

    setState(() {
      _salvando = true;
      _erro = null;
    });
    try {
      await _service.criarDesconto(
        produtorId: _produtor!.id!,
        data: _data,
        valor: valor,
        descricao: _descricaoController.text.trim(),
      );
      if (mounted) Navigator.of(context).pop(true);
    } catch (e) {
      if (mounted) {
        setState(() {
          _erro = 'Não foi possível salvar: $e';
          _salvando = false;
        });
      }
    }
  }

  String _dataFmt(DateTime d) {
    String dois(int n) => n.toString().padLeft(2, '0');
    return '${dois(d.day)}/${dois(d.month)}/${d.year}';
  }

  @override
  Widget build(BuildContext context) {
    return Dialog(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 420),
        child: Padding(
          padding: const EdgeInsets.all(20),
          child: Form(
            key: _formKey,
            child: SingleChildScrollView(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                    'Novo desconto',
                    style: TextStyle(fontSize: 17, fontWeight: FontWeight.w600),
                  ),
                  const SizedBox(height: 16),
                  Autocomplete<PessoaModel>(
                    displayStringForOption: (p) => p.rSocialNome,
                    optionsBuilder: (value) async {
                      final termo = value.text.trim();
                      if (termo.length < 2) return const Iterable<PessoaModel>.empty();
                      try {
                        return await _pessoaRepository.getProdutores(query: termo);
                      } catch (_) {
                        return const Iterable<PessoaModel>.empty();
                      }
                    },
                    onSelected: (p) => setState(() => _produtor = p),
                    fieldViewBuilder: (context, controller, focusNode, onSubmit) {
                      return TextField(
                        controller: controller,
                        focusNode: focusNode,
                        style: const TextStyle(fontSize: 13),
                        decoration: InputDecoration(
                          labelText: 'Produtor *',
                          labelStyle: const TextStyle(fontSize: 12),
                          hintText: 'Digite ao menos 2 letras...',
                          hintStyle: const TextStyle(fontSize: 12),
                          border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
                          isDense: true,
                          contentPadding: const EdgeInsets.symmetric(horizontal: 10, vertical: 10),
                          prefixIcon: const Icon(Icons.person_outline, size: 18),
                        ),
                      );
                    },
                    optionsViewBuilder: (context, onSelected, options) {
                      return Align(
                        alignment: Alignment.topLeft,
                        child: Material(
                          elevation: 4,
                          borderRadius: BorderRadius.circular(8),
                          child: ConstrainedBox(
                            constraints: const BoxConstraints(maxHeight: 200, maxWidth: 380),
                            child: ListView(
                              padding: EdgeInsets.zero,
                              shrinkWrap: true,
                              children: options
                                  .map((p) => ListTile(
                                        dense: true,
                                        title: Text(p.rSocialNome, style: const TextStyle(fontSize: 13)),
                                        onTap: () => onSelected(p),
                                      ))
                                  .toList(),
                            ),
                          ),
                        ),
                      );
                    },
                  ),
                  const SizedBox(height: 10),
                  TextField(
                    controller: _valorController,
                    keyboardType: const TextInputType.numberWithOptions(decimal: true),
                    style: const TextStyle(fontSize: 13),
                    decoration: InputDecoration(
                      labelText: 'Valor (R\$) *',
                      labelStyle: const TextStyle(fontSize: 12),
                      border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
                      isDense: true,
                      contentPadding: const EdgeInsets.symmetric(horizontal: 10, vertical: 10),
                      prefixIcon: const Icon(Icons.attach_money, size: 18),
                    ),
                  ),
                  const SizedBox(height: 10),
                  TextField(
                    controller: _descricaoController,
                    style: const TextStyle(fontSize: 13),
                    decoration: InputDecoration(
                      labelText: 'Descrição',
                      labelStyle: const TextStyle(fontSize: 12),
                      hintText: 'ex: Ração, adiantamento...',
                      hintStyle: const TextStyle(fontSize: 12),
                      border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
                      isDense: true,
                      contentPadding: const EdgeInsets.symmetric(horizontal: 10, vertical: 10),
                    ),
                  ),
                  const SizedBox(height: 10),
                  InkWell(
                    onTap: _selecionarData,
                    child: InputDecorator(
                      decoration: InputDecoration(
                        labelText: 'Data',
                        labelStyle: const TextStyle(fontSize: 12),
                        border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
                        isDense: true,
                        contentPadding: const EdgeInsets.symmetric(horizontal: 10, vertical: 10),
                        prefixIcon: const Icon(Icons.event, size: 18),
                      ),
                      child: Text(_dataFmt(_data), style: const TextStyle(fontSize: 13)),
                    ),
                  ),
                  if (_erro != null) ...[
                    const SizedBox(height: 10),
                    Text(_erro!, style: TextStyle(color: Colors.red.shade700, fontSize: 12)),
                  ],
                  const SizedBox(height: 20),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.end,
                    children: [
                      TextButton(
                        onPressed: _salvando ? null : () => Navigator.of(context).pop(false),
                        child: const Text('Cancelar'),
                      ),
                      const SizedBox(width: 8),
                      ElevatedButton(
                        onPressed: _salvando ? null : _salvar,
                        style: ElevatedButton.styleFrom(
                          backgroundColor: const Color(0xFF2E7D4F),
                          padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                        ),
                        child: _salvando
                            ? const SizedBox(
                                width: 16,
                                height: 16,
                                child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
                              )
                            : const Text('Salvar', style: TextStyle(color: Colors.white)),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}
