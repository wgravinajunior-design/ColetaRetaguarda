import '../models/parada_model.dart';
import '../repositories/parada_repository.dart';
import '../../core/viewmodels/base_viewmodel.dart';
import '../../core/services/location_service.dart';

class ColetaViewModel extends BaseViewModel<ParadaModel> {
  final ParadaRepository _repository = ParadaRepository();
  final LocationService _locationService = LocationService();
  int? _currentRotaId;
  ParadaModel? _selectedParada;

  ParadaModel? get selectedParada => _selectedParada;
  int? get currentRotaId => _currentRotaId;

  bool _capturandoGps = false;
  String? _gpsError;
  bool get capturandoGps => _capturandoGps;
  String? get gpsError => _gpsError;

  Future<void> loadParadasFromRota(int rotaId) async {
    _currentRotaId = rotaId;
    setLoading();
    try {
      final paradas = await _repository.getParadasByRota(rotaId);
      setItems(paradas);
    } catch (e) {
      setError('Erro ao carregar paradas: $e');
    }
  }

  // Filtro de status para a lista geral de coletas (null = todos).
  String? _filtroStatus;
  String? get filtroStatus => _filtroStatus;

  /// Carrega todas as coletas de todas as rotas, aplicando o filtro de status.
  Future<void> loadTodasColetas({String? status}) async {
    _filtroStatus = status;
    setLoading();
    try {
      final coletas = await _repository.getTodasColetas(status: status);
      setItems(coletas);
    } catch (e) {
      setError('Erro ao carregar coletas: $e');
    }
  }

  void aplicarFiltroStatus(String? status) {
    loadTodasColetas(status: status);
  }

  /// Reordena as paradas na tela e persiste ORDEM_VISITA no banco.
  Future<bool> reordenarParadas(List<ParadaModel> novaOrdem) async {
    setItems(List.from(novaOrdem));
    try {
      await _repository.reordenarParadas(novaOrdem.map((p) => p.id!).toList());
      return true;
    } catch (e) {
      setError('Erro ao salvar ordem: $e');
      return false;
    }
  }

  void selectParada(ParadaModel parada) {
    _selectedParada = parada;
    notifyListeners();
  }

  /// Inicia a coleta de uma parada: captura o GPS do dispositivo, registra o
  /// horário de chegada e muda o status para "Em Andamento" (E).
  /// Retorna true se o GPS foi capturado e gravado com sucesso.
  Future<bool> iniciarColeta(ParadaModel parada) async {
    // Se já foi iniciada/concluída, não repete a captura.
    if (parada.status != 'P') {
      _selectedParada = parada;
      notifyListeners();
      return true;
    }

    _capturandoGps = true;
    _gpsError = null;
    notifyListeners();

    try {
      // 1) Captura a localização atual
      final resultado = await _locationService.capturarPosicao();
      if (!resultado.success) {
        _gpsError = resultado.error;
        _capturandoGps = false;
        notifyListeners();
        return false;
      }

      final pos = resultado.position!;
      final horarioChegada = DateTime.now().toIso8601String();

      // 2) Grava o GPS + horário de chegada
      await _repository.registrarGPS(
        parada.id!,
        pos.latitude,
        pos.longitude,
        horarioChegada: horarioChegada,
      );

      // 3) Muda status para "Em Andamento"
      await _repository.atualizarStatusParada(
        paradaId: parada.id!,
        novoStatus: 'E',
      );

      final updated = parada.copyWith(
        status: 'E',
        gpsCapturaLatitude: pos.latitude,
        gpsCapturaltitude: pos.longitude,
        horarioChegada: horarioChegada,
      );
      _selectedParada = updated;

      // Atualiza na lista
      final index = items.indexWhere((p) => p.id == parada.id);
      if (index >= 0) {
        items[index] = updated;
        setItems(List.from(items));
      }

      _capturandoGps = false;
      notifyListeners();
      return true;
    } catch (e) {
      _gpsError = 'Erro ao iniciar coleta: $e';
      _capturandoGps = false;
      setError('Erro ao iniciar coleta: $e');
      return false;
    }
  }

  Future<bool> finalizarColetaComSucesso({
    required ParadaModel parada,
    required double temperatura,
    required double volume,
    String? assinaturaBase64,
    String? fotoPath,
  }) async {
    try {
      await _repository.atualizarStatusParada(
        paradaId: parada.id!,
        novoStatus: 'C',
        temperatura: temperatura,
        volume: volume,
        assinaturaBase64: assinaturaBase64,
        fotoPath: fotoPath,
      );
      final updated = parada.copyWith(
        status: 'C',
        temperatura: temperatura,
        volume: volume,
        assinaturaBase64: assinaturaBase64,
        fotoPath: fotoPath,
      );
      _selectedParada = updated;

      // Atualizar na lista
      final index = items.indexWhere((p) => p.id == parada.id);
      if (index >= 0) {
        items[index] = updated;
        setItems(List.from(items));
      }

      notifyListeners();
      return true;
    } catch (e) {
      setError('Erro ao finalizar coleta: $e');
      return false;
    }
  }

  Future<bool> recusarColeta({
    required ParadaModel parada,
    required String justificativa,
  }) async {
    try {
      await _repository.atualizarStatusParada(
        paradaId: parada.id!,
        novoStatus: 'R',
        justificativa: justificativa,
      );
      final updated = parada.copyWith(
        status: 'R',
        justificativa: justificativa,
      );
      _selectedParada = updated;

      final index = items.indexWhere((p) => p.id == parada.id);
      if (index >= 0) {
        items[index] = updated;
        setItems(List.from(items));
      }

      notifyListeners();
      return true;
    } catch (e) {
      setError('Erro ao recusar coleta: $e');
      return false;
    }
  }

  Future<bool> registrarGPS(ParadaModel parada, double latitude, double longitude) async {
    try {
      await _repository.registrarGPS(parada.id!, latitude, longitude);
      final updated = parada.copyWith(
        gpsCapturaLatitude: latitude,
        gpsCapturaltitude: longitude,
      );
      _selectedParada = updated;
      notifyListeners();
      return true;
    } catch (e) {
      setError('Erro ao registrar GPS: $e');
      return false;
    }
  }

  int get totalParadas => items.length;
  int get paradasPendentes => items.where((p) => p.status == 'P').length;
  int get paradasEmAndamento => items.where((p) => p.status == 'E').length;
  int get paradasConcluidas => items.where((p) => p.status == 'C').length;
  int get paradasRecusadas => items.where((p) => p.status == 'R').length;

  double get percentualConclusao {
    if (totalParadas == 0) return 0;
    return (paradasConcluidas / totalParadas) * 100;
  }
}
