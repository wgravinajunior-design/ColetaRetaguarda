import 'package:geolocator/geolocator.dart';

/// Resultado da captura de localização.
class LocationResult {
  final Position? position;
  final String? error;

  LocationResult({this.position, this.error});

  bool get success => position != null;
}

/// Serviço centralizado para captura de GPS com tratamento de permissões.
class LocationService {
  static final LocationService _instance = LocationService._internal();
  factory LocationService() => _instance;
  LocationService._internal();

  /// Verifica se o serviço de localização está habilitado e se há permissão.
  Future<bool> verificarPermissao() async {
    final servicoAtivo = await Geolocator.isLocationServiceEnabled();
    if (!servicoAtivo) return false;

    LocationPermission permission = await Geolocator.checkPermission();
    if (permission == LocationPermission.denied) {
      permission = await Geolocator.requestPermission();
    }
    return permission == LocationPermission.whileInUse ||
        permission == LocationPermission.always;
  }

  /// Captura a posição atual do dispositivo.
  /// Retorna [LocationResult] com a posição ou uma mensagem de erro.
  Future<LocationResult> capturarPosicao({
    Duration timeLimit = const Duration(seconds: 30),
  }) async {
    try {
      final servicoAtivo = await Geolocator.isLocationServiceEnabled();
      if (!servicoAtivo) {
        return LocationResult(error: 'GPS desativado. Ative a localização do dispositivo.');
      }

      final temPermissao = await verificarPermissao();
      if (!temPermissao) {
        return LocationResult(error: 'Permissão de localização negada.');
      }

      final position = await Geolocator.getCurrentPosition(
        desiredAccuracy: LocationAccuracy.high,
        timeLimit: timeLimit,
      );

      return LocationResult(position: position);
    } catch (e) {
      return LocationResult(error: 'Erro ao capturar GPS: $e');
    }
  }
}
