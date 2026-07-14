import '../../core/viewmodels/base_viewmodel.dart';
import '../models/veiculo_model.dart';
import '../repositories/veiculo_repository.dart';

class VeiculoViewModel extends BaseViewModel<VeiculoModel> {
  final VeiculoRepository _repository = VeiculoRepository();

  Future<void> loadVeiculos({String? query}) async {
    setLoading();
    try {
      final veiculos = await _repository.getVeiculos(query: query);
      setItems(veiculos.isEmpty ? _repository.getMockVeiculos() : veiculos);
    } catch (e) {
      setError('Erro ao carregar veículos: $e');
    }
  }

  Future<bool> createVeiculo(VeiculoModel v) async {
    setLoading();
    try {
      final novo = await _repository.createVeiculo(v);
      if (novo != null) {
        items.add(novo);
        setSuccess();
        return true;
      }
      return false;
    } catch (e) {
      setError('Erro: $e');
      return false;
    }
  }

  Future<bool> updateVeiculo(VeiculoModel v) async {
    setLoading();
    try {
      if (await _repository.updateVeiculo(v)) {
        final i = items.indexWhere((x) => x.id == v.id);
        if (i != -1) items[i] = v;
        setSuccess();
        return true;
      }
      return false;
    } catch (e) {
      setError('Erro: $e');
      return false;
    }
  }

  Future<bool> deleteVeiculo(int id) async {
    setLoading();
    try {
      if (await _repository.deleteVeiculo(id)) {
        items.removeWhere((x) => x.id == id);
        setSuccess();
        return true;
      }
      return false;
    } catch (e) {
      setError('Erro: $e');
      return false;
    }
  }
}
