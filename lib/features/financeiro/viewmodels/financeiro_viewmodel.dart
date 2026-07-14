import 'package:flutter/foundation.dart';
import '../models/movimento_model.dart';
import '../repositories/financeiro_repository.dart';

class FinanceiroViewModel extends ChangeNotifier {
  final FinanceiroRepository _repository = FinanceiroRepository();
  
  List<MovimentoModel> movimentos = [];
  bool isLoading = false;
  String? errorMessage;

  double get totalReceitas => movimentos
      .where((m) => m.tipo == 'C' && m.status != 'C') // Considerando 'C' como cancelado, talvez usar m.status == 'C' (Confirmado). Ajustar conforme BD.
      .fold(0, (sum, m) => sum + m.valor);

  double get totalDespesas => movimentos
      .where((m) => m.tipo == 'D')
      .fold(0, (sum, m) => sum + m.valor);

  double get saldoFinal => totalReceitas - totalDespesas;

  Future<void> fetchMovimentos() async {
    isLoading = true;
    errorMessage = null;
    notifyListeners();

    try {
      movimentos = await _repository.getMovimentos();
    } catch (e) {
      errorMessage = 'Erro ao carregar movimentos: $e';
    } finally {
      isLoading = false;
      notifyListeners();
    }
  }

  Future<bool> saveMovimento(MovimentoModel mov) async {
    isLoading = true;
    notifyListeners();

    bool success = false;
    try {
      if (mov.id == null) {
        final novo = await _repository.createMovimento(mov);
        if (novo != null) {
          movimentos.add(novo);
          success = true;
        }
      } else {
        // A API de Delphi parece ter PUT para update
        // Para mock estamos apenas reinserindo
      }
    } catch (e) {
      errorMessage = 'Erro ao salvar movimento: $e';
    } finally {
      isLoading = false;
      notifyListeners();
    }
    return success;
  }

  Future<bool> deleteMovimento(int id) async {
    isLoading = true;
    notifyListeners();

    bool success = false;
    try {
      success = await _repository.deleteMovimento(id);
      if (success) {
        movimentos.removeWhere((m) => m.id == id);
      }
    } catch (e) {
      errorMessage = 'Erro ao deletar movimento: $e';
    } finally {
      isLoading = false;
      notifyListeners();
    }
    return success;
  }
}
