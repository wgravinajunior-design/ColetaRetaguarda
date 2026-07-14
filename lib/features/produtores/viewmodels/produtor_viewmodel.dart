import 'package:flutter/foundation.dart';
import '../models/pessoa_model.dart';
import '../repositories/pessoa_repository.dart';

class ProdutorViewModel extends ChangeNotifier {
  final PessoaRepository _repository = PessoaRepository();
  
  List<PessoaModel> produtores = [];
  bool isLoading = false;
  String? errorMessage;

  Future<void> fetchProdutores() async {
    isLoading = true;
    errorMessage = null;
    notifyListeners();

    try {
      final data = await _repository.getProdutores();
      // Filtrar apenas produtores (clientes), mas mock já traz certo
      produtores = data.where((p) => p.cliente == 'S').toList();
    } catch (e) {
      errorMessage = 'Erro ao carregar produtores: $e';
    } finally {
      isLoading = false;
      notifyListeners();
    }
  }

  Future<bool> saveProdutor(PessoaModel produtor) async {
    isLoading = true;
    notifyListeners();

    bool success = false;
    try {
      if (produtor.id == null) {
        final newProdutor = await _repository.createPessoa(produtor);
        if (newProdutor != null) {
          produtores.add(newProdutor);
          success = true;
        }
      } else {
        success = await _repository.updatePessoa(produtor);
        if (success) {
          final index = produtores.indexWhere((p) => p.id == produtor.id);
          if (index != -1) {
            produtores[index] = produtor;
          }
        }
      }
    } catch (e) {
      errorMessage = 'Erro ao salvar produtor: $e';
    } finally {
      isLoading = false;
      notifyListeners();
    }
    return success;
  }

  Future<bool> deleteProdutor(int id) async {
    isLoading = true;
    notifyListeners();

    bool success = false;
    try {
      success = await _repository.deletePessoa(id);
      if (success) {
        produtores.removeWhere((p) => p.id == id);
      }
    } catch (e) {
      errorMessage = 'Erro ao deletar produtor: $e';
    } finally {
      isLoading = false;
      notifyListeners();
    }
    return success;
  }
}
