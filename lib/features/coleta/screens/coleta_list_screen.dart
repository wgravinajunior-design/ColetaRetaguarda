import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../models/parada_model.dart';
import '../viewmodels/coleta_viewmodel.dart';
import '../../core/sync/recarrega_ao_sincronizar.dart';
import 'coleta_parada_screen.dart';

class ColetaListScreen extends StatefulWidget {
  const ColetaListScreen({super.key});

  @override
  State<ColetaListScreen> createState() => _ColetaListScreenState();
}

class _ColetaListScreenState extends State<ColetaListScreen> {
  final _buscaController = TextEditingController();
  String _busca = '';

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      context.read<ColetaViewModel>().loadTodasColetas();
    });
  }

  @override
  void dispose() {
    _buscaController.dispose();
    super.dispose();
  }

  /// Aplica o filtro de busca por produtor/CNPJ/endereço sobre a lista já
  /// filtrada por status no viewmodel.
  List<ParadaModel> _filtrarBusca(List<ParadaModel> itens) {
    if (_busca.isEmpty) return itens;
    final q = _busca.toLowerCase();
    return itens.where((p) {
      return p.pessoaNome.toLowerCase().contains(q) ||
          p.cnpjCpf.toLowerCase().contains(q) ||
          p.endereco.toLowerCase().contains(q);
    }).toList();
  }

  /// Recarrega quando o celular grava uma coleta, sem o usuário sair da tela.
  void _recarregar() {
    final vm = context.read<ColetaViewModel>();
    vm.loadTodasColetas(status: vm.filtroStatus);
  }

  @override
  Widget build(BuildContext context) {
    return RecarregaAoSincronizar(
      aoAlterar: _recarregar,
      child: Scaffold(
        backgroundColor: const Color(0xFFF3F5F4),
        appBar: AppBar(
          title: const Text('Coletas'),
          elevation: 0,
          actions: [
            Consumer<ColetaViewModel>(
              builder: (context, vm, _) => IconButton(
                icon: const Icon(Icons.refresh),
                tooltip: 'Recarregar',
                onPressed: () => vm.loadTodasColetas(status: vm.filtroStatus),
              ),
            ),
          ],
        ),
        body: Consumer<ColetaViewModel>(
          builder: (context, vm, _) {
            final visiveis = _filtrarBusca(vm.items);
            return Column(
              children: [
                _buildResumo(vm),
                _buildPeriodo(vm),
                _buildBusca(),
                _buildFiltros(vm),
                const Divider(height: 1),
                Expanded(child: _buildLista(vm, visiveis)),
              ],
            );
          },
        ),
      ),
    );
  }

  Widget _buildResumo(ColetaViewModel vm) {
    final concluidas = vm.items.where((p) => p.status == 'C').toList();
    final totalLitros = concluidas.fold<double>(
      0,
      (s, p) => s + (p.volume ?? 0),
    );
    final pendentes = vm.items
        .where((p) => p.status == 'P' || p.status == 'E')
        .length;

    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 12, 16, 4),
      child: Row(
        children: [
          _ResumoCard(
            icon: Icons.water_drop,
            cor: Colors.blue,
            valor: '${totalLitros.toStringAsFixed(0)} L',
            label: 'Coletado',
          ),
          _ResumoCard(
            icon: Icons.check_circle,
            cor: Colors.green,
            valor: '${concluidas.length}',
            label: 'Concluídas',
          ),
          _ResumoCard(
            icon: Icons.pending_actions,
            cor: Colors.orange,
            valor: '$pendentes',
            label: 'A coletar',
          ),
        ],
      ),
    );
  }

  /// Recorte por data da rota. Abre no dia de hoje — é a operação corrente;
  /// sem isso a lista trazia o histórico inteiro logo de cara.
  Widget _buildPeriodo(ColetaViewModel vm) {
    String rotulo(DateTime? d) {
      if (d == null) return '—';
      final hoje = DateTime.now();
      if (d.year == hoje.year && d.month == hoje.month && d.day == hoje.day) {
        return 'Hoje';
      }
      String dois(int n) => n.toString().padLeft(2, '0');
      return '${dois(d.day)}/${dois(d.month)}/${d.year}';
    }

    Future<void> escolher({required bool ehInicio}) async {
      final hoje = DateTime.now();
      final d = await showDatePicker(
        context: context,
        initialDate: (ehInicio ? vm.inicio : vm.fim) ?? hoje,
        firstDate: DateTime(hoje.year - 5),
        lastDate: DateTime(hoje.year + 1),
      );
      if (d == null) return;
      vm.aplicarPeriodo(ehInicio ? d : vm.inicio, ehInicio ? vm.fim : d);
    }

    final semPeriodo = vm.inicio == null && vm.fim == null;

    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 8, 16, 4),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(10),
          border: Border.all(color: Colors.grey.shade200),
        ),
        child: Row(
          children: [
            Icon(Icons.event, size: 15, color: Colors.grey[500]),
            const SizedBox(width: 8),
            Expanded(
              child: OutlinedButton(
                style: OutlinedButton.styleFrom(
                  visualDensity: VisualDensity.compact,
                  side: BorderSide(color: Colors.grey.shade300),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(8),
                  ),
                ),
                onPressed: () => escolher(ehInicio: true),
                child: Text(
                  'De: ${rotulo(vm.inicio)}',
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(fontSize: 12),
                ),
              ),
            ),
            const SizedBox(width: 8),
            Expanded(
              child: OutlinedButton(
                style: OutlinedButton.styleFrom(
                  visualDensity: VisualDensity.compact,
                  side: BorderSide(color: Colors.grey.shade300),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(8),
                  ),
                ),
                onPressed: () => escolher(ehInicio: false),
                child: Text(
                  'Até: ${rotulo(vm.fim)}',
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(fontSize: 12),
                ),
              ),
            ),
            const SizedBox(width: 8),
            TextButton.icon(
              style: TextButton.styleFrom(
                visualDensity: VisualDensity.compact,
              ),
              icon: Icon(
                semPeriodo ? Icons.today : Icons.filter_alt_off,
                size: 15,
              ),
              label: Text(
                semPeriodo ? 'Hoje' : 'Todo período',
                style: const TextStyle(fontSize: 12),
              ),
              onPressed: () {
                if (semPeriodo) {
                  final hoje = DateTime.now();
                  vm.aplicarPeriodo(hoje, hoje);
                } else {
                  vm.limparPeriodo();
                }
              },
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildBusca() {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 8, 16, 4),
      child: TextField(
        controller: _buscaController,
        onChanged: (v) => setState(() => _busca = v),
        style: const TextStyle(fontSize: 13),
        decoration: InputDecoration(
          hintText: 'Buscar por produtor, CNPJ ou endereço...',
          hintStyle: const TextStyle(fontSize: 13),
          prefixIcon: const Icon(Icons.search, size: 20),
          isDense: true,
          filled: true,
          fillColor: Colors.white,
          contentPadding: const EdgeInsets.symmetric(vertical: 10),
          border: OutlineInputBorder(
            borderRadius: BorderRadius.circular(10),
            borderSide: BorderSide(color: Colors.grey.shade200),
          ),
          enabledBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(10),
            borderSide: BorderSide(color: Colors.grey.shade200),
          ),
          suffixIcon: _busca.isNotEmpty
              ? IconButton(
                  icon: const Icon(Icons.clear, size: 18),
                  onPressed: () {
                    _buscaController.clear();
                    setState(() => _busca = '');
                  },
                )
              : null,
        ),
      ),
    );
  }

  Widget _buildFiltros(ColetaViewModel vm) {
    const filtros = <_FiltroStatus>[
      _FiltroStatus(
        status: null,
        label: 'Todos',
        emoji: '📋',
        cor: Colors.blue,
      ),
      _FiltroStatus(
        status: 'P',
        label: 'Pendentes',
        emoji: '🔴',
        cor: Colors.red,
      ),
      _FiltroStatus(
        status: 'E',
        label: 'Em Andamento',
        emoji: '🟡',
        cor: Colors.orange,
      ),
      _FiltroStatus(
        status: 'C',
        label: 'Concluídas',
        emoji: '🟢',
        cor: Colors.green,
      ),
      _FiltroStatus(
        status: 'A',
        label: 'Adiadas',
        emoji: '🔵',
        cor: Colors.blue,
      ),
      _FiltroStatus(
        status: 'R',
        label: 'Recusadas',
        emoji: '⚫',
        cor: Colors.grey,
      ),
      _FiltroStatus(
        status: 'X',
        label: 'Canceladas',
        emoji: '⛔',
        cor: Colors.black54,
      ),
    ];

    return Container(
      padding: const EdgeInsets.fromLTRB(16, 8, 16, 4),
      child: SingleChildScrollView(
        scrollDirection: Axis.horizontal,
        child: Row(
          children: filtros.map((f) {
            final selecionado = vm.filtroStatus == f.status;
            return Padding(
              padding: const EdgeInsets.only(right: 6),
              child: FilterChip(
                label: Text(
                  '${f.emoji} ${f.label}',
                  style: const TextStyle(fontSize: 12),
                ),
                selected: selecionado,
                showCheckmark: false,
                visualDensity: VisualDensity.compact,
                onSelected: (_) => vm.aplicarFiltroStatus(f.status),
                selectedColor: f.cor.withValues(alpha: 0.12),
                backgroundColor: Colors.white,
                labelStyle: TextStyle(
                  color: selecionado ? f.cor : Colors.grey[700],
                  fontWeight: selecionado ? FontWeight.w600 : FontWeight.w400,
                ),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(20),
                  side: BorderSide(
                    color: selecionado ? f.cor : Colors.grey.shade300,
                  ),
                ),
              ),
            );
          }).toList(),
        ),
      ),
    );
  }

  Widget _buildLista(ColetaViewModel vm, List<ParadaModel> visiveis) {
    if (vm.isLoading) {
      return const Center(child: CircularProgressIndicator());
    }

    if (vm.errorMessage != null) {
      return Center(child: Text(vm.errorMessage!));
    }

    if (visiveis.isEmpty) {
      return Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.inbox_outlined, size: 64, color: Colors.grey[400]),
            const SizedBox(height: 12),
            Text(
              _busca.isNotEmpty
                  ? 'Nenhum resultado para "$_busca"'
                  : vm.filtroStatus == null
                  ? 'Nenhuma coleta encontrada'
                  : 'Nenhuma coleta com este status',
              style: TextStyle(color: Colors.grey[600]),
            ),
          ],
        ),
      );
    }

    return Column(
      children: [
        // Contador do total exibido
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 8, 16, 0),
          child: Align(
            alignment: Alignment.centerLeft,
            child: Text(
              '${visiveis.length} ${visiveis.length == 1 ? 'coleta' : 'coletas'}',
              style: TextStyle(
                fontSize: 11,
                color: Colors.grey[500],
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
        ),
        Expanded(
          child: ListView.builder(
            padding: const EdgeInsets.fromLTRB(16, 4, 16, 16),
            itemCount: visiveis.length,
            itemBuilder: (context, index) {
              final parada = visiveis[index];
              return _ColetaCard(
                parada: parada,
                onTap: () async {
                  await Navigator.of(context).push(
                    MaterialPageRoute(
                      builder: (context) => ColetaParadaScreen(parada: parada),
                    ),
                  );
                  // Recarrega ao voltar (status pode ter mudado)
                  if (mounted) {
                    vm.loadTodasColetas(status: vm.filtroStatus);
                  }
                },
              );
            },
          ),
        ),
      ],
    );
  }
}

