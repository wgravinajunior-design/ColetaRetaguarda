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
            v.marca.toLowerCase().contains(q) ||
            v.modelo.toLowerCase().contains(q))
        .toList();
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

  List<VeiculoModel> getMockVeiculos() {
    return [
      VeiculoModel(
        id: 1,
        placa: 'ABC-1234',
        marca: 'Mercedes',
        modelo: 'Sprinter',
        cor: 'Branco',
        ano: '2022',
        tipo: 'F',
        renavam: '12345678901234',
        status: 'A',
      ),
      VeiculoModel(
        id: 2,
        placa: 'XYZ-5678',
        marca: 'Volvo',
        modelo: 'FH',
        cor: 'Branco',
        ano: '2021',
        tipo: 'C',
        renavam: '98765432109876',
        status: 'A',
      ),
    ];
  }
}
