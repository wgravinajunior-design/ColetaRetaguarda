import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:go_router/go_router.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:latlong2/latlong.dart';
import '../models/pessoa_model.dart';
import '../viewmodels/produtor_viewmodel.dart';
import '../../core/database/firebird_service.dart';
import '../../core/services/location_service.dart';
import '../../core/utils/documento_validator.dart';

class ProdutorFormScreen extends StatefulWidget {
  final PessoaModel? produtor;

  const ProdutorFormScreen({super.key, this.produtor});

  @override
  State<ProdutorFormScreen> createState() => _ProdutorFormScreenState();
}

class _ProdutorFormScreenState extends State<ProdutorFormScreen> {
  late TextEditingController nomeController;
  late TextEditingController cnpjCpfController;
  late TextEditingController logradouroController;
  late TextEditingController numeroController;
  late TextEditingController complementoController;
  late TextEditingController referenciaController;
  late TextEditingController bairroController;
  late TextEditingController cepController;
  late TextEditingController celularController;
  late TextEditingController emailController;
  late TextEditingController kmController;
  late TextEditingController volumeController;
  late TextEditingController precoLitroController;
  late TextEditingController latController;
  late TextEditingController lonController;

  final _firebird = FirebirdService();
  final _location = LocationService();
  final _mapController = MapController();

  /// O formulário é longo e passa da tela; sem controlador a barra de rolagem
  /// só aparece durante o arrasto (ver RolagemSempreVisivel).
  final _rolagem = ScrollController();

  double? _latitude;
  double? _longitude;
  String? _horarioColeta; // "HH:mm"
  int? _resfriadorId;
  List<OpcaoRef> _resfriadores = [];
  bool _capturandoGps = false;

  @override
  void initState() {
    super.initState();
    final p = widget.produtor;
    nomeController = TextEditingController(text: p?.rSocialNome ?? '');
    cnpjCpfController = TextEditingController(text: p?.cnpjCpf ?? '');
    logradouroController = TextEditingController(text: p?.endereco ?? '');
    numeroController = TextEditingController(text: p?.numero ?? '');
    complementoController = TextEditingController(text: p?.complemento ?? '');
    referenciaController = TextEditingController(text: p?.referencia ?? '');
    bairroController = TextEditingController(text: p?.bairro ?? '');
    cepController = TextEditingController(text: p?.cep ?? '');
    celularController = TextEditingController(text: p?.celular ?? '');
    emailController = TextEditingController(text: p?.email ?? '');
    kmController = TextEditingController(text: p?.km?.toString() ?? '');
    volumeController = TextEditingController(text: p?.volumeMedio?.toString() ?? '');
    precoLitroController =
        TextEditingController(text: p?.precoLitro?.toString() ?? '');
    _latitude = p?.latitude;
    _longitude = p?.longitude;
    latController = TextEditingController(text: p?.latitude?.toStringAsFixed(6) ?? '');
    lonController = TextEditingController(text: p?.longitude?.toStringAsFixed(6) ?? '');
    _horarioColeta = p?.horarioColeta;
    _resfriadorId = p?.resfriadorId;
    _carregarResfriadores();
  }

  @override
  void dispose() {
    nomeController.dispose();
    cnpjCpfController.dispose();
    logradouroController.dispose();
    numeroController.dispose();
    complementoController.dispose();
    referenciaController.dispose();
    bairroController.dispose();
    cepController.dispose();
    celularController.dispose();
    emailController.dispose();
    kmController.dispose();
    volumeController.dispose();
    precoLitroController.dispose();
    latController.dispose();
    lonController.dispose();
    _rolagem.dispose();
    super.dispose();
  }

  Future<void> _carregarResfriadores() async {
    try {
      final res = await _firebird.getResfriadoresRef();
      if (mounted) setState(() => _resfriadores = res);
    } catch (_) {}
  }

  void _setCoordenada(double lat, double lon) {
    setState(() {
      _latitude = lat;
      _longitude = lon;
      latController.text = lat.toStringAsFixed(6);
      lonController.text = lon.toStringAsFixed(6);
    });
    _mapController.move(LatLng(lat, lon), 15);
  }

