import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:fl_chart/fl_chart.dart';
import '../coleta/repositories/parada_repository.dart';
import '../coleta/models/parada_model.dart';
import '../rotas/repositories/rota_repository.dart';
import '../produtores/repositories/pessoa_repository.dart';
import '../core/sync/recarrega_ao_sincronizar.dart';

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
    return RecarregaAoSincronizar(
      // Os números do dashboard mudam a cada coleta que o celular envia.
      aoAlterar: _carregar,
      child: Scaffold(
        backgroundColor: const Color(0xFFF3F5F4),
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
            : RefreshIndicator(onRefresh: _carregar, child: _buildConteudo()),
      ),
    );
  }

  static const _corPendente = Color(0xFFE4572E);
  static const _corAndamento = Color(0xFFD9A441);
  static const _corConcluida = Color(0xFF2F9E63);
  static const _corRecusada = Color(0xFF7C4DA8);

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
        // Resumo geral em destaque
        _ResumoHero(
          progresso: progresso,
          concluidas: concluidas,
          total: _coletas.length,
        ),
        const SizedBox(height: 24),

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
              valor: tempMedia == null
                  ? '—'
                  : '${tempMedia.toStringAsFixed(1)}°C',
              label: 'Temp. média',
            ),
            _CardMetrica(
              icon: Icons.check_circle,
              cor: _corConcluida,
              valor: '$concluidas',
              label: 'Concluídas',
            ),
          ],
        ),
        const SizedBox(height: 24),

        // Distribuição de status em gráfico de rosca
        Text(
          'Status das Coletas',
          style: Theme.of(context).textTheme.titleMedium,
        ),
        const SizedBox(height: 8),
        Card(
          elevation: 0,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(16),
            side: BorderSide(color: Colors.grey.shade200),
          ),
          child: Padding(
            padding: const EdgeInsets.all(20),
            child: _coletas.isEmpty
                ? const Padding(
                    padding: EdgeInsets.symmetric(vertical: 24),
                    child: Center(child: Text('Nenhuma coleta registrada')),
                  )
                : _StatusDonutChart(
                    pendentes: pendentes,
                    andamento: andamento,
                    concluidas: concluidas,
                    recusadas: recusadas,
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
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(12),
              ),
            ),
            icon: const Icon(Icons.agriculture, color: Colors.white),
            label: const Text(
              'Ver todas as coletas',
              style: TextStyle(color: Colors.white),
            ),
            onPressed: () => context.go('/coleta'),
          ),
        ),
      ],
    );
  }
}

class _ResumoHero extends StatelessWidget {
  final double progresso;
  final int concluidas;
  final int total;

  const _ResumoHero({
    required this.progresso,
    required this.concluidas,
    required this.total,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          colors: [Color(0xFF2E7D4F), Color(0xFF1B5E3A)],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(18),
        boxShadow: [
          BoxShadow(
            color: const Color(0xFF1B5E3A).withValues(alpha: 0.25),
            blurRadius: 16,
            offset: const Offset(0, 8),
          ),
        ],
      ),
      child: Row(
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  'Progresso geral',
                  style: TextStyle(color: Colors.white70, fontSize: 13),
                ),
                const SizedBox(height: 4),
                Text(
                  '${(progresso * 100).toStringAsFixed(0)}%',
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 32,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  '$concluidas de $total coletas concluídas',
                  style: const TextStyle(color: Colors.white70, fontSize: 12),
                ),
              ],
            ),
          ),
          SizedBox(
            width: 72,
            height: 72,
            child: Stack(
              alignment: Alignment.center,
              children: [
                TweenAnimationBuilder<double>(
                  tween: Tween(begin: 0, end: progresso),
                  duration: const Duration(milliseconds: 700),
                  curve: Curves.easeOutCubic,
                  builder: (context, value, _) => CircularProgressIndicator(
                    value: value,
                    strokeWidth: 7,
                    backgroundColor: Colors.white24,
                    valueColor: const AlwaysStoppedAnimation<Color>(
                      Colors.white,
                    ),
                  ),
                ),
                const Icon(Icons.agriculture, color: Colors.white, size: 26),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _StatusDonutChart extends StatelessWidget {
  final int pendentes;
  final int andamento;
  final int concluidas;
  final int recusadas;

  const _StatusDonutChart({
    required this.pendentes,
    required this.andamento,
    required this.concluidas,
    required this.recusadas,
  });

  @override
  Widget build(BuildContext context) {
    final total = pendentes + andamento + concluidas + recusadas;
    final itens = <_StatusItem>[
      _StatusItem(
        'Pendentes',
        pendentes,
        _DashboardScreenState._corPendente,
      ),
      _StatusItem(
        'Andamento',
        andamento,
        _DashboardScreenState._corAndamento,
      ),
      _StatusItem(
        'Concluídas',
        concluidas,
        _DashboardScreenState._corConcluida,
      ),
      _StatusItem(
        'Recusadas',
        recusadas,
        _DashboardScreenState._corRecusada,
      ),
    ];

    return Column(
      children: [
        SizedBox(
          height: 180,
          child: Row(
            children: [
              Expanded(
                child: PieChart(
                  PieChartData(
                    sectionsSpace: 2,
                    centerSpaceRadius: 42,
                    sections: itens.map((item) {
                      final pct = total == 0 ? 0.0 : item.count / total * 100;
                      final destacar = item.count > 0;
                      return PieChartSectionData(
                        value: item.count.toDouble().clamp(
                          0.0001,
                          double.infinity,
                        ),
                        color: item.cor,
                        radius: destacar ? 46 : 40,
                        title: item.count == 0
                            ? ''
                            : '${pct.toStringAsFixed(0)}%',
                        titleStyle: const TextStyle(
                          fontSize: 12,
                          fontWeight: FontWeight.bold,
                          color: Colors.white,
                        ),
                      );
                    }).toList(),
                  ),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: itens
                      .map(
                        (item) => Padding(
                          padding: const EdgeInsets.symmetric(vertical: 6),
                          child: Row(
                            children: [
                              Container(
                                width: 10,
                                height: 10,
                                decoration: BoxDecoration(
                                  color: item.cor,
                                  shape: BoxShape.circle,
                                ),
                              ),
                              const SizedBox(width: 8),
                              Expanded(
                                child: Text(
                                  item.label,
                                  style: const TextStyle(fontSize: 12),
                                  overflow: TextOverflow.ellipsis,
                                ),
                              ),
                              Text(
                                '${item.count}',
                                style: const TextStyle(
                                  fontSize: 12,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                            ],
                          ),
                        ),
                      )
                      .toList(),
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }
}

class _StatusItem {
  final String label;
  final int count;
  final Color cor;
  _StatusItem(this.label, this.count, this.cor);
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
          elevation: 0,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(14),
            side: BorderSide(color: Colors.grey.shade200),
          ),
          child: InkWell(
            onTap: onTap,
            borderRadius: BorderRadius.circular(14),
            child: Padding(
              padding: const EdgeInsets.symmetric(vertical: 16, horizontal: 8),
              child: Column(
                children: [
                  Container(
                    padding: const EdgeInsets.all(10),
                    decoration: BoxDecoration(
                      color: cor.withValues(alpha: 0.12),
                      shape: BoxShape.circle,
                    ),
                    child: Icon(icon, color: cor, size: 24),
                  ),
                  const SizedBox(height: 10),
                  Text(
                    valor,
                    style: TextStyle(
                      fontWeight: FontWeight.bold,
                      fontSize: 18,
                      color: cor,
                    ),
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
