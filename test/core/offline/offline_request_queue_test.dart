import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_retaguarda/core/offline/offline_request_queue.dart';

void main() {
  group('OfflineRequest', () {
    test('cria requisição com valores padrão', () {
      final request = OfflineRequest(
        id: '1',
        method: OfflineRequestMethod.post,
        endpoint: '/api/users',
      );

      expect(request.id, '1');
      expect(request.method, OfflineRequestMethod.post);
      expect(request.endpoint, '/api/users');
      expect(request.priority, 5);
      expect(request.retryCount, 0);
      expect(request.isProcessing, false);
    });

    test('serializa para JSON', () {
      final request = OfflineRequest(
        id: '1',
        method: OfflineRequestMethod.post,
        endpoint: '/api/users',
        body: {'name': 'John'},
        priority: 3,
      );

      final json = request.toJson();

      expect(json['id'], '1');
      expect(json['method'], 'post');
      expect(json['endpoint'], '/api/users');
      expect(json['priority'], 3);
    });

    test('desserializa de JSON', () {
      final json = {
        'id': '1',
        'method': 'put',
        'endpoint': '/api/users/1',
        'body': '{"name":"Jane"}',
        'priority': 2,
        'createdAt': DateTime.now().toIso8601String(),
        'retryCount': 1,
        'isProcessing': 0,
      };

      final request = OfflineRequest.fromJson(json);

      expect(request.id, '1');
      expect(request.method, OfflineRequestMethod.put);
      expect(request.retryCount, 1);
    });

    test('copyWith cria nova instância', () {
      final original = OfflineRequest(
        id: '1',
        method: OfflineRequestMethod.post,
        endpoint: '/api/users',
        priority: 5,
      );

      final updated = original.copyWith(
        priority: 1,
        retryCount: 2,
      );

      expect(updated.id, original.id);
      expect(updated.priority, 1);
      expect(updated.retryCount, 2);
      expect(original.priority, 5);
    });
  });

  group('OfflineRequestQueue', () {
    late OfflineRequestQueue queue;

    setUp(() {
      queue = OfflineRequestQueue();
      queue.clear();
    });

    tearDown(() {
      queue.stopAutoSync();
      queue.clear();
    });

    test('é singleton', () {
      final queue1 = OfflineRequestQueue();
      final queue2 = OfflineRequestQueue();

      expect(identical(queue1, queue2), true);
    });

    test('adiciona requisição à fila', () async {
      await queue.enqueue(
        OfflineRequestMethod.post,
        '/api/users',
        body: {'name': 'John'},
      );

      expect(queue.pendingCount, 1);
      expect(queue.queue.first.endpoint, '/api/users');
    });

    test('ordena por prioridade', () async {
      queue.init(processCallback: (_) async => true);

      await queue.enqueue(OfflineRequestMethod.post, '/api/1', priority: 5);
      await queue.enqueue(OfflineRequestMethod.post, '/api/2', priority: 1);
      await queue.enqueue(OfflineRequestMethod.post, '/api/3', priority: 3);

      expect(queue.queue[0].priority, 1);
      expect(queue.queue[1].priority, 3);
      expect(queue.queue[2].priority, 5);
    });

    test('remove requisição por ID', () async {
      await queue.enqueue(OfflineRequestMethod.post, '/api/users');
      final id = queue.queue.first.id;

      await queue.remove(id);

      expect(queue.pendingCount, 0);
    });

    test('sincroniza requisições com sucesso', () async {
      int processedCount = 0;

      queue.init(
        processCallback: (_) async {
          processedCount++;
          return true;
        },
      );

      await queue.enqueue(OfflineRequestMethod.post, '/api/1');
      await queue.enqueue(OfflineRequestMethod.post, '/api/2');

      await queue.sync();

      expect(processedCount, 2);
      expect(queue.pendingCount, 0);
    });

    test('retenta requisições falhadas', () async {
      int attempts = 0;

      queue.init(
        processCallback: (_) async {
          attempts++;
          return attempts > 1; // Falha na primeira, passa na segunda
        },
      );

      await queue.enqueue(OfflineRequestMethod.post, '/api/test');
      await queue.sync();

      expect(queue.pendingCount, 1); // Ainda na fila para retry
      expect(queue.queue.first.retryCount, 1);
    });

    test('para retentativas após limite', () async {
      queue.init(
        processCallback: (_) async => false, // Sempre falha
        maxRetries: 2,
      );

      await queue.enqueue(OfflineRequestMethod.post, '/api/test');

      // Tenta 3 vezes (inicial + 2 retries)
      await queue.sync();
      await queue.sync();
      await queue.sync();

      expect(queue.queue.first.retryCount, 2);
    });

    test('track status de sincronização', () async {
      queue.init(processCallback: (_) async => true);

      expect(queue.syncing, false);

      await queue.enqueue(OfflineRequestMethod.post, '/api/test');
      await queue.sync();

      expect(queue.syncing, false); // Após sync
    });

    test('limita sincronização com fila vazia', () async {
      queue.init(processCallback: (_) async => true);

      // Sem itens, sync retorna imediatamente
      await queue.sync();

      expect(queue.pendingCount, 0);
    });

    test('filtra requisições falhadas', () async {
      queue.init(
        processCallback: (_) async => false,
        maxRetries: 1,
      );

      await queue.enqueue(OfflineRequestMethod.post, '/api/1');
      await queue.enqueue(OfflineRequestMethod.post, '/api/2');

      await queue.sync(); // Primeira tentativa: retryCount = 1
      await queue.sync(); // Segunda tentativa: retryCount = 2 (exceeds maxRetries=1)

      expect(queue.failedRequests.length, greaterThanOrEqualTo(1));
    });

    test('filtra requisições em retry', () async {
      int attempts = 0;

      queue.init(
        processCallback: (_) async {
          attempts++;
          return false;
        },
      );

      await queue.enqueue(OfflineRequestMethod.post, '/api/test');
      await queue.sync();

      expect(queue.retryingRequests.length, 1);
    });

    test('notifica listeners ao enqueue', () async {
      bool notified = false;
      queue.addListener(() {
        notified = true;
      });

      await queue.enqueue(OfflineRequestMethod.post, '/api/test');

      expect(notified, true);
    });

    test('limpa fila', () async {
      await queue.enqueue(OfflineRequestMethod.post, '/api/1');
      await queue.enqueue(OfflineRequestMethod.post, '/api/2');

      await queue.clear();

      expect(queue.pendingCount, 0);
    });

    test('auto-sync periódico', () async {
      int syncCount = 0;

      queue.init(
        processCallback: (_) async {
          syncCount++;
          return true;
        },
      );

      await queue.enqueue(OfflineRequestMethod.post, '/api/test');
      queue.startAutoSync(interval: const Duration(milliseconds: 50));

      await Future.delayed(const Duration(milliseconds: 100));
      queue.stopAutoSync();

      expect(syncCount, greaterThan(0));
    });
  });

  group('OfflineRequestMethod', () {
    test('contém métodos esperados', () {
      expect(OfflineRequestMethod.post, isNotNull);
      expect(OfflineRequestMethod.put, isNotNull);
      expect(OfflineRequestMethod.delete, isNotNull);
    });
  });
}
