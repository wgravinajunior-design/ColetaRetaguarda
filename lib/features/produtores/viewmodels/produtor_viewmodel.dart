import '../../core/viewmodels/base_viewmodel.dart';
import '../models/pessoa_model.dart';
import '../repositories/pessoa_repository.dart';
import '../../core/database/sync_service.dart';
import '../../core/sync/sync_handlers.dart';

class ProdutorViewModel extends BaseViewModel<PessoaModel> {
  final PessoaRepository _repository = PessoaRepository();
  final SyncService _syncService = SyncService();

  // Filtro de status ativo por padrão ('A' = ativos).
  String? _filtroStatus = 'A';
  String? get filtroStatus => _filtroStatus;

  Future<void> loadProdutores({String? query, String? status}) async {
    _filtroStatus = status ?? _filtroStatus;

    // Tenta cache primeiro
    final cacheKey = '/produtores'.cacheKey('status=${_filtroStatus ?? ""}');
    final cached = cacheManager.get<List<PessoaModel>>(cacheKey);
    if (cached != null) {
      setItems(cached);
      return;
    }

    setLoading();
    try {
      final produtores = await _repository.getProdutores(
        query: query,
        status: _filtroStatus,
      );
      cacheManager.put(cacheKey, produtores, ttl: const Duration(minutes: 10));
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
        // Invalida cache
        cacheManager.removePattern('/produtores');
        return true;
      }
      return false;
    } catch (e) {
      // Base indisponível: enfileira a operação para replay no Firebird.
      await _syncService.queueOperation(
        tabela: SyncEntities.produtor,
        operacao: 'CREATE',
        dados: produtor.toJson(),
      );
      setError('Sem conexão com a base. Cadastro salvo na fila offline e será sincronizado automaticamente.');
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
        cacheManager.removePattern('/produtores');
        return true;
      }
      return false;
    } catch (e) {
      await _syncService.queueOperation(
        tabela: SyncEntities.produtor,
        operacao: 'UPDATE',
        registroId: produtor.id,
        dados: produtor.toJson(),
      );
      setError('Sem conexão com a base. Alteração salva na fila offline e será sincronizada automaticamente.');
      return false;
    }
  }

  Future<bool> deleteProdutor(int id) async {
    setLoading();
    try {
      if (await _repository.deletePessoa(id)) {
        items.removeWhere((p) => p.id == id);
        setSuccess();
        cacheManager.removePattern('/produtores');
        return true;
      }
      return false;
    } catch (e) {
      await _syncService.queueOperation(
        tabela: SyncEntities.produtor,
        operacao: 'DELETE',
        registroId: id,
        dados: {'id': id},
      );
      setError('Sem conexão com a base. Exclusão salva na fila offline e será sincronizada automaticamente.');
      return false;
    }
  }
}
