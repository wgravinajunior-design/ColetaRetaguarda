import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:go_router/go_router.dart';
import '../../produtores/models/pessoa_model.dart';
import '../viewmodels/motorista_viewmodel.dart';

class MotoristaFormScreen extends StatefulWidget {
  final PessoaModel? motorista;
  
  const MotoristaFormScreen({super.key, this.motorista});

  @override
  State<MotoristaFormScreen> createState() => _MotoristaFormScreenState();
}

class _MotoristaFormScreenState extends State<MotoristaFormScreen> {
  final _formKey = GlobalKey<FormState>();
  
  late TextEditingController _nomeController;
  late TextEditingController _apelidoController;
  late TextEditingController _cpfController;
  late TextEditingController _rgController;
  late TextEditingController _celularController;

  @override
  void initState() {
    super.initState();
    _nomeController = TextEditingController(text: widget.motorista?.rSocialNome ?? '');
    _apelidoController = TextEditingController(text: widget.motorista?.fantasiaApelido ?? '');
    _cpfController = TextEditingController(text: widget.motorista?.cnpjCpf ?? '');
    _rgController = TextEditingController(text: widget.motorista?.ieRg ?? '');
    _celularController = TextEditingController(text: widget.motorista?.celular ?? '');
  }

  @override
  void dispose() {
    _nomeController.dispose();
    _apelidoController.dispose();
    _cpfController.dispose();
    _rgController.dispose();
    _celularController.dispose();
    super.dispose();
  }

  void _save() async {
    if (_formKey.currentState!.validate()) {
      final viewModel = context.read<MotoristaViewModel>();
      
      final pessoa = PessoaModel(
        id: widget.motorista?.id,
        tipoPessoa: 'F',
        rSocialNome: _nomeController.text,
        fantasiaApelido: _apelidoController.text,
        cnpjCpf: _cpfController.text,
        ieRg: _rgController.text,
        endereco: widget.motorista?.endereco ?? '',
        numero: widget.motorista?.numero ?? '',
        complemento: widget.motorista?.complemento ?? '',
        bairro: widget.motorista?.bairro ?? '',
        cep: widget.motorista?.cep ?? '',
        telefone: widget.motorista?.telefone ?? '',
        celular: _celularController.text,
        email: widget.motorista?.email ?? '',
        contato: widget.motorista?.contato ?? '',
        referencia: widget.motorista?.referencia ?? '',
        status: widget.motorista?.status ?? 'A',
        cliente: 'N',
        transportador: 'S',
        contribuinte: 'N',
      );

      final success = await viewModel.saveMotorista(pessoa);
      if (success && mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Motorista salvo com sucesso!')),
        );
        context.pop();
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final isEditing = widget.motorista != null;

    return Scaffold(
      appBar: AppBar(
        title: Text(isEditing ? 'Editar Motorista' : 'Novo Motorista'),
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
                    controller: _apelidoController,
                    decoration: const InputDecoration(labelText: 'Apelido'),
                  ),
                  const SizedBox(height: 16),
                  TextFormField(
                    controller: _cpfController,
                    decoration: const InputDecoration(labelText: 'CPF'),
                  ),
                  const SizedBox(height: 16),
                  TextFormField(
                    controller: _rgController,
                    decoration: const InputDecoration(labelText: 'RG'),
                  ),
                  const SizedBox(height: 16),
                  TextFormField(
                    controller: _celularController,
                    decoration: const InputDecoration(labelText: 'Celular'),
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
