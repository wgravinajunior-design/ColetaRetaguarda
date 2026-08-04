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
    descricaoController = TextEditingController(
      text: widget.rota?.descricao ?? '',
    );
    _motoristaId = widget.rota?.motoristaId;
    _veiculoId = widget.rota?.veiculoId;
    if (widget.rota?.dataPrevista != null) {
      _dataColeta =
          DateTime.tryParse(widget.rota!.dataPrevista!) ?? DateTime.now();
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
        if (_motoristaId != null &&
            !_motoristas.any((m) => m.id == _motoristaId)) {
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
        const SnackBar(
          content: Text('Rota salva com sucesso!'),
          backgroundColor: Colors.green,
        ),
      );
      context.go('/rotas');
    } else {
      _erro(viewModel.errorMessage ?? 'Não foi possível salvar a rota');
    }
  }

  void _erro(String msg) {
    ScaffoldMessenger.of(
      context,
    ).showSnackBar(SnackBar(content: Text(msg), backgroundColor: Colors.red));
  }

  String _dataFmt(DateTime d) {
    String dois(int n) => n.toString().padLeft(2, '0');
    return '${dois(d.day)}/${dois(d.month)}/${d.year}';
  }

  Widget _campo(TextEditingController c, String label) {
    return TextField(
      controller: c,
      style: const TextStyle(fontSize: 13),
      decoration: InputDecoration(
        labelText: label,
        labelStyle: const TextStyle(fontSize: 12),
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
        title: Text(widget.rota == null ? 'Nova Rota' : 'Editar Rota'),
        elevation: 0,
      ),
      body: _carregando
          ? const Center(child: CircularProgressIndicator())
          : SingleChildScrollView(
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
                            _campo(descricaoController, 'Descrição *'),
                            const SizedBox(height: 10),
                            // Data da coleta
                            InkWell(
                              onTap: _selecionarData,
                              child: InputDecorator(
                                decoration: InputDecoration(
                                  labelText: 'Data da coleta *',
                                  labelStyle: const TextStyle(fontSize: 12),
                                  border: OutlineInputBorder(
                                    borderRadius: BorderRadius.circular(8),
                                  ),
                                  isDense: true,
                                  contentPadding: const EdgeInsets.symmetric(
                                    horizontal: 10,
                                    vertical: 10,
                                  ),
                                  prefixIcon: const Icon(
                                    Icons.calendar_today,
                                    size: 18,
                                  ),
                                ),
                                child: Text(
                                  _dataFmt(_dataColeta),
                                  style: const TextStyle(fontSize: 13),
                                ),
                              ),
                            ),
                            const SizedBox(height: 10),
                            // Motorista (obrigatório)
                            DropdownButtonFormField<int>(
                              initialValue: _motoristaId,
                              isExpanded: true,
                              style: const TextStyle(fontSize: 13, color: Colors.black87),
                              decoration: InputDecoration(
                                labelText: 'Motorista *',
                                labelStyle: const TextStyle(fontSize: 12),
                                border: OutlineInputBorder(
                                  borderRadius: BorderRadius.circular(8),
                                ),
                                isDense: true,
                                contentPadding: const EdgeInsets.symmetric(
                                  horizontal: 10,
                                  vertical: 10,
                                ),
                                prefixIcon: const Icon(Icons.person, size: 18),
                              ),
                              items: _motoristas
                                  .map(
                                    (m) => DropdownMenuItem(
                                      value: m.id,
                                      child: Text(m.label),
                                    ),
                                  )
                                  .toList(),
                              onChanged: (v) => setState(() => _motoristaId = v),
                              hint: Text(
                                _motoristas.isEmpty
                                    ? 'Nenhum motorista cadastrado'
                                    : 'Selecione',
                                style: const TextStyle(fontSize: 13),
                              ),
                            ),
                            const SizedBox(height: 10),
                            // Veículo (obrigatório)
                            DropdownButtonFormField<int>(
                              initialValue: _veiculoId,
                              isExpanded: true,
                              style: const TextStyle(fontSize: 13, color: Colors.black87),
                              decoration: InputDecoration(
                                labelText: 'Veículo *',
                                labelStyle: const TextStyle(fontSize: 12),
                                border: OutlineInputBorder(
                                  borderRadius: BorderRadius.circular(8),
                                ),
                                isDense: true,
                                contentPadding: const EdgeInsets.symmetric(
                                  horizontal: 10,
                                  vertical: 10,
                                ),
                                prefixIcon: const Icon(
                                  Icons.local_shipping,
                                  size: 18,
                                ),
                              ),
                              items: _veiculos
                                  .map(
                                    (v) => DropdownMenuItem(
                                      value: v.id,
                                      child: Text(v.label),
                                    ),
                                  )
                                  .toList(),
                              onChanged: (v) => setState(() => _veiculoId = v),
                              hint: Text(
                                _veiculos.isEmpty
                                    ? 'Nenhum veículo cadastrado'
                                    : 'Selecione',
                                style: const TextStyle(fontSize: 13),
                              ),
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(height: 16),
                      SizedBox(
                        width: double.infinity,
                        child: ElevatedButton(
                          onPressed: _salvando ? null : _save,
                          style: ElevatedButton.styleFrom(
                            backgroundColor: const Color(0xFF2E7D4F),
                            padding: const EdgeInsets.symmetric(vertical: 13),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(10),
                            ),
                          ),
                          child: _salvando
                              ? const SizedBox(
                                  height: 18,
                                  width: 18,
                                  child: CircularProgressIndicator(
                                    strokeWidth: 2,
                                    color: Colors.white,
                                  ),
                                )
                              : const Text(
                                  'Salvar',
                                  style: TextStyle(
                                    color: Colors.white,
                                    fontWeight: FontWeight.w600,
                                  ),
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
