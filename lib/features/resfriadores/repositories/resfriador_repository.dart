import '../../core/database/firebird_service.dart';
import '../models/resfriador_model.dart';

class ResfriadorRepository {
  final FirebirdService _firebird = FirebirdService();

  Future<List<ResfriadorModel>> getResfriadores({String? query, String? status}) async {
    final lista = await _firebird.getResfriadores(status: status);
    if (query == null || query.isEmpty) return lista;
    final q = query.toLowerCase();
    return lista
        .where((r) =>
            r.numeroId.toLowerCase().contains(q) ||
            r.marcaModelo.toLowerCase().contains(q))
        .toList();
  }

  Future<ResfriadorModel?> create(ResfriadorModel r) => _firebird.criarResfriador(r);
  Future<bool> update(ResfriadorModel r) => _firebird.atualizarResfriador(r);
  Future<bool> delete(int id) => _firebird.excluirResfriador(id);
}
