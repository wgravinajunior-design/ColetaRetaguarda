import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:go_router/go_router.dart';
import '../models/parada_model.dart';
import '../viewmodels/coleta_viewmodel.dart';
import '../screens/mapa_rota_screen.dart';
import '../../rotas/models/rota_model.dart';

class ColetaRotasScreen extends StatefulWidget {
  final RotaModel rota;

  const ColetaRotasScreen({super.key, required this.rota});

  @override
  State<ColetaRotasScreen> createState() => _ColetaRotasScreenState();
}

class _ColetaRotasScreenState extends State<ColetaRotasScreen> {
  @override
  void initState() {
    super.initState();
    final viewModel = context.read<ColetaViewModel>();
    viewModel.loadParadasFromRota(widget.rota.id ?? 0);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text('Coleta - ${widget.rota.descricao}'),
        elevation: 0,
        actions: [
          IconButton(
            icon: const Icon(Icons.map),
            tooltip: 'Ver Mapa da Rota',
            onPressed: () {
              Navigator.of(context).push(
                MaterialPageRoute(
                  builder: (context) => MapaRotaScreen(
                    paradas: viewModel.items,
                    rotaDescricao: widget.rota.descricao,
                  ),
                ),
              );
            },
          ),
        ],
      ),
      body: Consumer<ColetaViewModel>(
        builder: (context, viewModel, _) {
          if (viewModel.isLoading) {
            return const Center(child: CircularProgressIndicator());
          }

          if (viewModel.items.isEmpty) {
            return const Center(
              child: Text('Nenhuma parada encontrada para esta rota'),
            );
          }

          return Column(
            children: [
              // Indicador de progresso
              Container(
                padding: const EdgeInsets.all(16),
                color: Colors.blue.shade50,
                child: Column(
                  children: [
                    Text(
                      'Progresso da Coleta',
                      style: Theme.of(context).textTheme.titleMedium,
                    ),
                    const SizedBox(height: 8),
                    ClipRRect(
                      borderRadius: BorderRadius.circular(8),
                      child: LinearProgressIndicator(
                        value: viewModel.percentualConclusao / 100,
                        minHeight: 10,
                        backgroundColor: Colors.grey[300],
                        valueColor: AlwaysStoppedAnimation<Color>(Colors.green),
                      ),
                    ),
                    const SizedBox(height: 12),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceAround,
                      children: [
                        _StatCard(
                          emoji: '🔴',
                          label: 'Pendentes',
                          count: viewModel.paradasPendentes,
                        ),
                        _StatCard(
                          emoji: '🟡',
                          label: 'Em Andamento',
                          count: viewModel.paradasEmAndamento,
                        ),
                        _StatCard(
                          emoji: '🟢',
                          label: 'Concluídas',
                          count: viewModel.paradasConcluidas,
                        ),
                        _StatCard(
                          emoji: '⚫',
                          label: 'Recusadas',
                          count: viewModel.paradasRecusadas,
                        ),
                      ],
                    ),
                  ],
                ),
              ),
              // Lista de paradas
              Expanded(
                child: ListView.builder(
                  padding: const EdgeInsets.all(8),
                  itemCount: viewModel.items.length,
                  itemBuilder: (context, index) {
                    final parada = viewModel.items[index];
                    return _ParadaCard(parada: parada, index: index + 1);
                  },
                ),
              ),
            ],
          );
        },
      ),
    );
  }
}

class _StatCard extends StatelessWidget {
  final String emoji;
  final String label;
  final int count;

  const _StatCard({
    required this.emoji,
    required this.label,
    required this.count,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        Text(emoji, style: const TextStyle(fontSize: 24)),
        const SizedBox(height: 4),
        Text(count.toString(), style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
        Text(label, style: const TextStyle(fontSize: 11)),
      ],
    );
  }
}

class _ParadaCard extends StatelessWidget {
  final ParadaModel parada;
  final int index;

  const _ParadaCard({
    required this.parada,
    required this.index,
  });

  Color _getStatusColor(String status) {
    switch (status) {
      case 'P':
        return Colors.red;
      case 'E':
        return Colors.orange;
      case 'C':
        return Colors.green;
      case 'R':
        return Colors.grey;
      default:
        return Colors.blue;
    }
  }

  @override
  Widget build(BuildContext context) {
    return Card(
      margin: const EdgeInsets.symmetric(vertical: 8, horizontal: 0),
      child: ListTile(
        leading: Container(
          width: 40,
          height: 40,
          decoration: BoxDecoration(
            color: _getStatusColor(parada.status).withOpacity(0.2),
            borderRadius: BorderRadius.circular(8),
          ),
          child: Center(
            child: Text(
              '$index',
              style: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.bold,
                color: _getStatusColor(parada.status),
              ),
            ),
          ),
        ),
        title: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              parada.pessoaNome,
              style: const TextStyle(fontWeight: FontWeight.bold),
            ),
            Text(
              parada.cnpjCpf,
              style: TextStyle(fontSize: 12, color: Colors.grey[600]),
            ),
          ],
        ),
        subtitle: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const SizedBox(height: 4),
            Text(parada.endereco, style: const TextStyle(fontSize: 12)),
            const SizedBox(height: 4),
            Row(
              children: [
                Text(
                  parada.statusEmoji,
                  style: const TextStyle(fontSize: 14),
                ),
                const SizedBox(width: 8),
                Text(
                  parada.statusLabel,
                  style: TextStyle(
                    fontSize: 12,
                    color: _getStatusColor(parada.status),
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ],
            ),
          ],
        ),
        trailing: IconButton(
          icon: const Icon(Icons.arrow_forward),
          onPressed: () {
            context.push('/coleta/parada/${parada.id}', extra: parada);
          },
        ),
      ),
    );
  }
}
