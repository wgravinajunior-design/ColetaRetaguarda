import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:go_router/go_router.dart';
import '../../produtores/models/pessoa_model.dart';
import '../viewmodels/colaborador_viewmodel.dart';

class ColaboradorFormScreen extends StatefulWidget {
  final PessoaModel? colaborador;
  
  const ColaboradorFormScreen({super.key, this.colaborador});

  @override
  State<ColaboradorFormScreen> createState() => _ColaboradorFormScreenState();
}

class _ColaboradorFormScreenState extends State<ColaboradorFormScreen> {
  final _formKey = GlobalKey<FormState>();
  
  late TextEditingController _nomeController;
  late TextEditingController _cargoController;
  late TextEditingController _cpfController;
  late TextEditingController _telefoneController;

  @override
  void initState() {
    super.initState();
    _nomeController = TextEditingController(text: widget.colaborador?.rSocialNome ?? '');
    _cargoController = TextEditingController(text: widget.colaborador?.fantasiaApelido ?? '');
    _cpfController = TextEditingController(text: widget.colaborador?.cnpjCpf ?? '');
    _telefoneController = TextEditingController(text: widget.colaborador?.telefone ?? '');
  }

  @override
  void dispose() {
    _nomeController.dispose();
    _cargoController.dispose();
    _cpfController.dispose();
    _telefoneController.dispose();
    super.dispose();
  }

  void _save() async {
    if (_formKey.currentState!.validate()) {
      final viewModel = context.read<ColaboradorViewModel>();
      
      final pessoa = PessoaModel(
        id: widget.colaborador?.id,
        tipoPessoa: 'F',
        rSocialNome: _nomeController.text,
        fantasiaApelido: _cargoController.text,
        cnpjCpf: _cpfController.text,
        ieRg: widget.colaborador?.ieRg ?? '',
        endereco: widget.colaborador?.endereco ?? '',
        numero: widget.colaborador?.numero ?? '',
        complemento: widget.colaborador?.complemento ?? '',
        bairro: widget.colaborador?.bairro ?? '',
        cep: widget.colaborador?.cep ?? '',
        telefone: _telefoneController.text,
        celular: widget.colaborador?.celular ?? '',
        email: widget.colaborador?.email ?? '',
        contato: widget.colaborador?.contato ?? '',
        referencia: widget.colaborador?.referencia ?? '',
        status: widget.colaborador?.status ?? 'A',
        cliente: 'N',
        transportador: 'N',
        contribuinte: 'N',
      );

      final success = await viewModel.saveColaborador(pessoa);
      if (success && mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Colaborador salvo com sucesso!')),
        );
        context.pop();
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final isEditing = widget.colaborador != null;

    return Scaffold(
      appBar: AppBar(
        title: Text(isEditing ? 'Editar Colaborador' : 'Novo Colaborador'),
      ),
      body: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Card(
          child: Padding(
            padding: const EdgeInsets.all(24.0),
            child: Form(
              key: _formKey,
              child: ListView(
                children: [
                  TextFormField(
                    controller: _nomeController,
                    decoration: const InputDecoration(labelText: 'Nome Completo'),
                    validator: (v) => v!.isEmpty ? 'Campo obrigatório' : null,
                  ),
                  const SizedBox(height: 16),
                  TextFormField(
                    controller: _cargoController,
                    decoration: const InputDecoration(labelText: 'Cargo / Função'),
                  ),
                  const SizedBox(height: 16),
                  TextFormField(
                    controller: _cpfController,
                    decoration: const InputDecoration(labelText: 'CPF'),
                  ),
                  const SizedBox(height: 16),
                  TextFormField(
                    controller: _telefoneController,
                    decoration: const InputDecoration(labelText: 'Telefone'),
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
                        child: const Text('Salvar'),
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
