import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../../produtores/models/pessoa_model.dart';
import '../../produtores/repositories/pessoa_repository.dart';
import '../pagamento_service.dart';

final _moeda = NumberFormat.currency(locale: 'pt_BR', symbol: 'R\$');
final _dataBr = DateFormat('dd/MM/yyyy');

/// Pagamentos aos produtores: o depósito que o laticínio faz, a folha que
/// repassa o leite a cada produtor, e os descontos que entram nela.
class PagamentoLancamentoScreen extends StatefulWidget {
  const PagamentoLancamentoScreen({super.key});

  @override
  State<PagamentoLancamentoScreen> createState() =>
      _PagamentoLancamentoScreenState();
}

class _PagamentoLancamentoScreenState extends State<PagamentoLancamentoScreen>
    with SingleTickerProviderStateMixin {
  late final TabController _tabs;

  @override
  void initState() {
    super.initState();
    _tabs = TabController(length: 4, vsync: this);
  }

  @override
  void dispose() {
    _tabs.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Pagamentos'),
        bottom: TabBar(
          controller: _tabs,
          tabs: const [
            Tab(text: 'Folha de pagamento'),
            Tab(text: 'Descontos'),
            Tab(text: 'Depósito do laticínio'),
            Tab(text: 'Histórico'),
          ],
        ),
      ),
      body: TabBarView(
        controller: _tabs,
        children: const [
          _FolhaTab(),
          _DescontosTab(),
          _DepositoTab(),
          _HistoricoTab(),
        ],
      ),
    );
  }
}

// ── Folha ──────────────────────────────────────────────────────────────────

class _FolhaTab extends StatefulWidget {
  const _FolhaTab();

  @override
  State<_FolhaTab> createState() => _FolhaTabState();
}

class _FolhaTabState extends State<_FolhaTab> {
  final _service = PagamentoService();
  final _obs = TextEditingController();

  late DateTime _inicio;
  late DateTime _fim;
  List<LinhaFolha> _linhas = const [];
  bool _carregando = false;
  bool _salvando = false;
  String? _erro;

  @override
  void initState() {
    super.initState();
    // Mês corrente: é o fechamento mais comum, e evita começar com tudo vazio.
    final hoje = DateTime.now();
    _inicio = DateTime(hoje.year, hoje.month, 1);
    _fim = DateTime(hoje.year, hoje.month + 1, 0);
    _montar();
  }

  @override
  void dispose() {
    _obs.dispose();
    super.dispose();
  }

  Future<void> _montar() async {
    setState(() {
      _carregando = true;
      _erro = null;
    });
    try {
      final linhas = await _service.montarFolha(_inicio, _fim);
      if (!mounted) return;
      setState(() {
        _linhas = linhas;
        _carregando = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _erro = 'Não foi possível montar a folha: $e';
        _carregando = false;
      });
    }
  }

  Future<void> _escolherPeriodo() async {
    final intervalo = await showDateRangePicker(
      context: context,
      firstDate: DateTime(2020),
      lastDate: DateTime.now().add(const Duration(days: 365)),
      initialDateRange: DateTimeRange(start: _inicio, end: _fim),
    );
    if (intervalo == null) return;
    setState(() {
      _inicio = intervalo.start;
      _fim = intervalo.end;
    });
    await _montar();
  }

  double get _totalBruto => _linhas.fold(0, (s, l) => s + l.bruto);
  double get _totalDescontos => _linhas.fold(0, (s, l) => s + l.descontos);
  double get _totalLiquido => _linhas.fold(0, (s, l) => s + l.liquido);

  Future<void> _fechar() async {
    final semPreco = _linhas.where((l) => l.semPreco).toList();
    if (semPreco.isNotEmpty) {
      final segue = await showDialog<bool>(
        context: context,
        builder: (ctx) => AlertDialog(
          title: const Text('Produtores sem preço por litro'),
          content: Text(
            '${semPreco.length} produtor(es) entregaram leite no período mas '
            'não têm preço por litro no cadastro, então entram com valor '
            'zero:\n\n${semPreco.map((l) => '• ${l.produtorNome}').join('\n')}'
            '\n\nFechar a folha assim mesmo?',
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(ctx, false),
              child: const Text('Cancelar'),
            ),
            ElevatedButton(
              onPressed: () => Navigator.pop(ctx, true),
              child: const Text('Fechar assim mesmo'),
            ),
          ],
        ),
      );
      if (segue != true) return;
    }

