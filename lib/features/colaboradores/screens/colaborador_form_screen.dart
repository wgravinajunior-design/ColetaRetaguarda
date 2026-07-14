import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:go_router/go_router.dart';
import '../models/colaborador_model.dart';
import '../viewmodels/colaborador_viewmodel.dart';

class ColaboradorFormScreen extends StatefulWidget {
  final ColaboradorModel? colaborador;
  
  const ColaboradorFormScreen({super.key, this.colaborador});

  @override
  State<ColaboradorFormScreen> createState() => _ColaboradorFormScreenState();
}

class _ColaboradorFormScreenState extends State<ColaboradorFormScreen> {
  late TextEditingController nomeController;
  late TextEditingController cpfController;
  late TextEditingController funcaoController;
  late TextEditingController celularController;
  late TextEditingController emailController;

  @override
  void initState() {
    super.initState();
    nomeController = TextEditingController(text: widget.colaborador?.nome ?? '');
    cpfController = TextEditingController(text: widget.colaborador?.cpf ?? '');
    funcaoController = TextEditingController(text: widget.colaborador?.funcao ?? '');
    celularController = TextEditingController(text: widget.colaborador?.celular ?? '');
    emailController = TextEditingController(text: widget.colaborador?.email ?? '');
  }

  @override
  void dispose() {
    nomeController.dispose();
    cpfController.dispose();
    funcaoController.dispose();
    celularController.dispose();
    emailController.dispose();
    super.dispose();
  }

  void _save() async {
    final viewModel = context.read<ColaboradorViewModel>();

    final c = ColaboradorModel(
      id: widget.colaborador?.id,
      nome: nomeController.text,
      cpf: cpfController.text,
      funcao: funcaoController.text,
      celular: celularController.text,
      email: emailController.text,
      status: 'A',
    );

    bool success;
    if (widget.colaborador == null) {
      success = await viewModel.createColaborador(c);
    } else {
      success = await viewModel.updateColaborador(c);
    }

    if (success && mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Colaborador salvo com sucesso!')),
      );
      context.go('/colaboradores');
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(widget.colaborador == null ? 'Novo Colaborador' : 'Editar Colaborador'),
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Column(
          children: [
            TextField(
              controller: nomeController,
              decoration: const InputDecoration(labelText: 'Nome'),
            ),
            const SizedBox(height: 16),
            TextField(
              controller: cpfController,
              decoration: const InputDecoration(labelText: 'CPF'),
            ),
            const SizedBox(height: 16),
            TextField(
              controller: funcaoController,
              decoration: const InputDecoration(labelText: 'Função'),
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
