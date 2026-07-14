import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:go_router/go_router.dart';
import '../../rotas/viewmodels/rota_viewmodel.dart';
import 'coleta_rotas_screen.dart';

class ColetaListScreen extends StatefulWidget {
  const ColetaListScreen({super.key});

  @override
  State<ColetaListScreen> createState() => _ColetaListScreenState();
}

class _ColetaListScreenState extends State<ColetaListScreen> {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      context.read<RotaViewModel>().loadRotas();
    });
  }

  @override
  Widget build(BuildContext context) {
    final viewModel = context.watch<RotaViewModel>();

    return Scaffold(
      appBar: AppBar(
        title: const Text('Coleta de Leite'),
        elevation: 0,
      ),
      body: viewModel.isLoading
          ? const Center(child: CircularProgressIndicator())
          : _buildBody(viewModel),
    );
  }

  Widget _buildBody(RotaViewModel viewModel) {
    if (viewModel.errorMessage != null) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Icon(Icons.error, size: 64, color: Colors.red),
            const SizedBox(height: 16),
            Text(viewModel.errorMessage!),
            const SizedBox(height: 16),
            ElevatedButton(
              onPressed: () => viewModel.loadRotas(),
              child: const Text('Tentar Novamente'),
            ),
          ],
        ),
      );
    }

    if (viewModel.items.isEmpty) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Icon(Icons.route, size: 64, color: Colors.grey),
            const SizedBox(height: 16),
            const Text('Nenhuma rota disponível'),
            const SizedBox(height: 16),
            ElevatedButton(
              onPressed: () => context.go('/rotas'),
              child: const Text('Criar Rota'),
            ),
          ],
        ),
      );
    }

    return ListView.builder(
      padding: const EdgeInsets.all(12),
      itemCount: viewModel.items.length,
      itemBuilder: (context, index) {
        final rota = viewModel.items[index];
        return Card(
          elevation: 2,
          margin: const EdgeInsets.symmetric(vertical: 8),
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Cabeçalho com nome da rota
                Row(
                  children: [
                    Container(
                      width: 50,
                      height: 50,
                      decoration: BoxDecoration(
                        color: Colors.brown.withOpacity(0.2),
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: const Icon(
                        Icons.agriculture,
                        color: Colors.brown,
                        size: 28,
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            rota.descricao,
                            style: const TextStyle(
                              fontSize: 18,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                          if (rota.regiao != null)
                            Text(
                              '📍 ${rota.regiao}',
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
                const SizedBox(height: 12),
                // Estatísticas
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceAround,
                  children: [
                    _StatItem(
                      icon: Icons.location_on,
                      label: 'Paradas',
                      value: (rota.paradas ?? 0).toString(),
                      color: Colors.red,
                    ),
                    _StatItem(
                      icon: Icons.speed,
                      label: 'Distância',
                      value: '${rota.kmEstimado?.toStringAsFixed(1) ?? '0'} km',
                      color: Colors.blue,
                    ),
                    _StatItem(
                      icon: Icons.info,
                      label: 'Status',
                      value: rota.status == 'A' ? 'Ativo' : 'Inativo',
                      color: rota.status == 'A' ? Colors.green : Colors.grey,
                    ),
                  ],
                ),
                const SizedBox(height: 16),
                // Botão de ação
                SizedBox(
                  width: double.infinity,
                  child: ElevatedButton.icon(
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.brown,
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
              ],
            ),
          ),
        );
      },
    );
  }
}

class _StatItem extends StatelessWidget {
  final IconData icon;
  final String label;
  final String value;
  final Color color;

  const _StatItem({
    required this.icon,
    required this.label,
    required this.value,
    required this.color,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        Icon(icon, color: color, size: 24),
        const SizedBox(height: 4),
        Text(
          value,
          style: TextStyle(
            fontWeight: FontWeight.bold,
            fontSize: 14,
            color: color,
          ),
        ),
        Text(
          label,
          style: const TextStyle(fontSize: 11, color: Colors.grey),
        ),
      ],
    );
  }
}
