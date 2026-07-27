import '../../core/database/firebird_service.dart';
import '../models/veiculo_model.dart';

class VeiculoRepository {
  final FirebirdService _firebird = FirebirdService();

  Future<List<VeiculoModel>> getVeiculos({String? query, String? status}) async {
    final veiculos = await _firebird.getVeiculos(status: status);
    if (query == null || query.isEmpty) return veiculos;
    final q = query.toLowerCase();
    return veiculos
        .where((v) =>
            v.placa.toLowerCase().contains(q) ||
            v.descricao.toLowerCase().contains(q) ||
            v.marca.toLowerCase().contains(q) ||
            v.modelo.toLowerCase().contains(q))
        .toList();
  }

  Future<VeiculoModel?> buscarPorPlaca(String placa) async {
    return await _firebird.buscarVeiculoPorPlaca(placa);
  }

  Future<VeiculoModel?> createVeiculo(VeiculoModel v) async {
    return await _firebird.criarVeiculo(v);
  }

  Future<bool> updateVeiculo(VeiculoModel v) async {
    if (v.id == null) return false;
    return await _firebird.atualizarVeiculo(v);
  }

  Future<bool> deleteVeiculo(int id) async {
    return await _firebird.excluirVeiculo(id);
  }
}
