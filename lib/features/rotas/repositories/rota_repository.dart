import '../../../core/api/http_client.dart';
import '../../core/database/daos/rota_dao.dart';
import '../../core/database/sync_service.dart';
import '../models/rota_model.dart';

class RotaRepository {
  final ApiClient _apiClient = ApiClient();
  final RotaDao _dao = RotaDao();
  final SyncService _syncService = SyncService();

  Future<List<RotaModel>> getRotas({String? query}) async {
    try {
      final response = await _apiClient.get(
        '/coleta/rotas${query != null ? '?q=$query' : ''}',
      );

      if (response.success && response.data is List) {
        final rotas = (response.data as List)
            .map((e) => RotaModel.fromJson(e as Map<String, dynamic>))
            .toList();
        for (var r in rotas) {
          await _dao.insert(r);
        }
        return rotas;
      }
    } catch (e) {
      print('Erro ao carregar rotas da API: $e');
    }

    try {
      return await _dao.getAll();
    } catch (e) {
      print('Erro ao carregar rotas do SQLite: $e');
    }

    return getMockRotas();
  }

  Future<RotaModel?> getRotaById(int id) async {
    try {
      final response = await _apiClient.get('/coleta/rotas/$id');
      if (response.success && response.data != null) {
        final rota = RotaModel.fromJson(response.data as Map<String, dynamic>);
        await _dao.insert(rota);
        return rota;
      }
    } catch (e) {
      print('Erro ao carregar rota $id da API: $e');
    }

    try {
      return await _dao.getById(id);
    } catch (e) {
      print('Erro ao carregar rota $id do SQLite: $e');
    }

    return null;
  }

  Future<RotaModel?> createRota(RotaModel r) async {
    try {
      final response = await _apiClient.post(
        '/coleta/rotas',
        body: r.toJson(),
      );
      if (response.success && response.data != null) {
        final created = RotaModel.fromJson(response.data as Map<String, dynamic>);
        await _dao.insert(created);
        return created;
      }
    } catch (e) {
      print('Erro ao criar rota na API: $e');
    }

    r.id ??= DateTime.now().millisecondsSinceEpoch;
    await _dao.insert(r);
    await _syncService.queueOperation(
      tabela: 'tb_rota',
      operacao: 'CREATE',
      registroId: r.id,
      dados: r.toJson(),
    );
    return r;
  }

  Future<bool> updateRota(RotaModel r) async {
    if (r.id == null) return false;
    try {
      final response = await _apiClient.put(
        '/coleta/rotas/${r.id}',
        body: r.toJson(),
      );
      if (response.success) {
        await _dao.update(r);
        return true;
      }
    } catch (e) {
      print('Erro ao atualizar rota na API: $e');
    }

    await _dao.update(r);
    await _syncService.queueOperation(
      tabela: 'tb_rota',
      operacao: 'UPDATE',
      registroId: r.id,
      dados: r.toJson(),
    );
    return true;
  }

  Future<bool> deleteRota(int id) async {
    try {
      await _apiClient.delete('/coleta/rotas/$id');
      await _dao.delete(id);
      return true;
    } catch (e) {
      print('Erro ao deletar rota na API: $e');
    }

    await _dao.delete(id);
    await _syncService.queueOperation(
      tabela: 'tb_rota',
      operacao: 'DELETE',
      registroId: id,
      dados: {'id': id},
    );
    return true;
  }

  List<RotaModel> getMockRotas() {
    return [
      RotaModel(
        id: 1,
        descricao: 'Rota Zona Rural - Produtor A',
        regiao: 'Zona Rural',
        motoristaId: 1,
        veiculoId: 1,
        status: 'A',
        dataPrevista: DateTime.now().add(const Duration(days: 1)).toIso8601String(),
        paradas: 5,
        kmEstimado: 150.0,
      ),
      RotaModel(
        id: 2,
        descricao: 'Rota Bairro Centro',
        regiao: 'Centro',
        motoristaId: 2,
        veiculoId: 2,
        status: 'A',
        dataPrevista: DateTime.now().add(const Duration(days: 2)).toIso8601String(),
        paradas: 8,
        kmEstimado: 80.0,
      ),
    ];
  }
}
