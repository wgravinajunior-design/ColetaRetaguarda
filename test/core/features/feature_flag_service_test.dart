import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_retaguarda/core/features/feature_flag_service.dart';

void main() {
  group('FeatureFlag', () {
    test('cria flag habilitada', () {
      final flag = FeatureFlag(key: 'test', enabled: true);

      expect(flag.key, 'test');
      expect(flag.enabled, true);
      expect(flag.isAvailable, true);
    });

    test('cria flag desabilitada', () {
      final flag = FeatureFlag(key: 'test', enabled: false);

      expect(flag.enabled, false);
      expect(flag.isAvailable, false);
    });

    test('respeita rollout percentual', () {
      final flag50 = FeatureFlag(
        key: 'test',
        enabled: true,
        rolloutPercentage: 50,
      );
      final flag25 = FeatureFlag(
        key: 'test',
        enabled: true,
        rolloutPercentage: 25,
      );

      expect(flag50.isAvailable, true);
      expect(flag25.isAvailable, false);
    });

    test('stores description and config', () {
      final flag = FeatureFlag(
        key: 'test',
        enabled: true,
        description: 'Test feature',
        config: {'timeout': 5000},
      );

      expect(flag.description, 'Test feature');
      expect(flag.config!['timeout'], 5000);
    });

    test('armazena timestamp', () {
      final flag = FeatureFlag(key: 'test', enabled: true);

      expect(flag.lastUpdated, isA<DateTime>());
    });
  });

  group('FeatureFlagService', () {
    late FeatureFlagService service;

    setUp(() {
      service = FeatureFlagService();
      service.clear();
      service.setRemoteConfigEnabled(true); // Restaura estado padrão
    });

    test('é singleton', () {
      final service1 = FeatureFlagService();
      final service2 = FeatureFlagService();

      expect(identical(service1, service2), true);
    });

    test('inicializa com flags padrão', () {
      final defaults = {
        'feature1': FeatureFlag(key: 'feature1', enabled: true),
        'feature2': FeatureFlag(key: 'feature2', enabled: false),
      };

      service.initializeDefaults(defaults);

      expect(service.isEnabled('feature1'), true);
      expect(service.isEnabled('feature2'), false);
    });

    test('registra nova flag', () {
      service.registerFlag('test_feature', enabled: true, description: 'Test');

      expect(service.isEnabled('test_feature'), true);
    });

    test('retorna false para flag desconhecida', () {
      expect(service.isEnabled('unknown'), false);
    });

    test('obtém flag completa', () {
      service.registerFlag('test', enabled: true);

      final flag = service.getFlag('test');

      expect(flag, isNotNull);
      expect(flag!.key, 'test');
    });

    test('sincroniza flags remotas', () async {
      final remoteFlags = {
        'new_feature': FeatureFlag(key: 'new_feature', enabled: true),
      };

      await service.syncRemoteFlags(remoteFlags);

      expect(service.isEnabled('new_feature'), true);
    });

    test('simula sincronização remota', () async {
      await service.simulateRemoteSync();

      expect(service.getFlag('analytics_v2'), isNotNull);
      expect(service.isEnabled('dark_mode'), true);
    });

    test('restaura flags padrão após erro', () async {
      final defaults = {
        'default_feature': FeatureFlag(key: 'default_feature', enabled: true),
      };
      service.initializeDefaults(defaults);

      // Limpa e restaura
      service.setRemoteConfigEnabled(false);

      expect(service.isEnabled('default_feature'), true);
    });

    test('desabilita config remota', () async {
      service.registerFlag('feature', enabled: true);
      service.setRemoteConfigEnabled(false);

      expect(service.isRemoteConfigEnabled, false);
    });

    test('retorna todas as flags', () {
      service.registerFlag('feature1', enabled: true);
      service.registerFlag('feature2', enabled: false);

      final flags = service.getAllFlags();

      expect(flags.length, 2);
      expect(flags.containsKey('feature1'), true);
    });

    test('retorna flags habilitadas', () {
      service.registerFlag('enabled1', enabled: true);
      service.registerFlag('enabled2', enabled: true);
      service.registerFlag('disabled', enabled: false);

      final enabled = service.getEnabledFlags();

      expect(enabled.length, 2);
      expect(enabled.contains('disabled'), false);
    });

    test('retorna flags desabilitadas', () {
      service.registerFlag('enabled', enabled: true);
      service.registerFlag('disabled1', enabled: false);
      service.registerFlag('disabled2', enabled: false);

      final disabled = service.getDisabledFlags();

      expect(disabled.length, 2);
      expect(disabled.contains('enabled'), false);
    });

    test('retorna config de flag', () {
      service.registerFlag('test', enabled: true);
      final flag = service.getFlag('test');
      if (flag != null) {
        // Flag não tem config, retorna null
        expect(service.getConfig('test'), isNull);
      }
    });

    test('retorna debug info', () {
      service.registerFlag('feature', enabled: true);

      final info = service.getDebugInfo();

      expect(info.containsKey('remoteConfigEnabled'), true);
      expect(info.containsKey('totalFlags'), true);
      expect(info.containsKey('enabledFlags'), true);
    });

    test('notifica listeners ao sincronizar', () async {
      service.clear(); // Limpa antes de adicionar listener
      bool notified = false;
      service.addListener(() => notified = true);

      final remoteFlags = {
        'test': FeatureFlag(key: 'test', enabled: true),
      };
      await service.syncRemoteFlags(remoteFlags);

      expect(notified, true);
    });

    test('limpa todas as flags', () {
      service.registerFlag('feature', enabled: true);
      service.clear();

      expect(service.getAllFlags().length, 0);
    });

    test('armazena tempo de sincronização', () async {
      service.clear();
      expect(service.lastSyncTime, isNull);

      final remoteFlags = {
        'test': FeatureFlag(key: 'test', enabled: true),
      };
      await service.syncRemoteFlags(remoteFlags);

      expect(service.lastSyncTime, isNotNull);
    });
  });
}
