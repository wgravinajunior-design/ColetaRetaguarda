import '../../core/viewmodels/base_viewmodel.dart';
import '../models/pessoa_model.dart';
import '../repositories/pessoa_repository.dart';

class ProdutorViewModel extends BaseViewModel<PessoaModel> {
  final PessoaRepository _repository = PessoaRepository();

  Future<void> loadProdutores({String? query}) async {
    setLoading();
    try {
      final produtores = await _repository.getProdutores(query: query);
      if (produtores.isEmpty) {
        setItems(_repository.getMockProdutores());
      } else {
        setItems(produtores);
      }
    } catch (e) {
      setError('Erro ao carregar produtores: $e');
    }
  }

  Future<bool> createProdutor(PessoaModel produtor) async {
    setLoading();
    try {
      final novo = await _repository.createPessoa(produtor);
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

  Future<bool> updateProdutor(PessoaModel produtor) async {
    setLoading();
    try {
      if (await _repository.updatePessoa(produtor)) {
        final index = items.indexWhere((p) => p.id == produtor.id);
        if (index != -1) items[index] = produtor;
        setSuccess();
        return true;
      }
      return false;
    } catch (e) {
      setError('Erro: $e');
      return false;
    }
  }

  Future<bool> deleteProdutor(int id) async {
    setLoading();
    try {
      if (await _repository.deletePessoa(id)) {
        items.removeWhere((p) => p.id == id);
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
