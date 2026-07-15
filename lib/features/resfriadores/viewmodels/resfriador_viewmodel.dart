import '../../core/viewmodels/base_viewmodel.dart';
import '../models/resfriador_model.dart';
import '../repositories/resfriador_repository.dart';
import '../../core/database/sync_service.dart';
import '../../core/sync/sync_handlers.dart';

class ResfriadorViewModel extends BaseViewModel<ResfriadorModel> {
  final ResfriadorRepository _repository = ResfriadorRepository();
  final SyncService _syncService = SyncService();

  Future<void> load({String? query}) async {
    final cacheKey = '/resfriadores'.cacheKey('query=${query ?? ""}');
    final cached = cacheManager.get<List<ResfriadorModel>>(cacheKey);
    if (cached != null) {
      setItems(cached);
      return;
    }

    setLoading();
    try {
      final data = await _repository.getResfriadores(query: query);
      cacheManager.put(cacheKey, data, ttl: const Duration(minutes: 10));
      setItems(data);
    } catch (e) {
      setError('Erro ao carregar resfriadores: $e');
    }
  }

  Future<bool> create(ResfriadorModel r) async {
    setLoading();
    try {
      final novo = await _repository.create(r);
      if (novo != null) {
        items.add(novo);
        setSuccess();
        cacheManager.removePattern('/resfriadores');
        return true;
      }
      return false;
    } catch (e) {
      await _syncService.queueOperation(
        tabela: SyncEntities.resfriador,
        operacao: 'CREATE',
        dados: r.toJson(),
      );
      setError('Sem conexão com a base. Cadastro salvo na fila offline e será sincronizado automaticamente.');
      return false;
    }
  }

  Future<bool> update(ResfriadorModel r) async {
    setLoading();
    try {
      if (await _repository.update(r)) {
        final i = items.indexWhere((x) => x.id == r.id);
        if (i != -1) items[i] = r;
        setSuccess();
        cacheManager.removePattern('/resfriadores');
        return true;
      }
      return false;
    } catch (e) {
      await _syncService.queueOperation(
        tabela: SyncEntities.resfriador,
        operacao: 'UPDATE',
        registroId: r.id,
        dados: r.toJson(),
      );
      setError('Sem conexão com a base. Alteração salva na fila offline e será sincronizada automaticamente.');
      return false;
    }
  }

  Future<bool> delete(int id) async {
    setLoading();
    try {
      if (await _repository.delete(id)) {
        items.removeWhere((x) => x.id == id);
        setSuccess();
        cacheManager.removePattern('/resfriadores');
        return true;
      }
      return false;
    } catch (e) {
      await _syncService.queueOperation(
        tabela: SyncEntities.resfriador,
        operacao: 'DELETE',
        registroId: id,
        dados: {'id': id},
      );
      setError('Sem conexão com a base. Exclusão salva na fila offline e será sincronizada automaticamente.');
      return false;
    }
  }
}
