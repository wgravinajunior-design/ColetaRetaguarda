import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:go_router/go_router.dart';
import '../models/movimento_model.dart';
import '../viewmodels/financeiro_viewmodel.dart';
import '../../core/database/firebird_service.dart';

class FinanceiroFormScreen extends StatefulWidget {
  final MovimentoModel? movimento;

  const FinanceiroFormScreen({super.key, this.movimento});

  @override
  State<FinanceiroFormScreen> createState() => _FinanceiroFormScreenState();
}

class _FinanceiroFormScreenState extends State<FinanceiroFormScreen> {
  late TextEditingController historicoController;
  late TextEditingController valorController;
  late TextEditingController contaBuscaController;
  String tipoSelecionado = 'C';

  final _firebird = FirebirdService();
  List<ContaRef> _contas = [];
  List<ContaRef> _contasFiltradas = [];
  int? _contaId;
  bool _carregando = true;
  bool _mostrarSugestoes = false;

  @override
  void initState() {
    super.initState();
    historicoController = TextEditingController(text: widget.movimento?.historico ?? '');
    valorController = TextEditingController(text: widget.movimento?.valor.toString() ?? '');
    contaBuscaController = TextEditingController();
    _contaId = widget.movimento?.conta;
    tipoSelecionado = widget.movimento?.tipo ?? 'C';
    _carregarContas();
  }

  Future<void> _carregarContas() async {
    try {
      final contas = await _firebird.getContas();
      if (!mounted) return;
      setState(() {
        _contas = contas;
        _contaId ??= contas.isNotEmpty ? contas.first.id : null;
        _carregando = false;
      });
    } catch (_) {
      if (mounted) setState(() => _carregando = false);
    }
  }

  @override
  void dispose() {
    historicoController.dispose();
    valorController.dispose();
    contaBuscaController.dispose();
    super.dispose();
  }

  void _filtrarContas(String termo) {
    if (termo.isEmpty) {
      setState(() {
        _contasFiltradas = [];
        _mostrarSugestoes = false;
      });
      return;
    }
    final filtradas = _contas
        .where((c) =>
            c.descricao.toLowerCase().contains(termo.toLowerCase()) ||
            c.id.toString().contains(termo))
        .toList();
    setState(() {
      _contasFiltradas = filtradas;
      _mostrarSugestoes = true;
    });
  }

  void _selecionarConta(ContaRef conta) {
    setState(() {
      _contaId = conta.id;
      contaBuscaController.text = conta.descricao;
      _mostrarSugestoes = false;
    });
  }

  void _save() async {
    if (_contaId == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Selecione a conta'), backgroundColor: Colors.red),
      );
      return;
    }
    final viewModel = context.read<FinanceiroViewModel>();

    final m = MovimentoModel(
      id: widget.movimento?.id,
      historico: historicoController.text,
      valor: double.tryParse(valorController.text.replaceAll(',', '.')) ?? 0.0,
      conta: _contaId!,
      tipo: tipoSelecionado,
      status: 'P',
      dtEmissao: DateTime.now().toString().split(' ')[0],
    );

    bool success;
    if (widget.movimento == null) {
      success = await viewModel.createMovimento(m);
    } else {
      success = await viewModel.updateMovimento(m);
    }

    if (success && mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Movimento salvo com sucesso!')),
      );
      context.go('/financeiro');
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(widget.movimento == null ? 'Novo Lançamento' : 'Editar Lançamento'),
      ),
      body: _carregando
          ? const Center(child: CircularProgressIndicator())
          : SingleChildScrollView(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  TextField(
                    controller: historicoController,
                    decoration: const InputDecoration(
                      labelText: 'Histórico',
                      border: OutlineInputBorder(),
                    ),
                  ),
                  const SizedBox(height: 16),
                  TextField(
                    controller: valorController,
                    decoration: const InputDecoration(
                      labelText: 'Valor (R\$)',
                      border: OutlineInputBorder(),
                      prefixIcon: Icon(Icons.attach_money),
                    ),
                    keyboardType: const TextInputType.numberWithOptions(decimal: true),
                  ),
                  const SizedBox(height: 16),
                  // Campo de busca de conta (plano de contas)
                  Stack(
                    children: [
                      TextField(
                        controller: contaBuscaController,
                        decoration: InputDecoration(
                          labelText: 'Plano de Contas *',
                          border: const OutlineInputBorder(),
                          prefixIcon: const Icon(Icons.account_balance),
                          hintText: 'Digite para buscar...',
                          suffixIcon: _contaId != null
                              ? IconButton(
                                  icon: const Icon(Icons.clear),
                                  onPressed: () => setState(() {
                                    _contaId = null;
                                    contaBuscaController.clear();
                                  }),
                                )
                              : null,
                        ),
                        onChanged: _filtrarContas,
                        onTap: () {
                          if (contaBuscaController.text.isEmpty && _contas.isNotEmpty) {
                            setState(() {
                              _contasFiltradas = _contas;
                              _mostrarSugestoes = true;
                            });
                          }
                        },
                      ),
                      if (_mostrarSugestoes && _contasFiltradas.isNotEmpty)
                        Positioned(
                          top: 60,
                          left: 0,
                          right: 0,
                          child: Material(
                            elevation: 4,
                            child: Container(
                              constraints: const BoxConstraints(maxHeight: 200),
                              child: ListView.builder(
                                shrinkWrap: true,
                                itemCount: _contasFiltradas.length,
                                itemBuilder: (context, idx) {
                                  final conta = _contasFiltradas[idx];
                                  return ListTile(
                                    title: Text(conta.descricao),
                                    subtitle: Text(conta.isBanco ? 'Banco' : 'Caixa'),
                                    onTap: () => _selecionarConta(conta),
                                  );
                                },
                              ),
                            ),
                          ),
                        ),
                    ],
                  ),
                  const SizedBox(height: 16),
                  DropdownButtonFormField<String>(
                    initialValue: tipoSelecionado,
                    decoration: const InputDecoration(
                      labelText: 'Tipo',
                      border: OutlineInputBorder(),
                    ),
                    onChanged: (val) => setState(() => tipoSelecionado = val ?? 'C'),
                    items: const [
                      DropdownMenuItem(value: 'C', child: Text('Receita (entrada)')),
                      DropdownMenuItem(value: 'D', child: Text('Despesa (saída)')),
                    ],
                  ),
                  const SizedBox(height: 32),
                  SizedBox(
                    width: double.infinity,
                    child: ElevatedButton(
                      onPressed: _save,
                      child: const Text('Salvar'),
                    ),
                  ),
                ],
              ),
            ),
    );
  }
}
