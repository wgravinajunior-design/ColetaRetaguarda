import '../../../core/api/http_client.dart';
import '../../../core/api/api_endpoints.dart';
import '../../core/database/daos/rota_dao.dart';
import '../../core/database/sync_service.dart';
import '../models/rota_model.dart';

class RotaRepository {
  final ApiClient _apiClient = ApiClient();
  final RotaDao _dao = RotaDao();
  final SyncService _syncService = SyncService();

  Future<List<RotaModel>> getRotas({String? query}) async {
    try {
      final params = <String, String>{};
      if (query != null) params['search'] = query;

      final response = await _apiClient.get(
        ApiEndpoints.rotas,
        queryParams: params.isNotEmpty ? params : null,
      );

      if (response.success && response.data is List) {
        return (response.data as List)
            .map((e) => RotaModel.fromJson(e as Map<String, dynamic>))
            .toList();
      }
      return getMockRotas();
    } catch (e) {
      return getMockRotas();
    }
  }

  Future<RotaModel?> getRotaById(int id) async {
    try {
      final response = await _apiClient.get('${ApiEndpoints.rotas}/$id');
      if (response.success && response.data != null) {
        return RotaModel.fromJson(response.data as Map<String, dynamic>);
      }
      return null;
    } catch (e) {
      return null;
    }
  }

  Future<RotaModel?> createRota(RotaModel r) async {
    try {
      final response = await _apiClient.post(
        ApiEndpoints.rotas,
        body: r.toJson(),
      );
      if (response.success && response.data != null) {
        return RotaModel.fromJson(response.data as Map<String, dynamic>);
      }
      return null;
    } catch (e) {
      return null;
    }
  }

  Future<bool> updateRota(RotaModel r) async {
    if (r.id == null) return false;
    try {
      final response = await _apiClient.put(
        '${ApiEndpoints.rotas}/${r.id}',
        body: r.toJson(),
      );
      return response.success;
    } catch (e) {
      return false;
    }
  }

  Future<bool> deleteRota(int id) async {
    try {
      final response = await _apiClient.delete('${ApiEndpoints.rotas}/$id');
      return response.success;
    } catch (e) {
      return false;
    }
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
        dataPrevista: DateTime.now().add(const Duration(days: 1)),
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
        dataPrevista: DateTime.now().add(const Duration(days: 2)),
        paradas: 8,
        kmEstimado: 80.0,
      ),
    ];
  }
}
