import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import '../models/rota_model.dart';
import '../../coleta/screens/coleta_rotas_screen.dart';

class RotaDetalheScreen extends StatelessWidget {
  final RotaModel rota;

  const RotaDetalheScreen({super.key, required this.rota});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(rota.descricao),
        elevation: 0,
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Card com informações principais
            Card(
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Informações da Rota',
                      style: Theme.of(context).textTheme.titleMedium,
                    ),
                    const SizedBox(height: 16),
                    _InfoRow(label: 'Nome', value: rota.descricao),
                    _InfoRow(label: 'Região', value: rota.regiao ?? 'N/A'),
                    _InfoRow(label: 'Status', value: rota.status),
                    _InfoRow(label: 'Paradas', value: (rota.paradas ?? 0).toString()),
                    _InfoRow(label: 'Distância Estimada', value: '${rota.kmEstimado?.toStringAsFixed(1) ?? '0'} km'),
                    _InfoRow(label: 'Distância Realizada', value: '${rota.kmRealizado?.toStringAsFixed(1) ?? '0'} km'),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 24),
            // Botões de ação em linha horizontal
            Text(
              'Ações',
              style: Theme.of(context).textTheme.titleMedium,
            ),
            const SizedBox(height: 12),
            SingleChildScrollView(
              scrollDirection: Axis.horizontal,
              child: Row(
                children: [
                  _BotaoAcaoPequeno(
                    icon: Icons.edit,
                    label: 'Editar',
                    onPressed: () => context.go('/rotas/editar', extra: rota),
                  ),
                  const SizedBox(width: 8),
                  _BotaoAcaoPequeno(
                    icon: Icons.info_outline,
                    label: 'Detalhes',
                    onPressed: () {
                      showModalBottomSheet(
                        context: context,
                        builder: (context) => _DetalhesBottomSheet(rota: rota),
                      );
                    },
                  ),
                  const SizedBox(width: 8),
                  _BotaoAcaoPequeno(
                    icon: Icons.print,
                    label: 'Imprimir',
                    onPressed: () {
                      ScaffoldMessenger.of(context).showSnackBar(
                        const SnackBar(content: Text('Impressão em desenvolvimento')),
                      );
                    },
                  ),
                  const SizedBox(width: 8),
                  _BotaoAcaoPequeno(
                    icon: Icons.map,
                    label: 'Mapa',
                    onPressed: () {
                      ScaffoldMessenger.of(context).showSnackBar(
                        const SnackBar(content: Text('Abrindo mapa...')),
                      );
                    },
                  ),
                  const SizedBox(width: 8),
                  _BotaoAcaoPequeno(
                    icon: Icons.edit_attributes,
                    label: 'Status',
                    onPressed: () {
                      _mostrarDialogoStatus(context);
                    },
                  ),
                ],
              ),
            ),
            const SizedBox(height: 24),
            // Seção de Coleta/Paradas
            Container(
              decoration: BoxDecoration(
                border: Border.all(color: Colors.blue.shade200, width: 1),
                borderRadius: BorderRadius.circular(8),
              ),
              child: Column(
                children: [
                  Container(
                    color: Colors.blue.shade50,
                    padding: const EdgeInsets.all(16),
                    child: Row(
                      children: [
                        const Icon(Icons.agriculture, color: Colors.blue, size: 28),
                        const SizedBox(width: 12),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                'Gerenciar Coleta',
                                style: Theme.of(context).textTheme.titleMedium?.copyWith(
                                  color: Colors.blue,
                                ),
                              ),
                              Text(
                                'Paradas e dados de coleta',
                                style: TextStyle(
                                  fontSize: 12,
                                  color: Colors.grey[600],
                                ),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ),
                  Padding(
                    padding: const EdgeInsets.all(12),
                    child: Row(
                      children: [
                        Expanded(
                          child: ElevatedButton.icon(
                            style: ElevatedButton.styleFrom(
                              backgroundColor: Colors.blue,
                              padding: const EdgeInsets.symmetric(vertical: 12),
                            ),
                            icon: const Icon(Icons.play_arrow),
                            label: const Text('Iniciar Coleta'),
                            onPressed: () {
                              Navigator.of(context).push(
                                MaterialPageRoute(
                                  builder: (context) => ColetaRotasScreen(rota: rota),
                                ),
                              );
                            },
                          ),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: ElevatedButton.icon(
                            style: ElevatedButton.styleFrom(
                              backgroundColor: Colors.blue,
                            ),
                            icon: const Icon(Icons.add),
                            label: const Text('Adicionar Parada'),
                            onPressed: () {
                              ScaffoldMessenger.of(context).showSnackBar(
                                const SnackBar(content: Text('Adicionar parada em desenvolvimento')),
                              );
                            },
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  void _mostrarDialogoStatus(BuildContext context) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Mudar Status'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            _StatusOption(
              status: 'A',
              label: 'Ativo',
              color: Colors.green,
              onTap: () => Navigator.pop(context),
            ),
            _StatusOption(
              status: 'E',
              label: 'Em Coleta',
              color: Colors.orange,
              onTap: () => Navigator.pop(context),
            ),
            _StatusOption(
              status: 'C',
              label: 'Concluída',
              color: Colors.blue,
              onTap: () => Navigator.pop(context),
            ),
            _StatusOption(
              status: 'X',
              label: 'Cancelada',
              color: Colors.red,
              onTap: () => Navigator.pop(context),
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
      padding: const EdgeInsets.symmetric(vertical: 8),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(label, style: const TextStyle(color: Colors.grey)),
          Text(value, style: const TextStyle(fontWeight: FontWeight.bold)),
        ],
      ),
    );
  }
}

class _BotaoAcaoPequeno extends StatelessWidget {
  final IconData icon;
  final String label;
  final VoidCallback onPressed;

  const _BotaoAcaoPequeno({
    required this.icon,
    required this.label,
    required this.onPressed,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        border: Border.all(color: Colors.blue.shade300, width: 1),
        borderRadius: BorderRadius.circular(6),
        color: Colors.white,
      ),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: onPressed,
          borderRadius: BorderRadius.circular(6),
          child: Padding(
            padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 12),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(icon, color: Colors.blue.shade400, size: 20),
                const SizedBox(height: 2),
                Text(
                  label,
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    color: Colors.blue.shade600,
                    fontSize: 11,
                    fontWeight: FontWeight.w500,
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

class _DetalhesBottomSheet extends StatelessWidget {
  final RotaModel rota;

  const _DetalhesBottomSheet({required this.rota});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(16),
      child: SingleChildScrollView(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              rota.descricao,
              style: const TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 16),
            _DetailItem(label: 'Região', value: rota.regiao ?? 'N/A'),
            _DetailItem(label: 'Status', value: rota.status),
            _DetailItem(label: 'Motorista ID', value: '${rota.motoristaId ?? 'N/A'}'),
            _DetailItem(label: 'Veículo ID', value: '${rota.veiculoId ?? 'N/A'}'),
            _DetailItem(label: 'Paradas', value: '${rota.paradas ?? 0}'),
            _DetailItem(label: 'KM Estimado', value: '${rota.kmEstimado?.toStringAsFixed(2) ?? '0'} km'),
            _DetailItem(label: 'KM Realizado', value: '${rota.kmRealizado?.toStringAsFixed(2) ?? '0'} km'),
            _DetailItem(label: 'Data Prevista', value: rota.dataPrevista ?? 'N/A'),
            _DetailItem(label: 'Data Início', value: rota.dataInicio ?? 'N/A'),
            _DetailItem(label: 'Data Fim', value: rota.dataFim ?? 'N/A'),
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

class _DetailItem extends StatelessWidget {
  final String label;
  final String value;

  const _DetailItem({required this.label, required this.value});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(label, style: const TextStyle(fontSize: 12, color: Colors.grey)),
          Text(value, style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w500)),
        ],
      ),
    );
  }
}

class _StatusOption extends StatelessWidget {
  final String status;
  final String label;
  final Color color;
  final VoidCallback onTap;

  const _StatusOption({
    required this.status,
    required this.label,
    required this.color,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: InkWell(
        onTap: onTap,
        child: Container(
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(
            color: color.withOpacity(0.1),
            border: Border.all(color: color),
            borderRadius: BorderRadius.circular(8),
          ),
          child: Row(
            children: [
              Container(
                width: 12,
                height: 12,
                decoration: BoxDecoration(
                  color: color,
                  shape: BoxShape.circle,
                ),
              ),
              const SizedBox(width: 12),
              Text(
                label,
                style: TextStyle(color: color, fontWeight: FontWeight.w500),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

