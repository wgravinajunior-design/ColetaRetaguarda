import '../../core/viewmodels/base_viewmodel.dart';
import '../models/veiculo_model.dart';
import '../repositories/veiculo_repository.dart';
import '../../core/database/sync_service.dart';
import '../../core/sync/sync_handlers.dart';

class VeiculoViewModel extends BaseViewModel<VeiculoModel> {
  final VeiculoRepository _repository = VeiculoRepository();
  final SyncService _syncService = SyncService();

  Future<void> loadVeiculos({String? query}) async {
    final cacheKey = '/veiculos'.cacheKey('query=${query ?? ""}');
    final cached = cacheManager.get<List<VeiculoModel>>(cacheKey);
    if (cached != null) {
      setItems(cached);
      return;
    }

    setLoading();
    try {
      final veiculos = await _repository.getVeiculos(query: query);
      cacheManager.put(cacheKey, veiculos, ttl: const Duration(minutes: 10));
      setItems(veiculos);
    } catch (e) {
      setError('Erro ao carregar veículos: $e');
    }
  }

  Future<bool> createVeiculo(VeiculoModel v) async {
    setLoading();
    try {
      final novo = await _repository.createVeiculo(v);
      if (novo != null) {
        items.add(novo);
        setSuccess();
        cacheManager.removePattern('/veiculos');
        return true;
      }
      return false;
    } catch (e) {
      await _syncService.queueOperation(
        tabela: SyncEntities.veiculo,
        operacao: 'CREATE',
        dados: v.toJson(),
      );
      setError('Sem conexão com a base. Cadastro salvo na fila offline e será sincronizado automaticamente.');
      return false;
    }
  }

  Future<bool> updateVeiculo(VeiculoModel v) async {
    setLoading();
    try {
      if (await _repository.updateVeiculo(v)) {
        final i = items.indexWhere((x) => x.id == v.id);
        if (i != -1) items[i] = v;
        setSuccess();
        cacheManager.removePattern('/veiculos');
        return true;
      }
      return false;
    } catch (e) {
      await _syncService.queueOperation(
        tabela: SyncEntities.veiculo,
        operacao: 'UPDATE',
        registroId: v.id,
        dados: v.toJson(),
      );
      setError('Sem conexão com a base. Alteração salva na fila offline e será sincronizada automaticamente.');
      return false;
    }
  }

  Future<bool> deleteVeiculo(int id) async {
    setLoading();
    try {
      if (await _repository.deleteVeiculo(id)) {
        items.removeWhere((x) => x.id == id);
        setSuccess();
        cacheManager.removePattern('/veiculos');
        return true;
      }
      return false;
    } catch (e) {
      await _syncService.queueOperation(
        tabela: SyncEntities.veiculo,
        operacao: 'DELETE',
        registroId: id,
        dados: {'id': id},
      );
      setError('Sem conexão com a base. Exclusão salva na fila offline e será sincronizada automaticamente.');
      return false;
    }
  }
}
