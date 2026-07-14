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
  late TextEditingController nomeController;
  late TextEditingController cnpjCpfController;
  late TextEditingController enderecoController;
  late TextEditingController celularController;
  late TextEditingController emailController;

  @override
  void initState() {
    super.initState();
    nomeController = TextEditingController(text: widget.produtor?.rSocialNome ?? '');
    cnpjCpfController = TextEditingController(text: widget.produtor?.cnpjCpf ?? '');
    enderecoController = TextEditingController(text: widget.produtor?.endereco ?? '');
    celularController = TextEditingController(text: widget.produtor?.celular ?? '');
    emailController = TextEditingController(text: widget.produtor?.email ?? '');
  }

  @override
  void dispose() {
    nomeController.dispose();
    cnpjCpfController.dispose();
    enderecoController.dispose();
    celularController.dispose();
    emailController.dispose();
    super.dispose();
  }

  void _save() async {
    final viewModel = context.read<ProdutorViewModel>();

    final p = PessoaModel(
      id: widget.produtor?.id,
      rSocialNome: nomeController.text,
      cnpjCpf: cnpjCpfController.text,
      endereco: enderecoController.text,
      celular: celularController.text,
      email: emailController.text,
      status: 'A',
      cliente: true,
    );

    bool success;
    if (widget.produtor == null) {
      success = await viewModel.createProdutor(p);
    } else {
      success = await viewModel.updateProdutor(p);
    }

    if (success && mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Produtor salvo com sucesso!')),
      );
      context.go('/produtores');
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(widget.produtor == null ? 'Novo Produtor' : 'Editar Produtor'),
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Column(
          children: [
            TextField(
              controller: nomeController,
              decoration: const InputDecoration(labelText: 'Razão Social'),
            ),
            const SizedBox(height: 16),
            TextField(
              controller: cnpjCpfController,
              decoration: const InputDecoration(labelText: 'CNPJ/CPF'),
            ),
            const SizedBox(height: 16),
            TextField(
              controller: enderecoController,
              decoration: const InputDecoration(labelText: 'Endereço'),
            ),
            const SizedBox(height: 16),
            TextField(
              controller: celularController,
              decoration: const InputDecoration(labelText: 'Celular'),
            ),
            const SizedBox(height: 16),
            TextField(
              controller: emailController,
              decoration: const InputDecoration(labelText: 'Email'),
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
