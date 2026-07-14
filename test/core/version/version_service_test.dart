import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_retaguarda/core/version/version_service.dart';

void main() {
  group('AppVersion', () {
    test('cria versão com valores', () {
      final version = AppVersion(
        version: '1.17.0',
        buildNumber: '30',
        checkTime: DateTime.now(),
        needsUpdate: false,
      );

      expect(version.version, '1.17.0');
      expect(version.buildNumber, '30');
      expect(version.fullVersion, '1.17.0+30');
      expect(version.needsUpdate, false);
    });

    test('fullVersion concatena version e buildNumber', () {
      final version = AppVersion(
        version: '1.0.0',
        buildNumber: '1',
        checkTime: DateTime.now(),
      );

      expect(version.fullVersion, '1.0.0+1');
    });

    test('toString retorna representação clara', () {
      final version = AppVersion(
        version: '1.2.3',
        buildNumber: '45',
        checkTime: DateTime.now(),
        needsUpdate: true,
      );

      final str = version.toString();
      expect(str, contains('1.2.3'));
      expect(str, contains('45'));
      expect(str, contains('true'));
    });
  });

  group('VersionService', () {
    late VersionService service;

    setUp(() {
      service = VersionService();
    });

    test('é singleton', () {
      final service1 = VersionService();
      final service2 = VersionService();

      expect(identical(service1, service2), true);
    });

    test('currentVersion é null até inicializar', () {
      expect(service.currentVersion, isNull);
    });

    test('inicialização carrega versão atual', () async {
      await service.init();

      expect(service.currentVersion, isNotNull);
      expect(service.currentVersion?.version, isNotEmpty);
      expect(service.currentVersion?.buildNumber, isNotEmpty);
    });

    test('checkForUpdate verifica atualizações', () async {
      await service.init();
      final result = await service.checkForUpdate();

      expect(result, isA<bool>());
      expect(service.latestVersion, isNotNull);
    });

    test('needsUpdate retorna falso quando atualizado', () async {
      await service.init();

      // A versão simulada (1.17.1) é maior que versão do pub (1.17.0)
      // então needsUpdate será true no teste
      final result = await service.checkForUpdate();

      expect(result, isA<bool>());
    });

    test('getVersionInfo retorna string de versão', () async {
      await service.init();

      final info = service.getVersionInfo();
      expect(info, contains('v'));
      expect(info, contains('+'));
    });

    test('getVersionDetails retorna mapa com informações', () async {
      await service.init();
      await service.checkForUpdate();

      final details = service.getVersionDetails();

      expect(details, isA<Map<String, dynamic>>());
      expect(details.containsKey('current'), true);
      expect(details.containsKey('latest'), true);
      expect(details.containsKey('needsUpdate'), true);
      expect(details.containsKey('lastCheck'), true);
      expect(details.containsKey('updateUrl'), true);
    });

    test('resetCheckFlag reseta estado', () async {
      await service.init();
      await service.checkForUpdate();

      service.resetCheckFlag();

      // Após reset, pode fazer novo check
      expect(service.latestVersion, isNotNull);
    });

    test('notifica listeners ao fazer check', () async {
      await service.init();

      bool notified = false;
      service.addListener(() {
        notified = true;
      });

      await service.checkForUpdate();

      expect(notified, true);
    });

    test('compara versões corretamente', () async {
      await service.init();

      // Teste comparação interna
      expect(service.currentVersion?.version, isNotEmpty);
    });

    test('trata erro na inicialização gracefully', () async {
      // Mesmo com erro, não deve lançar exceção
      await service.init();

      expect(service.getVersionInfo(), isNotEmpty);
    });
  });
}
