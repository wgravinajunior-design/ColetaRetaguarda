import 'dart:convert';
import 'dart:io';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:geolocator/geolocator.dart';
import 'package:signature/signature.dart';
import 'package:image_picker/image_picker.dart';
import '../models/parada_model.dart';
import '../viewmodels/coleta_viewmodel.dart';
import '../widgets/mini_map.dart';
import '../services/comprovante_service.dart';
import '../../core/services/location_service.dart';

class ColetaParadaScreen extends StatefulWidget {
  final ParadaModel parada;

  const ColetaParadaScreen({super.key, required this.parada});

  @override
  State<ColetaParadaScreen> createState() => _ColetaParadaScreenState();
}

class _ColetaParadaScreenState extends State<ColetaParadaScreen> {
  late TextEditingController _temperatureController;
  late TextEditingController _volumeController;
  late TextEditingController _justificativaController;
  final LocationService _locationService = LocationService();
  Position? _currentPosition;
  bool _loadingGPS = false;
  String? _gpsError;

  final SignatureController _signatureController = SignatureController(
    penStrokeWidth: 2,
    penColor: Colors.black,
    exportBackgroundColor: Colors.white,
  );
  String? _fotoPath;

  @override
  void initState() {
    super.initState();
    _temperatureController = TextEditingController();
    _volumeController = TextEditingController();
    _justificativaController = TextEditingController();

    // Recupera assinatura/foto já salvas, se houver
    _fotoPath = widget.parada.fotoPath;

    // Ao abrir a parada, inicia a coleta automaticamente:
    // captura o GPS e registra o horário de chegada (status Pendente → Em Andamento).
    if (widget.parada.status == 'P') {
      WidgetsBinding.instance.addPostFrameCallback((_) => _iniciarColeta());
    } else if (widget.parada.gpsCapturaLatitude != null) {
      // Já iniciada: mostra o GPS que foi capturado antes.
      _currentPosition = Position(
        latitude: widget.parada.gpsCapturaLatitude!,
        longitude: widget.parada.gpsCapturaltitude ?? 0.0,
        timestamp: DateTime.now(),
        accuracy: 0,
        altitude: 0,
        altitudeAccuracy: 0,
        heading: 0,
        headingAccuracy: 0,
        speed: 0,
        speedAccuracy: 0,
      );
    }
  }

