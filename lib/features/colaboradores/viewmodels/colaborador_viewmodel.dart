import '../../core/viewmodels/base_viewmodel.dart';
import '../models/colaborador_model.dart';
import '../repositories/colaborador_repository.dart';

class ColaboradorViewModel extends BaseViewModel<ColaboradorModel> {
  final ColaboradorRepository _repository = ColaboradorRepository();

  Future<void> loadColaboradores({String? query}) async {
    setLoading();
    try {
      final colaboradores = await _repository.getColaboradores(query: query);
      if (colaboradores.isEmpty) {
        setItems(_repository.getMockColaboradores());
      } else {
        setItems(colaboradores);
      }
    } catch (e) {
      setError('Erro ao carregar colaboradores: $e');
    }
  }

  Future<bool> createColaborador(ColaboradorModel c) async {
    setLoading();
    try {
      final novo = await _repository.createColaborador(c);
      if (novo != null) {
        items.add(novo);
        setSuccess();
        return true;
      }
      setError('Erro ao criar colaborador');
      return false;
    } catch (e) {
      setError('Erro: $e');
      return false;
    }
  }

  Future<bool> updateColaborador(ColaboradorModel c) async {
    setLoading();
    try {
      final success = await _repository.updateColaborador(c);
      if (success) {
        final index = items.indexWhere((x) => x.id == c.id);
        if (index != -1) items[index] = c;
        setSuccess();
        return true;
      }
      setError('Erro ao atualizar');
      return false;
    } catch (e) {
      setError('Erro: $e');
      return false;
    }
  }

  Future<bool> deleteColaborador(int id) async {
    setLoading();
    try {
      final success = await _repository.deleteColaborador(id);
      if (success) {
        items.removeWhere((x) => x.id == id);
        setSuccess();
        return true;
      }
      setError('Erro ao deletar');
      return false;
    } catch (e) {
      setError('Erro: $e');
      return false;
    }
  }
}
