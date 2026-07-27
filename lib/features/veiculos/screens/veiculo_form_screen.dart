import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import 'package:go_router/go_router.dart';
import '../models/veiculo_model.dart';
import '../viewmodels/veiculo_viewmodel.dart';

/// Cadastro de veículo.
///
/// O foco é o básico — placa, descrição e modelo, o bastante para saber qual
/// carro sai para a coleta. Os demais dados do ERP ficam recolhidos em "Mais
/// dados", para quem quiser preencher.
///
/// Digitar uma placa já cadastrada não cria um segundo registro: a consulta
/// traz o veículo existente e o formulário passa a editá-lo.
class VeiculoFormScreen extends StatefulWidget {
  final VeiculoModel? veiculo;

  const VeiculoFormScreen({super.key, this.veiculo});

  @override
  State<VeiculoFormScreen> createState() => _VeiculoFormScreenState();
}

class _VeiculoFormScreenState extends State<VeiculoFormScreen> {
  final _formKey = GlobalKey<FormState>();

  late final TextEditingController placaController;
  late final TextEditingController descricaoController;
  late final TextEditingController modeloController;
  late final TextEditingController marcaController;
  late final TextEditingController corController;
  late final TextEditingController anoController;
  late final TextEditingController renavamController;

  /// Id do registro sendo editado. Muda quando a consulta por placa encontra um
  /// veículo já cadastrado e o formulário passa a editá-lo.
  int? _editandoId;
  String _status = 'A';

  bool _consultando = false;
  bool _salvando = false;
  bool _maisDados = false;
  String? _avisoPlaca;

  @override
  void initState() {
    super.initState();
    final v = widget.veiculo;
    _editandoId = v?.id;
    _status = v?.status.isNotEmpty == true ? v!.status : 'A';

    placaController = TextEditingController(text: v?.placa ?? '');
    descricaoController = TextEditingController(text: v?.descricao ?? '');
    modeloController = TextEditingController(text: v?.modelo ?? '');
    marcaController = TextEditingController(text: v?.marca ?? '');
    corController = TextEditingController(text: v?.cor ?? '');
    anoController = TextEditingController(text: v?.ano ?? '');
    renavamController = TextEditingController(text: v?.renavam ?? '');
  }

  @override
  void dispose() {
    placaController.dispose();
    descricaoController.dispose();
    modeloController.dispose();
    marcaController.dispose();
    corController.dispose();
    anoController.dispose();
    renavamController.dispose();
    super.dispose();
  }

  /// Procura a placa na base e, se achar, carrega o veículo para edição.
  Future<void> _consultarPlaca() async {
    final placa = placaController.text.trim();
    if (placa.isEmpty) {
      setState(() => _avisoPlaca = 'Informe a placa para consultar.');
      return;
    }

    setState(() {
      _consultando = true;
      _avisoPlaca = null;
    });

    try {
      final achado = await context.read<VeiculoViewModel>().buscarPorPlaca(
        placa,
      );
      if (!mounted) return;

      if (achado == null) {
        setState(
          () => _avisoPlaca = 'Placa não cadastrada — preencha para incluir.',
        );
        return;
      }

      // Já existe: passa a editar o registro encontrado em vez de duplicar.
      setState(() {
        _editandoId = achado.id;
        _status = achado.status.isEmpty ? 'A' : achado.status;
        placaController.text = achado.placa;
        descricaoController.text = achado.descricao;
        modeloController.text = achado.modelo;
        marcaController.text = achado.marca;
        corController.text = achado.cor;
        anoController.text = achado.ano;
        renavamController.text = achado.renavam;
        _avisoPlaca = 'Veículo encontrado. Os dados abaixo já são os da base.';
      });
    } catch (e) {
      if (mounted) setState(() => _avisoPlaca = 'Não foi possível consultar: $e');
    } finally {
      if (mounted) setState(() => _consultando = false);
    }
  }

