import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_retaguarda/core/cache/cache_manager.dart';

void main() {
  group('CacheManager', () {
    late CacheManager cache;

    setUp(() {
      cache = CacheManager();
      cache.clear();
      cache.setEnabled(true);
    });

    tearDown(() {
      cache.dispose();
    });

    test('é singleton', () {
      final cache1 = CacheManager();
      final cache2 = CacheManager();

      expect(identical(cache1, cache2), true);
    });

    test('armazena e recupera valor', () {
      cache.put('key', 'value');

      final result = cache.get<String>('key');
      expect(result, 'value');
    });

    test('retorna null para chave não encontrada', () {
      final result = cache.get<String>('nonexistent');
      expect(result, isNull);
    });

    test('expira itens após TTL', () async {
      cache.put('key', 'value', ttl: const Duration(milliseconds: 100));

      // Imediatamente deve estar disponível
      expect(cache.get<String>('key'), 'value');

      // Aguarda expiração
      await Future.delayed(const Duration(milliseconds: 150));

      // Deve ter expirado
      expect(cache.get<String>('key'), isNull);
    });

    test('remove itens do cache', () {
      cache.put('key', 'value');
      expect(cache.get<String>('key'), 'value');

      cache.remove('key');
      expect(cache.get<String>('key'), isNull);
    });

    test('remove itens por padrão', () {
      cache.put('user:1', 'data1');
      cache.put('user:2', 'data2');
      cache.put('post:1', 'data3');

      cache.removePattern('user:');

      expect(cache.get<String>('user:1'), isNull);
      expect(cache.get<String>('user:2'), isNull);
      expect(cache.get<String>('post:1'), 'data3');
    });

    test('limpa todo o cache', () {
      cache.put('key1', 'value1');
      cache.put('key2', 'value2');

      cache.clear();

      expect(cache.get<String>('key1'), isNull);
      expect(cache.get<String>('key2'), isNull);
    });

    test('respeita configuração de habilitação', () {
      cache.put('key', 'value');
      expect(cache.get<String>('key'), 'value');

      cache.setEnabled(false);
      expect(cache.get<String>('key'), isNull);

      cache.put('key2', 'value2');
      expect(cache.get<String>('key2'), isNull);
    });

    test('usa TTL padrão de 5 minutos', () {
      cache.put('key', 'value');
      // Item deve estar disponível imediatamente
      expect(cache.get<String>('key'), 'value');
    });

    test('gera estatísticas', () {
      cache.put('key1', 'value1');
      cache.put('key2', 'value2', ttl: const Duration(milliseconds: 100));

      final stats = cache.getStats();

      expect(stats, contains('Total items: 2'));
      expect(stats, contains('Valid items'));
    });

    test('armazena diferentes tipos de dados', () {
      cache.put('string', 'value');
      cache.put('number', 42);
      cache.put('list', [1, 2, 3]);
      cache.put('map', {'key': 'value'});

      expect(cache.get<String>('string'), 'value');
      expect(cache.get<int>('number'), 42);
      expect(cache.get<List<int>>('list'), [1, 2, 3]);
      expect(cache.get<Map<String, String>>('map'), {'key': 'value'});
    });

    test('respeita TTL customizado', () async {
      cache.put('key', 'value', ttl: const Duration(milliseconds: 200));

      expect(cache.get<String>('key'), 'value');

      await Future.delayed(const Duration(milliseconds: 250));
      expect(cache.get<String>('key'), isNull);
    });
  });

  group('CacheItem', () {
    test('detecta expiração', () async {
      final item = CacheItem(
        data: 'value',
        ttl: const Duration(milliseconds: 100),
      );

      expect(item.isExpired, false);

      await Future.delayed(const Duration(milliseconds: 150));
      expect(item.isExpired, true);
    });

    test('formata toString com informações', () {
      final item = CacheItem(data: 'value', ttl: const Duration(minutes: 5));

      final str = item.toString();
      expect(str, contains('age:'));
      expect(str, contains('ttl:'));
      expect(str, contains('expired:'));
    });
  });

  group('CacheKeyExtension', () {
    test('gera chave com prefixo', () {
      expect('data'.cacheKey('prefix'), 'prefix:data');
    });

    test('gera chave para cache de API GET', () {
      expect('/users/123'.apiGetCacheKey(), 'api:get:/users/123');
    });

    test('gera chave para cache de lista', () {
      expect('users'.listCacheKey(), 'list:users');
    });

    test('gera chave para cache de detalhe', () {
      expect('user:123'.detailsCacheKey(), 'detail:user:123');
    });
  });
}
