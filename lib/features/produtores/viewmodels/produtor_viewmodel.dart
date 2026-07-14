import '../../core/viewmodels/base_viewmodel.dart';
import '../models/pessoa_model.dart';
import '../repositories/pessoa_repository.dart';

class ProdutorViewModel extends BaseViewModel<PessoaModel> {
  final PessoaRepository _repository = PessoaRepository();

  // Filtro de status ativo por padrão ('A' = ativos).
  String? _filtroStatus = 'A';
  String? get filtroStatus => _filtroStatus;

  Future<void> loadProdutores({String? query, String? status}) async {
    _filtroStatus = status ?? _filtroStatus;
    setLoading();
    try {
      final produtores = await _repository.getProdutores(query: query, status: _filtroStatus);
      setItems(produtores);
    } catch (e) {
      setError('Erro ao carregar produtores: $e');
    }
  }

  void aplicarFiltroStatus(String? status) {
    _filtroStatus = status;
    loadProdutores(status: status);
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
