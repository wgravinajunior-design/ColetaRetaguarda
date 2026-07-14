import '../../core/viewmodels/base_viewmodel.dart';
import '../models/rota_model.dart';
import '../repositories/rota_repository.dart';

class RotaViewModel extends BaseViewModel<RotaModel> {
  final RotaRepository _repository = RotaRepository();

  Future<void> loadRotas({String? query}) async {
    setLoading();
    try {
      final rotas = await _repository.getRotas(query: query);
      setItems(rotas.isEmpty ? _repository.getMockRotas() : rotas);
    } catch (e) {
      setError('Erro ao carregar rotas: $e');
    }
  }

  Future<bool> createRota(RotaModel r) async {
    setLoading();
    try {
      final novo = await _repository.createRota(r);
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

  Future<bool> updateRota(RotaModel r) async {
    setLoading();
    try {
      if (await _repository.updateRota(r)) {
        final i = items.indexWhere((x) => x.id == r.id);
        if (i != -1) items[i] = r;
        setSuccess();
        return true;
      }
      return false;
    } catch (e) {
      setError('Erro: $e');
      return false;
    }
  }

  Future<bool> deleteRota(int id) async {
    setLoading();
    try {
      if (await _repository.deleteRota(id)) {
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
