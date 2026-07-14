import '../../core/viewmodels/base_viewmodel.dart';
import '../../core/database/firebird_service.dart';
import '../models/movimento_model.dart';
import '../repositories/financeiro_repository.dart';
import '../../../core/offline/offline_request_queue.dart';

class FinanceiroViewModel extends BaseViewModel<MovimentoModel> {
  final FinanceiroRepository _repository = FinanceiroRepository();
  final OfflineRequestQueue _offlineQueue = OfflineRequestQueue();

  // Contas (caixa e bancos) e filtro selecionado
  List<ContaRef> _contas = [];
  List<ContaRef> get contas => _contas;
  int? _contaFiltro; // null = todas
  int? get contaFiltro => _contaFiltro;

  // Saldos por conta
  List<SaldoConta> _saldos = [];
  List<SaldoConta> get saldos => _saldos;

  double get totalReceitas =>
      items.where((m) => m.tipo == 'C').fold(0, (sum, m) => sum + m.valor);

  double get totalDespesas =>
      items.where((m) => m.tipo == 'D').fold(0, (sum, m) => sum + m.valor);

  double get saldoFinal => totalReceitas - totalDespesas;

  Future<void> loadContas() async {
    try {
      // Tenta cache primeiro
      final cached = cacheManager.get<List<ContaRef>>('/contas'.apiGetCacheKey());
      if (cached != null) {
        _contas = cached;
        notifyListeners();
        return;
      }

      _contas = await _repository.getContas();
      cacheManager.put('/contas'.apiGetCacheKey(), _contas, ttl: const Duration(minutes: 15));
      notifyListeners();
    } catch (_) {
      _contas = [];
    }
  }

  Future<void> loadMovimentos({String? tipo, int? contaId}) async {
    _contaFiltro = contaId;

    // Tenta cache primeiro
    final cacheKey = '/movimentos'.cacheKey('conta=${contaId ?? ""}&tipo=${tipo ?? ""}');
    final cached = cacheManager.get<List<MovimentoModel>>(cacheKey);
    if (cached != null) {
      setItems(cached);
      return;
    }

    setLoading();
    try {
      if (_contas.isEmpty) {
        _contas = await _repository.getContas();
      }
      _saldos = await _repository.getSaldosPorConta();
      final movimentos = await _repository.getMovimentos(contaId: contaId, tipo: tipo);
      cacheManager.put(cacheKey, movimentos, ttl: const Duration(minutes: 10));
      setItems(movimentos);
    } catch (e) {
      setError('Erro ao carregar movimentos: $e');
    }
  }

  void aplicarFiltroConta(int? contaId) {
    loadMovimentos(contaId: contaId);
  }

  Future<bool> createMovimento(MovimentoModel mov) async {
    setLoading();
    try {
      final novo = await _repository.createMovimento(mov);
      if (novo != null) {
        items.add(novo);
        setSuccess();
        cacheManager.removePattern('/movimentos');
        return true;
      }
      return false;
    } catch (e) {
      setError('Erro: $e');
      // Enfileira para processamento offline
      await _offlineQueue.enqueue(
        OfflineRequestMethod.post,
        '/api/movimentos',
        body: mov.toJson(),
        priority: 2,
      );
      return false;
    }
  }

  Future<bool> updateMovimento(MovimentoModel mov) async {
    setLoading();
    try {
      if (await _repository.updateMovimento(mov)) {
        final index = items.indexWhere((m) => m.id == mov.id);
        if (index != -1) items[index] = mov;
        setSuccess();
        cacheManager.removePattern('/movimentos');
        return true;
      }
      return false;
    } catch (e) {
      setError('Erro: $e');
      // Enfileira para processamento offline
      await _offlineQueue.enqueue(
        OfflineRequestMethod.put,
        '/api/movimentos/${mov.id}',
        body: mov.toJson(),
        priority: 2,
      );
      return false;
    }
  }

  Future<bool> deleteMovimento(int id) async {
    setLoading();
    try {
      if (await _repository.deleteMovimento(id)) {
        items.removeWhere((m) => m.id == id);
        setSuccess();
        cacheManager.removePattern('/movimentos');
        return true;
      }
      return false;
    } catch (e) {
      setError('Erro: $e');
      // Enfileira para processamento offline
      await _offlineQueue.enqueue(
        OfflineRequestMethod.delete,
        '/api/movimentos/$id',
        priority: 2,
      );
      return false;
    }
  }
}
