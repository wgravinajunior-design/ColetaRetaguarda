import '../../../core/api/http_client.dart';
import '../../../core/api/api_endpoints.dart';
import '../../core/database/daos/veiculo_dao.dart';
import '../../core/database/sync_service.dart';
import '../models/veiculo_model.dart';

class VeiculoRepository {
  final ApiClient _apiClient = ApiClient();
  final VeiculoDao _dao = VeiculoDao();
  final SyncService _syncService = SyncService();

  Future<List<VeiculoModel>> getVeiculos({String? query}) async {
    try {
      final response = await _apiClient.get(
        '/coleta/veiculos${query != null ? '?q=$query' : ''}',
      );

      if (response.success && response.data is List) {
        final veiculos = (response.data as List)
            .map((e) => VeiculoModel.fromJson(e as Map<String, dynamic>))
            .toList();
        for (var v in veiculos) {
          await _dao.insert(v);
        }
        return veiculos;
      }
    } catch (e) {
      print('Erro ao carregar veículos da API: $e');
    }

    try {
      return await _dao.getAll();
    } catch (e) {
      print('Erro ao carregar veículos do SQLite: $e');
    }

    return getMockVeiculos();
  }

  Future<VeiculoModel?> getVeiculoById(int id) async {
    try {
      final response = await _apiClient.get('/coleta/veiculos/$id');
      if (response.success && response.data != null) {
        final veiculo = VeiculoModel.fromJson(response.data as Map<String, dynamic>);
        await _dao.insert(veiculo);
        return veiculo;
      }
    } catch (e) {
      print('Erro ao carregar veículo $id da API: $e');
    }

    try {
      return await _dao.getById(id);
    } catch (e) {
      print('Erro ao carregar veículo $id do SQLite: $e');
    }

    return null;
  }

  Future<VeiculoModel?> createVeiculo(VeiculoModel v) async {
    try {
      final response = await _apiClient.post(
        '/coleta/veiculos',
        body: v.toJson(),
      );
      if (response.success && response.data != null) {
        final created = VeiculoModel.fromJson(response.data as Map<String, dynamic>);
        await _dao.insert(created);
        return created;
      }
    } catch (e) {
      print('Erro ao criar veículo na API: $e');
    }

    v.id ??= DateTime.now().millisecondsSinceEpoch;
    await _dao.insert(v);
    await _syncService.queueOperation(
      tabela: 'tb_veiculo',
      operacao: 'CREATE',
      registroId: v.id,
      dados: v.toJson(),
    );
    return v;
  }

  Future<bool> updateVeiculo(VeiculoModel v) async {
    if (v.id == null) return false;
    try {
      final response = await _apiClient.put(
        '/coleta/veiculos/${v.id}',
        body: v.toJson(),
      );
      if (response.success) {
        await _dao.update(v);
        return true;
      }
    } catch (e) {
      print('Erro ao atualizar veículo na API: $e');
    }

    await _dao.update(v);
    await _syncService.queueOperation(
      tabela: 'tb_veiculo',
      operacao: 'UPDATE',
      registroId: v.id,
      dados: v.toJson(),
    );
    return true;
  }

  Future<bool> deleteVeiculo(int id) async {
    try {
      await _apiClient.delete('/coleta/veiculos/$id');
      await _dao.delete(id);
      return true;
    } catch (e) {
      print('Erro ao deletar veículo na API: $e');
    }

    await _dao.delete(id);
    await _syncService.queueOperation(
      tabela: 'tb_veiculo',
      operacao: 'DELETE',
      registroId: id,
      dados: {'id': id},
    );
    return true;
  }

  List<VeiculoModel> getMockVeiculos() {
    return [
      VeiculoModel(
        id: 1,
        placa: 'ABC-1234',
        marca: 'Mercedes',
        modelo: 'Sprinter',
        cor: 'Branco',
        ano: '2022',
        tipo: 'F',
        renavam: '12345678901234',
        status: 'A',
      ),
      VeiculoModel(
        id: 2,
        placa: 'XYZ-5678',
        marca: 'Volvo',
        modelo: 'FH',
        cor: 'Branco',
        ano: '2021',
        tipo: 'C',
        renavam: '98765432109876',
        status: 'A',
      ),
    ];
  }
}
