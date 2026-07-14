import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_retaguarda/features/core/database/daos/sync_queue_dao.dart';

void main() {
  group('SyncQueueItem', () {
    test('creates sync queue item with defaults', () {
      final item = SyncQueueItem(
        tabela: 'tb_pessoa',
        operacao: 'CREATE',
        dados: '{"nome":"João"}',
        dataCriacao: DateTime.now().toIso8601String(),
      );

      expect(item.tabela, 'tb_pessoa');
      expect(item.operacao, 'CREATE');
      expect(item.status, 'P'); // Pending
      expect(item.tentativas, 0);
    });

    test('sync queue item can be marked as success', () {
      var item = SyncQueueItem(
        tabela: 'tb_pessoa',
        operacao: 'CREATE',
        dados: '{"nome":"João"}',
        dataCriacao: DateTime.now().toIso8601String(),
        status: 'P',
      );

      expect(item.status, 'P');
      item.status = 'S'; // Simulate marking as success
      expect(item.status, 'S');
    });

    test('sync queue item tracks tentativas', () {
      var item = SyncQueueItem(
        tabela: 'tb_pessoa',
        operacao: 'CREATE',
        dados: '{"nome":"João"}',
        dataCriacao: DateTime.now().toIso8601String(),
        tentativas: 0,
      );

      expect(item.tentativas, 0);
      item.tentativas++;
      expect(item.tentativas, 1);
      item.tentativas++;
      expect(item.tentativas, 2);
    });

    test('sync queue item has all required fields', () {
      final item = SyncQueueItem(
        tabela: 'tb_motorista',
        operacao: 'UPDATE',
        registroId: 123,
        dados: '{"nome":"Maria"}',
        status: 'P',
        tentativas: 2,
        dataCriacao: DateTime.now().toIso8601String(),
        dataUltimoTentativa: DateTime.now().toIso8601String(),
      );

      expect(item.tabela, 'tb_motorista');
      expect(item.operacao, 'UPDATE');
      expect(item.registroId, 123);
      expect(item.tentativas, 2);
      expect(item.dataUltimoTentativa, isNotNull);
    });

    test('DELETE operation creates valid sync queue item', () {
      final item = SyncQueueItem(
        tabela: 'tb_veiculo',
        operacao: 'DELETE',
        registroId: 456,
        dados: '{"id":456}',
        dataCriacao: DateTime.now().toIso8601String(),
      );

      expect(item.operacao, 'DELETE');
      expect(item.registroId, 456);
    });

    test('sync queue item operations are case-sensitive', () {
      final item1 = SyncQueueItem(
        tabela: 'tb_pessoa',
        operacao: 'CREATE',
        dados: '{}',
        dataCriacao: DateTime.now().toIso8601String(),
      );

      final item2 = SyncQueueItem(
        tabela: 'tb_pessoa',
        operacao: 'create',
        dados: '{}',
        dataCriacao: DateTime.now().toIso8601String(),
      );

      expect(item1.operacao, 'CREATE');
      expect(item2.operacao, 'create');
      expect(item1.operacao != item2.operacao, true);
    });
  });
}
