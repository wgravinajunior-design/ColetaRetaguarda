import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_retaguarda/core/routing/deep_link_service.dart';

void main() {
  group('DeepLink', () {
    test('cria deep link com path', () {
      final link = DeepLink(path: '/produtores');

      expect(link.path, '/produtores');
      expect(link.isValid, true);
    });

    test('cria deep link com query params', () {
      final link = DeepLink(
        path: '/produtores',
        queryParams: {'id': '123', 'name': 'João'},
      );

      expect(link.queryParams['id'], '123');
      expect(link.queryParams['name'], 'João');
    });

    test('cria deep link a partir de URI', () {
      final uri = Uri.parse('/produtores?id=123&status=ativo');
      final link = DeepLink.fromUri(uri);

      expect(link.path, '/produtores');
      expect(link.queryParams['id'], '123');
      expect(link.queryParams['status'], 'ativo');
    });

    test('detecta deep link inválido', () {
      final link = DeepLink(path: 'produtores'); // Sem /

      expect(link.isValid, false);
    });

    test('extrai ID do path', () {
      final link = DeepLink(path: '/produtores/123');

      expect(link.getIdFromPath(), '123');
    });

    test('extrai ID de path com múltiplos segmentos', () {
      final link = DeepLink(path: '/rotas/456/paradas/789');

      expect(link.getIdFromPath(), '789');
    });

    test('retorna null para path simples', () {
      final link = DeepLink(path: '/produtores');

      expect(link.getIdFromPath(), isNull);
    });

    test('armazena timestamp de criação', () {
      final link = DeepLink(path: '/produtores');

      expect(link.createdAt, isA<DateTime>());
    });
  });

  group('DeepLinkService', () {
    late DeepLinkService service;

    setUp(() {
      service = DeepLinkService();
      service.reset(); // Limpa handlers e histórico
    });

    test('é singleton', () {
      final service1 = DeepLinkService();
      final service2 = DeepLinkService();

      expect(identical(service1, service2), true);
    });

    test('registra handler para rota', () async {
      bool handlerCalled = false;
      service.registerHandler('/produtores', (_) async {
        handlerCalled = true;
        return true;
      });

      final link = DeepLink(path: '/produtores');
      await service.handle(link);

      expect(handlerCalled, true);
    });

    test('processa deep link válido', () async {
      service.registerHandler('/produtores', (_) async => true);

      final link = DeepLink(path: '/produtores');
      final result = await service.handle(link);

      expect(result, true);
      expect(service.currentDeepLink?.path, '/produtores');
    });

    test('rejeita deep link inválido', () async {
      final link = DeepLink(path: 'produtores');
      final result = await service.handle(link);

      expect(result, false);
    });

    test('processa URI string', () async {
      service.registerHandler('/motoristas', (_) async => true);

      final result = await service.handleUriString('/motoristas?id=456');

      expect(result, true);
    });

    test('registra múltiplos handlers', () {
      final handlers = {
        '/produtores': (_) async => true,
        '/motoristas': (_) async => true,
      };

      service.registerHandlers(handlers);

      expect(service.getRegisteredPatterns().length, 2);
    });

    test('coincide com padrão wildcard', () async {
      service.registerHandler('/produtores/*', (_) async => true);

      final link = DeepLink(path: '/produtores/123');
      final result = await service.handle(link);

      expect(result, true);
    });

    test('mantém histórico de deep links', () async {
      service.registerHandler('/produtores', (_) async => true);

      await service.handle(DeepLink(path: '/produtores'));
      await service.handle(DeepLink(path: '/produtores'));

      expect(service.history.length, 2);
    });

    test('filtra histórico por path', () async {
      service.registerHandler('/produtores', (_) async => true);
      service.registerHandler('/motoristas', (_) async => true);

      await service.handle(DeepLink(path: '/produtores'));
      await service.handle(DeepLink(path: '/motoristas'));
      await service.handle(DeepLink(path: '/produtores'));

      final produtoresHistory = service.getHistoryByPath('/produtores');
      expect(produtoresHistory.length, 2);
    });

    test('limpa histórico', () async {
      service.registerHandler('/produtores', (_) async => true);
      await service.handle(DeepLink(path: '/produtores'));

      service.clearHistory();

      expect(service.history.length, 0);
    });

    test('retorna padrões registrados', () {
      service.registerHandlers({
        '/produtores': (_) async => true,
        '/motoristas': (_) async => true,
        '/rotas': (_) async => true,
      });

      final patterns = service.getRegisteredPatterns();

      expect(patterns.length, 3);
      expect(patterns.contains('/produtores'), true);
    });

    test('cria URI com query params', () {
      final uri = service.createUri(
        '/produtores',
        queryParams: {'id': '123', 'status': 'ativo'},
      );

      expect(uri.path, '/produtores');
      expect(uri.queryParameters['id'], '123');
    });

    test('retorna debug info', () {
      service.registerHandler('/produtores', (_) async => true);

      final info = service.getDebugInfo();

      expect(info.containsKey('registeredPatterns'), true);
      expect(info.containsKey('historyCount'), true);
    });

    test('notifica listeners ao processar deep link', () async {
      bool notified = false;
      service.addListener(() => notified = true);

      service.registerHandler('/produtores', (_) async => true);
      await service.handle(DeepLink(path: '/produtores'));

      expect(notified, true);
    });

    test('trata erro gracefully', () async {
      service.registerHandler('/erro', (_) async {
        throw Exception('Handler error');
      });

      final result = await service.handle(DeepLink(path: '/erro'));

      expect(result, false);
    });

    test('preserva query params através do fluxo', () async {
      service.registerHandler('/produtores', (_) async => true);

      final link = DeepLink(
        path: '/produtores',
        queryParams: {'id': '123'},
      );
      await service.handle(link);

      expect(service.currentDeepLink?.queryParams['id'], '123');
    });
  });
}
