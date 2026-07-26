import 'package:flutter/foundation.dart';
import '../../../core/api/http_client.dart';
import '../../core/database/daos/rota_dao.dart';
import '../../core/database/firebird_service.dart';
import '../models/rota_model.dart';

class RotaRepository {
  final ApiClient _apiClient = ApiClient();
  final RotaDao _dao = RotaDao();
  final FirebirdService _firebird = FirebirdService();

  Future<List<RotaModel>> getRotas({
    String? query,
    String? status,
    DateTime? inicio,
    DateTime? fim,
  }) async {
    // Fonte primária: base Firebird configurada (COLETAS_ROTA)
    try {
      final rotas = await _firebird.getRotas(
        status: status,
        inicio: inicio,
        fim: fim,
      );
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

    return [];
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

  /// Coletas da rota ainda em aberto (pendentes ou em andamento).
  Future<int> coletasEmAberto(int rotaId) =>
      _firebird.coletasEmAbertoNaRota(rotaId);

  /// Encerra a rota e marca o horário de término.
  Future<bool> finalizar(int rotaId) => _firebird.finalizarRota(rotaId);

  /// Reabre uma rota concluída.
  Future<bool> reabrir(int rotaId) => _firebird.reabrirRota(rotaId);
}