    setState(() => _salvando = true);
    try {
      await _service.salvarFolha(
        inicio: _inicio,
        fim: _fim,
        linhas: _linhas,
        observacao: _obs.text.trim(),
      );
      if (!mounted) return;
      _obs.clear();
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Folha fechada.')),
      );
      await _montar(); // os descontos abatidos somem daqui
      if (mounted) setState(() => _salvando = false);
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _erro = 'Não foi possível fechar a folha: $e';
        _salvando = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Padding(
          padding: const EdgeInsets.all(16),
          child: Row(
            children: [
              Expanded(
                child: Text(
                  'Período: ${_dataBr.format(_inicio)} a ${_dataBr.format(_fim)}',
                  style: const TextStyle(fontWeight: FontWeight.bold),
                ),
              ),
              OutlinedButton.icon(
                onPressed: _carregando ? null : _escolherPeriodo,
                icon: const Icon(Icons.date_range, size: 18),
                label: const Text('Trocar período'),
              ),
            ],
          ),
        ),
        if (_erro != null)
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16),
            child: Text(_erro!, style: const TextStyle(color: Colors.red)),
          ),
        Expanded(
          child: _carregando
              ? const Center(child: CircularProgressIndicator())
              : _linhas.isEmpty
                  ? const Center(
                      child: Text(
                        'Nenhuma coleta confirmada neste período.',
                      ),
                    )
                  : SingleChildScrollView(
                      scrollDirection: Axis.horizontal,
                      child: SingleChildScrollView(
                        child: DataTable(
                          columns: const [
                            DataColumn(label: Text('Produtor')),
                            DataColumn(label: Text('Litros'), numeric: true),
                            DataColumn(label: Text('R\$/L'), numeric: true),
                            DataColumn(label: Text('Bruto'), numeric: true),
                            DataColumn(label: Text('Descontos'), numeric: true),
                            DataColumn(label: Text('A repassar'), numeric: true),
                          ],
                          rows: _linhas
                              .map(
                                (l) => DataRow(
                                  cells: [
                                    DataCell(
                                      Row(
                                        mainAxisSize: MainAxisSize.min,
                                        children: [
                                          if (l.semPreco)
                                            const Padding(
                                              padding:
                                                  EdgeInsets.only(right: 6),
                                              child: Icon(
                                                Icons.warning_amber_rounded,
                                                size: 16,
                                                color: Colors.orange,
                                              ),
                                            ),
                                          Text(l.produtorNome),
                                        ],
                                      ),
                                    ),
                                    DataCell(
                                      Text(l.litros.toStringAsFixed(2)),
                                    ),
                                    DataCell(
                                      Text(l.precoLitro.toStringAsFixed(4)),
                                    ),
                                    DataCell(Text(_moeda.format(l.bruto))),
                                    DataCell(
                                      Text(
                                        l.descontos > 0
                                            ? '- ${_moeda.format(l.descontos)}'
                                            : '—',
                                        style: TextStyle(
                                          color: l.descontos > 0
                                              ? Colors.red.shade700
                                              : null,
                                        ),
                                      ),
                                    ),
                                    DataCell(
                                      Text(
                                        _moeda.format(l.liquido),
                                        style: const TextStyle(
                                          fontWeight: FontWeight.bold,
                                        ),
                                      ),
                                    ),
                                  ],
                                ),
                              )
                              .toList(),
                        ),
                      ),
                    ),
        ),
        const Divider(height: 1),
        Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              _totalLinha('Bruto', _totalBruto),
              _totalLinha('(-) Descontos', _totalDescontos, negativo: true),
              const Divider(),
              _totalLinha('(=) A repassar', _totalLiquido, destaque: true),
              const SizedBox(height: 12),
              TextField(
                controller: _obs,
                decoration: const InputDecoration(
                  labelText: 'Observação',
                  border: OutlineInputBorder(),
                  isDense: true,
                ),
              ),
              const SizedBox(height: 12),
              ElevatedButton.icon(
                onPressed:
                    (_salvando || _linhas.isEmpty) ? null : _fechar,
                icon: _salvando
                    ? const SizedBox(
                        height: 16,
                        width: 16,
                        child: CircularProgressIndicator(strokeWidth: 2),
                      )
                    : const Icon(Icons.check),
                label: const Text('Fechar folha do período'),
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _totalLinha(
    String rotulo,
    double valor, {
    bool negativo = false,
    bool destaque = false,
  }) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 2),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(
            rotulo,
            style: TextStyle(
              fontWeight: destaque ? FontWeight.bold : FontWeight.normal,
            ),
          ),
          Text(
            _moeda.format(valor),
            style: TextStyle(
              fontWeight: destaque ? FontWeight.bold : FontWeight.normal,
              fontSize: destaque ? 17 : 14,
              color: negativo ? Colors.red.shade700 : null,
            ),
          ),
        ],
      ),
    );
  }
}

