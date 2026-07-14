import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:go_router/go_router.dart';
import '../models/motorista_model.dart';
import '../viewmodels/motorista_viewmodel.dart';

class MotoristaFormScreen extends StatefulWidget {
  final MotoristaModel? motorista;

  const MotoristaFormScreen({super.key, this.motorista});

  @override
  State<MotoristaFormScreen> createState() => _MotoristaFormScreenState();
}

class _MotoristaFormScreenState extends State<MotoristaFormScreen> {
  late TextEditingController nomeController;
  late TextEditingController cpfController;
  late TextEditingController cnhController;
  late TextEditingController celularController;
  late TextEditingController emailController;

  @override
  void initState() {
    super.initState();
    nomeController = TextEditingController(text: widget.motorista?.nome ?? '');
    cpfController = TextEditingController(text: widget.motorista?.cpf ?? '');
    cnhController = TextEditingController(text: widget.motorista?.cnh ?? '');
    celularController = TextEditingController(text: widget.motorista?.celular ?? '');
    emailController = TextEditingController(text: widget.motorista?.email ?? '');
  }

  @override
  void dispose() {
    nomeController.dispose();
    cpfController.dispose();
    cnhController.dispose();
    celularController.dispose();
    emailController.dispose();
    super.dispose();
  }

  void _save() async {
    final viewModel = context.read<MotoristaViewModel>();

    final m = MotoristaModel(
      id: widget.motorista?.id,
      nome: nomeController.text,
      cpf: cpfController.text,
      cnh: cnhController.text,
      celular: celularController.text,
      email: emailController.text,
      status: 'A',
    );

    bool success;
    if (widget.motorista == null) {
      success = await viewModel.createMotorista(m);
    } else {
      success = await viewModel.updateMotorista(m);
    }

    if (success && mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Motorista salvo com sucesso!')),
      );
      context.go('/motoristas');
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(widget.motorista == null ? 'Novo Motorista' : 'Editar Motorista'),
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
              controller: cnhController,
              decoration: const InputDecoration(labelText: 'CNH'),
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
