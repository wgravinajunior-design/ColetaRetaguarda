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
          style: const TextStyle(fontSize: 13),
          decoration: InputDecoration(
            labelText: 'Cidade',
            labelStyle: const TextStyle(fontSize: 12),
            hintText: 'Digite ao menos 2 letras...',
            hintStyle: const TextStyle(fontSize: 12),
            border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
            isDense: true,
            contentPadding: const EdgeInsets.symmetric(horizontal: 10, vertical: 10),
            prefixIcon: const Icon(Icons.location_city, size: 18),
            suffixIcon: _cidadeId != null
                ? IconButton(
                    icon: const Icon(Icons.clear, size: 18),
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

  Widget _campo(TextEditingController c, String label, {IconData? icone}) {
    return TextField(
      controller: c,
      style: const TextStyle(fontSize: 13),
      decoration: InputDecoration(
        labelText: label,
        labelStyle: const TextStyle(fontSize: 12),
        border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
        isDense: true,
        contentPadding: const EdgeInsets.symmetric(horizontal: 10, vertical: 10),
        prefixIcon: icone != null ? Icon(icone, size: 18) : null,
      ),
    );
  }

  Widget _secaoCard(String titulo, IconData icone, List<Widget> campos) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.grey.shade200),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(children: [
            Container(
              padding: const EdgeInsets.all(6),
              decoration: BoxDecoration(
                color: Colors.blue.withValues(alpha: 0.1),
                borderRadius: BorderRadius.circular(8),
              ),
              child: Icon(icone, size: 15, color: Colors.blue[700]),
            ),
            const SizedBox(width: 8),
            Text(
              titulo,
              style: TextStyle(
                fontWeight: FontWeight.w600,
                fontSize: 13,
                color: Colors.blue[700],
              ),
            ),
          ]),
          const SizedBox(height: 10),
          for (final campo in campos) ...[
            campo,
            const SizedBox(height: 10),
          ],
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF3F5F4),
      appBar: AppBar(
        title: Text(widget.motorista == null ? 'Novo Motorista' : 'Editar Motorista'),
        elevation: 0,
      ),
      body: LayoutBuilder(
        builder: (context, constraints) {
          final duasColunas = constraints.maxWidth >= 760;

          final colunaEsquerda = _secaoCard('Dados pessoais', Icons.person, [
            _campo(nomeController, 'Nome', icone: Icons.badge_outlined),
            Row(children: [
              Expanded(child: _campo(cpfController, 'CPF')),
              const SizedBox(width: 12),
              Expanded(child: _campo(rgController, 'RG')),
            ]),
            _campo(cnhController, 'CNH', icone: Icons.credit_card),
          ]);

          final colunaDireita = _secaoCard('Contato', Icons.phone, [
            Row(children: [
              Expanded(child: _campo(celularController, 'Celular', icone: Icons.smartphone)),
              const SizedBox(width: 12),
              Expanded(child: _campo(emailController, 'Email', icone: Icons.email_outlined)),
            ]),
            _buildCampoCidade(),
          ]);

          return SingleChildScrollView(
            padding: const EdgeInsets.all(12),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                if (duasColunas)
                  Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Expanded(child: colunaEsquerda),
                      const SizedBox(width: 12),
                      Expanded(child: colunaDireita),
                    ],
                  )
                else ...[
                  colunaEsquerda,
                  const SizedBox(height: 10),
                  colunaDireita,
                ],
                const SizedBox(height: 16),
                SizedBox(
                  width: double.infinity,
                  child: ElevatedButton(
                    onPressed: _save,
                    style: ElevatedButton.styleFrom(
                      backgroundColor: const Color(0xFF2E7D4F),
                      padding: const EdgeInsets.symmetric(vertical: 13),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(10),
                      ),
                    ),
                    child: const Text(
                      'Salvar',
                      style: TextStyle(color: Colors.white, fontWeight: FontWeight.w600),
                    ),
                  ),
                ),
              ],
            ),
          );
        },
      ),
    );
  }
}
