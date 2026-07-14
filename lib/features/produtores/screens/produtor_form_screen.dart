import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:go_router/go_router.dart';
import '../models/pessoa_model.dart';
import '../viewmodels/produtor_viewmodel.dart';

class ProdutorFormScreen extends StatefulWidget {
  final PessoaModel? produtor;
  
  const ProdutorFormScreen({super.key, this.produtor});

  @override
  State<ProdutorFormScreen> createState() => _ProdutorFormScreenState();
}

class _ProdutorFormScreenState extends State<ProdutorFormScreen> {
  final _formKey = GlobalKey<FormState>();
  
  late TextEditingController _nomeController;
  late TextEditingController _apelidoController;
  late TextEditingController _cpfCnpjController;
  late TextEditingController _telefoneController;
  late TextEditingController _cidadeController;

  @override
  void initState() {
    super.initState();
    _nomeController = TextEditingController(text: widget.produtor?.rSocialNome ?? '');
    _apelidoController = TextEditingController(text: widget.produtor?.fantasiaApelido ?? '');
    _cpfCnpjController = TextEditingController(text: widget.produtor?.cnpjCpf ?? '');
    _telefoneController = TextEditingController(text: widget.produtor?.telefone ?? '');
    _cidadeController = TextEditingController(text: widget.produtor?.bairro ?? '');
  }

  @override
  void dispose() {
    _nomeController.dispose();
    _apelidoController.dispose();
    _cpfCnpjController.dispose();
    _telefoneController.dispose();
    _cidadeController.dispose();
    super.dispose();
  }

  void _save() async {
    if (_formKey.currentState!.validate()) {
      final viewModel = context.read<ProdutorViewModel>();
      
      final pessoa = PessoaModel(
        id: widget.produtor?.id,
        tipoPessoa: 'P',
        rSocialNome: _nomeController.text,
        fantasiaApelido: _apelidoController.text,
        cnpjCpf: _cpfCnpjController.text,
        ieRg: widget.produtor?.ieRg ?? '',
        endereco: widget.produtor?.endereco ?? '',
        numero: widget.produtor?.numero ?? '',
        complemento: widget.produtor?.complemento ?? '',
        bairro: _cidadeController.text,
        cep: widget.produtor?.cep ?? '',
        telefone: _telefoneController.text,
        celular: widget.produtor?.celular ?? '',
        email: widget.produtor?.email ?? '',
        contato: widget.produtor?.contato ?? '',
        referencia: widget.produtor?.referencia ?? '',
        status: widget.produtor?.status ?? 'A',
        cliente: 'S',
        transportador: 'N',
        contribuinte: 'S',
      );

      final success = await viewModel.saveProdutor(pessoa);
      if (success && mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Produtor salvo com sucesso!')),
        );
        context.pop();
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final isEditing = widget.produtor != null;

    return Scaffold(
      appBar: AppBar(
        title: Text(isEditing ? 'Editar Produtor' : 'Novo Produtor'),
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
                    decoration: const InputDecoration(labelText: 'Nome / Razão Social'),
                    validator: (v) => v!.isEmpty ? 'Campo obrigatório' : null,
                  ),
                  const SizedBox(height: 16),
                  TextFormField(
                    controller: _apelidoController,
                    decoration: const InputDecoration(labelText: 'Apelido / Fantasia'),
                  ),
                  const SizedBox(height: 16),
                  TextFormField(
                    controller: _cpfCnpjController,
                    decoration: const InputDecoration(labelText: 'CPF / CNPJ'),
                  ),
                  const SizedBox(height: 16),
                  TextFormField(
                    controller: _telefoneController,
                    decoration: const InputDecoration(labelText: 'Telefone'),
                  ),
                  const SizedBox(height: 16),
                  TextFormField(
                    controller: _cidadeController,
                    decoration: const InputDecoration(labelText: 'Cidade/Bairro'),
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
