import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:go_router/go_router.dart';
import '../models/rota_model.dart';
import '../viewmodels/rota_viewmodel.dart';
import '../../core/database/firebird_service.dart';

class RotaFormScreen extends StatefulWidget {
  final RotaModel? rota;

  const RotaFormScreen({super.key, this.rota});

  @override
  State<RotaFormScreen> createState() => _RotaFormScreenState();
}

class _RotaFormScreenState extends State<RotaFormScreen> {
  final _firebird = FirebirdService();
  late TextEditingController descricaoController;

  List<OpcaoRef> _motoristas = [];
  List<OpcaoRef> _veiculos = [];
  int? _motoristaId;
  int? _veiculoId;
  DateTime _dataColeta = DateTime.now();
  bool _carregando = true;
  bool _salvando = false;

  @override
  void initState() {
    super.initState();
    descricaoController = TextEditingController(text: widget.rota?.descricao ?? '');
    _motoristaId = widget.rota?.motoristaId;
    _veiculoId = widget.rota?.veiculoId;
    if (widget.rota?.dataPrevista != null) {
      _dataColeta = DateTime.tryParse(widget.rota!.dataPrevista!) ?? DateTime.now();
    }
    _carregarOpcoes();
  }

  @override
  void dispose() {
    descricaoController.dispose();
    super.dispose();
  }

  Future<void> _carregarOpcoes() async {
    setState(() => _carregando = true);
    try {
      final motoristas = await _firebird.getMotoristasRef();
      final veiculos = await _firebird.getVeiculosRef();
      if (!mounted) return;
      setState(() {
        _motoristas = motoristas;
        _veiculos = veiculos;
        // Mantém seleção válida
        if (_motoristaId != null && !_motoristas.any((m) => m.id == _motoristaId)) {
          _motoristaId = null;
        }
        if (_veiculoId != null && !_veiculos.any((v) => v.id == _veiculoId)) {
          _veiculoId = null;
        }
        _carregando = false;
      });
    } catch (e) {
      if (mounted) {
        setState(() => _carregando = false);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Erro ao carregar motoristas/veículos: $e')),
        );
      }
    }
  }

  Future<void> _selecionarData() async {
    final data = await showDatePicker(
      context: context,
      initialDate: _dataColeta,
      firstDate: DateTime(2020),
      lastDate: DateTime(2100),
    );
    if (data != null) setState(() => _dataColeta = data);
  }

  Future<void> _save() async {
    // Validações obrigatórias
    if (descricaoController.text.trim().isEmpty) {
      _erro('Informe a descrição da rota');
      return;
    }
    if (_motoristaId == null) {
      _erro('Selecione o motorista');
      return;
    }
    if (_veiculoId == null) {
      _erro('Selecione o veículo');
      return;
    }

    setState(() => _salvando = true);
    final viewModel = context.read<RotaViewModel>();

    final r = RotaModel(
      id: widget.rota?.id,
      descricao: descricaoController.text.trim(),
      motoristaId: _motoristaId,
      veiculoId: _veiculoId,
      dataPrevista: _dataColeta.toIso8601String(),
      status: widget.rota?.status ?? 'PENDENTE',
    );

    final success = widget.rota == null
        ? await viewModel.createRota(r)
        : await viewModel.updateRota(r);

    if (!mounted) return;
    setState(() => _salvando = false);

    if (success) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Rota salva com sucesso!'), backgroundColor: Colors.green),
      );
      context.go('/rotas');
    } else {
      _erro(viewModel.errorMessage ?? 'Não foi possível salvar a rota');
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
      appBar: AppBar(
        title: Text(widget.rota == null ? 'Nova Rota' : 'Editar Rota'),
      ),
      body: _carregando
          ? const Center(child: CircularProgressIndicator())
          : SingleChildScrollView(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  TextField(
                    controller: descricaoController,
                    decoration: const InputDecoration(
                      labelText: 'Descrição *',
                      border: OutlineInputBorder(),
                    ),
                  ),
                  const SizedBox(height: 16),
                  // Data da coleta
                  InkWell(
                    onTap: _selecionarData,
                    child: InputDecorator(
                      decoration: const InputDecoration(
                        labelText: 'Data da coleta *',
                        border: OutlineInputBorder(),
                        prefixIcon: Icon(Icons.calendar_today),
                      ),
                      child: Text(_dataFmt(_dataColeta)),
                    ),
                  ),
                  const SizedBox(height: 16),
                  // Motorista (obrigatório)
                  DropdownButtonFormField<int>(
                    initialValue: _motoristaId,
                    isExpanded: true,
                    decoration: const InputDecoration(
                      labelText: 'Motorista *',
                      border: OutlineInputBorder(),
                      prefixIcon: Icon(Icons.person),
                    ),
                    items: _motoristas
                        .map((m) => DropdownMenuItem(value: m.id, child: Text(m.label)))
                        .toList(),
                    onChanged: (v) => setState(() => _motoristaId = v),
                    hint: _motoristas.isEmpty
                        ? const Text('Nenhum motorista cadastrado')
                        : const Text('Selecione'),
                  ),
                  const SizedBox(height: 16),
                  // Veículo (obrigatório)
                  DropdownButtonFormField<int>(
                    initialValue: _veiculoId,
                    isExpanded: true,
                    decoration: const InputDecoration(
                      labelText: 'Veículo *',
                      border: OutlineInputBorder(),
                      prefixIcon: Icon(Icons.local_shipping),
                    ),
                    items: _veiculos
                        .map((v) => DropdownMenuItem(value: v.id, child: Text(v.label)))
                        .toList(),
                    onChanged: (v) => setState(() => _veiculoId = v),
                    hint: _veiculos.isEmpty
                        ? const Text('Nenhum veículo cadastrado')
                        : const Text('Selecione'),
                  ),
                  const SizedBox(height: 32),
                  SizedBox(
                    width: double.infinity,
                    child: ElevatedButton(
                      onPressed: _salvando ? null : _save,
                      child: _salvando
                          ? const SizedBox(
                              height: 20, width: 20,
                              child: CircularProgressIndicator(strokeWidth: 2),
                            )
                          : const Text('Salvar'),
                    ),
                  ),
                ],
              ),
            ),
    );
  }
}
