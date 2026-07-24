import '../../core/database/firebird_service.dart';
import '../models/motorista_model.dart';

class MotoristaRepository {
  final FirebirdService _firebird = FirebirdService();

  Future<List<MotoristaModel>> getMotoristas({String? query, String? status = 'A'}) async {
    final motoristas = await _firebird.getMotoristas(status: status);
    if (query == null || query.isEmpty) return motoristas;
    final q = query.toLowerCase();
    return motoristas
        .where((m) =>
            (m.nome ?? '').toLowerCase().contains(q) ||
            m.cpf.toLowerCase().contains(q))
        .toList();
  }

  Future<MotoristaModel?> createMotorista(MotoristaModel motorista) async {
    return await _firebird.criarMotorista(motorista);
  }

  Future<bool> updateMotorista(MotoristaModel motorista) async {
    if (motorista.id == null) return false;
    return await _firebird.atualizarMotorista(motorista);
  }

  Future<bool> deleteMotorista(int id) async {
    return await _firebird.excluirMotorista(id);
  }
}
