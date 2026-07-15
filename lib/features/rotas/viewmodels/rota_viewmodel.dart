import '../../core/viewmodels/base_viewmodel.dart';
import '../models/rota_model.dart';
import '../repositories/rota_repository.dart';
import '../../core/database/sync_service.dart';
import '../../core/sync/sync_handlers.dart';

class RotaViewModel extends BaseViewModel<RotaModel> {
  final RotaRepository _repository = RotaRepository();
  final SyncService _syncService = SyncService();

  Future<void> loadRotas({String? query}) async {
    final cacheKey = '/rotas'.cacheKey('query=${query ?? ""}');
    final cached = cacheManager.get<List<RotaModel>>(cacheKey);
    if (cached != null) {
      setItems(cached);
      return;
    }

    setLoading();
    try {
      final rotas = await _repository.getRotas(query: query);
      cacheManager.put(cacheKey, rotas, ttl: const Duration(minutes: 10));
      setItems(rotas);
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
        cacheManager.removePattern('/rotas');
        return true;
      }
      return false;
    } catch (e) {
      await _syncService.queueOperation(
        tabela: SyncEntities.rota,
        operacao: 'CREATE',
        dados: r.toJson(),
      );
      setError('Sem conexão com a base. Cadastro salvo na fila offline e será sincronizado automaticamente.');
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
        cacheManager.removePattern('/rotas');
        return true;
      }
      return false;
    } catch (e) {
      await _syncService.queueOperation(
        tabela: SyncEntities.rota,
        operacao: 'UPDATE',
        registroId: r.id,
        dados: r.toJson(),
      );
      setError('Sem conexão com a base. Alteração salva na fila offline e será sincronizada automaticamente.');
      return false;
    }
  }

  Future<bool> deleteRota(int id) async {
    setLoading();
    try {
      if (await _repository.deleteRota(id)) {
        items.removeWhere((x) => x.id == id);
        setSuccess();
        cacheManager.removePattern('/rotas');
        return true;
      }
      return false;
    } catch (e) {
      await _syncService.queueOperation(
        tabela: SyncEntities.rota,
        operacao: 'DELETE',
        registroId: id,
        dados: {'id': id},
      );
      setError('Sem conexão com a base. Exclusão salva na fila offline e será sincronizada automaticamente.');
      return false;
    }
  }

  Future<bool> mudarStatus(int rotaId, String status) async {
    try {
      final ok = await _repository.mudarStatus(rotaId, status);
      if (ok) {
        final i = items.indexWhere((x) => x.id == rotaId);
        if (i != -1) items[i].status = status;
        cacheManager.removePattern('/rotas');
        notifyListeners();
      }
      return ok;
    } catch (e) {
      setError('Erro: $e');
      return false;
    }
  }
}
