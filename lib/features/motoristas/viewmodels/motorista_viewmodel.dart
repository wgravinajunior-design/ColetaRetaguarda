import '../../core/viewmodels/base_viewmodel.dart';
import '../models/motorista_model.dart';
import '../repositories/motorista_repository.dart';
import '../../core/database/sync_service.dart';
import '../../core/sync/sync_handlers.dart';

class MotoristaViewModel extends BaseViewModel<MotoristaModel> {
  final MotoristaRepository _repository = MotoristaRepository();
  final SyncService _syncService = SyncService();

  String _searchQuery = '';

  String get searchQuery => _searchQuery;

  Future<void> loadMotoristas({String? query}) async {
    // Tenta cache primeiro
    final cacheKey = '/motoristas'.cacheKey('query=${query ?? ""}');
    final cached = cacheManager.get<List<MotoristaModel>>(cacheKey);
    if (cached != null) {
      setItems(cached);
      return;
    }

    setLoading();
    try {
      final motoristas = await _repository.getMotoristas(query: query);
      cacheManager.put(cacheKey, motoristas, ttl: const Duration(minutes: 10));
      setItems(motoristas);
    } catch (e) {
      setError('Erro ao carregar motoristas: $e');
    }
  }

  Future<bool> createMotorista(MotoristaModel motorista) async {
    setLoading();
    try {
      final novo = await _repository.createMotorista(motorista);
      if (novo != null) {
        items.add(novo);
        setSuccess();
        cacheManager.removePattern('/motoristas');
        return true;
      }
      setError('Erro ao criar motorista');
      return false;
    } catch (e) {
      await _syncService.queueOperation(
        tabela: SyncEntities.motorista,
        operacao: 'CREATE',
        dados: motorista.toJson(),
      );
      setError('Sem conexão com a base. Cadastro salvo na fila offline e será sincronizado automaticamente.');
      return false;
    }
  }

  Future<bool> updateMotorista(MotoristaModel motorista) async {
    setLoading();
    try {
      final success = await _repository.updateMotorista(motorista);
      if (success) {
        final index = items.indexWhere((m) => m.id == motorista.id);
        if (index != -1) {
          items[index] = motorista;
        }
        setSuccess();
        cacheManager.removePattern('/motoristas');
        return true;
      }
      setError('Erro ao atualizar motorista');
      return false;
    } catch (e) {
      await _syncService.queueOperation(
        tabela: SyncEntities.motorista,
        operacao: 'UPDATE',
        registroId: motorista.id,
        dados: motorista.toJson(),
      );
      setError('Sem conexão com a base. Alteração salva na fila offline e será sincronizada automaticamente.');
      return false;
    }
  }

  Future<bool> deleteMotorista(int id) async {
    setLoading();
    try {
      final success = await _repository.deleteMotorista(id);
      if (success) {
        items.removeWhere((m) => m.id == id);
        setSuccess();
        cacheManager.removePattern('/motoristas');
        return true;
      }
      setError('Erro ao deletar motorista');
      return false;
    } catch (e) {
      await _syncService.queueOperation(
        tabela: SyncEntities.motorista,
        operacao: 'DELETE',
        registroId: id,
        dados: {'id': id},
      );
      setError('Sem conexão com a base. Exclusão salva na fila offline e será sincronizada automaticamente.');
      return false;
    }
  }

  void setSearchQuery(String query) {
    _searchQuery = query;
    notifyListeners();
  }

  List<MotoristaModel> getFilteredMotoristas() {
    if (_searchQuery.isEmpty) {
      return items;
    }
    return items
        .where((m) =>
            (m.nome?.toLowerCase().contains(_searchQuery.toLowerCase()) ??
                false) ||
            (m.cpf.toLowerCase().contains(_searchQuery.toLowerCase())))
        .toList();
  }
}
