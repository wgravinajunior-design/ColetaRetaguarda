import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';
import '../models/movimento_model.dart';
import '../viewmodels/financeiro_viewmodel.dart';

class FinanceiroFormScreen extends StatefulWidget {
  const FinanceiroFormScreen({super.key});

  @override
  State<FinanceiroFormScreen> createState() => _FinanceiroFormScreenState();
}

class _FinanceiroFormScreenState extends State<FinanceiroFormScreen> {
  final _formKey = GlobalKey<FormState>();
  
  late TextEditingController _historicoController;
  late TextEditingController _valorController;
  late TextEditingController _dataController;
  
  String _tipo = 'C'; // C = Receita, D = Despesa
  
  @override
  void initState() {
    super.initState();
    _historicoController = TextEditingController();
    _valorController = TextEditingController();
    _dataController = TextEditingController(text: DateFormat('yyyy-MM-dd').format(DateTime.now()));
  }

  @override
  void dispose() {
    _historicoController.dispose();
    _valorController.dispose();
    _dataController.dispose();
    super.dispose();
  }

  void _save() async {
    if (_formKey.currentState!.validate()) {
      final viewModel = context.read<FinanceiroViewModel>();
      
      final mov = MovimentoModel(
        tipo: _tipo,
        historico: _historicoController.text,
        valor: double.tryParse(_valorController.text.replaceAll(',', '.')) ?? 0.0,
        dtEmissao: _dataController.text,
        conta: 1, // Fixando conta padrão 1 como pedido
      );

      final success = await viewModel.saveMovimento(mov);
      if (success && mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Lançamento salvo com sucesso!')),
        );
        context.pop();
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Novo Lançamento Financeiro'),
      ),
      body: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 600),
          child: Padding(
            padding: const EdgeInsets.all(16.0),
            child: Card(
              child: Padding(
                padding: const EdgeInsets.all(24.0),
                child: Form(
                  key: _formKey,
                  child: ListView(
                    shrinkWrap: true,
                    children: [
                      Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          ChoiceChip(
                            label: const Text('Receita (Crédito)'),
                            selected: _tipo == 'C',
                            selectedColor: Colors.green.withOpacity(0.3),
                            onSelected: (val) {
                              if (val) setState(() => _tipo = 'C');
                            },
                          ),
                          const SizedBox(width: 16),
                          ChoiceChip(
                            label: const Text('Despesa (Débito)'),
                            selected: _tipo == 'D',
                            selectedColor: Colors.red.withOpacity(0.3),
                            onSelected: (val) {
                              if (val) setState(() => _tipo = 'D');
                            },
                          ),
                        ],
                      ),
                      const SizedBox(height: 24),
                      TextFormField(
                        controller: _historicoController,
                        decoration: const InputDecoration(labelText: 'Histórico / Descrição'),
                        validator: (v) => v!.isEmpty ? 'Campo obrigatório' : null,
                      ),
                      const SizedBox(height: 16),
                      TextFormField(
                        controller: _valorController,
                        decoration: const InputDecoration(
                          labelText: 'Valor (R\$)',
                          prefixText: 'R\$ ',
                        ),
                        keyboardType: const TextInputType.numberWithOptions(decimal: true),
                        validator: (v) {
                          if (v!.isEmpty) return 'Campo obrigatório';
                          if (double.tryParse(v.replaceAll(',', '.')) == null) return 'Valor inválido';
                          return null;
                        },
                      ),
                      const SizedBox(height: 16),
                      TextFormField(
                        controller: _dataController,
                        decoration: const InputDecoration(labelText: 'Data Emissão (YYYY-MM-DD)'),
                        validator: (v) => v!.isEmpty ? 'Campo obrigatório' : null,
                      ),
                      const SizedBox(height: 32),
                      Row(
                        mainAxisAlignment: MainAxisAlignment.end,
                        children: [
                          TextButton(
                            onPressed: () => context.pop(),
                            child: const Text('Cancelar'),
                          ),
                          const SizedBox(width: 16),
                          ElevatedButton(
                            onPressed: _save,
                            style: ElevatedButton.styleFrom(
                              backgroundColor: _tipo == 'C' ? Colors.green : Colors.red,
                              foregroundColor: Colors.white,
                            ),
                            child: const Text('Lançar'),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}
