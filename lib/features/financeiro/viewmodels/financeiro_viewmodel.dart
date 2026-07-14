import '../../core/viewmodels/base_viewmodel.dart';
import '../models/movimento_model.dart';
import '../repositories/financeiro_repository.dart';

class FinanceiroViewModel extends BaseViewModel<MovimentoModel> {
  final FinanceiroRepository _repository = FinanceiroRepository();

  double get totalReceitas =>
      items.where((m) => m.tipo == 'C').fold(0, (sum, m) => sum + m.valor);

  double get totalDespesas =>
      items.where((m) => m.tipo == 'D').fold(0, (sum, m) => sum + m.valor);

  double get saldoFinal => totalReceitas - totalDespesas;

  Future<void> loadMovimentos({String? tipo}) async {
    setLoading();
    try {
      var movimentos = await _repository.getMovimentos();
      if (tipo != null) {
        movimentos = movimentos.where((m) => m.tipo == tipo).toList();
      }
      setItems(movimentos.isEmpty
          ? _repository.getMockMovimentos()
          : movimentos);
    } catch (e) {
      setError('Erro ao carregar movimentos: $e');
    }
  }

  Future<bool> createMovimento(MovimentoModel mov) async {
    setLoading();
    try {
      final novo = await _repository.createMovimento(mov);
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

  Future<bool> updateMovimento(MovimentoModel mov) async {
    setLoading();
    try {
      if (await _repository.updateMovimento(mov)) {
        final index = items.indexWhere((m) => m.id == mov.id);
        if (index != -1) items[index] = mov;
        setSuccess();
        return true;
      }
      return false;
    } catch (e) {
      setError('Erro: $e');
      return false;
    }
  }

  Future<bool> deleteMovimento(int id) async {
    setLoading();
    try {
      if (await _repository.deleteMovimento(id)) {
        items.removeWhere((m) => m.id == id);
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
