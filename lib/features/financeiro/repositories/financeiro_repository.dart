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

  List<MovimentoModel> getMockMovimentos() {
    return [
      MovimentoModel(
        id: 1,
        tipo: 'C',
        status: 'C',
        conta: 1,
        contaNome: 'Banco do Brasil',
        valor: 1500.0,
        dtEmissao: '2026-07-01',
        dtCompensado: '2026-07-01',
        historico: 'Venda de Soja',
      ),
      MovimentoModel(
        id: 2,
        tipo: 'D',
        status: 'C',
        conta: 1,
        contaNome: 'Banco do Brasil',
        valor: 500.0,
        dtEmissao: '2026-07-05',
        dtCompensado: '2026-07-05',
        historico: 'Pagamento de Frete',
      ),
      MovimentoModel(
        id: 3,
        tipo: 'D',
        status: 'P',
        conta: 1,
        contaNome: 'Banco do Brasil',
        valor: 250.0,
        dtEmissao: '2026-07-10',
        historico: 'Manutenção Veículo',
      ),
    ];
  }
}
