import '../../core/database/firebird_service.dart';
import '../models/movimento_model.dart';

class FinanceiroRepository {
  final FirebirdService _firebird = FirebirdService();

  /// Lista as contas financeiras (caixa e bancos) da base.
  Future<List<ContaRef>> getContas() => _firebird.getContas();

  /// Saldo acumulado de cada conta.
  Future<List<SaldoConta>> getSaldosPorConta() => _firebird.getSaldosPorConta();

  Future<List<MovimentoModel>> getMovimentos({int? contaId, String? tipo}) async {
    return await _firebird.getMovimentos(contaId: contaId, tipo: tipo);
  }

  Future<MovimentoModel?> createMovimento(MovimentoModel mov) async {
    return await _firebird.criarMovimento(mov);
  }

  Future<bool> updateMovimento(MovimentoModel mov) async {
    return await _firebird.atualizarMovimento(mov);
  }

  Future<bool> deleteMovimento(int id) async {
    return await _firebird.excluirMovimento(id);
  }
}
