import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:go_router/go_router.dart';
import '../models/rota_model.dart';
import '../viewmodels/rota_viewmodel.dart';

class RotaFormScreen extends StatefulWidget {
  final RotaModel? rota;

  const RotaFormScreen({super.key, this.rota});

  @override
  State<RotaFormScreen> createState() => _RotaFormScreenState();
}

class _RotaFormScreenState extends State<RotaFormScreen> {
  late TextEditingController descricaoController;
  late TextEditingController regiaoController;
  late TextEditingController paradasController;
  late TextEditingController kmEstimadoController;

  @override
  void initState() {
    super.initState();
    descricaoController = TextEditingController(text: widget.rota?.descricao ?? '');
    regiaoController = TextEditingController(text: widget.rota?.regiao ?? '');
    paradasController = TextEditingController(text: widget.rota?.paradas?.toString() ?? '');
    kmEstimadoController = TextEditingController(text: widget.rota?.kmEstimado?.toString() ?? '');
  }

  @override
  void dispose() {
    descricaoController.dispose();
    regiaoController.dispose();
    paradasController.dispose();
    kmEstimadoController.dispose();
    super.dispose();
  }

  void _save() async {
    final viewModel = context.read<RotaViewModel>();

    final r = RotaModel(
      id: widget.rota?.id,
      descricao: descricaoController.text,
      regiao: regiaoController.text,
      paradas: int.tryParse(paradasController.text) ?? 0,
      kmEstimado: double.tryParse(kmEstimadoController.text) ?? 0.0,
      status: 'A',
    );

    bool success;
    if (widget.rota == null) {
      success = await viewModel.createRota(r);
    } else {
      success = await viewModel.updateRota(r);
    }

    if (success && mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Rota salva com sucesso!')),
      );
      context.go('/rotas');
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(widget.rota == null ? 'Nova Rota' : 'Editar Rota'),
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Column(
          children: [
            TextField(
              controller: descricaoController,
              decoration: const InputDecoration(labelText: 'Descrição'),
            ),
            const SizedBox(height: 16),
            TextField(
              controller: regiaoController,
              decoration: const InputDecoration(labelText: 'Região'),
            ),
            const SizedBox(height: 16),
            TextField(
              controller: paradasController,
              decoration: const InputDecoration(labelText: 'Paradas'),
              keyboardType: TextInputType.number,
            ),
            const SizedBox(height: 16),
            TextField(
              controller: kmEstimadoController,
              decoration: const InputDecoration(labelText: 'KM Estimado'),
              keyboardType: TextInputType.number,
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
