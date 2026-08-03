import 'package:flutter/material.dart';
import 'sync_service.dart';
import 'daos/sync_queue_dao.dart';
import 'daos/mobile_sync_log_dao.dart';

/// Tela de sincronização, em duas abas:
///
/// - **Mobile**: o que o app do celular baixou e enviou (`tb_mobile_sync_log`).
/// - **Fila do desktop**: escritas que esta máquina enfileirou por estar sem
///   o Firebird, com a opção de reenviar (`tb_sync_queue`).
///
/// As duas eram confundidas: a tela só mostrava a fila do desktop, então
/// ficava em "Tudo sincronizado" mesmo com o mobile sincronizando.
class SyncQueueScreen extends StatefulWidget {
  const SyncQueueScreen({super.key});

  @override
  State<SyncQueueScreen> createState() => _SyncQueueScreenState();
}

class _SyncQueueScreenState extends State<SyncQueueScreen>
    with SingleTickerProviderStateMixin {
  final _sync = SyncService();
  final _logDao = MobileSyncLogDao();

  late final TabController _tabs;
  bool _loading = true;
  bool _sincronizando = false;
  List<SyncQueueItem> _itens = [];
  List<MobileSyncLogItem> _logMobile = [];

  @override
  void initState() {
    super.initState();
    _tabs = TabController(length: 2, vsync: this);
    _tabs.addListener(() => setState(() {}));
    _carregar();
  }

  @override
  void dispose() {
    _tabs.dispose();
    super.dispose();
  }

  Future<void> _carregar() async {
    setState(() => _loading = true);
    final itens = await _sync.getAllItems();
    final log = await _logDao.ultimos();
    if (!mounted) return;
    setState(() {
      _itens = itens;
      _logMobile = log;
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

  Future<void> _limparLogMobile() async {
    await _logDao.limpar();
    await _carregar();
  }

  @override
  Widget build(BuildContext context) {
    final pendentes = _itens.where((i) => i.status == 'P').length;
    final erros = _itens.where((i) => i.status == 'E').length;
    final enviados = _itens.where((i) => i.status == 'S').length;
    final naAbaMobile = _tabs.index == 0;

    return Scaffold(
      backgroundColor: const Color(0xFFF3F5F4),
      appBar: AppBar(
        title: const Text('Sincronização'),
        elevation: 0,
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh),
            tooltip: 'Atualizar',
            onPressed: _carregar,
          ),
          if (naAbaMobile && _logMobile.isNotEmpty)
            IconButton(
              icon: const Icon(Icons.cleaning_services),
              tooltip: 'Limpar histórico do mobile',
              onPressed: _limparLogMobile,
            ),
          if (!naAbaMobile && enviados > 0)
            IconButton(
              icon: const Icon(Icons.cleaning_services),
              tooltip: 'Limpar enviados',
              onPressed: _limparEnviados,
            ),
        ],
        bottom: TabBar(
          controller: _tabs,
          tabs: const [
            Tab(icon: Icon(Icons.smartphone), text: 'Mobile'),
            Tab(icon: Icon(Icons.desktop_windows), text: 'Fila do desktop'),
          ],
        ),
      ),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : TabBarView(
              controller: _tabs,
              children: [
                _buildAbaMobile(),
                _buildAbaDesktop(pendentes, erros, enviados),
              ],
            ),
      bottomNavigationBar: naAbaMobile
          ? null
          : Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: Colors.white,
                border: Border(top: BorderSide(color: Colors.grey.shade200)),
              ),
              child: Row(
                children: [
                  if (erros > 0) ...[
                    Expanded(
                      child: OutlinedButton.icon(
                        style: OutlinedButton.styleFrom(
                          padding: const EdgeInsets.symmetric(vertical: 12),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(10),
                          ),
                        ),
                        icon: const Icon(Icons.replay, size: 18),
                        label: const Text('Tentar erros'),
                        onPressed: _sincronizando ? null : _tentarNovamente,
                      ),
                    ),
                    const SizedBox(width: 8),
                  ],
                  Expanded(
                    child: ElevatedButton.icon(
                      style: ElevatedButton.styleFrom(
                        backgroundColor: const Color(0xFF2E7D4F),
                        padding: const EdgeInsets.symmetric(vertical: 12),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(10),
                        ),
                      ),
                      icon: _sincronizando
                          ? const SizedBox(
                              width: 18,
                              height: 18,
                              child: CircularProgressIndicator(
                                  strokeWidth: 2, color: Colors.white))
                          : const Icon(Icons.sync, color: Colors.white, size: 18),
                      label: Text(
                        pendentes > 0
                            ? 'Sincronizar ($pendentes)'
                            : 'Sincronizar',
                        style: const TextStyle(color: Colors.white),
                      ),
                      onPressed: (_sincronizando || pendentes == 0)
                          ? null
                          : _sincronizarAgora,
                    ),
                  ),
                ],
              ),
            ),
    );
  }

  // ---------------------------------------------------------------- mobile

  Widget _buildAbaMobile() {
    final comErro = _logMobile.where((l) => !l.sucesso).length;
    final baixados = _logMobile
        .where((l) => l.sucesso && l.metodo == 'GET')
        .fold<int>(0, (soma, l) => soma + (l.registros ?? 0));

    return Column(
      children: [
        _resumoContainer([
          _chip('Requisições', _logMobile.length, Colors.blue),
          _chip('Registros enviados', baixados, Colors.green),
          _chip('Falhas', comErro, comErro > 0 ? Colors.red : Colors.grey),
        ]),
        if (_logMobile.isNotEmpty)
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 8, 16, 0),
            child: Row(
              children: [
                Icon(Icons.schedule, size: 14, color: Colors.grey[600]),
                const SizedBox(width: 6),
                Text(
                  'Última atividade: ${_formatar(_logMobile.first.dataHora)}'
                  '${_logMobile.first.clienteIp != null ? ' • ${_logMobile.first.clienteIp}' : ''}',
                  style: TextStyle(fontSize: 12, color: Colors.grey[600]),
                ),
              ],
            ),
          ),
        const SizedBox(height: 8),
        Expanded(child: _buildListaMobile()),
      ],
    );
  }

  Widget _resumoContainer(List<Widget> chips) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 12, 16, 0),
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 14),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: Colors.grey.shade200),
        ),
        child: Row(mainAxisAlignment: MainAxisAlignment.spaceAround, children: chips),
      ),
    );
  }

  Widget _buildListaMobile() {
    if (_logMobile.isEmpty) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(32),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(Icons.smartphone, size: 64, color: Colors.grey[300]),
              const SizedBox(height: 12),
              Text('Nenhuma sincronização do mobile ainda',
                  style: TextStyle(color: Colors.grey[600])),
              const SizedBox(height: 6),
              Text(
                'Abra o app no celular e toque em Atualizar. '
                'Cada requisição que chegar aqui aparece nesta lista.',
                textAlign: TextAlign.center,
                style: TextStyle(fontSize: 12, color: Colors.grey[500]),
              ),
            ],
          ),
        ),
      );
    }

    return ListView.builder(
      padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
      itemCount: _logMobile.length,
      itemBuilder: (context, index) {
        final item = _logMobile[index];
        final cor = item.sucesso ? Colors.green : Colors.red;
        return Card(
          elevation: 0,
          margin: const EdgeInsets.only(bottom: 8),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12),
            side: BorderSide(color: Colors.grey.shade200),
          ),
          child: ListTile(
            visualDensity: VisualDensity.compact,
            leading: Container(
              width: 36,
              height: 36,
              decoration: BoxDecoration(
                color: cor.withValues(alpha: 0.1),
                borderRadius: BorderRadius.circular(9),
              ),
              child: Icon(
                item.sucesso ? Icons.check_circle_outline : Icons.error_outline,
                color: cor,
                size: 18,
              ),
            ),
            title: Text(
              item.descricao,
              style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 13),
            ),
            subtitle: Text(
              '${_formatar(item.dataHora)} • ${item.metodo} ${item.rota}'
              '${item.duracaoMs != null ? ' • ${item.duracaoMs} ms' : ''}'
              '${item.erro != null ? '\n${item.erro}' : ''}',
              style: const TextStyle(fontSize: 11),
            ),
            isThreeLine: item.erro != null,
            trailing: item.registros != null
                ? Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Text('${item.registros}',
                          style: TextStyle(
                              fontSize: 14,
                              fontWeight: FontWeight.bold,
                              color: cor)),
                      Text('reg.',
                          style:
                              TextStyle(fontSize: 10, color: Colors.grey[600])),
                    ],
                  )
                : Text('${item.statusHttp}',
                    style: TextStyle(
                        fontSize: 11,
                        color: cor,
                        fontWeight: FontWeight.bold)),
          ),
        );
      },
    );
  }

  // --------------------------------------------------------------- desktop

  Widget _buildAbaDesktop(int pendentes, int erros, int enviados) {
    return Column(
      children: [
        _resumoContainer([
          _chip('Pendentes', pendentes, Colors.orange),
          _chip('Erros', erros, Colors.red),
          _chip('Enviados', enviados, Colors.green),
        ]),
        const SizedBox(height: 8),
        Expanded(child: _buildLista()),
      ],
    );
  }

  Widget _chip(String label, int count, Color cor) {
    return Column(
      children: [
        Text('$count',
            style: TextStyle(
                fontSize: 18, fontWeight: FontWeight.bold, color: cor)),
        Text(label,
            style: TextStyle(fontSize: 11, color: Colors.grey[600])),
      ],
    );
  }

  Widget _buildLista() {
    if (_itens.isEmpty) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(32),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(Icons.cloud_done, size: 64, color: Colors.green[300]),
              const SizedBox(height: 12),
              Text('Tudo sincronizado',
                  style: TextStyle(color: Colors.grey[600])),
              const SizedBox(height: 6),
              Text(
                'Esta fila guarda o que o desktop gravou sem o Firebird. '
                'O que o celular sincroniza fica na aba Mobile.',
                textAlign: TextAlign.center,
                style: TextStyle(fontSize: 12, color: Colors.grey[500]),
              ),
            ],
          ),
        ),
      );
    }

    return ListView.builder(
      padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
      itemCount: _itens.length,
      itemBuilder: (context, index) {
        final item = _itens[index];
        final cor = _statusColor(item.status);
        return Card(
          elevation: 0,
          margin: const EdgeInsets.only(bottom: 8),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12),
            side: BorderSide(color: Colors.grey.shade200),
          ),
          child: ListTile(
            visualDensity: VisualDensity.compact,
            leading: Container(
              width: 36,
              height: 36,
              decoration: BoxDecoration(
                color: cor.withValues(alpha: 0.1),
                borderRadius: BorderRadius.circular(9),
              ),
              child: Icon(_statusIcone(item.status), color: cor, size: 18),
            ),
            title: Text('${item.operacao} • ${item.tabela}',
                style:
                    const TextStyle(fontWeight: FontWeight.w600, fontSize: 13)),
            subtitle: Text(
              'ID ${item.registroId ?? '-'} • tentativas: ${item.tentativas}'
              '${item.dataUltimoTentativa != null ? '\nÚltima: ${_formatar(item.dataUltimoTentativa!)}' : ''}',
              style: const TextStyle(fontSize: 11),
            ),
            isThreeLine: item.dataUltimoTentativa != null,
            trailing: Container(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
              decoration: BoxDecoration(
                color: cor.withValues(alpha: 0.1),
                borderRadius: BorderRadius.circular(20),
              ),
              child: Text(
                _statusLabel(item.status),
                style: TextStyle(
                    fontSize: 10, color: cor, fontWeight: FontWeight.w600),
              ),
            ),
          ),
        );
      },
    );
  }

  IconData _statusIcone(String status) => switch (status) {
        'S' => Icons.check_circle_outline,
        'E' => Icons.error_outline,
        _ => Icons.schedule,
      };

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