  Future<void> _usarLocalizacaoAtual() async {
    setState(() => _capturandoGps = true);
    final res = await _location.capturarPosicao();
    if (!mounted) return;
    setState(() => _capturandoGps = false);
    if (res.success) {
      _setCoordenada(res.position!.latitude, res.position!.longitude);
    } else {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(res.error ?? 'Não foi possível obter a localização')),
      );
    }
  }

  Future<void> _selecionarHorario() async {
    TimeOfDay inicial = const TimeOfDay(hour: 7, minute: 0);
    if (_horarioColeta != null && _horarioColeta!.contains(':')) {
      final partes = _horarioColeta!.split(':');
      inicial = TimeOfDay(hour: int.tryParse(partes[0]) ?? 7, minute: int.tryParse(partes[1]) ?? 0);
    }
    final t = await showTimePicker(context: context, initialTime: inicial);
    if (t != null) {
      setState(() => _horarioColeta =
          '${t.hour.toString().padLeft(2, '0')}:${t.minute.toString().padLeft(2, '0')}');
    }
  }

  void _save() async {
    if (nomeController.text.trim().isEmpty) {
      _erro('Informe a razão social / nome');
      return;
    }
    final erroDoc = DocumentoValidator.mensagemErro(cnpjCpfController.text);
    if (erroDoc != null) {
      _erro(erroDoc);
      return;
    }

    final viewModel = context.read<ProdutorViewModel>();
    final base = widget.produtor;

    final p = PessoaModel(
      id: base?.id,
      tipoPessoa: 'P',
      rSocialNome: nomeController.text.trim(),
      fantasiaApelido: base?.fantasiaApelido ?? '',
      cnpjCpf: cnpjCpfController.text,
      ieRg: base?.ieRg ?? '',
      endereco: logradouroController.text,
      numero: numeroController.text,
      complemento: complementoController.text,
      bairro: bairroController.text,
      cep: cepController.text,
      referencia: referenciaController.text,
      telefone: base?.telefone ?? '',
      celular: celularController.text,
      email: emailController.text,
      status: base?.status ?? 'A',
      cliente: 'S',
      latitude: _latitude,
      longitude: _longitude,
      horarioColeta: _horarioColeta,
      km: double.tryParse(kmController.text.replaceAll(',', '.')),
      volumeMedio: double.tryParse(volumeController.text.replaceAll(',', '.')),
      precoLitro: double.tryParse(
        precoLitroController.text.replaceAll(',', '.'),
      ),
      resfriadorId: _resfriadorId,
    );

    final success = base == null
        ? await viewModel.createProdutor(p)
        : await viewModel.updateProdutor(p);

    if (success && mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Produtor salvo com sucesso!'), backgroundColor: Colors.green),
      );
      context.go('/produtores');
    } else if (mounted) {
      _erro(viewModel.errorMessage ?? 'Não foi possível salvar');
    }
  }

  void _erro(String msg) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(msg), backgroundColor: Colors.red),
    );
  }

  @override
  Widget build(BuildContext context) {
    final center = LatLng(_latitude ?? -19.9167, _longitude ?? -43.9345);
    return Scaffold(
      backgroundColor: const Color(0xFFF3F5F4),
      appBar: AppBar(
        title: Text(widget.produtor == null ? 'Novo Produtor' : 'Editar Produtor'),
        elevation: 0,
      ),
      body: LayoutBuilder(
        builder: (context, constraints) {
          // Em janela larga, duas colunas lado a lado evitam a rolagem que
          // o formulário inteiro empilhado sempre produzia.
          final duasColunas = constraints.maxWidth >= 860;

          final colunaEsquerda = Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              _secaoCard('Dados', Icons.person, [
                _campo(nomeController, 'Razão Social / Nome *'),
                _campo(cnpjCpfController, 'CNPJ / CPF'),
              ]),
              const SizedBox(height: 10),
              _secaoCard('Endereço', Icons.location_on, [
                _campo(logradouroController, 'Logradouro'),
                Row(children: [
                  Expanded(child: _campo(numeroController, 'Número')),
                  const SizedBox(width: 12),
                  Expanded(child: _campo(cepController, 'CEP')),
                ]),
                _campo(complementoController, 'Complemento'),
                Row(children: [
                  Expanded(child: _campo(bairroController, 'Bairro')),
                  const SizedBox(width: 12),
                  Expanded(child: _campo(referenciaController, 'Referência')),
                ]),
              ]),
              const SizedBox(height: 10),
              _secaoCard('Contato', Icons.phone, [
                Row(children: [
                  Expanded(child: _campo(celularController, 'Celular')),
                  const SizedBox(width: 12),
                  Expanded(child: _campo(emailController, 'Email')),
                ]),
              ]),
            ],
          );

          final colunaDireita = Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              _secaoCard('Coleta', Icons.agriculture, [
                Row(children: [
                  Expanded(
                    child: InkWell(
                      onTap: _selecionarHorario,
                      child: InputDecorator(
                        decoration: const InputDecoration(
                          labelText: 'Horário de coleta',
                          border: OutlineInputBorder(),
                          isDense: true,
                          prefixIcon: Icon(Icons.schedule, size: 18),
                        ),
                        child: Text(_horarioColeta ?? '--:--'),
                      ),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(child: _campo(kmController, 'Distância (km)', numero: true)),
                ]),
                Row(children: [
                  Expanded(
                    child: _campo(
                      volumeController,
                      'Volume médio diário (L)',
                      numero: true,
                    ),
                  ),
                  const SizedBox(width: 12),
                  // Base do valor deste produtor na folha de pagamento.
                  Expanded(
                    child: _campo(
                      precoLitroController,
                      'Preço por litro (R\$)',
                      numero: true,
                    ),
                  ),
                ]),
                DropdownButtonFormField<int>(
                  initialValue: _resfriadorId,
                  isExpanded: true,
                  decoration: const InputDecoration(
                    labelText: 'Resfriador',
                    border: OutlineInputBorder(),
                    isDense: true,
                    prefixIcon: Icon(Icons.ac_unit, size: 18),
                  ),
                  items: [
                    const DropdownMenuItem<int>(value: null, child: Text('Nenhum')),
                    ..._resfriadores.map((r) => DropdownMenuItem(value: r.id, child: Text(r.label))),
                  ],
                  onChanged: (v) => setState(() => _resfriadorId = v),
                  hint: _resfriadores.isEmpty ? const Text('Nenhum resfriador cadastrado') : null,
                ),
              ]),
              const SizedBox(height: 10),
              _secaoCard('Localização (GPS)', Icons.map_outlined, [
                Row(children: [
                  Expanded(
                    child: _campo(latController, 'Latitude', numero: true, onChanged: (v) {
                      _latitude = double.tryParse(v.replaceAll(',', '.'));
                    }),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: _campo(lonController, 'Longitude', numero: true, onChanged: (v) {
                      _longitude = double.tryParse(v.replaceAll(',', '.'));
                    }),
                  ),
                ]),
                SizedBox(
                  width: double.infinity,
                  child: OutlinedButton.icon(
                    style: OutlinedButton.styleFrom(
                      visualDensity: VisualDensity.compact,
                      padding: const EdgeInsets.symmetric(vertical: 10),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(8),
                      ),
                    ),
                    icon: _capturandoGps
                        ? const SizedBox(width: 14, height: 14, child: CircularProgressIndicator(strokeWidth: 2))
                        : const Icon(Icons.my_location, size: 16),
                    label: const Text('Usar minha localização', style: TextStyle(fontSize: 12)),
                    onPressed: _capturandoGps ? null : _usarLocalizacaoAtual,
                  ),
                ),
                const SizedBox(height: 4),
                Text('Toque no mapa para marcar a propriedade',
                    style: TextStyle(fontSize: 11, color: Colors.grey[600])),
                const SizedBox(height: 6),
                ClipRRect(
                  borderRadius: BorderRadius.circular(8),
                  child: SizedBox(
                    height: duasColunas ? 190 : 240,
                    child: FlutterMap(
                      mapController: _mapController,
                      options: MapOptions(
                        initialCenter: center,
                        initialZoom: _latitude != null ? 15 : 12,
                        onTap: (tapPos, latlng) => _setCoordenada(latlng.latitude, latlng.longitude),
                      ),
                      children: [
                        TileLayer(
                          urlTemplate: 'https://tile.openstreetmap.org/{z}/{x}/{y}.png',
                          userAgentPackageName: 'com.goup.coletaup',
                        ),
                        if (_latitude != null && _longitude != null)
                          MarkerLayer(markers: [
                            Marker(
                              point: LatLng(_latitude!, _longitude!),
                              width: 36,
                              height: 36,
                              child: const Icon(Icons.location_pin, color: Colors.red, size: 36),
                            ),
                          ]),
                      ],
                    ),
                  ),
                ),
              ]),
            ],
          );

          return SingleChildScrollView(
            controller: _rolagem,
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
                const SizedBox(height: 12),
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

  Widget _campo(TextEditingController c, String label,
      {bool numero = false, ValueChanged<String>? onChanged}) {
    return TextField(
      controller: c,
      style: const TextStyle(fontSize: 13),
      keyboardType: numero ? const TextInputType.numberWithOptions(decimal: true) : null,
      onChanged: onChanged,
      decoration: InputDecoration(
        labelText: label,
        labelStyle: const TextStyle(fontSize: 12),
        border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
        isDense: true,
        contentPadding: const EdgeInsets.symmetric(horizontal: 10, vertical: 10),
      ),
    );
  }
}
