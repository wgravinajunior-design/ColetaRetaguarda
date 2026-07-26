import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';
import '../models/rota_model.dart';
import '../repositories/rota_repository.dart';
import '../viewmodels/rota_viewmodel.dart';
import '../../coleta/screens/coleta_rotas_screen.dart';
import '../../coleta/screens/adicionar_parada_screen.dart';
import '../../coleta/screens/mapa_rota_screen.dart';
import '../../coleta/repositories/parada_repository.dart';
import '../../coleta/services/comprovante_service.dart';
import '../../core/sync/recarrega_ao_sincronizar.dart';
import '../../../core/widgets/pdf_preview_screen.dart';

class RotaDetalheScreen extends StatelessWidget {
  final RotaModel rota;

  const RotaDetalheScreen({super.key, required this.rota});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(rota.descricao),
        elevation: 0,
        actions: [
          if (rota.status == 'CONCLUIDA')
            TextButton.icon(
              icon: const Icon(Icons.lock_open, color: Colors.white, size: 18),
              label: const Text(
                'Reabrir rota',
                style: TextStyle(color: Colors.white),
              ),
              onPressed: () => _reabrirRota(context),
            )
          else
            TextButton.icon(
              icon: const Icon(Icons.flag, color: Colors.white, size: 18),
              label: const Text(
                'Finalizar rota',
                style: TextStyle(color: Colors.white),
              ),
              onPressed: () => _finalizarRota(context),
            ),
          const SizedBox(width: 8),
        ],
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
                    _InfoRow(
                      label: 'Paradas',
                      value: (rota.paradas ?? 0).toString(),
                    ),
                    _InfoRow(
                      label: 'Distância Estimada',
                      value: '${rota.kmEstimado?.toStringAsFixed(1) ?? '0'} km',
                    ),
                    _InfoRow(
                      label: 'Distância Realizada',
                      value:
                          '${rota.kmRealizado?.toStringAsFixed(1) ?? '0'} km',
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 24),
            // Botões de ação em linha horizontal
            Text('Ações', style: Theme.of(context).textTheme.titleMedium),
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
                    onPressed: () => _imprimirComprovante(context),
                  ),
                  const SizedBox(width: 8),
                  _BotaoAcaoPequeno(
                    icon: Icons.map,
                    label: 'Mapa',
                    onPressed: () => _abrirMapa(context),
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
            _ColetasSection(rota: rota),
          ],
        ),
      ),
    );
  }

  /// Encerra a rota, avisando antes se ficaram coletas em aberto.
  ///
  /// Fechar com coleta pendente deixa o produtor sem registro de atendimento
  /// naquele dia — vale confirmar, mas não impedir: às vezes a rota acaba
  /// mesmo com produtor não atendido.
  Future<void> _finalizarRota(BuildContext context) async {
    final repo = RotaRepository();
    final id = rota.id;
    if (id == null) return;

    int emAberto;
    try {
      emAberto = await repo.coletasEmAberto(id);
    } catch (e) {
      if (!context.mounted) return;
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text('Não foi possível verificar: $e')));
      return;
    }

    if (!context.mounted) return;
    final confirmou = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Finalizar rota'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('Encerrar a rota "${rota.descricao}"?'),
            if (emAberto > 0) ...[
              const SizedBox(height: 12),
              Container(
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(
                  color: Colors.orange.shade50,
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(color: Colors.orange.shade200),
                ),
                child: Row(
                  children: [
                    Icon(
                      Icons.warning_amber_rounded,
                      color: Colors.orange.shade800,
                      size: 20,
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        '$emAberto coleta(s) ainda em aberto. Elas ficarão '
                        'sem registro de atendimento neste dia.',
                        style: const TextStyle(fontSize: 12.5),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(false),
            child: const Text('Cancelar'),
          ),
          ElevatedButton.icon(
            icon: const Icon(Icons.flag, size: 18),
            label: const Text('Finalizar'),
            onPressed: () => Navigator.of(ctx).pop(true),
          ),
        ],
      ),
    );

    if (confirmou != true || !context.mounted) return;

    await repo.finalizar(id);
    if (!context.mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text('Rota finalizada.'),
        backgroundColor: Colors.green,
      ),
    );
    Navigator.of(context).pop(true);
  }

  /// Reabre uma rota concluída — para receber coleta remanejada ou desfazer um
  /// encerramento indevido.
  Future<void> _reabrirRota(BuildContext context) async {
    final id = rota.id;
    if (id == null) return;

    final confirmou = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Reabrir rota'),
        content: Text(
          'A rota "${rota.descricao}" volta para "em andamento" e poderá '
          'receber coletas de novo.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(false),
            child: const Text('Cancelar'),
          ),
          ElevatedButton(
            onPressed: () => Navigator.of(ctx).pop(true),
            child: const Text('Reabrir'),
          ),
        ],
      ),
    );

    if (confirmou != true || !context.mounted) return;

    await RotaRepository().reabrir(id);
    if (!context.mounted) return;
    ScaffoldMessenger.of(
      context,
    ).showSnackBar(const SnackBar(content: Text('Rota reaberta.')));
    Navigator.of(context).pop(true);
  }

  Future<void> _imprimirComprovante(BuildContext context) async {
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (_) => const Center(child: CircularProgressIndicator()),
    );

    try {
      final paradas = await ParadaRepository().getParadasByRota(rota.id ?? 0);

      if (!context.mounted) return;
      Navigator.pop(context); // fecha o loading

      await PdfPreviewScreen.abrir(
        context,
        titulo: 'Comprovante · ${rota.descricao}',
        nomeArquivo: 'comprovante_${rota.id ?? ''}',
        gerar: () => ComprovanteService().gerarComprovanteRota(
          rota: rota,
          paradas: paradas,
        ),
      );
    } catch (e) {
      if (context.mounted) {
        Navigator.pop(context);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Erro ao gerar comprovante: $e')),
        );
      }
    }
  }

  Future<void> _abrirMapa(BuildContext context) async {
    // Mostra loading enquanto carrega as paradas da rota
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (_) => const Center(child: CircularProgressIndicator()),
    );

    final paradas = await ParadaRepository().getParadasByRota(rota.id ?? 0);

    if (!context.mounted) return;
    Navigator.pop(context); // fecha o loading

    if (paradas.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Esta rota ainda não tem paradas cadastradas'),
        ),
      );
      return;
    }

    Navigator.of(context).push(
      MaterialPageRoute(
        builder: (context) =>
            MapaRotaScreen(paradas: paradas, rotaDescricao: rota.descricao),
      ),
    );
  }

  void _mostrarDialogoStatus(BuildContext context) {
    showDialog(
      context: context,
      builder: (dialogCtx) => AlertDialog(
        title: const Text('Status da Rota'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            _StatusOption(
              status: 'PENDENTE',
              label: 'Pendente',
              color: Colors.grey,
              onTap: () => _mudarStatus(context, dialogCtx, 'PENDENTE'),
            ),
            _StatusOption(
              status: 'LIBERADA',
              label: 'Liberada (motorista)',
              color: Colors.blue,
              onTap: () => _mudarStatus(context, dialogCtx, 'LIBERADA'),
            ),
            _StatusOption(
              status: 'EM_ANDAMENTO',
              label: 'Em Andamento',
              color: Colors.orange,
              onTap: () => _mudarStatus(context, dialogCtx, 'EM_ANDAMENTO'),
            ),
            _StatusOption(
              status: 'CONCLUIDA',
              label: 'Concluída',
              color: Colors.green,
              onTap: () => _mudarStatus(context, dialogCtx, 'CONCLUIDA'),
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _mudarStatus(
    BuildContext context,
    BuildContext dialogCtx,
    String status,
  ) async {
    Navigator.pop(dialogCtx);
    if (rota.id == null) return;
    final ok = await context.read<RotaViewModel>().mudarStatus(
      rota.id!,
      status,
    );
    if (ok) rota.status = status;
    if (context.mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            ok
                ? 'Status alterado para $status'
                : 'Não foi possível alterar o status',
          ),
          backgroundColor: ok ? Colors.green : Colors.red,
        ),
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
            _DetailItem(
              label: 'Motorista ID',
              value: '${rota.motoristaId ?? 'N/A'}',
            ),
            _DetailItem(
              label: 'Veículo ID',
              value: '${rota.veiculoId ?? 'N/A'}',
            ),
            _DetailItem(label: 'Paradas', value: '${rota.paradas ?? 0}'),
            _DetailItem(
              label: 'KM Estimado',
              value: '${rota.kmEstimado?.toStringAsFixed(2) ?? '0'} km',
            ),
            _DetailItem(
              label: 'KM Realizado',
              value: '${rota.kmRealizado?.toStringAsFixed(2) ?? '0'} km',
            ),
            _DetailItem(
              label: 'Data Prevista',
              value: rota.dataPrevista ?? 'N/A',
            ),
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
          Text(
            value,
            style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w500),
          ),
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
            color: color.withValues(alpha: 0.1),
            border: Border.all(color: color),
            borderRadius: BorderRadius.circular(8),
          ),
          child: Row(
            children: [
              Container(
                width: 12,
                height: 12,
                decoration: BoxDecoration(color: color, shape: BoxShape.circle),
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

class _ColetasSection extends StatefulWidget {
  final RotaModel rota;

  const _ColetasSection({required this.rota});

  @override
  State<_ColetasSection> createState() => _ColetasSectionState();
}

class _ColetasSectionState extends State<_ColetasSection> {
  final _paradaRepo = ParadaRepository();
  late Future<List> _paradasFuture;

  @override
  void initState() {
    super.initState();
    _reloadParadas();
  }

  void _reloadParadas() {
    _paradasFuture = _paradaRepo.getParadasByRota(widget.rota.id ?? 0);
  }

  String _statusLabel(String status) {
    return switch (status) {
      'E' => 'Em Andamento',
      'C' => 'Concluída',
      'R' => 'Recusada',
      'A' => 'Adiada',
      'X' => 'Cancelada',
      _ => 'Pendente',
    };
  }

  Color _statusColor(String status) {
    return switch (status) {
      'E' => Colors.orange,
      'C' => Colors.green,
      'R' => Colors.red,
      'A' => Colors.blue,
      'X' => Colors.black54,
      _ => Colors.grey,
    };
  }

  @override
  Widget build(BuildContext context) {
    return RecarregaAoSincronizar(
      // É a lista que mais muda: cada coleta confirmada no celular cai aqui.
      aoAlterar: () => setState(_reloadParadas),
      child: Container(
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
                          'Coletas da Rota',
                          style: Theme.of(
                            context,
                          ).textTheme.titleMedium?.copyWith(color: Colors.blue),
                        ),
                        Text(
                          '${widget.rota.paradas ?? 0} parada(s) cadastrada(s)',
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
              child: Column(
                children: [
                  FutureBuilder(
                    future: _paradasFuture,
                    builder: (context, snapshot) {
                      if (snapshot.connectionState == ConnectionState.waiting) {
                        return const Center(child: CircularProgressIndicator());
                      }
                      if (snapshot.hasError) {
                        return Center(
                          child: Text('Erro ao carregar: ${snapshot.error}'),
                        );
                      }

                      final paradas = snapshot.data ?? [];
                      if (paradas.isEmpty) {
                        return Padding(
                          padding: const EdgeInsets.symmetric(vertical: 16),
                          child: Text(
                            'Nenhuma coleta cadastrada',
                            style: TextStyle(color: Colors.grey[600]),
                          ),
                        );
                      }

                      return ListView.builder(
                        shrinkWrap: true,
                        physics: const NeverScrollableScrollPhysics(),
                        itemCount: paradas.length,
                        itemBuilder: (context, idx) {
                          final parada = paradas[idx];
                          final status = parada.status ?? 'P';
                          return Card(
                            margin: const EdgeInsets.only(bottom: 8),
                            child: Padding(
                              padding: const EdgeInsets.all(12),
                              child: Row(
                                children: [
                                  Container(
                                    width: 8,
                                    height: 60,
                                    decoration: BoxDecoration(
                                      color: _statusColor(status),
                                      borderRadius: BorderRadius.circular(2),
                                    ),
                                  ),
                                  const SizedBox(width: 12),
                                  Expanded(
                                    child: Column(
                                      crossAxisAlignment:
                                          CrossAxisAlignment.start,
                                      children: [
                                        Text(
                                          parada.pessoaNome ?? 'N/A',
                                          style: const TextStyle(
                                            fontWeight: FontWeight.w600,
                                          ),
                                        ),
                                        Text(
                                          parada.cnpjCpf ?? '',
                                          style: TextStyle(
                                            fontSize: 12,
                                            color: Colors.grey[600],
                                          ),
                                        ),
                                        // Só depois de coletado esses números
                                        // dizem algo; antes disso vêm zerados.
                                        if (status == 'C') ...[
                                          const SizedBox(height: 2),
                                          Text(
                                            '${(parada.volume ?? 0).toStringAsFixed(0)} L'
                                            ' · ${(parada.temperatura ?? 0).toStringAsFixed(1)} °C',
                                            style: const TextStyle(
                                              fontSize: 12,
                                              fontWeight: FontWeight.w600,
                                              color: Colors.green,
                                            ),
                                          ),
                                        ],
                                      ],
                                    ),
                                  ),
                                  Column(
                                    crossAxisAlignment: CrossAxisAlignment.end,
                                    children: [
                                      Chip(
                                        label: Text(_statusLabel(status)),
                                        backgroundColor: _statusColor(
                                          status,
                                        ).withValues(alpha: 0.2),
                                        labelStyle: TextStyle(
                                          color: _statusColor(status),
                                        ),
                                      ),
                                    ],
                                  ),
                                ],
                              ),
                            ),
                          );
                        },
                      );
                    },
                  ),
                  const SizedBox(height: 12),
                  Row(
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
                                builder: (context) =>
                                    ColetaRotasScreen(rota: widget.rota),
                              ),
                            );
                          },
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: ElevatedButton.icon(
                          style: ElevatedButton.styleFrom(
                            backgroundColor: Colors.green,
                          ),
                          icon: const Icon(Icons.add),
                          label: const Text('Adicionar'),
                          onPressed: () async {
                            await Navigator.of(context).push(
                              MaterialPageRoute(
                                builder: (context) => AdicionarParadaScreen(
                                  rotaId: widget.rota.id ?? 0,
                                  sequencia: (widget.rota.paradas ?? 0) + 1,
                                ),
                              ),
                            );
                            setState(() => _reloadParadas());
                          },
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}
