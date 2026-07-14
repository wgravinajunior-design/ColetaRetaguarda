import '../../../core/api/http_client.dart';
import '../../core/database/daos/parada_dao.dart';
import '../../core/database/sync_service.dart';
import '../models/parada_model.dart';

class ParadaRepository {
  final ApiClient _apiClient = ApiClient();
  final ParadaDao _dao = ParadaDao();
  final SyncService _syncService = SyncService();

  Future<List<ParadaModel>> getParadasByRota(int rotaId) async {
    try {
      final response = await _apiClient.get('/coleta/rotas/$rotaId/paradas');
      if (response.success && response.data is List) {
        final paradas = (response.data as List)
            .map((e) => ParadaModel.fromJson(e as Map<String, dynamic>))
            .toList();
        for (var p in paradas) {
          await _dao.insert(p);
        }
        return paradas;
      }
    } catch (e) {
      print('Erro ao carregar paradas da API: $e');
    }

    try {
      return await _dao.getByRotaId(rotaId);
    } catch (e) {
      print('Erro ao carregar paradas do SQLite: $e');
    }

    return [];
  }

  Future<ParadaModel?> getParadaById(int id) async {
    try {
      final response = await _apiClient.get('/coleta/paradas/$id');
      if (response.success && response.data != null) {
        final parada = ParadaModel.fromJson(response.data as Map<String, dynamic>);
        await _dao.insert(parada);
        return parada;
      }
    } catch (e) {
      print('Erro ao carregar parada $id da API: $e');
    }

    try {
      return await _dao.getById(id);
    } catch (e) {
      print('Erro ao carregar parada $id do SQLite: $e');
    }

    return null;
  }

  Future<bool> atualizarStatusParada({
    required int paradaId,
    required String novoStatus,
    double? temperatura,
    double? volume,
    String? justificativa,
  }) async {
    try {
      final response = await _apiClient.put(
        '/coleta/paradas/$paradaId/status',
        body: {
          'status': novoStatus,
          'temperatura': temperatura,
          'volume': volume,
          'justificativa': justificativa,
        },
      );
      if (response.success) {
        await _dao.updateStatus(
          paradaId,
          novoStatus,
          temperatura: temperatura,
          volume: volume,
          justificativa: justificativa,
        );
        return true;
      }
    } catch (e) {
      print('Erro ao atualizar status na API: $e');
    }

    await _dao.updateStatus(
      paradaId,
      novoStatus,
      temperatura: temperatura,
      volume: volume,
      justificativa: justificativa,
    );

    await _syncService.queueOperation(
      tabela: 'tb_parada',
      operacao: 'UPDATE',
      registroId: paradaId,
      dados: {
        'status': novoStatus,
        'temperatura': temperatura,
        'volume': volume,
        'justificativa': justificativa,
      },
    );

    return true;
  }

  Future<bool> registrarGPS(int paradaId, double latitude, double longitude) async {
    try {
      await _apiClient.post(
        '/coleta/paradas/$paradaId/gps',
        body: {
          'latitude': latitude,
          'longitude': longitude,
        },
      );
    } catch (e) {
      print('Erro ao registrar GPS na API: $e');
    }

    await _dao.registrarGPS(paradaId, latitude, longitude);

    await _syncService.queueOperation(
      tabela: 'tb_parada',
      operacao: 'GPS',
      registroId: paradaId,
      dados: {
        'latitude': latitude,
        'longitude': longitude,
      },
    );

    return true;
  }

  List<ParadaModel> getMockParadas() {
    return [
      ParadaModel(
        id: 1,
        rotaId: 1,
        pessoaId: 1,
        pessoaNome: 'Fazenda dos Santos',
        cnpjCpf: '12.345.678/0001-90',
        endereco: 'Estrada Rural km 10',
        latitude: -19.8157,
        longitude: -43.9542,
        status: 'P',
      ),
      ParadaModel(
        id: 2,
        rotaId: 1,
        pessoaId: 2,
        pessoaNome: 'Granja Central',
        cnpjCpf: '98.765.432/0001-10',
        endereco: 'Estrada Rural km 25',
        latitude: -19.8250,
        longitude: -43.9650,
        status: 'P',
      ),
    ];
  }
}