  Future<void> _salvar() async {
    if (!(_formKey.currentState?.validate() ?? false)) return;

    final viewModel = context.read<VeiculoViewModel>();

    // Placa nova que já existe na base viraria um registro duplicado: aqui ela
    // é redirecionada para uma alteração do que já está cadastrado.
    if (_editandoId == null) {
      final jaExiste = await viewModel.buscarPorPlaca(placaController.text);
      if (jaExiste != null) {
        if (!mounted) return;
        setState(() {
          _editandoId = jaExiste.id;
          _avisoPlaca =
              'Esta placa já estava cadastrada. O registro existente será '
              'atualizado com o que você preencheu.';
        });
      }
    }

    setState(() => _salvando = true);

    final v = VeiculoModel(
      id: _editandoId,
      placa: placaController.text.trim().toUpperCase(),
      descricao: descricaoController.text.trim(),
      modelo: modeloController.text.trim(),
      marca: marcaController.text.trim(),
      cor: corController.text.trim(),
      ano: anoController.text.trim(),
      tipo: widget.veiculo?.tipo ?? 'C',
      renavam: renavamController.text.trim(),
      chassi: widget.veiculo?.chassi,
      status: _status,
    );

    final ok = _editandoId == null
        ? await viewModel.createVeiculo(v)
        : await viewModel.updateVeiculo(v);

    if (!mounted) return;
    setState(() => _salvando = false);

    if (ok) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Veículo salvo.')),
      );
      context.go('/veiculos');
    } else {
      // O viewmodel guarda o motivo real (inclusive o da fila offline).
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(viewModel.errorMessage ?? 'Não foi possível salvar.'),
          backgroundColor: Colors.orange.shade800,
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final editando = _editandoId != null;

    return Scaffold(
      appBar: AppBar(
        title: Text(editando ? 'Editar veículo' : 'Novo veículo'),
      ),
      body: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 560),
          child: Form(
            key: _formKey,
            child: ListView(
              padding: const EdgeInsets.all(24),
              children: [
                Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Expanded(
                      child: TextFormField(
                        controller: placaController,
                        textCapitalization: TextCapitalization.characters,
                        inputFormatters: [
                          UpperCaseTextFormatter(),
                          LengthLimitingTextInputFormatter(10),
                        ],
                        decoration: const InputDecoration(
                          labelText: 'Placa *',
                          hintText: 'ABC1D23',
                          border: OutlineInputBorder(),
                        ),
                        validator: (t) => (t == null || t.trim().length < 7)
                            ? 'Informe a placa completa'
                            : null,
                        onFieldSubmitted: (_) => _consultarPlaca(),
                      ),
                    ),
                    const SizedBox(width: 12),
                    SizedBox(
                      height: 58,
                      child: ElevatedButton.icon(
                        onPressed: _consultando ? null : _consultarPlaca,
                        icon: _consultando
                            ? const SizedBox(
                                width: 16,
                                height: 16,
                                child: CircularProgressIndicator(
                                  strokeWidth: 2,
                                ),
                              )
                            : const Icon(Icons.search),
                        label: const Text('Consultar'),
                      ),
                    ),
                  ],
                ),
                if (_avisoPlaca != null) ...[
                  const SizedBox(height: 8),
                  Text(
                    _avisoPlaca!,
                    style: TextStyle(
                      fontSize: 12.5,
                      color: editando
                          ? Colors.green.shade800
                          : Colors.grey.shade700,
                    ),
                  ),
                ],

                const SizedBox(height: 20),
                TextFormField(
                  controller: descricaoController,
                  decoration: const InputDecoration(
                    labelText: 'Descrição *',
                    hintText: 'Como o carro é chamado: "Caminhão 1"',
                    border: OutlineInputBorder(),
                  ),
                  validator: (t) => (t == null || t.trim().isEmpty)
                      ? 'Informe a descrição'
                      : null,
                ),

                const SizedBox(height: 16),
                TextFormField(
                  controller: modeloController,
                  decoration: const InputDecoration(
                    labelText: 'Modelo',
                    border: OutlineInputBorder(),
                  ),
                ),

                const SizedBox(height: 16),
                DropdownButtonFormField<String>(
                  initialValue: _status,
                  decoration: const InputDecoration(
                    labelText: 'Situação',
                    border: OutlineInputBorder(),
                  ),
                  items: const [
                    DropdownMenuItem(value: 'A', child: Text('Ativo')),
                    DropdownMenuItem(value: 'I', child: Text('Inativo')),
                  ],
                  onChanged: (v) => setState(() => _status = v ?? 'A'),
                ),

                const SizedBox(height: 8),
                ExpansionTile(
                  tilePadding: EdgeInsets.zero,
                  title: const Text(
                    'Mais dados',
                    style: TextStyle(fontSize: 14),
                  ),
                  subtitle: const Text(
                    'Opcional: marca, cor, ano e renavam',
                    style: TextStyle(fontSize: 12),
                  ),
                  initiallyExpanded: _maisDados,
                  onExpansionChanged: (v) => setState(() => _maisDados = v),
                  children: [
                    const SizedBox(height: 8),
                    TextFormField(
                      controller: marcaController,
                      decoration: const InputDecoration(
                        labelText: 'Marca',
                        border: OutlineInputBorder(),
                      ),
                    ),
                    const SizedBox(height: 12),
                    TextFormField(
                      controller: corController,
                      decoration: const InputDecoration(
                        labelText: 'Cor',
                        border: OutlineInputBorder(),
                      ),
                    ),
                    const SizedBox(height: 12),
                    TextFormField(
                      controller: anoController,
                      keyboardType: TextInputType.number,
                      inputFormatters: [
                        FilteringTextInputFormatter.digitsOnly,
                        LengthLimitingTextInputFormatter(4),
                      ],
                      decoration: const InputDecoration(
                        labelText: 'Ano',
                        border: OutlineInputBorder(),
                      ),
                    ),
                    const SizedBox(height: 12),
                    TextFormField(
                      controller: renavamController,
                      keyboardType: TextInputType.number,
                      inputFormatters: [
                        FilteringTextInputFormatter.digitsOnly,
                        LengthLimitingTextInputFormatter(11),
                      ],
                      decoration: const InputDecoration(
                        labelText: 'Renavam',
                        border: OutlineInputBorder(),
                      ),
                    ),
                  ],
                ),

                const SizedBox(height: 28),
                SizedBox(
                  height: 46,
                  child: ElevatedButton.icon(
                    onPressed: _salvando ? null : _salvar,
                    icon: _salvando
                        ? const SizedBox(
                            width: 16,
                            height: 16,
                            child: CircularProgressIndicator(strokeWidth: 2),
                          )
                        : const Icon(Icons.save),
                    label: Text(_salvando ? 'Salvando...' : 'Salvar'),
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

/// Mantém a placa em maiúsculas enquanto se digita, sem mover o cursor.
class UpperCaseTextFormatter extends TextInputFormatter {
  @override
  TextEditingValue formatEditUpdate(
    TextEditingValue oldValue,
    TextEditingValue newValue,
  ) {
    return TextEditingValue(
      text: newValue.text.toUpperCase(),
      selection: newValue.selection,
    );
  }
}
