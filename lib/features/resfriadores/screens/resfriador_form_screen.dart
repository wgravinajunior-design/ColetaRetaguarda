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

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: Text(widget.resfriador == null ? 'Novo Resfriador' : 'Editar Resfriador')),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            TextField(
              controller: numeroController,
              decoration: const InputDecoration(
                labelText: 'Número / Identificador *',
                hintText: 'ex: RES-001',
                border: OutlineInputBorder(),
              ),
            ),
            const SizedBox(height: 16),
            TextField(
              controller: marcaController,
              decoration: const InputDecoration(labelText: 'Marca e Modelo *', border: OutlineInputBorder()),
            ),
            const SizedBox(height: 16),
            Row(children: [
              Expanded(
                child: TextField(
                  controller: capacidadeController,
                  keyboardType: const TextInputType.numberWithOptions(decimal: true),
                  decoration: const InputDecoration(labelText: 'Capacidade (L) *', border: OutlineInputBorder()),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: TextField(
                  controller: anoController,
                  keyboardType: TextInputType.number,
                  decoration: const InputDecoration(labelText: 'Ano fabricação', border: OutlineInputBorder()),
                ),
              ),
            ]),
            const SizedBox(height: 16),
            InkWell(
              onTap: _selecionarData,
              child: InputDecorator(
                decoration: const InputDecoration(
                  labelText: 'Última manutenção',
                  border: OutlineInputBorder(),
                  prefixIcon: Icon(Icons.build),
                ),
                child: Text(_ultimaManutencao == null ? '--/--/----' : _dataFmt(_ultimaManutencao!)),
              ),
            ),
            const SizedBox(height: 16),
            DropdownButtonFormField<String>(
              initialValue: _status,
              decoration: const InputDecoration(labelText: 'Status', border: OutlineInputBorder()),
              items: const [
                DropdownMenuItem(value: 'ATIVO', child: Text('Ativo')),
                DropdownMenuItem(value: 'MANUTENCAO', child: Text('Em manutenção')),
                DropdownMenuItem(value: 'INATIVO', child: Text('Inativo')),
              ],
              onChanged: (v) => setState(() => _status = v ?? 'ATIVO'),
            ),
            const SizedBox(height: 28),
            SizedBox(
              width: double.infinity,
              child: ElevatedButton(
                onPressed: _save,
                style: ElevatedButton.styleFrom(padding: const EdgeInsets.symmetric(vertical: 14)),
                child: const Text('Salvar'),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
