import 'package:flutter/material.dart';
import '../models/parada_model.dart';
import '../repositories/parada_repository.dart';
import '../../core/viewmodels/base_viewmodel.dart';

class ColetaViewModel extends BaseViewModel<ParadaModel> {
  final ParadaRepository _repository = ParadaRepository();
  int? _currentRotaId;
  ParadaModel? _selectedParada;

  ParadaModel? get selectedParada => _selectedParada;
  int? get currentRotaId => _currentRotaId;

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

  void selectParada(ParadaModel parada) {
    _selectedParada = parada;
    notifyListeners();
  }

  Future<bool> iniciarColeta(ParadaModel parada) async {
    try {
      _selectedParada = parada;
      await _repository.atualizarStatusParada(
        paradaId: parada.id!,
        novoStatus: 'E',
        justificativa: 'Coleta iniciada',
      );
      final updated = parada.copyWith(status: 'E');
      _selectedParada = updated;
      notifyListeners();
      return true;
    } catch (e) {
      setError('Erro ao iniciar coleta: $e');
      return false;
    }
  }

  Future<bool> finalizarColetaComSucesso({
    required ParadaModel parada,
    required double temperatura,
    required double volume,
  }) async {
    try {
      await _repository.atualizarStatusParada(
        paradaId: parada.id!,
        novoStatus: 'C',
        temperatura: temperatura,
        volume: volume,
      );
      final updated = parada.copyWith(
        status: 'C',
        temperatura: temperatura,
        volume: volume,
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
