import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import '../coleta/repositories/parada_repository.dart';
import '../coleta/models/parada_model.dart';
import '../rotas/repositories/rota_repository.dart';
import '../produtores/repositories/pessoa_repository.dart';

class DashboardScreen extends StatefulWidget {
  const DashboardScreen({super.key});

  @override
  State<DashboardScreen> createState() => _DashboardScreenState();
}

class _DashboardScreenState extends State<DashboardScreen> {
  bool _loading = true;

  int _totalRotas = 0;
  int _totalProdutores = 0;
  List<ParadaModel> _coletas = [];

  @override
  void initState() {
    super.initState();
    _carregar();
  }

  Future<void> _carregar() async {
    setState(() => _loading = true);
    try {
      final rotas = await RotaRepository().getRotas();
      final produtores = await PessoaRepository().getProdutores();
      final coletas = await ParadaRepository().getTodasColetas();

      if (!mounted) return;
      setState(() {
        _totalRotas = rotas.length;
        _totalProdutores = produtores.length;
        _coletas = coletas;
        _loading = false;
      });
    } catch (e) {
      if (mounted) setState(() => _loading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Dashboard'),
        elevation: 0,
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh),
            tooltip: 'Atualizar',
            onPressed: _carregar,
          ),
        ],
      ),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : RefreshIndicator(
              onRefresh: _carregar,
              child: _buildConteudo(),
            ),
    );
  }

  Widget _buildConteudo() {
    final pendentes = _coletas.where((p) => p.status == 'P').length;
    final andamento = _coletas.where((p) => p.status == 'E').length;
    final concluidas = _coletas.where((p) => p.status == 'C').length;
    final recusadas = _coletas.where((p) => p.status == 'R').length;
    final totalLitros = _coletas
        .where((p) => p.status == 'C')
        .fold<double>(0, (s, p) => s + (p.volume ?? 0));
    final tempsValidas = _coletas
        .where((p) => p.status == 'C' && p.temperatura != null)
        .map((p) => p.temperatura!)
        .toList();
    final tempMedia = tempsValidas.isEmpty
        ? null
        : tempsValidas.reduce((a, b) => a + b) / tempsValidas.length;

    final progresso = _coletas.isEmpty ? 0.0 : concluidas / _coletas.length;

    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        // Cadastros gerais
        Text('Cadastros', style: Theme.of(context).textTheme.titleMedium),
        const SizedBox(height: 8),
        Row(
          children: [
            _CardMetrica(
              icon: Icons.local_shipping,
              cor: Colors.teal,
              valor: '$_totalRotas',
              label: 'Rotas',
              onTap: () => context.go('/rotas'),
            ),
            _CardMetrica(
              icon: Icons.people,
              cor: Colors.green,
              valor: '$_totalProdutores',
              label: 'Produtores',
              onTap: () => context.go('/produtores'),
            ),
            _CardMetrica(
              icon: Icons.agriculture,
              cor: Colors.brown,
              valor: '${_coletas.length}',
              label: 'Coletas',
              onTap: () => context.go('/coleta'),
            ),
          ],
        ),
        const SizedBox(height: 24),

        // Produção
        Text('Produção', style: Theme.of(context).textTheme.titleMedium),
        const SizedBox(height: 8),
        Row(
          children: [
            _CardMetrica(
              icon: Icons.water_drop,
              cor: Colors.blue,
              valor: '${totalLitros.toStringAsFixed(0)} L',
              label: 'Coletado',
            ),
            _CardMetrica(
              icon: Icons.thermostat,
              cor: Colors.deepOrange,
              valor: tempMedia == null ? '—' : '${tempMedia.toStringAsFixed(1)}°C',
              label: 'Temp. média',
            ),
            _CardMetrica(
              icon: Icons.check_circle,
              cor: Colors.green,
              valor: '$concluidas',
              label: 'Concluídas',
            ),
          ],
        ),
        const SizedBox(height: 24),

        // Progresso das coletas
        Text('Status das Coletas', style: Theme.of(context).textTheme.titleMedium),
        const SizedBox(height: 8),
        Card(
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Expanded(
                      child: Text(
                        'Progresso geral',
                        style: TextStyle(color: Colors.grey[700]),
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                    const SizedBox(width: 8),
                    Text(
                      '${(progresso * 100).toStringAsFixed(0)}%',
                      style: const TextStyle(fontWeight: FontWeight.bold),
                    ),
                  ],
                ),
                const SizedBox(height: 8),
                ClipRRect(
                  borderRadius: BorderRadius.circular(8),
                  child: LinearProgressIndicator(
                    value: progresso,
                    minHeight: 10,
                    backgroundColor: Colors.grey[300],
                    valueColor: const AlwaysStoppedAnimation<Color>(Colors.green),
                  ),
                ),
                const SizedBox(height: 16),
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceAround,
                  children: [
                    Expanded(child: _StatusMini(emoji: '🔴', label: 'Pendentes', count: pendentes)),
                    Expanded(child: _StatusMini(emoji: '🟡', label: 'Andamento', count: andamento)),
                    Expanded(child: _StatusMini(emoji: '🟢', label: 'Concluídas', count: concluidas)),
                    Expanded(child: _StatusMini(emoji: '⚫', label: 'Recusadas', count: recusadas)),
                  ],
                ),
              ],
            ),
          ),
        ),
        const SizedBox(height: 24),

        // Atalho
        SizedBox(
          width: double.infinity,
          child: ElevatedButton.icon(
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.brown,
              padding: const EdgeInsets.symmetric(vertical: 14),
            ),
            icon: const Icon(Icons.agriculture, color: Colors.white),
            label: const Text('Ver todas as coletas', style: TextStyle(color: Colors.white)),
            onPressed: () => context.go('/coleta'),
          ),
        ),
      ],
    );
  }
}

class _CardMetrica extends StatelessWidget {
  final IconData icon;
  final Color cor;
  final String valor;
  final String label;
  final VoidCallback? onTap;

  const _CardMetrica({
    required this.icon,
    required this.cor,
    required this.valor,
    required this.label,
    this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return Expanded(
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 4),
        child: Card(
          child: InkWell(
            onTap: onTap,
            borderRadius: BorderRadius.circular(12),
            child: Padding(
              padding: const EdgeInsets.symmetric(vertical: 16, horizontal: 8),
              child: Column(
                children: [
                  Icon(icon, color: cor, size: 28),
                  const SizedBox(height: 8),
                  Text(
                    valor,
                    style: TextStyle(fontWeight: FontWeight.bold, fontSize: 18, color: cor),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    label,
                    textAlign: TextAlign.center,
                    style: TextStyle(fontSize: 11, color: Colors.grey[600]),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _StatusMini extends StatelessWidget {
  final String emoji;
  final String label;
  final int count;

  const _StatusMini({required this.emoji, required this.label, required this.count});

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        Text(emoji, style: const TextStyle(fontSize: 22)),
        const SizedBox(height: 4),
        Text('$count', style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
        Text(
          label,
          style: const TextStyle(fontSize: 10),
          textAlign: TextAlign.center,
          overflow: TextOverflow.ellipsis,
        ),
      ],
    );
  }
}
