import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:geolocator/geolocator.dart';
import '../models/parada_model.dart';
import '../viewmodels/coleta_viewmodel.dart';
import '../widgets/mini_map.dart';

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
  Position? _currentPosition;
  bool _loadingGPS = false;
  String? _gpsError;

  @override
  void initState() {
    super.initState();
    _temperatureController = TextEditingController();
    _volumeController = TextEditingController();
    _justificativaController = TextEditingController();
  }

  @override
  void dispose() {
    _temperatureController.dispose();
    _volumeController.dispose();
    _justificativaController.dispose();
    super.dispose();
  }

  Future<void> _capturarGPS() async {
    setState(() {
      _loadingGPS = true;
      _gpsError = null;
    });

    try {
      final hasPermission = await _verificarPermissaoGPS();
      if (!hasPermission) {
        setState(() {
          _gpsError = 'Permissão de GPS negada';
          _loadingGPS = false;
        });
        return;
      }

      final position = await Geolocator.getCurrentPosition(
        desiredAccuracy: LocationAccuracy.high,
        timeLimit: const Duration(seconds: 30),
      );

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
    } catch (e) {
      setState(() {
        _gpsError = 'Erro ao capturar GPS: $e';
        _loadingGPS = false;
      });
    }
  }

  Future<bool> _verificarPermissaoGPS() async {
    LocationPermission permission = await Geolocator.checkPermission();
    if (permission == LocationPermission.denied) {
      permission = await Geolocator.requestPermission();
    }
    return permission == LocationPermission.whileInUse || permission == LocationPermission.always;
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

    final viewModel = context.read<ColetaViewModel>();
    final success = await viewModel.finalizarColetaComSucesso(
      parada: widget.parada,
      temperatura: temp,
      volume: vol,
    );

    if (success && mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Coleta finalizada com sucesso!')),
      );
      Navigator.pop(context);
    }
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
                    if (_currentPosition != null) ...[
                      Container(
                        padding: const EdgeInsets.all(12),
                        decoration: BoxDecoration(
                          color: Colors.green.shade50,
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            const Text('✅ GPS Capturado', style: TextStyle(color: Colors.green, fontWeight: FontWeight.bold)),
                            const SizedBox(height: 8),
                            Text('Lat: ${_currentPosition!.latitude.toStringAsFixed(6)}'),
                            Text('Long: ${_currentPosition!.longitude.toStringAsFixed(6)}'),
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
                        child: Text(
                          _gpsError!,
                          style: TextStyle(color: Colors.red.shade900),
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
                        label: _loadingGPS ? const Text('Capturando GPS...') : const Text('Capturar GPS Agora'),
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
