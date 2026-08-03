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
      // Sem isto o lançamento nascia como 'MANUAL' e o próprio financeiro da
      // coleta não o mostrava, por não reconhecê-lo como seu.
      origem: MovimentoModel.origemColeta,
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
      backgroundColor: const Color(0xFFF3F5F4),
      appBar: AppBar(
        title: Text(widget.movimento == null ? 'Novo Lançamento' : 'Editar Lançamento'),
        elevation: 0,
      ),
      body: _carregando
          ? const Center(child: CircularProgressIndicator())
          : SingleChildScrollView(
              padding: const EdgeInsets.all(12),
              child: Center(
                child: ConstrainedBox(
                  constraints: const BoxConstraints(maxWidth: 560),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      Container(
                        padding: const EdgeInsets.all(12),
                        decoration: BoxDecoration(
                          color: Colors.white,
                          borderRadius: BorderRadius.circular(12),
                          border: Border.all(color: Colors.grey.shade200),
                        ),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            TextField(
                              controller: historicoController,
                              style: const TextStyle(fontSize: 13),
                              decoration: InputDecoration(
                                labelText: 'Histórico',
                                labelStyle: const TextStyle(fontSize: 12),
                                border: OutlineInputBorder(
                                  borderRadius: BorderRadius.circular(8),
                                ),
                                isDense: true,
                                contentPadding: const EdgeInsets.symmetric(
                                  horizontal: 10,
                                  vertical: 10,
                                ),
                              ),
                            ),
                            const SizedBox(height: 10),
                            TextField(
                              controller: valorController,
                              style: const TextStyle(fontSize: 13),
                              decoration: InputDecoration(
                                labelText: 'Valor (R\$)',
                                labelStyle: const TextStyle(fontSize: 12),
                                border: OutlineInputBorder(
                                  borderRadius: BorderRadius.circular(8),
                                ),
                                isDense: true,
                                contentPadding: const EdgeInsets.symmetric(
                                  horizontal: 10,
                                  vertical: 10,
                                ),
                                prefixIcon: const Icon(Icons.attach_money, size: 18),
                              ),
                              keyboardType: const TextInputType.numberWithOptions(decimal: true),
                            ),
                            const SizedBox(height: 10),
                            // Campo de busca de conta (plano de contas)
                            Stack(
                              children: [
                                TextField(
                                  controller: contaBuscaController,
                                  style: const TextStyle(fontSize: 13),
                                  decoration: InputDecoration(
                                    labelText: 'Plano de Contas *',
                                    labelStyle: const TextStyle(fontSize: 12),
                                    border: OutlineInputBorder(
                                      borderRadius: BorderRadius.circular(8),
                                    ),
                                    isDense: true,
                                    contentPadding: const EdgeInsets.symmetric(
                                      horizontal: 10,
                                      vertical: 10,
                                    ),
                                    prefixIcon: const Icon(Icons.account_balance, size: 18),
                                    hintText: 'Digite para buscar...',
                                    hintStyle: const TextStyle(fontSize: 12),
                                    suffixIcon: _contaId != null
                                        ? IconButton(
                                            icon: const Icon(Icons.clear, size: 18),
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
                                    top: 52,
                                    left: 0,
                                    right: 0,
                                    child: Material(
                                      elevation: 3,
                                      borderRadius: BorderRadius.circular(8),
                                      child: Container(
                                        constraints: const BoxConstraints(maxHeight: 200),
                                        decoration: BoxDecoration(
                                          borderRadius: BorderRadius.circular(8),
                                          border: Border.all(color: Colors.grey.shade200),
                                        ),
                                        child: ListView.builder(
                                          shrinkWrap: true,
                                          itemCount: _contasFiltradas.length,
                                          itemBuilder: (context, idx) {
                                            final conta = _contasFiltradas[idx];
                                            return ListTile(
                                              dense: true,
                                              visualDensity: VisualDensity.compact,
                                              title: Text(
                                                conta.descricao,
                                                style: const TextStyle(fontSize: 13),
                                              ),
                                              subtitle: Text(
                                                conta.isBanco ? 'Banco' : 'Caixa',
                                                style: const TextStyle(fontSize: 11),
                                              ),
                                              onTap: () => _selecionarConta(conta),
                                            );
                                          },
                                        ),
                                      ),
                                    ),
                                  ),
                              ],
                            ),
                            const SizedBox(height: 10),
                            DropdownButtonFormField<String>(
                              initialValue: tipoSelecionado,
                              style: const TextStyle(fontSize: 13, color: Colors.black87),
                              decoration: InputDecoration(
                                labelText: 'Tipo',
                                labelStyle: const TextStyle(fontSize: 12),
                                border: OutlineInputBorder(
                                  borderRadius: BorderRadius.circular(8),
                                ),
                                isDense: true,
                                contentPadding: const EdgeInsets.symmetric(
                                  horizontal: 10,
                                  vertical: 10,
                                ),
                              ),
                              onChanged: (val) => setState(() => tipoSelecionado = val ?? 'C'),
                              items: const [
                                DropdownMenuItem(value: 'C', child: Text('Receita (entrada)')),
                                DropdownMenuItem(value: 'D', child: Text('Despesa (saída)')),
                              ],
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(height: 16),
                      SizedBox(
                        width: double.infinity,
                        child: ElevatedButton(
                          onPressed: _save,
                          style: ElevatedButton.styleFrom(
                            backgroundColor: const Color(0xFF2E7D4F),
                            padding: const EdgeInsets.symmetric(vertical: 13),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(10),
                            ),
                          ),
                          child: const Text(
                            'Salvar',
                            style: TextStyle(color: Colors.white, fontWeight: FontWeight.w600),
                          ),
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
