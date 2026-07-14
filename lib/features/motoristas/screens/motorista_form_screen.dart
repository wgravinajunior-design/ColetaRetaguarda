import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:go_router/go_router.dart';
import '../models/motorista_model.dart';
import '../viewmodels/motorista_viewmodel.dart';
import '../../core/database/firebird_service.dart';

class MotoristaFormScreen extends StatefulWidget {
  final MotoristaModel? motorista;

  const MotoristaFormScreen({super.key, this.motorista});

  @override
  State<MotoristaFormScreen> createState() => _MotoristaFormScreenState();
}

class _MotoristaFormScreenState extends State<MotoristaFormScreen> {
  late TextEditingController nomeController;
  late TextEditingController cpfController;
  late TextEditingController rgController;
  late TextEditingController cnhController;
  late TextEditingController celularController;
  late TextEditingController emailController;
  late TextEditingController cidadeController;

  final _firebird = FirebirdService();
  int? _cidadeId;

  @override
  void initState() {
    super.initState();
    nomeController = TextEditingController(text: widget.motorista?.nome ?? '');
    cpfController = TextEditingController(text: widget.motorista?.cpf ?? '');
    rgController = TextEditingController(text: widget.motorista?.rg ?? '');
    cnhController = TextEditingController(text: widget.motorista?.cnh ?? '');
    celularController = TextEditingController(text: widget.motorista?.celular ?? '');
    emailController = TextEditingController(text: widget.motorista?.email ?? '');
    _cidadeId = widget.motorista?.cidadeId;
    cidadeController = TextEditingController(text: widget.motorista?.cidadeNome ?? '');
  }

  @override
  void dispose() {
    nomeController.dispose();
    cpfController.dispose();
    rgController.dispose();
    cnhController.dispose();
    celularController.dispose();
    emailController.dispose();
    cidadeController.dispose();
    super.dispose();
  }

  void _save() async {
    final viewModel = context.read<MotoristaViewModel>();

    final m = MotoristaModel(
      id: widget.motorista?.id,
      nome: nomeController.text,
      cpf: cpfController.text,
      rg: rgController.text,
      cnh: cnhController.text,
      celular: celularController.text,
      email: emailController.text,
      cidadeId: _cidadeId,
      cidadeNome: cidadeController.text,
      status: widget.motorista?.status ?? 'A',
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

  Widget _buildCampoCidade() {
    return Autocomplete<OpcaoRef>(
      initialValue: TextEditingValue(text: widget.motorista?.cidadeNome ?? ''),
      displayStringForOption: (o) => o.label,
      optionsBuilder: (value) async {
        final termo = value.text.trim();
        if (termo.length < 2) return const Iterable<OpcaoRef>.empty();
        try {
          return await _firebird.buscarCidades(termo);
        } catch (_) {
          return const Iterable<OpcaoRef>.empty();
        }
      },
      onSelected: (o) {
        setState(() {
          _cidadeId = o.id;
          cidadeController.text = o.label;
        });
      },
      fieldViewBuilder: (context, controller, focusNode, onSubmit) {
        return TextField(
          controller: controller,
          focusNode: focusNode,
          decoration: InputDecoration(
            labelText: 'Cidade',
            hintText: 'Digite ao menos 2 letras...',
            border: const OutlineInputBorder(),
            prefixIcon: const Icon(Icons.location_city),
            suffixIcon: _cidadeId != null
                ? IconButton(
                    icon: const Icon(Icons.clear),
                    onPressed: () {
                      controller.clear();
                      setState(() {
                        _cidadeId = null;
                        cidadeController.clear();
                      });
                    },
                  )
                : null,
          ),
          onChanged: (_) {
            // Ao digitar de novo, invalida a seleção anterior até escolher outra
            if (_cidadeId != null) setState(() => _cidadeId = null);
          },
        );
      },
      optionsViewBuilder: (context, onSelected, options) {
        return Align(
          alignment: Alignment.topLeft,
          child: Material(
            elevation: 4,
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxHeight: 240, maxWidth: 400),
              child: ListView(
                padding: EdgeInsets.zero,
                shrinkWrap: true,
                children: options
                    .map((o) => ListTile(
                          dense: true,
                          title: Text(o.label),
                          onTap: () => onSelected(o),
                        ))
                    .toList(),
              ),
            ),
          ),
        );
      },
    );
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
              controller: rgController,
              decoration: const InputDecoration(labelText: 'RG'),
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
            const SizedBox(height: 16),
            _buildCampoCidade(),
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
