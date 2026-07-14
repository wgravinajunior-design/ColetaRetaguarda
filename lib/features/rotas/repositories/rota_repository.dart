import 'package:flutter/foundation.dart';
import '../../../core/api/http_client.dart';
import '../../core/database/daos/rota_dao.dart';
import '../../core/database/firebird_service.dart';
import '../models/rota_model.dart';

class RotaRepository {
  final ApiClient _apiClient = ApiClient();
  final RotaDao _dao = RotaDao();
  final FirebirdService _firebird = FirebirdService();

  Future<List<RotaModel>> getRotas({String? query}) async {
    // Fonte primária: base Firebird configurada (COLETAS_ROTA)
    try {
      final rotas = await _firebird.getRotas();
      if (query == null || query.isEmpty) return rotas;
      final q = query.toLowerCase();
      return rotas.where((r) => r.descricao.toLowerCase().contains(q)).toList();
    } catch (e) {
      debugPrint('Erro ao carregar rotas do Firebird: $e');
    }

    try {
      return await _dao.getAll();
    } catch (e) {
      debugPrint('Erro ao carregar rotas do SQLite: $e');
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
      debugPrint('Erro ao carregar rota $id da API: $e');
    }

    try {
      return await _dao.getById(id);
    } catch (e) {
      debugPrint('Erro ao carregar rota $id do SQLite: $e');
    }

    return null;
  }

  Future<RotaModel?> createRota(RotaModel r) async {
    // Grava direto na base Firebird (COLETAS_ROTA)
    final criada = await _firebird.criarRota(r);
    return criada;
  }

  Future<bool> updateRota(RotaModel r) async {
    if (r.id == null) return false;
    return await _firebird.atualizarRota(r);
  }

  Future<bool> deleteRota(int id) async {
    return await _firebird.excluirRota(id);
  }

  Future<bool> mudarStatus(int rotaId, String status) async {
    return await _firebird.atualizarStatusRota(rotaId, status);
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
