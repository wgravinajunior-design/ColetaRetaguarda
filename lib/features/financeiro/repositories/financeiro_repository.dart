import '../../../core/api/http_client.dart';
import '../../core/database/daos/movimento_dao.dart';
import '../../core/database/sync_service.dart';
import '../models/movimento_model.dart';

class FinanceiroRepository {
  final ApiClient _apiClient = ApiClient();
  final MovimentoDao _dao = MovimentoDao();
  final SyncService _syncService = SyncService();

  Future<List<MovimentoModel>> getMovimentos({String? tipo, String? dataInicio, String? dataFim}) async {
    try {
      final response = await _apiClient.get(
        '/coleta/movimento-conta${tipo != null ? '?tipo=$tipo' : ''}',
      );

      if (response.success && response.data is List) {
        final movimentos = (response.data as List)
            .map((m) => MovimentoModel.fromJson(m as Map<String, dynamic>))
            .toList();
        for (var m in movimentos) {
          await _dao.insert(m);
        }
        return movimentos;
      }
    } catch (e) {
      print('Erro ao carregar movimentos da API: $e');
    }

    try {
      if (tipo != null) {
        return await _dao.getByTipo(tipo);
      }
      return await _dao.getAll();
    } catch (e) {
      print('Erro ao carregar movimentos do SQLite: $e');
    }

    return getMockMovimentos();
  }

  Future<MovimentoModel?> createMovimento(MovimentoModel mov) async {
    try {
      final response = await _apiClient.post(
        '/coleta/movimento-conta',
        body: mov.toJson(),
      );

      if (response.success && response.data != null) {
        final created = MovimentoModel.fromJson(response.data as Map<String, dynamic>);
        await _dao.insert(created);
        return created;
      }
    } catch (e) {
      print('Erro ao criar movimento na API: $e');
    }

    mov.id ??= DateTime.now().millisecondsSinceEpoch;
    await _dao.insert(mov);
    await _syncService.queueOperation(
      tabela: 'tb_movimento_conta',
      operacao: 'CREATE',
      registroId: mov.id,
      dados: mov.toJson(),
    );
    return mov;
  }

  Future<bool> updateMovimento(MovimentoModel mov) async {
    if (mov.id == null) return false;
    try {
      final response = await _apiClient.put(
        '/coleta/movimento-conta/${mov.id}',
        body: mov.toJson(),
      );
      if (response.success) {
        await _dao.update(mov);
        return true;
      }
    } catch (e) {
      print('Erro ao atualizar movimento na API: $e');
    }

    await _dao.update(mov);
    await _syncService.queueOperation(
      tabela: 'tb_movimento_conta',
      operacao: 'UPDATE',
      registroId: mov.id,
      dados: mov.toJson(),
    );
    return true;
  }

  Future<bool> deleteMovimento(int id) async {
    try {
      await _apiClient.delete('/coleta/movimento-conta/$id');
      await _dao.delete(id);
      return true;
    } catch (e) {
      print('Erro ao deletar movimento na API: $e');
    }

    await _dao.delete(id);
    await _syncService.queueOperation(
      tabela: 'tb_movimento_conta',
      operacao: 'DELETE',
      registroId: id,
      dados: {'id': id},
    );
    return true;
  }

  List<MovimentoModel> getMockMovimentos() {
    return [
      MovimentoModel(
        id: 1,
        tipo: 'C',
        status: 'C',
        conta: 1,
        contaNome: 'Banco do Brasil',
        valor: 1500.0,
        dtEmissao: '2026-07-01',
        dtCompensado: '2026-07-01',
        historico: 'Venda de Soja',
      ),
      MovimentoModel(
        id: 2,
        tipo: 'D',
        status: 'C',
        conta: 1,
        contaNome: 'Banco do Brasil',
        valor: 500.0,
        dtEmissao: '2026-07-05',
        dtCompensado: '2026-07-05',
        historico: 'Pagamento de Frete',
      ),
      MovimentoModel(
        id: 3,
        tipo: 'D',
        status: 'P',
        conta: 1,
        contaNome: 'Banco do Brasil',
        valor: 250.0,
        dtEmissao: '2026-07-10',
        historico: 'Manutenção Veículo',
      ),
    ];
  }
}
