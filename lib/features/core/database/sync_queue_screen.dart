import 'package:flutter/material.dart';
import 'sync_service.dart';
import 'daos/sync_queue_dao.dart';

/// Tela da fila de sincronização: mostra o que está pendente/erro/enviado
/// e permite forçar o envio ou reenfileirar itens com falha.
class SyncQueueScreen extends StatefulWidget {
  const SyncQueueScreen({super.key});

  @override
  State<SyncQueueScreen> createState() => _SyncQueueScreenState();
}

class _SyncQueueScreenState extends State<SyncQueueScreen> {
  final _sync = SyncService();
  bool _loading = true;
  bool _sincronizando = false;
  List<SyncQueueItem> _itens = [];

  @override
  void initState() {
    super.initState();
    _carregar();
  }

  Future<void> _carregar() async {
    setState(() => _loading = true);
    final itens = await _sync.getAllItems();
    if (!mounted) return;
    setState(() {
      _itens = itens;
      _loading = false;
    });
  }

  Future<void> _sincronizarAgora() async {
    setState(() => _sincronizando = true);
    await _sync.syncPendingItems();
    if (!mounted) return;
    setState(() => _sincronizando = false);
    await _carregar();
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Sincronização executada')),
      );
    }
  }

  Future<void> _tentarNovamente() async {
    await _sync.retryFailed();
    await _sincronizarAgora();
  }

  Future<void> _limparEnviados() async {
    await _sync.clearSynced();
    await _carregar();
  }

  @override
  Widget build(BuildContext context) {
    final pendentes = _itens.where((i) => i.status == 'P').length;
    final erros = _itens.where((i) => i.status == 'E').length;
    final enviados = _itens.where((i) => i.status == 'S').length;

    return Scaffold(
      appBar: AppBar(
        title: const Text('Sincronização'),
        actions: [
          IconButton(icon: const Icon(Icons.refresh), onPressed: _carregar),
          if (enviados > 0)
            IconButton(
              icon: const Icon(Icons.cleaning_services),
              tooltip: 'Limpar enviados',
              onPressed: _limparEnviados,
            ),
        ],
      ),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : Column(
              children: [
                _buildResumo(pendentes, erros, enviados),
                const Divider(height: 1),
                Expanded(child: _buildLista()),
              ],
            ),
      bottomNavigationBar: Padding(
        padding: const EdgeInsets.all(12),
        child: Row(
          children: [
            if (erros > 0) ...[
              Expanded(
                child: OutlinedButton.icon(
                  icon: const Icon(Icons.replay),
                  label: const Text('Tentar erros'),
                  onPressed: _sincronizando ? null : _tentarNovamente,
                ),
              ),
              const SizedBox(width: 8),
            ],
            Expanded(
              child: ElevatedButton.icon(
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.blue,
                  padding: const EdgeInsets.symmetric(vertical: 12),
                ),
                icon: _sincronizando
                    ? const SizedBox(width: 18, height: 18, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
                    : const Icon(Icons.sync, color: Colors.white),
                label: Text(
                  pendentes > 0 ? 'Sincronizar ($pendentes)' : 'Sincronizar',
                  style: const TextStyle(color: Colors.white),
                ),
                onPressed: (_sincronizando || pendentes == 0) ? null : _sincronizarAgora,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildResumo(int pendentes, int erros, int enviados) {
    return Container(
      color: Colors.grey.shade50,
      padding: const EdgeInsets.all(12),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceAround,
        children: [
          _chip('Pendentes', pendentes, Colors.orange),
          _chip('Erros', erros, Colors.red),
          _chip('Enviados', enviados, Colors.green),
        ],
      ),
    );
  }

  Widget _chip(String label, int count, Color cor) {
    return Column(
      children: [
        Text('$count', style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold, color: cor)),
        Text(label, style: TextStyle(fontSize: 12, color: Colors.grey[700])),
      ],
    );
  }

  Widget _buildLista() {
    if (_itens.isEmpty) {
      return Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.cloud_done, size: 64, color: Colors.green[300]),
            const SizedBox(height: 12),
            Text('Tudo sincronizado', style: TextStyle(color: Colors.grey[600])),
          ],
        ),
      );
    }

    return ListView.separated(
      padding: const EdgeInsets.all(8),
      itemCount: _itens.length,
      separatorBuilder: (_, _) => const Divider(height: 1),
      itemBuilder: (context, index) {
        final item = _itens[index];
        return ListTile(
          leading: _statusIcon(item.status),
          title: Text('${item.operacao} • ${item.tabela}',
              style: const TextStyle(fontWeight: FontWeight.w500, fontSize: 14)),
          subtitle: Text(
            'ID ${item.registroId ?? '-'} • tentativas: ${item.tentativas}'
            '${item.dataUltimoTentativa != null ? '\nÚltima: ${_formatar(item.dataUltimoTentativa!)}' : ''}',
            style: const TextStyle(fontSize: 12),
          ),
          isThreeLine: item.dataUltimoTentativa != null,
          trailing: Text(
            _statusLabel(item.status),
            style: TextStyle(fontSize: 11, color: _statusColor(item.status), fontWeight: FontWeight.bold),
          ),
        );
      },
    );
  }

  Widget _statusIcon(String status) {
    switch (status) {
      case 'S':
        return const Icon(Icons.check_circle, color: Colors.green);
      case 'E':
        return const Icon(Icons.error, color: Colors.red);
      default:
        return const Icon(Icons.schedule, color: Colors.orange);
    }
  }

  String _statusLabel(String s) => switch (s) {
        'S' => 'Enviado',
        'E' => 'Erro',
        _ => 'Pendente',
      };

  Color _statusColor(String s) => switch (s) {
        'S' => Colors.green,
        'E' => Colors.red,
        _ => Colors.orange,
      };

  String _formatar(String iso) {
    final d = DateTime.tryParse(iso);
    if (d == null) return iso;
    String dois(int n) => n.toString().padLeft(2, '0');
    return '${dois(d.day)}/${dois(d.month)} ${dois(d.hour)}:${dois(d.minute)}';
  }
}
