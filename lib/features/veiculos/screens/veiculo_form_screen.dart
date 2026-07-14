import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:go_router/go_router.dart';
import '../models/veiculo_model.dart';
import '../viewmodels/veiculo_viewmodel.dart';

class VeiculoFormScreen extends StatefulWidget {
  final VeiculoModel? veiculo;

  const VeiculoFormScreen({super.key, this.veiculo});

  @override
  State<VeiculoFormScreen> createState() => _VeiculoFormScreenState();
}

class _VeiculoFormScreenState extends State<VeiculoFormScreen> {
  late TextEditingController placaController;
  late TextEditingController marcaController;
  late TextEditingController modeloController;
  late TextEditingController anoController;
  late TextEditingController renavamController;

  @override
  void initState() {
    super.initState();
    placaController = TextEditingController(text: widget.veiculo?.placa ?? '');
    marcaController = TextEditingController(text: widget.veiculo?.marca ?? '');
    modeloController = TextEditingController(text: widget.veiculo?.modelo ?? '');
    anoController = TextEditingController(text: widget.veiculo?.ano ?? '');
    renavamController = TextEditingController(text: widget.veiculo?.renavam ?? '');
  }

  @override
  void dispose() {
    placaController.dispose();
    marcaController.dispose();
    modeloController.dispose();
    anoController.dispose();
    renavamController.dispose();
    super.dispose();
  }

  void _save() async {
    final viewModel = context.read<VeiculoViewModel>();

    final v = VeiculoModel(
      id: widget.veiculo?.id,
      placa: placaController.text,
      marca: marcaController.text,
      modelo: modeloController.text,
      cor: 'Branco',
      ano: anoController.text,
      tipo: 'C',
      renavam: renavamController.text,
      status: 'A',
    );

    bool success;
    if (widget.veiculo == null) {
      success = await viewModel.createVeiculo(v);
    } else {
      success = await viewModel.updateVeiculo(v);
    }

    if (success && mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Veículo salvo com sucesso!')),
      );
      context.go('/veiculos');
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(widget.veiculo == null ? 'Novo Veículo' : 'Editar Veículo'),
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Column(
          children: [
            TextField(
              controller: placaController,
              decoration: const InputDecoration(labelText: 'Placa'),
            ),
            const SizedBox(height: 16),
            TextField(
              controller: marcaController,
              decoration: const InputDecoration(labelText: 'Marca'),
            ),
            const SizedBox(height: 16),
            TextField(
              controller: modeloController,
              decoration: const InputDecoration(labelText: 'Modelo'),
            ),
            const SizedBox(height: 16),
            TextField(
              controller: anoController,
              decoration: const InputDecoration(labelText: 'Ano'),
            ),
            const SizedBox(height: 16),
            TextField(
              controller: renavamController,
              decoration: const InputDecoration(labelText: 'Renavam'),
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
