import '../../core/viewmodels/base_viewmodel.dart';
import '../models/colaborador_model.dart';
import '../repositories/colaborador_repository.dart';
import '../../core/database/sync_service.dart';
import '../../core/sync/sync_handlers.dart';

class ColaboradorViewModel extends BaseViewModel<ColaboradorModel> {
  final ColaboradorRepository _repository = ColaboradorRepository();
  final SyncService _syncService = SyncService();

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
      await _syncService.queueOperation(
        tabela: SyncEntities.colaborador,
        operacao: 'CREATE',
        dados: c.toJson(),
      );
      setError('Sem conexão com a base. Cadastro salvo na fila offline e será sincronizado automaticamente.');
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
      await _syncService.queueOperation(
        tabela: SyncEntities.colaborador,
        operacao: 'UPDATE',
        registroId: c.id,
        dados: c.toJson(),
      );
      setError('Sem conexão com a base. Alteração salva na fila offline e será sincronizada automaticamente.');
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
      await _syncService.queueOperation(
        tabela: SyncEntities.colaborador,
        operacao: 'DELETE',
        registroId: id,
        dados: {'id': id},
      );
      setError('Sem conexão com a base. Exclusão salva na fila offline e será sincronizada automaticamente.');
      return false;
    }
  }
}
