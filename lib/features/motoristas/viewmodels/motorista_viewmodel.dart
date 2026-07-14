import '../../core/viewmodels/base_viewmodel.dart';
import '../models/motorista_model.dart';
import '../repositories/motorista_repository.dart';

class MotoristaViewModel extends BaseViewModel<MotoristaModel> {
  final MotoristaRepository _repository = MotoristaRepository();

  String _searchQuery = '';

  String get searchQuery => _searchQuery;

  Future<void> loadMotoristas({String? query}) async {
    setLoading();
    try {
      final motoristas = await _repository.getMotoristas(query: query);
      setItems(motoristas);
    } catch (e) {
      setError('Erro ao carregar motoristas: $e');
    }
  }

  Future<bool> createMotorista(MotoristaModel motorista) async {
    setLoading();
    try {
      final novo = await _repository.createMotorista(motorista);
      if (novo != null) {
        items.add(novo);
        setSuccess();
        return true;
      }
      setError('Erro ao criar motorista');
      return false;
    } catch (e) {
      setError('Erro ao criar motorista: $e');
      return false;
    }
  }

  Future<bool> updateMotorista(MotoristaModel motorista) async {
    setLoading();
    try {
      final success = await _repository.updateMotorista(motorista);
      if (success) {
        final index = items.indexWhere((m) => m.id == motorista.id);
        if (index != -1) {
          items[index] = motorista;
        }
        setSuccess();
        return true;
      }
      setError('Erro ao atualizar motorista');
      return false;
    } catch (e) {
      setError('Erro ao atualizar motorista: $e');
      return false;
    }
  }

  Future<bool> deleteMotorista(int id) async {
    setLoading();
    try {
      final success = await _repository.deleteMotorista(id);
      if (success) {
        items.removeWhere((m) => m.id == id);
        setSuccess();
        return true;
      }
      setError('Erro ao deletar motorista');
      return false;
    } catch (e) {
      setError('Erro ao deletar motorista: $e');
      return false;
    }
  }

  void setSearchQuery(String query) {
    _searchQuery = query;
    notifyListeners();
  }

  List<MotoristaModel> getFilteredMotoristas() {
    if (_searchQuery.isEmpty) {
      return items;
    }
    return items
        .where((m) =>
            (m.nome?.toLowerCase().contains(_searchQuery.toLowerCase()) ??
                false) ||
            (m.cpf.toLowerCase().contains(_searchQuery.toLowerCase())))
        .toList();
  }
}
