import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:go_router/go_router.dart';
import '../models/movimento_model.dart';
import '../viewmodels/financeiro_viewmodel.dart';

class FinanceiroFormScreen extends StatefulWidget {
  final MovimentoModel? movimento;

  const FinanceiroFormScreen({super.key, this.movimento});

  @override
  State<FinanceiroFormScreen> createState() => _FinanceiroFormScreenState();
}

class _FinanceiroFormScreenState extends State<FinanceiroFormScreen> {
  late TextEditingController historicoController;
  late TextEditingController valorController;
  late TextEditingController contaController;
  String tipoSelecionado = 'C';

  @override
  void initState() {
    super.initState();
    historicoController = TextEditingController(text: widget.movimento?.historico ?? '');
    valorController = TextEditingController(text: widget.movimento?.valor?.toString() ?? '');
    contaController = TextEditingController(text: widget.movimento?.conta?.toString() ?? '');
    tipoSelecionado = widget.movimento?.tipo ?? 'C';
  }

  @override
  void dispose() {
    historicoController.dispose();
    valorController.dispose();
    contaController.dispose();
    super.dispose();
  }

  void _save() async {
    final viewModel = context.read<FinanceiroViewModel>();

    final m = MovimentoModel(
      id: widget.movimento?.id,
      historico: historicoController.text,
      valor: double.tryParse(valorController.text) ?? 0.0,
      conta: int.tryParse(contaController.text) ?? 1,
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
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Column(
          children: [
            TextField(
              controller: historicoController,
              decoration: const InputDecoration(labelText: 'Histórico'),
            ),
            const SizedBox(height: 16),
            TextField(
              controller: valorController,
              decoration: const InputDecoration(labelText: 'Valor'),
              keyboardType: TextInputType.number,
            ),
            const SizedBox(height: 16),
            TextField(
              controller: contaController,
              decoration: const InputDecoration(labelText: 'Conta'),
              keyboardType: TextInputType.number,
            ),
            const SizedBox(height: 16),
            DropdownButton<String>(
              value: tipoSelecionado,
              onChanged: (String? val) {
                setState(() => tipoSelecionado = val ?? 'C');
              },
              items: const [
                DropdownMenuItem(value: 'C', child: Text('Receita')),
                DropdownMenuItem(value: 'D', child: Text('Despesa')),
              ],
            ),
            const SizedBox(height: 32),
            ElevatedButton(
              onPressed: _save,
              child: const Text('Salvar'),
            ),
          ],
        ),
      ),
    );
  }
}