// ── Descontos ──────────────────────────────────────────────────────────────

class _DescontosTab extends StatefulWidget {
  const _DescontosTab();

  @override
  State<_DescontosTab> createState() => _DescontosTabState();
}

class _DescontosTabState extends State<_DescontosTab> {
  final _service = PagamentoService();
  List<DescontoModel> _descontos = const [];
  bool _carregando = true;

  @override
  void initState() {
    super.initState();
    _carregar();
  }

  Future<void> _carregar() async {
    setState(() => _carregando = true);
    try {
      final lista = await _service.descontos();
      if (!mounted) return;
      setState(() {
        _descontos = lista;
        _carregando = false;
      });
    } catch (_) {
      if (mounted) setState(() => _carregando = false);
    }
  }

  Future<void> _novo() async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (_) => const _DescontoDialog(),
    );
    if (ok == true) await _carregar();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: _carregando
          ? const Center(child: CircularProgressIndicator())
          : _descontos.isEmpty
              ? const Center(
                  child: Text(
                    'Nenhum desconto em aberto.\n'
                    'Os lançados aqui entram na próxima folha.',
                    textAlign: TextAlign.center,
                  ),
                )
              : ListView.separated(
                  padding: const EdgeInsets.all(12),
                  itemCount: _descontos.length,
                  separatorBuilder: (_, __) => const Divider(height: 1),
                  itemBuilder: (_, i) {
                    final d = _descontos[i];
                    return ListTile(
                      title: Text(d.produtorNome),
                      subtitle: Text(
                        [
                          d.data,
                          if (d.descricao.isNotEmpty) d.descricao,
                        ].join('  ·  '),
                      ),
                      trailing: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Text(
                            _moeda.format(d.valor),
                            style: TextStyle(
                              color: Colors.red.shade700,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                          IconButton(
                            tooltip: 'Excluir',
                            icon: const Icon(Icons.delete_outline),
                            onPressed: () async {
                              await _service.excluirDesconto(d.id!);
                              await _carregar();
                            },
                          ),
                        ],
                      ),
                    );
                  },
                ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: _novo,
        icon: const Icon(Icons.add),
        label: const Text('Lançar desconto'),
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
  final _service = PagamentoService();
  final _valor = TextEditingController();
  final _descricao = TextEditingController();

  List<PessoaModel> _produtores = const [];
  int? _produtorId;
  DateTime _data = DateTime.now();
  bool _carregando = true;
  bool _salvando = false;
  String? _erro;

  @override
  void initState() {
    super.initState();
    _carregarProdutores();
  }

  Future<void> _carregarProdutores() async {
    try {
      final lista = await PessoaRepository().getProdutores();
      if (!mounted) return;
      setState(() {
        _produtores = lista;
        _carregando = false;
      });
    } catch (_) {
      if (mounted) setState(() => _carregando = false);
    }
  }

  @override
  void dispose() {
    _valor.dispose();
    _descricao.dispose();
    super.dispose();
  }

  Future<void> _salvar() async {
    final valor = double.tryParse(_valor.text.replaceAll(',', '.')) ?? 0;
    if (_produtorId == null || valor <= 0) {
      setState(() => _erro = 'Escolha o produtor e informe um valor.');
      return;
    }
    setState(() => _salvando = true);
    try {
      await _service.criarDesconto(
        produtorId: _produtorId!,
        data: _data,
        valor: valor,
        descricao: _descricao.text.trim(),
      );
      if (mounted) Navigator.pop(context, true);
    } catch (e) {
      if (mounted) {
        setState(() {
          _erro = 'Não foi possível salvar: $e';
          _salvando = false;
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: const Text('Lançar desconto'),
      content: SizedBox(
        width: 420,
        child: _carregando
            ? const Padding(
                padding: EdgeInsets.all(24),
                child: Center(child: CircularProgressIndicator()),
              )
            : Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  DropdownButtonFormField<int>(
                    initialValue: _produtorId,
                    isExpanded: true,
                    decoration: const InputDecoration(
                      labelText: 'Produtor',
                      border: OutlineInputBorder(),
                    ),
                    items: _produtores
                        .map(
                          (p) => DropdownMenuItem(
                            value: p.id,
                            child: Text(
                              p.rSocialNome,
                              overflow: TextOverflow.ellipsis,
                            ),
                          ),
                        )
                        .toList(),
                    onChanged: (v) => setState(() => _produtorId = v),
                  ),
                  const SizedBox(height: 12),
                  TextField(
                    controller: _valor,
                    keyboardType: TextInputType.number,
                    decoration: const InputDecoration(
                      labelText: 'Valor',
                      prefixText: 'R\$ ',
                      border: OutlineInputBorder(),
                    ),
                  ),
                  const SizedBox(height: 12),
                  TextField(
                    controller: _descricao,
                    decoration: const InputDecoration(
                      labelText: 'Descrição',
                      hintText: 'Ração, medicamento, adiantamento...',
                      border: OutlineInputBorder(),
                    ),
                  ),
                  const SizedBox(height: 12),
                  ListTile(
                    contentPadding: EdgeInsets.zero,
                    title: const Text('Data'),
                    subtitle: Text(_dataBr.format(_data)),
                    trailing: const Icon(Icons.calendar_today, size: 18),
                    onTap: () async {
                      final d = await showDatePicker(
                        context: context,
                        initialDate: _data,
                        firstDate: DateTime(2020),
                        lastDate: DateTime.now().add(
                          const Duration(days: 365),
                        ),
                      );
                      if (d != null) setState(() => _data = d);
                    },
                  ),
                  if (_erro != null)
                    Text(
                      _erro!,
                      style: TextStyle(color: Colors.red.shade700),
                    ),
                ],
              ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context, false),
          child: const Text('Cancelar'),
        ),
        ElevatedButton(
          onPressed: _salvando ? null : _salvar,
          child: const Text('Salvar'),
        ),
      ],
    );
  }
}