  /// Inicia a coleta capturando o GPS do dispositivo e gravando o horário
  /// de chegada. Chamado automaticamente ao abrir uma parada pendente.
  Future<void> _iniciarColeta() async {
    setState(() {
      _loadingGPS = true;
      _gpsError = null;
    });

    final viewModel = context.read<ColetaViewModel>();
    final sucesso = await viewModel.iniciarColeta(widget.parada);

    if (!mounted) return;

    if (sucesso) {
      final atualizada = viewModel.selectedParada ?? widget.parada;
      setState(() {
        _loadingGPS = false;
        if (atualizada.gpsCapturaLatitude != null) {
          _currentPosition = Position(
            latitude: atualizada.gpsCapturaLatitude!,
            longitude: atualizada.gpsCapturaltitude ?? 0,
            timestamp: DateTime.now(),
            accuracy: 0,
            altitude: 0,
            altitudeAccuracy: 0,
            heading: 0,
            headingAccuracy: 0,
            speed: 0,
            speedAccuracy: 0,
          );
        }
      });
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('📍 Coleta iniciada — localização registrada'),
          backgroundColor: Colors.green,
        ),
      );
    } else {
      setState(() {
        _loadingGPS = false;
        _gpsError = viewModel.gpsError ?? 'Não foi possível capturar o GPS';
      });
    }
  }

  @override
  void dispose() {
    _temperatureController.dispose();
    _volumeController.dispose();
    _justificativaController.dispose();
    _signatureController.dispose();
    super.dispose();
  }

  Future<void> _tirarFoto() async {
    final viewModel = context.read<ColetaViewModel>();
    try {
      final picker = ImagePicker();
      final XFile? foto = await picker.pickImage(
        source: ImageSource.camera,
        maxWidth: 1280,
        imageQuality: 70,
      );
      if (foto != null) {
        await _persistirFotoCapturada(viewModel, foto.path);
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Não foi possível abrir a câmera: $e')),
        );
      }
    }
  }

  Future<void> _escolherFotoGaleria() async {
    final viewModel = context.read<ColetaViewModel>();
    try {
      final picker = ImagePicker();
      final XFile? foto = await picker.pickImage(
        source: ImageSource.gallery,
        maxWidth: 1280,
        imageQuality: 70,
      );
      if (foto != null) {
        await _persistirFotoCapturada(viewModel, foto.path);
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Não foi possível abrir a galeria: $e')),
        );
      }
    }
  }

  /// Move a foto capturada para o armazenamento gerenciado (uploads/paradas/)
  /// e atualiza _fotoPath com o caminho estável. Se a parada ainda não tem id
  /// ou a imagem for inválida, mantém o caminho temporário como fallback.
  Future<void> _persistirFotoCapturada(
      ColetaViewModel viewModel, String origemPath) async {
    final id = widget.parada.id;
    String? gerenciado;
    if (id != null) {
      gerenciado = await viewModel.salvarFoto(id, origemPath);
    }
    if (!mounted) return;
    setState(() => _fotoPath = gerenciado ?? origemPath);
    if (gerenciado == null && id != null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Foto inválida — use JPEG ou PNG.')),
      );
    }
  }

  /// Recaptura o GPS manualmente (caso a captura automática tenha falhado
  /// ou o motorista queira atualizar a posição).
  Future<void> _capturarGPS() async {
    setState(() {
      _loadingGPS = true;
      _gpsError = null;
    });

    final resultado = await _locationService.capturarPosicao();

    if (!mounted) return;

    if (!resultado.success) {
      setState(() {
        _gpsError = resultado.error;
        _loadingGPS = false;
      });
      return;
    }

    final position = resultado.position!;
    setState(() {
      _currentPosition = position;
      _loadingGPS = false;
    });

    final viewModel = context.read<ColetaViewModel>();
    await viewModel.registrarGPS(
      widget.parada,
      position.latitude,
      position.longitude,
    );
  }

  Future<void> _finalizarComSucesso() async {
    final temp = double.tryParse(_temperatureController.text);
    final vol = double.tryParse(_volumeController.text);

    if (temp == null || vol == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Temperatura e volume são obrigatórios')),
      );
      return;
    }

    if (_currentPosition == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('GPS precisa ser capturado')),
      );
      return;
    }

    // Validação de proximidade: se estiver longe do produtor cadastrado, confirma
    final pLat = widget.parada.latitude;
    final pLon = widget.parada.longitude;
    if (pLat != 0 && pLon != 0) {
      final metros = Geolocator.distanceBetween(
        _currentPosition!.latitude, _currentPosition!.longitude, pLat, pLon,
      );
      if (metros > 300) {
        final dist = metros < 1000 ? '${metros.toStringAsFixed(0)} m' : '${(metros / 1000).toStringAsFixed(2)} km';
        final continuar = await showDialog<bool>(
          context: context,
          builder: (_) => AlertDialog(
            title: Row(children: const [
              Icon(Icons.warning_amber, color: Colors.orange),
              SizedBox(width: 8),
              Text('Longe do produtor'),
            ]),
            content: Text(
              'Você está a $dist da localização cadastrada do produtor.\n\n'
              'Deseja finalizar a coleta mesmo assim?',
            ),
            actions: [
              TextButton(onPressed: () => Navigator.pop(context, false), child: const Text('Cancelar')),
              ElevatedButton(onPressed: () => Navigator.pop(context, true), child: const Text('Finalizar')),
            ],
          ),
        );
        if (continuar != true) return;
      }
    }

    if (!mounted) return;
    // Exporta a assinatura (se houver traços) para base64 PNG
    String? assinaturaBase64;
    if (_signatureController.isNotEmpty) {
      final bytes = await _signatureController.toPngBytes();
      if (bytes != null) {
        assinaturaBase64 = base64Encode(bytes);
      }
    }

    if (!mounted) return;
    final viewModel = context.read<ColetaViewModel>();
    final success = await viewModel.finalizarColetaComSucesso(
      parada: widget.parada,
      temperatura: temp,
      volume: vol,
      assinaturaBase64: assinaturaBase64,
      fotoPath: _fotoPath,
    );

    if (success && mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Coleta finalizada com sucesso!')),
      );
      Navigator.pop(context);
    }
  }

  String _formatarHorario(String iso) {
    final dt = DateTime.tryParse(iso);
    if (dt == null) return iso;
    String dois(int n) => n.toString().padLeft(2, '0');
    return '${dois(dt.day)}/${dois(dt.month)}/${dt.year} ${dois(dt.hour)}:${dois(dt.minute)}';
  }

  /// Mostra a distância entre o GPS capturado e a localização cadastrada
  /// do produtor (conferência de presença).
  List<Widget> _buildDistanciaProdutor() {
    final pLat = widget.parada.latitude;
    final pLon = widget.parada.longitude;
    if (_currentPosition == null || pLat == 0 || pLon == 0) return const [];

    final metros = Geolocator.distanceBetween(
      _currentPosition!.latitude, _currentPosition!.longitude, pLat, pLon,
    );
    final perto = metros <= 300; // tolerância de 300 m
    final texto = metros < 1000
        ? '${metros.toStringAsFixed(0)} m'
        : '${(metros / 1000).toStringAsFixed(2)} km';
    return [
      const SizedBox(height: 6),
      Row(
        children: [
          Icon(perto ? Icons.check_circle : Icons.warning_amber,
              size: 16, color: perto ? Colors.green : Colors.orange),
          const SizedBox(width: 6),
          Expanded(
            child: Text(
              perto
                  ? 'No local do produtor ($texto)'
                  : 'Distante do produtor cadastrado: $texto',
              style: TextStyle(
                fontSize: 12,
                color: perto ? Colors.green[800] : Colors.orange[800],
                fontWeight: FontWeight.w500,
              ),
            ),
          ),
        ],
      ),
    ];
  }

  Future<void> _recusarColeta() async {
    if (_justificativaController.text.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Justificativa é obrigatória')),
      );
      return;
    }

    final viewModel = context.read<ColetaViewModel>();
    final success = await viewModel.recusarColeta(
      parada: widget.parada,
      justificativa: _justificativaController.text,
    );

    if (success && mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Coleta recusada')),
      );
      Navigator.pop(context);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text('${widget.parada.statusEmoji} ${widget.parada.pessoaNome}'),
        elevation: 0,
        actions: [
          if (widget.parada.status == 'C' || widget.parada.status == 'R')
            IconButton(
              icon: const Icon(Icons.receipt_long),
              tooltip: 'Recibo',
              onPressed: () => ComprovanteService().imprimirReciboParada(widget.parada),
            ),
        ],
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Informações da parada
            Card(
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Informações da Parada',
                      style: Theme.of(context).textTheme.titleMedium,
                    ),
                    const SizedBox(height: 12),
                    _InfoRow(label: 'Produtor', value: widget.parada.pessoaNome),
                    _InfoRow(label: 'CNPJ/CPF', value: widget.parada.cnpjCpf),
                    _InfoRow(label: 'Endereço', value: widget.parada.endereco),
                    _InfoRow(
                      label: 'Localização',
                      value: '${widget.parada.latitude.toStringAsFixed(4)}, ${widget.parada.longitude.toStringAsFixed(4)}',
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 16),
            // GPS
            Card(
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Geolocalização (GPS)',
                      style: Theme.of(context).textTheme.titleMedium,
                    ),
                    const SizedBox(height: 12),
                    if (_loadingGPS) ...[
                      Container(
                        padding: const EdgeInsets.all(12),
                        decoration: BoxDecoration(
                          color: Colors.blue.shade50,
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: Row(
                          children: const [
                            SizedBox(width: 18, height: 18, child: CircularProgressIndicator(strokeWidth: 2)),
                            SizedBox(width: 12),
                            Expanded(child: Text('Capturando localização...', style: TextStyle(color: Colors.blue))),
                          ],
                        ),
                      ),
                    ] else if (_currentPosition != null) ...[
                      Container(
                        padding: const EdgeInsets.all(12),
                        decoration: BoxDecoration(
                          color: Colors.green.shade50,
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            const Text('✅ Localização registrada', style: TextStyle(color: Colors.green, fontWeight: FontWeight.bold)),
                            const SizedBox(height: 8),
                            Text('Lat: ${_currentPosition!.latitude.toStringAsFixed(6)}'),
                            Text('Long: ${_currentPosition!.longitude.toStringAsFixed(6)}'),
                            if (widget.parada.horarioChegada != null) ...[
                              const SizedBox(height: 4),
                              Text(
                                'Chegada: ${_formatarHorario(widget.parada.horarioChegada!)}',
                                style: TextStyle(fontSize: 12, color: Colors.grey[700]),
                              ),
                            ],
                            ..._buildDistanciaProdutor(),
                          ],
                        ),
                      ),
                    ] else if (_gpsError != null) ...[
                      Container(
                        padding: const EdgeInsets.all(12),
                        decoration: BoxDecoration(
                          color: Colors.red.shade50,
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              _gpsError!,
                              style: TextStyle(color: Colors.red.shade900),
                            ),
                            const SizedBox(height: 4),
                            const Text(
                              'Tente novamente no botão abaixo.',
                              style: TextStyle(fontSize: 12, color: Colors.red),
                            ),
                          ],
                        ),
                      ),
                    ] else ...[
                      Container(
                        padding: const EdgeInsets.all(12),
                        decoration: BoxDecoration(
                          color: Colors.orange.shade50,
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: const Text(
                          'GPS não capturado. Clique no botão abaixo para capturar.',
                          style: TextStyle(color: Colors.orange),
                        ),
                      ),
                    ],
                    const SizedBox(height: 12),
                    SizedBox(
                      width: double.infinity,
                      child: ElevatedButton.icon(
                        icon: _loadingGPS
                            ? const SizedBox(width: 16, height: 16, child: CircularProgressIndicator(strokeWidth: 2))
                            : const Icon(Icons.location_on),
                        label: _loadingGPS
                            ? const Text('Capturando GPS...')
                            : Text(_currentPosition != null ? 'Recapturar GPS' : 'Capturar GPS Agora'),
                        onPressed: _loadingGPS ? null : _capturarGPS,
                      ),
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 16),
            // Mini mapa da parada
            MiniMap(
              latitude: widget.parada.latitude,
              longitude: widget.parada.longitude,
              title: 'Localização da Parada',
            ),
            const SizedBox(height: 16),
            // Dados de coleta
            Card(
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Dados da Coleta',
                      style: Theme.of(context).textTheme.titleMedium,
                    ),
                    const SizedBox(height: 12),
                    TextField(
                      controller: _temperatureController,
                      keyboardType: const TextInputType.numberWithOptions(decimal: true),
                      decoration: const InputDecoration(
                        labelText: 'Temperatura (°C)',
                        border: OutlineInputBorder(),
                        prefixIcon: Icon(Icons.thermostat),
                      ),
                    ),
                    const SizedBox(height: 12),
                    TextField(
                      controller: _volumeController,
                      keyboardType: const TextInputType.numberWithOptions(decimal: true),
                      decoration: const InputDecoration(
                        labelText: 'Volume (L)',
                        border: OutlineInputBorder(),
                        prefixIcon: Icon(Icons.water_drop),
                      ),
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 16),
            // Foto da coleta
            _buildCardFoto(),
            const SizedBox(height: 16),
            // Assinatura do produtor
            _buildCardAssinatura(),
            const SizedBox(height: 16),
            // Justificativa (se recusar)
            Card(
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Justificativa (se aplicável)',
                      style: Theme.of(context).textTheme.titleMedium,
                    ),
                    const SizedBox(height: 12),
                    TextField(
                      controller: _justificativaController,
                      maxLines: 3,
                      decoration: const InputDecoration(
                        labelText: 'Motivo da recusa...',
                        border: OutlineInputBorder(),
                      ),
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 24),
            // Botões de ação
            Row(
              children: [
                Expanded(
                  child: ElevatedButton.icon(
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.green,
                      padding: const EdgeInsets.symmetric(vertical: 12),
                    ),
                    icon: const Icon(Icons.check_circle),
                    label: const Text('Sucesso'),
                    onPressed: _finalizarComSucesso,
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: ElevatedButton.icon(
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.red,
                      padding: const EdgeInsets.symmetric(vertical: 12),
                    ),
                    icon: const Icon(Icons.cancel),
                    label: const Text('Recusar'),
                    onPressed: _recusarColeta,
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildCardFoto() {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('Foto da Coleta', style: Theme.of(context).textTheme.titleMedium),
            const SizedBox(height: 12),
            if (_fotoPath != null && File(_fotoPath!).existsSync()) ...[
              ClipRRect(
                borderRadius: BorderRadius.circular(8),
                child: Image.file(
                  File(_fotoPath!),
                  height: 180,
                  width: double.infinity,
                  fit: BoxFit.cover,
                ),
              ),
              const SizedBox(height: 8),
              Row(
                children: [
                  Expanded(
                    child: OutlinedButton.icon(
                      icon: const Icon(Icons.refresh, size: 18),
                      label: const Text('Trocar'),
                      onPressed: _tirarFoto,
                    ),
                  ),
                  const SizedBox(width: 8),
                  IconButton(
                    icon: const Icon(Icons.delete_outline, color: Colors.red),
                    onPressed: () => setState(() => _fotoPath = null),
                  ),
                ],
              ),
            ] else ...[
              Container(
                height: 100,
                width: double.infinity,
                decoration: BoxDecoration(
                  color: Colors.grey.shade100,
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(color: Colors.grey.shade300),
                ),
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Icon(Icons.photo_camera_outlined, size: 32, color: Colors.grey[500]),
                    const SizedBox(height: 4),
                    Text('Nenhuma foto', style: TextStyle(color: Colors.grey[600], fontSize: 12)),
                  ],
                ),
              ),
              const SizedBox(height: 8),
              Row(
                children: [
                  Expanded(
                    child: OutlinedButton.icon(
                      icon: const Icon(Icons.photo_camera, size: 18),
                      label: const Text('Câmera'),
                      onPressed: _tirarFoto,
                    ),
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: OutlinedButton.icon(
                      icon: const Icon(Icons.photo_library, size: 18),
                      label: const Text('Galeria'),
                      onPressed: _escolherFotoGaleria,
                    ),
                  ),
                ],
              ),
            ],
          ],
        ),
      ),
    );
  }

  Widget _buildCardAssinatura() {
    final jaAssinada = widget.parada.assinaturaBase64 != null;
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text('Assinatura do Produtor', style: Theme.of(context).textTheme.titleMedium),
                TextButton.icon(
                  icon: const Icon(Icons.clear, size: 16),
                  label: const Text('Limpar'),
                  onPressed: () => _signatureController.clear(),
                ),
              ],
            ),
            const SizedBox(height: 8),
            if (jaAssinada) ...[
              Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: Colors.green.shade50,
                  borderRadius: BorderRadius.circular(6),
                ),
                child: Row(
                  children: [
                    const Icon(Icons.verified, color: Colors.green, size: 18),
                    const SizedBox(width: 6),
                    Expanded(
                      child: Image.memory(
                        base64Decode(widget.parada.assinaturaBase64!),
                        height: 60,
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 8),
              Text('Assine abaixo para atualizar:', style: TextStyle(fontSize: 12, color: Colors.grey[600])),
              const SizedBox(height: 4),
            ],
            Container(
              decoration: BoxDecoration(
                border: Border.all(color: Colors.grey.shade400),
                borderRadius: BorderRadius.circular(8),
              ),
              child: ClipRRect(
                borderRadius: BorderRadius.circular(8),
                child: Signature(
                  controller: _signatureController,
                  height: 150,
                  backgroundColor: Colors.grey.shade50,
                ),
              ),
            ),
            const SizedBox(height: 4),
            Text(
              'Peça para o produtor assinar no quadro acima',
              style: TextStyle(fontSize: 11, color: Colors.grey[500]),
            ),
          ],
        ),
      ),
    );
  }

  /// Captura a assinatura e atualiza a parada
  Future<void> _captureAssinatura() async {
    try {
      final signature = await _signatureController.toPngBytes();
      if (signature == null || signature.isEmpty) {
        if (!mounted) return;
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Por favor, assine o documento')),
        );
        return;
      }

      // Converter para base64
      final assinaturaBase64 = 'data:image/png;base64,${base64Encode(signature)}';

      // Atualizar parada
      final viewModel = context.read<ColetaViewModel>();
      await viewModel.finalizarColetaComSucesso(
        parada: widget.parada,
        temperatura: 0, // Valor padrão
        volume: 0, // Valor padrão
        assinaturaBase64: assinaturaBase64,
      );

      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('✅ Coleta finalizada com assinatura'),
          backgroundColor: Colors.green,
        ),
      );

      // Fechar tela
      Navigator.pop(context, true);
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Erro: $e')),
      );
    }
  }
}

class _InfoRow extends StatelessWidget {
  final String label;
  final String value;

  const _InfoRow({required this.label, required this.value});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(label, style: const TextStyle(color: Colors.grey, fontSize: 12)),
          Text(value, style: const TextStyle(fontWeight: FontWeight.w600)),
        ],
      ),
    );
  }
}
