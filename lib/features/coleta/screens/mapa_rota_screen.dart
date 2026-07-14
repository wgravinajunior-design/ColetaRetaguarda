import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:latlong2/latlong.dart';
import '../models/parada_model.dart';
import '../services/map_service.dart';

class MapaRotaScreen extends StatefulWidget {
  final List<ParadaModel> paradas;
  final String rotaDescricao;

  const MapaRotaScreen({
    super.key,
    required this.paradas,
    required this.rotaDescricao,
  });

  @override
  State<MapaRotaScreen> createState() => _MapaRotaScreenState();
}

class _MapaRotaScreenState extends State<MapaRotaScreen> {
  late MapController _mapController;

  @override
  void initState() {
    super.initState();
    _mapController = MapController();
  }

  @override
  void dispose() {
    _mapController.dispose();
    super.dispose();
  }

  void _centralizarMapa() {
    if (widget.paradas.isEmpty) return;

    final paradassJson = widget.paradas
        .map((p) => {'latitude': p.latitude, 'longitude': p.longitude})
        .toList();

    final center = MapService.paradasListToLatLng(paradassJson);
    _mapController.move(center, 13);
  }

  @override
  Widget build(BuildContext context) {
    final paradassJson = widget.paradas
        .map((p) => {'latitude': p.latitude, 'longitude': p.longitude})
        .toList();

    final center = MapService.paradasListToLatLng(paradassJson);
    final polyline = MapService.paradasToPolyline(paradassJson);

    return Scaffold(
      appBar: AppBar(
        title: Text('Mapa - ${widget.rotaDescricao}'),
        actions: [
          IconButton(
            icon: const Icon(Icons.center_focus_strong),
            onPressed: _centralizarMapa,
          ),
        ],
      ),
      body: Stack(
        children: [
          FlutterMap(
            mapController: _mapController,
            options: MapOptions(
              initialCenter: center,
              initialZoom: 13,
              maxZoom: 19,
              minZoom: 5,
            ),
            children: [
              TileLayer(
                urlTemplate: 'https://tile.openstreetmap.org/{z}/{x}/{y}.png',
                userAgentPackageName: 'com.example.flutter_retaguarda',
                maxZoom: 19,
              ),
              // Polyline da rota
              if (polyline.length > 1)
                PolylineLayer(
                  polylines: [
                    Polyline(
                      points: polyline,
                      color: Colors.blue,
                      strokeWidth: 4,
                    ),
                  ],
                ),
              // Marcadores das paradas
              MarkerLayer(
                markers: _buildMarkers(),
              ),
            ],
          ),
          // Legenda
          Positioned(
            bottom: 16,
            left: 16,
            child: Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(8),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withOpacity(0.2),
                    blurRadius: 4,
                    offset: const Offset(0, 2),
                  ),
                ],
              ),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                    'Legenda',
                    style: TextStyle(fontWeight: FontWeight.bold),
                  ),
                  const SizedBox(height: 8),
                  _LegendaItem(emoji: '🔴', label: 'Pendente'),
                  _LegendaItem(emoji: '🟡', label: 'Em Andamento'),
                  _LegendaItem(emoji: '🟢', label: 'Concluída'),
                  _LegendaItem(emoji: '⚫', label: 'Recusada'),
                ],
              ),
            ),
          ),
          // Estatísticas
          Positioned(
            top: 16,
            right: 16,
            child: Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(8),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withOpacity(0.2),
                    blurRadius: 4,
                    offset: const Offset(0, 2),
                  ),
                ],
              ),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    '${widget.paradas.length} paradas',
                    style: const TextStyle(fontWeight: FontWeight.bold),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    '🔴 ${widget.paradas.where((p) => p.status == 'P').length}',
                  ),
                  Text(
                    '🟡 ${widget.paradas.where((p) => p.status == 'E').length}',
                  ),
                  Text(
                    '🟢 ${widget.paradas.where((p) => p.status == 'C').length}',
                  ),
                  Text(
                    '⚫ ${widget.paradas.where((p) => p.status == 'R').length}',
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  List<Marker> _buildMarkers() {
    return List.generate(
      widget.paradas.length,
      (index) {
        final parada = widget.paradas[index];
        final color = MapService.getStatusColor(parada.status);

        return Marker(
          point: LatLng(parada.latitude, parada.longitude),
          width: 40,
          height: 40,
          child: GestureDetector(
            onTap: () => _mostrarDetalhes(parada, index + 1),
            child: Container(
              decoration: BoxDecoration(
                color: color,
                shape: BoxShape.circle,
                border: Border.all(color: Colors.white, width: 2),
                boxShadow: [
                  BoxShadow(
                    color: color.withOpacity(0.5),
                    blurRadius: 8,
                  ),
                ],
              ),
              child: Center(
                child: Text(
                  '${index + 1}',
                  style: const TextStyle(
                    color: Colors.white,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
            ),
          ),
        );
      },
    );
  }

  void _mostrarDetalhes(ParadaModel parada, int numero) {
    showModalBottomSheet(
      context: context,
      builder: (context) => Container(
        padding: const EdgeInsets.all(16),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Container(
                  width: 40,
                  height: 40,
                  decoration: BoxDecoration(
                    color: MapService.getStatusColor(parada.status),
                    shape: BoxShape.circle,
                  ),
                  child: Center(
                    child: Text(
                      '$numero',
                      style: const TextStyle(
                        color: Colors.white,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),
                ),
                const SizedBox(width: 12),
                Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      parada.pessoaNome,
                      style: const TextStyle(
                        fontWeight: FontWeight.bold,
                        fontSize: 16,
                      ),
                    ),
                    Text(
                      parada.statusEmoji + ' ' + parada.statusLabel,
                      style: TextStyle(
                        color: MapService.getStatusColor(parada.status),
                        fontSize: 12,
                      ),
                    ),
                  ],
                ),
              ],
            ),
            const SizedBox(height: 16),
            Text(
              parada.pessoaNome,
              style: const TextStyle(fontWeight: FontWeight.bold),
            ),
            Text(parada.cnpjCpf, style: const TextStyle(fontSize: 12)),
            const SizedBox(height: 8),
            Text(parada.endereco, style: const TextStyle(fontSize: 12)),
            const SizedBox(height: 8),
            Text(
              'Lat: ${parada.latitude.toStringAsFixed(6)}, Long: ${parada.longitude.toStringAsFixed(6)}',
              style: const TextStyle(fontSize: 11, color: Colors.grey),
            ),
            if (parada.temperatura != null) ...[
              const SizedBox(height: 8),
              Text('🌡️ Temperatura: ${parada.temperatura}°C'),
            ],
            if (parada.volume != null) ...[
              const SizedBox(height: 4),
              Text('💧 Volume: ${parada.volume}L'),
            ],
            if (parada.gpsCapturaLatitude != null) ...[
              const SizedBox(height: 8),
              Text(
                'GPS Capturado: ${parada.gpsCapturaLatitude!.toStringAsFixed(6)}, ${parada.gpsCapturaltitude!.toStringAsFixed(6)}',
                style: const TextStyle(fontSize: 11, color: Colors.green),
              ),
            ],
            const SizedBox(height: 16),
            SizedBox(
              width: double.infinity,
              child: ElevatedButton(
                onPressed: () => Navigator.pop(context),
                child: const Text('Fechar'),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _LegendaItem extends StatelessWidget {
  final String emoji;
  final String label;

  const _LegendaItem({
    required this.emoji,
    required this.label,
  });

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Text(emoji, style: const TextStyle(fontSize: 14)),
        const SizedBox(width: 6),
        Text(label, style: const TextStyle(fontSize: 12)),
      ],
    );
  }
}