// ── Depósito ───────────────────────────────────────────────────────────────

class _DepositoTab extends StatefulWidget {
  const _DepositoTab();

  @override
  State<_DepositoTab> createState() => _DepositoTabState();
}

class _DepositoTabState extends State<_DepositoTab> {
  final _service = PagamentoService();
  final _valor = TextEditingController();
  final _obs = TextEditingController();
  DateTime _data = DateTime.now();
  bool _salvando = false;
  String? _erro;

  @override
  void dispose() {
    _valor.dispose();
    _obs.dispose();
    super.dispose();
  }

  Future<void> _salvar() async {
    final valor = double.tryParse(_valor.text.replaceAll(',', '.')) ?? 0;
    if (valor <= 0) {
      setState(() => _erro = 'Informe o valor depositado.');
      return;
    }
    setState(() {
      _salvando = true;
      _erro = null;
    });
    try {
      await _service.salvarDeposito(
        data: _data,
        valor: valor,
        observacao: _obs.text.trim(),
      );
      if (!mounted) return;
      _valor.clear();
      _obs.clear();
      setState(() => _salvando = false);
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Depósito registrado.')),
      );
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _erro = 'Não foi possível salvar: $e';
        _salvando = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Card(
            child: Padding(
              padding: const EdgeInsets.all(12),
              child: Text(
                'O que o laticínio depositou. Fica registrado para conferir '
                'com o total das folhas do período — não é ele que define '
                'quanto cada produtor recebe; isso vem do preço por litro do '
                'cadastro de cada um.',
                style: TextStyle(fontSize: 12.5, color: Colors.grey.shade700),
              ),
            ),
          ),
          const SizedBox(height: 20),
          TextField(
            controller: _valor,
            keyboardType: TextInputType.number,
            decoration: const InputDecoration(
              labelText: 'Valor depositado',
              prefixText: 'R\$ ',
              border: OutlineInputBorder(),
            ),
          ),
          const SizedBox(height: 12),
          ListTile(
            contentPadding: EdgeInsets.zero,
            title: const Text('Data do depósito'),
            subtitle: Text(_dataBr.format(_data)),
            trailing: const Icon(Icons.calendar_today, size: 18),
            onTap: () async {
              final d = await showDatePicker(
                context: context,
                initialDate: _data,
                firstDate: DateTime(2020),
                lastDate: DateTime.now(),
              );
              if (d != null) setState(() => _data = d);
            },
          ),
          const SizedBox(height: 12),
          TextField(
            controller: _obs,
            maxLines: 3,
            decoration: const InputDecoration(
              labelText: 'Observação',
              border: OutlineInputBorder(),
            ),
          ),
          if (_erro != null) ...[
            const SizedBox(height: 12),
            Text(_erro!, style: TextStyle(color: Colors.red.shade700)),
          ],
          const SizedBox(height: 20),
          ElevatedButton.icon(
            onPressed: _salvando ? null : _salvar,
            icon: const Icon(Icons.check),
            label: const Text('Registrar depósito'),
          ),
        ],
      ),
    );
  }
}

