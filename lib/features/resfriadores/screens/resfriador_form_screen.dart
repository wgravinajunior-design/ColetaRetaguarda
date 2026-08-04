import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:go_router/go_router.dart';
import '../models/resfriador_model.dart';
import '../viewmodels/resfriador_viewmodel.dart';

class ResfriadorFormScreen extends StatefulWidget {
  final ResfriadorModel? resfriador;

  const ResfriadorFormScreen({super.key, this.resfriador});

  @override
  State<ResfriadorFormScreen> createState() => _ResfriadorFormScreenState();
}

class _ResfriadorFormScreenState extends State<ResfriadorFormScreen> {
  late TextEditingController numeroController;
  late TextEditingController marcaController;
  late TextEditingController capacidadeController;
  late TextEditingController anoController;
  String _status = 'ATIVO';
  DateTime? _ultimaManutencao;

  @override
  void initState() {
    super.initState();
    final r = widget.resfriador;
    numeroController = TextEditingController(text: r?.numeroId ?? '');
    marcaController = TextEditingController(text: r?.marcaModelo ?? '');
    capacidadeController = TextEditingController(text: r?.capacidadeLitros.toString() ?? '');
    anoController = TextEditingController(text: r?.anoFabricacao?.toString() ?? '');
    _status = r?.status.isNotEmpty == true ? r!.status : 'ATIVO';
    if (r?.ultimaManutencao != null && r!.ultimaManutencao!.isNotEmpty) {
      _ultimaManutencao = DateTime.tryParse(r.ultimaManutencao!);
    }
  }

  @override
  void dispose() {
    numeroController.dispose();
    marcaController.dispose();
    capacidadeController.dispose();
    anoController.dispose();
    super.dispose();
  }

  Future<void> _selecionarData() async {
    final d = await showDatePicker(
      context: context,
      initialDate: _ultimaManutencao ?? DateTime.now(),
      firstDate: DateTime(2000),
      lastDate: DateTime(2100),
    );
    if (d != null) setState(() => _ultimaManutencao = d);
  }

  void _save() async {
    if (numeroController.text.trim().isEmpty || marcaController.text.trim().isEmpty) {
      _erro('Preencha número/identificador e marca/modelo');
      return;
    }
    final capacidade = double.tryParse(capacidadeController.text.replaceAll(',', '.'));
    if (capacidade == null || capacidade <= 0) {
      _erro('Informe a capacidade em litros');
      return;
    }

    final vm = context.read<ResfriadorViewModel>();
    final r = ResfriadorModel(
      id: widget.resfriador?.id,
      numeroId: numeroController.text.trim(),
      marcaModelo: marcaController.text.trim(),
      capacidadeLitros: capacidade,
      anoFabricacao: int.tryParse(anoController.text),
      ultimaManutencao: _ultimaManutencao?.toIso8601String().split('T').first,
      status: _status,
    );

    final ok = widget.resfriador == null ? await vm.create(r) : await vm.update(r);
    if (ok && mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Resfriador salvo!'), backgroundColor: Colors.green),
      );
      context.go('/resfriadores');
    } else if (mounted) {
      _erro(vm.errorMessage ?? 'Não foi possível salvar');
    }
  }

  void _erro(String msg) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(msg), backgroundColor: Colors.red),
    );
  }

  String _dataFmt(DateTime d) {
    String dois(int n) => n.toString().padLeft(2, '0');
    return '${dois(d.day)}/${dois(d.month)}/${d.year}';
  }

  Widget _campo(
    TextEditingController c,
    String label, {
    String? hint,
    TextInputType? teclado,
  }) {
    return TextField(
      controller: c,
      keyboardType: teclado,
      style: const TextStyle(fontSize: 13),
      decoration: InputDecoration(
        labelText: label,
        labelStyle: const TextStyle(fontSize: 12),
        hintText: hint,
        hintStyle: const TextStyle(fontSize: 12),
        border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
        isDense: true,
        contentPadding: const EdgeInsets.symmetric(horizontal: 10, vertical: 10),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF3F5F4),
      appBar: AppBar(
        title: Text(widget.resfriador == null ? 'Novo Resfriador' : 'Editar Resfriador'),
        elevation: 0,
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(12),
        child: Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 560),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(color: Colors.grey.shade200),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      _campo(
                        numeroController,
                        'Número / Identificador *',
                        hint: 'ex: RES-001',
                      ),
                      const SizedBox(height: 10),
                      _campo(marcaController, 'Marca e Modelo *'),
                      const SizedBox(height: 10),
                      Row(children: [
                        Expanded(
                          child: _campo(
                            capacidadeController,
                            'Capacidade (L) *',
                            teclado: const TextInputType.numberWithOptions(decimal: true),
                          ),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: _campo(
                            anoController,
                            'Ano fabricação',
                            teclado: TextInputType.number,
                          ),
                        ),
                      ]),
                      const SizedBox(height: 10),
                      InkWell(
                        onTap: _selecionarData,
                        child: InputDecorator(
                          decoration: InputDecoration(
                            labelText: 'Última manutenção',
                            labelStyle: const TextStyle(fontSize: 12),
                            border: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(8),
                            ),
                            isDense: true,
                            contentPadding: const EdgeInsets.symmetric(
                              horizontal: 10,
                              vertical: 10,
                            ),
                            prefixIcon: const Icon(Icons.build, size: 18),
                          ),
                          child: Text(
                            _ultimaManutencao == null
                                ? '--/--/----'
                                : _dataFmt(_ultimaManutencao!),
                            style: const TextStyle(fontSize: 13),
                          ),
                        ),
                      ),
                      const SizedBox(height: 10),
                      DropdownButtonFormField<String>(
                        initialValue: _status,
                        style: const TextStyle(fontSize: 13, color: Colors.black87),
                        decoration: InputDecoration(
                          labelText: 'Status',
                          labelStyle: const TextStyle(fontSize: 12),
                          border: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(8),
                          ),
                          isDense: true,
                          contentPadding: const EdgeInsets.symmetric(
                            horizontal: 10,
                            vertical: 10,
                          ),
                        ),
                        items: const [
                          DropdownMenuItem(value: 'ATIVO', child: Text('Ativo')),
                          DropdownMenuItem(
                            value: 'MANUTENCAO',
                            child: Text('Em manutenção'),
                          ),
                          DropdownMenuItem(value: 'INATIVO', child: Text('Inativo')),
                        ],
                        onChanged: (v) => setState(() => _status = v ?? 'ATIVO'),
                      ),
                    ],
                  ),
                ),
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
          ),
        ),
      ),
    );
  }
}
