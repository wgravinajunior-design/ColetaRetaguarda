import 'package:flutter/foundation.dart';
import '../../core/database/daos/parada_dao.dart';
import '../../core/database/sync_service.dart';
import '../../core/database/firebird_service.dart';
import '../models/parada_model.dart';

class ParadaRepository {
  final ParadaDao _dao = ParadaDao();
  final SyncService _syncService = SyncService();
  final FirebirdService _firebird = FirebirdService();

  Future<List<ParadaModel>> getParadasByRota(int rotaId) async {
    // Fonte primária: base Firebird configurada
    try {
      return await _firebird.getParadasByRota(rotaId);
    } catch (e) {
      debugPrint('Erro ao carregar paradas do Firebird: $e');
    }

    try {
      return await _dao.getByRotaId(rotaId);
    } catch (e) {
      debugPrint('Erro ao carregar paradas do SQLite: $e');
    }

    return [];
  }

  /// Busca todas as coletas (paradas) de todas as rotas.
  /// Opcionalmente filtra por status (P/E/C/R).
  Future<List<ParadaModel>> getTodasColetas({String? status}) async {
    try {
      return await _firebird.getTodasColetas(status: status);
    } catch (e) {
      debugPrint('Erro ao carregar coletas do Firebird: $e');
    }

    try {
      if (status != null) {
        return await _dao.getByStatus(status);
      }
      return await _dao.getAll();
    } catch (e) {
      debugPrint('Erro ao carregar coletas do SQLite: $e');
    }

    return [];
  }

  Future<ParadaModel?> getParadaById(int id) async {
    try {
      return await _firebird.getParadaById(id);
    } catch (e) {
      debugPrint('Erro ao carregar parada $id do Firebird: $e');
    }

    try {
      return await _dao.getById(id);
    } catch (e) {
      debugPrint('Erro ao carregar parada $id do SQLite: $e');
    }

    return null;
  }

  Future<bool> atualizarStatusParada({
    required int paradaId,
    required String novoStatus,
    double? temperatura,
    double? volume,
    String? justificativa,
    String? assinaturaBase64,
    String? fotoPath,
  }) async {
    // Grava direto na base Firebird
    try {
      await _firebird.atualizarStatusColeta(
        paradaId: paradaId,
        novoStatus: novoStatus,
        temperatura: temperatura,
        volume: volume,
        justificativa: justificativa,
        assinaturaBase64: assinaturaBase64,
        fotoPath: fotoPath,
      );
      return true;
    } catch (e) {
      debugPrint('Erro ao atualizar status no Firebird: $e');
    }

    // Fallback offline: SQLite + fila de sincronização
    await _dao.updateStatus(
      paradaId,
      novoStatus,
      temperatura: temperatura,
      volume: volume,
      justificativa: justificativa,
      assinaturaBase64: assinaturaBase64,
      fotoPath: fotoPath,
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
        'assinatura_base64': assinaturaBase64,
        'foto_path': fotoPath,
      },
    );

    return true;
  }

  Future<bool> registrarGPS(
    int paradaId,
    double latitude,
    double longitude, {
    String? horarioChegada,
  }) async {
    // Grava o GPS de captura direto na base Firebird (COLETAS_DETALHE)
    try {
      await _firebird.registrarGpsColeta(paradaId, latitude, longitude, horarioChegada: horarioChegada);
      return true;
    } catch (e) {
      debugPrint('Erro ao registrar GPS no Firebird: $e');
    }

    // Fallback local best-effort
    try {
      await _dao.registrarGPS(paradaId, latitude, longitude, horarioChegada: horarioChegada);
    } catch (_) {}
    return true;
  }

  Future<bool> reordenarParadas(List<int> paradaIdsEmOrdem) async {
    return await _firebird.atualizarOrdemParadas(paradaIdsEmOrdem);
  }

  Future<ParadaModel?> criarParada(ParadaModel parada) async {
    // Grava direto na base Firebird
    try {
      final criada = await _firebird.criarParada(parada);
      if (criada != null) return criada;
    } catch (e) {
      debugPrint('Erro ao criar parada no Firebird: $e');
    }

    // Fallback offline
    final localParada = parada.copyWith(id: DateTime.now().millisecondsSinceEpoch);
    await _dao.insert(localParada);

    await _syncService.queueOperation(
      tabela: 'tb_parada',
      operacao: 'INSERT',
      dados: localParada.toJson(),
    );

    return localParada;
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
