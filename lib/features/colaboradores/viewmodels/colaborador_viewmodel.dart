import '../../core/viewmodels/base_viewmodel.dart';
import '../models/colaborador_model.dart';
import '../repositories/colaborador_repository.dart';
import '../../../core/offline/offline_request_queue.dart';

class ColaboradorViewModel extends BaseViewModel<ColaboradorModel> {
  final ColaboradorRepository _repository = ColaboradorRepository();
  final OfflineRequestQueue _offlineQueue = OfflineRequestQueue();

  Future<void> loadColaboradores({String? query}) async {
    // Tenta cache primeiro
    final cacheKey = '/colaboradores'.cacheKey('query=${query ?? ""}');
    final cached = cacheManager.get<List<ColaboradorModel>>(cacheKey);
    if (cached != null) {
      setItems(cached);
      return;
    }

    setLoading();
    try {
      final colaboradores = await _repository.getColaboradores(query: query);
      if (colaboradores.isEmpty) {
        setItems(_repository.getMockColaboradores());
      } else {
        cacheManager.put(cacheKey, colaboradores, ttl: const Duration(minutes: 10));
        setItems(colaboradores);
      }
    } catch (e) {
      setError('Erro ao carregar colaboradores: $e');
    }
  }

  Future<bool> createColaborador(ColaboradorModel c) async {
    setLoading();
    try {
      final novo = await _repository.createColaborador(c);
      if (novo != null) {
        items.add(novo);
        setSuccess();
        cacheManager.removePattern('/colaboradores');
        return true;
      }
      setError('Erro ao criar colaborador');
      return false;
    } catch (e) {
      setError('Erro: $e');
      await _offlineQueue.enqueue(
        OfflineRequestMethod.post,
        '/api/colaboradores',
        body: c.toJson(),
        priority: 3,
      );
      return false;
    }
  }

  Future<bool> updateColaborador(ColaboradorModel c) async {
    setLoading();
    try {
      final success = await _repository.updateColaborador(c);
      if (success) {
        final index = items.indexWhere((x) => x.id == c.id);
        if (index != -1) items[index] = c;
        setSuccess();
        cacheManager.removePattern('/colaboradores');
        return true;
      }
      setError('Erro ao atualizar');
      return false;
    } catch (e) {
      setError('Erro: $e');
      await _offlineQueue.enqueue(
        OfflineRequestMethod.put,
        '/api/colaboradores/${c.id}',
        body: c.toJson(),
        priority: 3,
      );
      return false;
    }
  }

  Future<bool> deleteColaborador(int id) async {
    setLoading();
    try {
      final success = await _repository.deleteColaborador(id);
      if (success) {
        items.removeWhere((x) => x.id == id);
        setSuccess();
        cacheManager.removePattern('/colaboradores');
        return true;
      }
      setError('Erro ao deletar');
      return false;
    } catch (e) {
      setError('Erro: $e');
      await _offlineQueue.enqueue(
        OfflineRequestMethod.delete,
        '/api/colaboradores/$id',
        priority: 3,
      );
      return false;
    }
  }
}