// ── Histórico ──────────────────────────────────────────────────────────────

class _HistoricoTab extends StatefulWidget {
  const _HistoricoTab();

  @override
  State<_HistoricoTab> createState() => _HistoricoTabState();
}

class _HistoricoTabState extends State<_HistoricoTab> {
  final _service = PagamentoService();
  List<PagamentoResumo> _itens = const [];
  bool _carregando = true;

  @override
  void initState() {
    super.initState();
    _carregar();
  }

  Future<void> _carregar() async {
    setState(() => _carregando = true);
    try {
      final lista = await _service.historico();
      if (!mounted) return;
      setState(() {
        _itens = lista;
        _carregando = false;
      });
    } catch (_) {
      if (mounted) setState(() => _carregando = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_carregando) {
      return const Center(child: CircularProgressIndicator());
    }
    if (_itens.isEmpty) {
      return const Center(child: Text('Nenhum pagamento registrado ainda.'));
    }
    return RefreshIndicator(
      onRefresh: _carregar,
      child: ListView.separated(
        padding: const EdgeInsets.all(12),
        itemCount: _itens.length,
        separatorBuilder: (_, __) => const Divider(height: 1),
        itemBuilder: (_, i) {
          final p = _itens[i];
          return ListTile(
            leading: Icon(
              p.ehDeposito ? Icons.account_balance : Icons.receipt_long,
              color: p.ehDeposito ? Colors.blue : Colors.green,
            ),
            title: Text(p.ehDeposito ? 'Depósito do laticínio' : 'Folha'),
            subtitle: Text(
              [
                p.ehDeposito
                    ? (p.dtInicio ?? '')
                    : '${p.dtInicio ?? ''} a ${p.dtFim ?? ''}',
                if (p.observacao.isNotEmpty) p.observacao,
              ].join('  ·  '),
            ),
            trailing: Text(
              _moeda.format(p.valorTotal),
              style: const TextStyle(fontWeight: FontWeight.bold),
            ),
            onTap: p.ehDeposito ? null : () => _verItens(p),
          );
        },
      ),
    );
  }

  Future<void> _verItens(PagamentoResumo p) async {
    final linhas = await _service.itensDaFolha(p.id);
    if (!mounted) return;
    await showDialog<void>(
      context: context,
      builder: (_) => AlertDialog(
        title: Text('Folha de ${p.dtInicio} a ${p.dtFim}'),
        content: SizedBox(
          width: 520,
          child: linhas.isEmpty
              ? const Text('Sem linhas.')
              : SingleChildScrollView(
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: linhas
                        .map(
                          (l) => ListTile(
                            dense: true,
                            contentPadding: EdgeInsets.zero,
                            title: Text(l.produtorNome),
                            subtitle: Text(
                              '${l.litros.toStringAsFixed(2)} L x '
                              '${l.precoLitro.toStringAsFixed(4)}'
                              '${l.descontos > 0 ? '  −  ${_moeda.format(l.descontos)}' : ''}',
                            ),
                            trailing: Text(_moeda.format(l.liquido)),
                          ),
                        )
                        .toList(),
                  ),
                ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Fechar'),
          ),
        ],
      ),
    );
  }
}
