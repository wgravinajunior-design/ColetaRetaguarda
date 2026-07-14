import '../../core/viewmodels/base_viewmodel.dart';
import '../models/rota_model.dart';
import '../repositories/rota_repository.dart';
import '../../../core/offline/offline_request_queue.dart';

class RotaViewModel extends BaseViewModel<RotaModel> {
  final RotaRepository _repository = RotaRepository();
  final OfflineRequestQueue _offlineQueue = OfflineRequestQueue();

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
      setError('Erro: $e');
      await _offlineQueue.enqueue(
        OfflineRequestMethod.post,
        '/api/rotas',
        body: r.toJson(),
        priority: 3,
      );
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
      setError('Erro: $e');
      await _offlineQueue.enqueue(
        OfflineRequestMethod.put,
        '/api/rotas/${r.id}',
        body: r.toJson(),
        priority: 3,
      );
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
      setError('Erro: $e');
      await _offlineQueue.enqueue(
        OfflineRequestMethod.delete,
        '/api/rotas/$id',
        priority: 3,
      );
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
