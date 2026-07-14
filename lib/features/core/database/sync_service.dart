import 'dart:convert';
import '../../core/api/http_client.dart';
import 'daos/sync_queue_dao.dart';

class SyncService {
  final SyncQueueDao _queueDao = SyncQueueDao();
  final ApiClient _apiClient = ApiClient();

  Future<void> queueOperation({
    required String tabela,
    required String operacao,
    int? registroId,
    required Map<String, dynamic> dados,
  }) async {
    final item = SyncQueueItem(
      tabela: tabela,
      operacao: operacao,
      registroId: registroId,
      dados: jsonEncode(dados),
      status: 'P',
      dataCriacao: DateTime.now().toIso8601String(),
    );

    await _queueDao.insert(item);
  }

  Future<void> syncPendingItems() async {
    final pendingItems = await _queueDao.getPendingItems();

    for (var item in pendingItems) {
      try {
        await _syncItem(item);
        await _queueDao.markAsSuccess(item.id!);
      } catch (e) {
        await _queueDao.incrementTentativas(item.id!);

        if (item.tentativas >= 3) {
          await _queueDao.markAsError(item.id!);
        }
      }
    }
  }

  Future<void> _syncItem(SyncQueueItem item) async {
    final endpoint = _getEndpoint(item.tabela);
    final dados = jsonDecode(item.dados);

    switch (item.operacao.toUpperCase()) {
      case 'CREATE':
        await _apiClient.post(endpoint, body: dados);
        break;
      case 'UPDATE':
        if (item.registroId != null) {
          await _apiClient.put('$endpoint/${item.registroId}', body: dados);
        }
        break;
      case 'DELETE':
        if (item.registroId != null) {
          await _apiClient.delete('$endpoint/${item.registroId}');
        }
        break;
    }
  }

  String _getEndpoint(String tabela) {
    return switch (tabela) {
      'tb_pessoa' => '/coleta/pessoas',
      'tb_motorista' => '/coleta/motoristas',
      'tb_veiculo' => '/coleta/veiculos',
      'tb_rota' => '/coleta/rotas',
      'tb_movimento_conta' => '/coleta/movimento-conta',
      _ => '/coleta/$tabela',
    };
  }

  Future<int> getPendingCount() => _queueDao.countPending();
}