class _ResumoCard extends StatelessWidget {
  final IconData icon;
  final Color cor;
  final String valor;
  final String label;

  const _ResumoCard({
    required this.icon,
    required this.cor,
    required this.valor,
    required this.label,
  });

  @override
  Widget build(BuildContext context) {
    return Expanded(
      child: Container(
        margin: const EdgeInsets.symmetric(horizontal: 3),
        padding: const EdgeInsets.symmetric(vertical: 10),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(10),
          border: Border.all(color: Colors.grey.shade200),
        ),
        child: Column(
          children: [
            Icon(icon, color: cor, size: 20),
            const SizedBox(height: 4),
            Text(
              valor,
              style: TextStyle(
                fontWeight: FontWeight.bold,
                fontSize: 15,
                color: cor,
              ),
            ),
            Text(
              label,
              style: TextStyle(fontSize: 10, color: Colors.grey[600]),
            ),
          ],
        ),
      ),
    );
  }
}

class _FiltroStatus {
  final String? status;
  final String label;
  final String emoji;
  final Color cor;

  const _FiltroStatus({
    required this.status,
    required this.label,
    required this.emoji,
    required this.cor,
  });
}

class _ColetaCard extends StatelessWidget {
  final ParadaModel parada;
  final VoidCallback onTap;

