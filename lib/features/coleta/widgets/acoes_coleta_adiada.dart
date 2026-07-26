import 'package:flutter/material.dart';
import '../models/parada_model.dart';
import '../repositories/parada_repository.dart';
import '../../rotas/models/rota_model.dart';

/// Ações disponíveis para uma coleta adiada.
///
/// Adiada não é o fim: o produtor não foi atendido naquela passagem, mas a
/// coleta continua valendo. Daqui dá para mudar a situação ou passá-la para
/// outra rota, em vez de virar um registro parado.
class AcoesColetaAdiada extends StatelessWidget {
  const AcoesColetaAdiada({
    required this.parada,
    required this.aoConcluir,
    super.key,
  });

  final ParadaModel parada;

  /// Chamado após qualquer alteração, para a tela recarregar.
  final VoidCallback aoConcluir;

  @override
  Widget build(BuildContext context) {
    return Card(
      color: Colors.blue.shade50,
      child: Padding(
        padding: const EdgeInsets.all(14),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(Icons.event_repeat, color: Colors.blue.shade700, size: 20),
                const SizedBox(width: 8),
                Text(
                  'Coleta adiada',
                  style: TextStyle(
                    fontWeight: FontWeight.bold,
                    color: Colors.blue.shade800,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 4),
            Text(
              parada.justificativa?.isNotEmpty == true
                  ? 'Motivo: ${parada.justificativa}'
                  : 'Sem motivo registrado.',
              style: TextStyle(fontSize: 12.5, color: Colors.grey[800]),
            ),
            const SizedBox(height: 12),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: [
                OutlinedButton.icon(
                  icon: const Icon(Icons.swap_horiz, size: 18),
                  label: const Text('Trocar de rota'),
                  onPressed: () => _trocarDeRota(context),
                ),
                OutlinedButton.icon(
                  icon: const Icon(Icons.tune, size: 18),
                  label: const Text('Mudar situação'),
                  onPressed: () => _mudarSituacao(context),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _trocarDeRota(BuildContext context) async {
    final repo = ParadaRepository();

    List<RotaModel> rotas;
    try {
      rotas = await repo.getRotasEmAberto();
    } catch (e) {
      if (!context.mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Não foi possível carregar as rotas: $e')),
      );
      return;
    }

    if (!context.mounted) return;
    // A rota atual não é destino.
    final disponiveis = rotas.where((r) => r.id != parada.rotaId).toList();

    if (disponiveis.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text(
            'Nenhuma outra rota em aberto. Crie uma rota nova ou reabra uma '
            'concluída para receber esta coleta.',
          ),
        ),
      );
      return;
    }

    final escolhida = await showDialog<RotaModel>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Mover para qual rota?'),
        content: SizedBox(
          width: 420,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'Rotas em aberto — pendentes ou já iniciadas.',
                style: TextStyle(fontSize: 12, color: Colors.grey[600]),
              ),
              const SizedBox(height: 10),
              Flexible(
                child: ListView.separated(
                  shrinkWrap: true,
                  itemCount: disponiveis.length,
                  separatorBuilder: (_, _) => const Divider(height: 1),
                  itemBuilder: (_, i) {
                    final r = disponiveis[i];
                    final emAndamento = r.status == 'EM_ANDAMENTO';
                    return ListTile(
                      leading: Icon(
                        emAndamento ? Icons.play_circle : Icons.schedule,
                        color: emAndamento ? Colors.orange : Colors.blueGrey,
                      ),
                      title: Text(r.descricao),
                      subtitle: Text(
                        '${_data(r.dataPrevista)} · '
                        '${r.paradas ?? 0} parada(s) · '
                        '${emAndamento ? "em andamento" : "pendente"}',
                        style: const TextStyle(fontSize: 12),
                      ),
                      onTap: () => Navigator.of(ctx).pop(r),
                    );
                  },
                ),
              ),
            ],
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(),
            child: const Text('Cancelar'),
          ),
        ],
      ),
    );

    if (escolhida?.id == null || !context.mounted) return;

    await repo.moverParaRota(paradaId: parada.id!, novaRotaId: escolhida!.id!);
    if (!context.mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text('Coleta movida para "${escolhida.descricao}".')),
    );
    aoConcluir();
  }

  Future<void> _mudarSituacao(BuildContext context) async {
    const opcoes = {
      'P': ('Pendente', 'Volta para a fila desta rota'),
      'C': ('Concluída', 'Registra como coletada'),
      'R': ('Recusada', 'O produtor recusou a coleta'),
      'X': ('Cancelada', 'Não será mais realizada'),
    };

    final novo = await showDialog<String>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Mudar situação'),
        content: SizedBox(
          width: 380,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: opcoes.entries
                .map(
                  (e) => ListTile(
                    title: Text(e.value.$1),
                    subtitle: Text(
                      e.value.$2,
                      style: const TextStyle(fontSize: 12),
                    ),
                    onTap: () => Navigator.of(ctx).pop(e.key),
                  ),
                )
                .toList(),
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(),
            child: const Text('Cancelar'),
          ),
        ],
      ),
    );

    if (novo == null || !context.mounted) return;

    await ParadaRepository().alterarSituacao(
      paradaId: parada.id!,
      novoStatus: novo,
    );
    if (!context.mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text('Situação alterada para ${opcoes[novo]!.$1}.')),
    );
    aoConcluir();
  }

  static String _data(String? iso) {
    if (iso == null || iso.isEmpty) return 'sem data';
    final d = DateTime.tryParse(iso);
    if (d == null) return iso.split(' ').first;
    String dois(int n) => n.toString().padLeft(2, '0');
    return '${dois(d.day)}/${dois(d.month)}/${d.year}';
  }
}
