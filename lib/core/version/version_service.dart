import 'package:package_info_plus/package_info_plus.dart';
import 'package:flutter/foundation.dart';
import '../logging/app_logger.dart';

/// Versão do app
class AppVersion {
  final String version;
  final String buildNumber;
  final DateTime checkTime;
  final bool needsUpdate;
  final String? updateUrl;

  AppVersion({
    required this.version,
    required this.buildNumber,
    required this.checkTime,
    this.needsUpdate = false,
    this.updateUrl,
  });

  String get fullVersion => '$version+$buildNumber';

  @override
  String toString() => 'AppVersion(version: $version, build: $buildNumber, needsUpdate: $needsUpdate)';
}

/// Serviço para gerenciar versões do app
class VersionService extends ChangeNotifier {
  static final VersionService _instance = VersionService._internal();

  factory VersionService() => _instance;

  VersionService._internal();

  final AppLogger _logger = AppLogger();
  AppVersion? _currentVersion;
  AppVersion? _latestVersion;
  bool _checkedRecently = false;

  AppVersion? get currentVersion => _currentVersion;
  AppVersion? get latestVersion => _latestVersion;
  bool get needsUpdate => _latestVersion?.needsUpdate ?? false;
  bool get isChecking => _currentVersion == null && !_checkedRecently;

  /// Inicializa o serviço com a versão atual
  Future<void> init() async {
    try {
      final info = await PackageInfo.fromPlatform();
      _currentVersion = AppVersion(
        version: info.version,
        buildNumber: info.buildNumber,
        checkTime: DateTime.now(),
      );
      _logger.info('VersionService', 'Initialized: ${_currentVersion?.fullVersion}');
    } catch (e) {
      _logger.error('VersionService', 'Failed to initialize: $e');
    }
  }

  /// Verifica se há uma versão mais nova disponível
  Future<bool> checkForUpdate({String? remoteVersionUrl}) async {
    if (_currentVersion == null) await init();
    if (_checkedRecently) return needsUpdate;

    try {
      _logger.info('VersionService', 'Checking for updates...');

      // Simula busca de versão remota
      // Em produção, isso buscaria de um backend, Firebase, ou Play Store
      final latestVersionNumber = _simulateRemoteVersionCheck();

      _latestVersion = AppVersion(
        version: latestVersionNumber,
        buildNumber: '999',
        checkTime: DateTime.now(),
        needsUpdate: _compareVersions(latestVersionNumber, _currentVersion!.version),
        updateUrl: 'https://play.google.com/store/apps/details?id=com.example.app',
      );

      _checkedRecently = true;
      _logger.info(
        'VersionService',
        'Update check complete: needsUpdate=${_latestVersion!.needsUpdate}',
      );

      notifyListeners();
      return _latestVersion!.needsUpdate;
    } catch (e) {
      _logger.error('VersionService', 'Error checking for update: $e');
      return false;
    }
  }

  /// Compara duas versões (ex: 1.17.0 vs 1.18.0)
  bool _compareVersions(String remoteVersion, String currentVersion) {
    try {
      final remoteParts = remoteVersion.split('.').map(int.parse).toList();
      final currentParts = currentVersion.split('.').map(int.parse).toList();

      // Compara major.minor.patch
      for (int i = 0; i < 3 && i < remoteParts.length && i < currentParts.length; i++) {
        if (remoteParts[i] > currentParts[i]) return true;
        if (remoteParts[i] < currentParts[i]) return false;
      }
      return false;
    } catch (e) {
      _logger.error('VersionService', 'Error comparing versions: $e');
      return false;
    }
  }

  /// Simula busca de versão remota
  String _simulateRemoteVersionCheck() {
    // Em produção, isso viria de uma API remota
    return '1.17.1'; // Simula pequena atualização disponível
  }

  /// Reseta estado de checagem
  void resetCheckFlag() {
    _checkedRecently = false;
    notifyListeners();
  }

  /// Retorna informações de versão como string
  String getVersionInfo() {
    if (_currentVersion == null) return 'Version unknown';
    return 'v${_currentVersion!.fullVersion}';
  }

  /// Retorna informações detalhadas
  Map<String, dynamic> getVersionDetails() {
    return {
      'current': _currentVersion?.fullVersion ?? 'unknown',
      'latest': _latestVersion?.fullVersion ?? 'unknown',
      'needsUpdate': needsUpdate,
      'lastCheck': _latestVersion?.checkTime ?? 'never',
      'updateUrl': _latestVersion?.updateUrl,
    };
  }
}