  const _ColetaCard({required this.parada, required this.onTap});

  Color _statusColor(String status) {
    switch (status) {
      case 'P':
        return Colors.red;
      case 'E':
        return Colors.orange;
      case 'C':
        return Colors.green;
      case 'R':
        return Colors.grey;
      case 'A':
        return Colors.blue;
      case 'X':
        return Colors.black54;
      default:
        return Colors.blue;
    }
  }

  @override
  Widget build(BuildContext context) {
    final cor = _statusColor(parada.status);
    return Card(
      elevation: 0,
      margin: const EdgeInsets.only(bottom: 8),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
        side: BorderSide(color: Colors.grey.shade200),
      ),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(12),
        child: Padding(
          padding: const EdgeInsets.all(10),
          child: Row(
            children: [
              Container(
                width: 38,
                height: 38,
                decoration: BoxDecoration(
                  color: cor.withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(9),
                ),
                child: Center(
                  child: Text(
                    parada.statusEmoji,
                    style: const TextStyle(fontSize: 17),
                  ),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      parada.pessoaNome,
                      style: const TextStyle(
                        fontWeight: FontWeight.w600,
                        fontSize: 14,
                      ),
                    ),
                    if (parada.cnpjCpf.isNotEmpty)
                      Text(
                        parada.cnpjCpf,
                        style: TextStyle(fontSize: 11, color: Colors.grey[600]),
                      ),
                    const SizedBox(height: 2),
                    Text(
                      parada.endereco,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(fontSize: 11, color: Colors.grey[700]),
                    ),
                    const SizedBox(height: 6),
                    Row(
                      children: [
                        Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 8,
                            vertical: 2,
                          ),
                          decoration: BoxDecoration(
                            color: cor.withValues(alpha: 0.1),
                            borderRadius: BorderRadius.circular(20),
                          ),
                          child: Text(
                            parada.statusLabel,
                            style: TextStyle(
                              fontSize: 10,
                              color: cor,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        ),
                        if (parada.status == 'C') ...[
                          const SizedBox(width: 8),
                          if (parada.temperatura != null)
                            _MiniInfo(
                              icon: Icons.thermostat,
                              text:
                                  '${parada.temperatura!.toStringAsFixed(1)}°C',
                            ),
                          if (parada.volume != null) ...[
                            const SizedBox(width: 6),
                            _MiniInfo(
                              icon: Icons.water_drop,
                              text: '${parada.volume!.toStringAsFixed(0)}L',
                            ),
                          ],
                        ],
                      ],
                    ),
                  ],
                ),
              ),
              const Icon(Icons.chevron_right, color: Colors.grey),
            ],
          ),
        ),
      ),
    );
  }
}

class _MiniInfo extends StatelessWidget {
  final IconData icon;
  final String text;

  const _MiniInfo({required this.icon, required this.text});

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(icon, size: 13, color: Colors.grey[600]),
        const SizedBox(width: 2),
        Text(text, style: TextStyle(fontSize: 11, color: Colors.grey[700])),
      ],
    );
  }
}
