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
  String tipoSelecionado = 'C';

  final _firebird = FirebirdService();
  List<ContaRef> _contas = [];
  int? _contaId;
  bool _carregando = true;

  @override
  void initState() {
    super.initState();
    historicoController = TextEditingController(text: widget.movimento?.historico ?? '');
    valorController = TextEditingController(text: widget.movimento?.valor.toString() ?? '');
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
    super.dispose();
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
                  DropdownButtonFormField<int>(
                    initialValue: _contaId,
                    isExpanded: true,
                    decoration: const InputDecoration(
                      labelText: 'Conta *',
                      border: OutlineInputBorder(),
                      prefixIcon: Icon(Icons.account_balance),
                    ),
                    items: _contas
                        .map((c) => DropdownMenuItem(
                              value: c.id,
                              child: Text('${c.descricao} (${c.isBanco ? 'Banco' : 'Caixa'})'),
                            ))
                        .toList(),
                    onChanged: (v) => setState(() => _contaId = v),
                    hint: _contas.isEmpty ? const Text('Nenhuma conta cadastrada') : null,
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
