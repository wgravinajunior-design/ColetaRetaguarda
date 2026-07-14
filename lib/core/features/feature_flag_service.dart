import 'package:flutter/foundation.dart';
import '../logging/app_logger.dart';

/// Feature flag com metadados
class FeatureFlag {
  final String key;
  final bool enabled;
  final DateTime lastUpdated;
  final String? description;
  final double? rolloutPercentage; // 0-100
  final Map<String, dynamic>? config;

  FeatureFlag({
    required this.key,
    required this.enabled,
    this.description,
    this.rolloutPercentage,
    this.config,
    DateTime? lastUpdated,
  }) : lastUpdated = lastUpdated ?? DateTime.now();

  /// Verifica se feature está habilitada (incluindo rollout)
  bool get isAvailable {
    if (!enabled) return false;
    if (rolloutPercentage == null) return true;
    // Simula rollout percentual
    return rolloutPercentage! >= 50;
  }

  @override
  String toString() =>
      'FeatureFlag($key: enabled=$enabled, rollout=$rolloutPercentage%)';
}

/// Serviço para gerenciar feature flags
class FeatureFlagService extends ChangeNotifier {
  static final FeatureFlagService _instance = FeatureFlagService._internal();

  factory FeatureFlagService() => _instance;

  FeatureFlagService._internal();

  final AppLogger _logger = AppLogger();
  final Map<String, FeatureFlag> _flags = {};
  final Map<String, FeatureFlag> _defaultFlags = {}; // Fallback local
  bool _useRemoteConfig = true;
  DateTime? _lastSyncTime;

  DateTime? get lastSyncTime => _lastSyncTime;
  bool get isRemoteConfigEnabled => _useRemoteConfig;

  /// Inicializa com flags padrão (fallback)
  void initializeDefaults(Map<String, FeatureFlag> defaults) {
    _defaultFlags.addAll(defaults);
    _flags.addAll(defaults);
    _logger.info(
      'FeatureFlagService',
      'Initialized with ${defaults.length} default flags',
    );
  }

  /// Registra uma flag com valor padrão
  void registerFlag(String key, {bool enabled = false, String? description}) {
    _flags[key] = FeatureFlag(
      key: key,
      enabled: enabled,
      description: description,
    );
    _logger.debug('FeatureFlagService', 'Flag registered: $key');
  }

  /// Verifica se feature está habilitada
  bool isEnabled(String key) {
    final flag = _flags[key];
    if (flag == null) {
      _logger.warning('FeatureFlagService', 'Flag not found: $key');
      return false;
    }
    return flag.isAvailable;
  }

  /// Obtém flag completa
  FeatureFlag? getFlag(String key) => _flags[key];

  /// Atualiza flags remotas
  Future<void> syncRemoteFlags(Map<String, FeatureFlag> remoteFlags) async {
    if (!_useRemoteConfig) return;

    try {
      _flags.clear();
      _flags.addAll(remoteFlags);
      _lastSyncTime = DateTime.now();
      _logger.info('FeatureFlagService', 'Synced ${remoteFlags.length} remote flags');
      notifyListeners();
    } catch (e) {
      _logger.error('FeatureFlagService', 'Error syncing remote flags: $e');
      // Fallback para flags padrão
      _restoreDefaults();
    }
  }

  /// Simula sincronização remota
  Future<void> simulateRemoteSync() async {
    // Simula busca de flags remotas
    final remoteFlags = {
      'analytics_v2': FeatureFlag(
        key: 'analytics_v2',
        enabled: true,
        description: 'Nova versão de analytics',
        rolloutPercentage: 100,
      ),
      'dark_mode': FeatureFlag(
        key: 'dark_mode',
        enabled: true,
        description: 'Suporte a tema escuro',
      ),
      'beta_features': FeatureFlag(
        key: 'beta_features',
        enabled: false,
        description: 'Recursos em beta',
        rolloutPercentage: 0,
      ),
    };

    await syncRemoteFlags(remoteFlags);
  }

  /// Restaura flags padrão (fallback)
  void _restoreDefaults() {
    _flags.clear();
    _flags.addAll(_defaultFlags);
    _logger.warning('FeatureFlagService', 'Restored default flags');
  }

  /// Desabilita sincronização remota
  void setRemoteConfigEnabled(bool enabled) {
    _useRemoteConfig = enabled;
    if (!enabled) {
      _restoreDefaults();
    }
    _logger.info('FeatureFlagService', 'Remote config: $_useRemoteConfig');
  }

  /// Retorna todas as flags
  Map<String, FeatureFlag> getAllFlags() {
    return Map.unmodifiable(_flags);
  }

  /// Retorna flags habilitadas
  List<String> getEnabledFlags() {
    return _flags.entries
        .where((e) => e.value.isAvailable)
        .map((e) => e.key)
        .toList();
  }

  /// Retorna flags desabilitadas
  List<String> getDisabledFlags() {
    return _flags.entries
        .where((e) => !e.value.isAvailable)
        .map((e) => e.key)
        .toList();
  }

  /// Retorna config de uma flag
  Map<String, dynamic>? getConfig(String key) {
    return _flags[key]?.config;
  }

  /// Retorna debug info
  Map<String, dynamic> getDebugInfo() {
    return {
      'remoteConfigEnabled': _useRemoteConfig,
      'lastSyncTime': _lastSyncTime?.toIso8601String() ?? 'never',
      'totalFlags': _flags.length,
      'enabledFlags': getEnabledFlags().length,
      'flags': _flags.keys.toList(),
    };
  }

  /// Limpa todas as flags
  void clear() {
    _flags.clear();
    _lastSyncTime = null;
    _logger.debug('FeatureFlagService', 'All flags cleared');
  }
}
