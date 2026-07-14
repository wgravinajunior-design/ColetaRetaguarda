import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_retaguarda/core/state/state_manager.dart';
import 'package:flutter_retaguarda/core/state/app_state.dart';

void main() {
  group('StateManager', () {
    late StateManager manager;

    setUp(() {
      manager = StateManager();
      manager.resetAll();
    });

    tearDown(() {
      manager.resetAll();
    });

    test('é singleton', () {
      final manager1 = StateManager();
      final manager2 = StateManager();

      expect(identical(manager1, manager2), true);
    });

    test('obtém estado registrado', () {
      manager.setLoading('test');
      final state = manager.getState('test');

      expect(state?.isLoading, true);
    });

    test('obtém estado registrado com dado', () {
      manager.setSuccess('test', 'dados');
      final state = manager.getState('test');

      expect(state?.isSuccess, true);
      expect(state?.data, 'dados');
    });

    test('define estado loading', () {
      manager.setLoading('test', message: 'Aguarde...');
      final state = manager.getState('test');

      expect(state?.isLoading, true);
      expect(state?.message, 'Aguarde...');
    });

    test('define estado success', () {
      manager.setSuccess('test', 42);
      final state = manager.getState('test');

      expect(state?.isSuccess, true);
      expect(state?.data, 42);
    });

    test('define estado error', () {
      manager.setError('test', 'Falha');
      final state = manager.getState('test');

      expect(state?.isError, true);
      expect(state?.error, 'Falha');
    });

    test('define estado empty', () {
      manager.setEmpty('test');
      final state = manager.getState('test');

      expect(state?.isEmpty, true);
    });

    test('define estado idle', () {
      manager.setIdle('test');
      final state = manager.getState('test');

      expect(state?.isIdle, true);
    });

    test('reseta estado individual', () {
      manager.setLoading('test');
      manager.reset('test');

      final state = manager.getState('test');
      expect(state, isNull);
    });

    test('reseta todos os estados', () {
      manager.setLoading('test1');
      manager.setLoading('test2');

      manager.resetAll();

      expect(manager.getState('test1'), isNull);
      expect(manager.getState('test2'), isNull);
    });

    test('executa operação assíncrona com sucesso', () async {
      final result = await manager.executeAsync(
        'test',
        () async => 42,
      );

      expect(result, 42);
      expect(manager.getState('test')?.isSuccess, true);
    });

    test('executa operação assíncrona com erro', () async {
      try {
        await manager.executeAsync(
          'test',
          () async => throw Exception('Erro'),
        );
      } catch (e) {
        // Esperado
      }

      expect(manager.getState('test')?.isError, true);
    });

    test('obtém múltiplos estados', () {
      manager.setLoading('op1');
      manager.setSuccess('op2', 'ok');

      final states = manager.getStates(['op1', 'op2']);

      expect(states.length, 2);
      expect(states['op1']?.isLoading, true);
      expect(states['op2']?.isSuccess, true);
    });

    test('verifica se alguma operação está carregando', () {
      manager.setLoading('op1');
      manager.setSuccess('op2', 'ok');

      expect(manager.anyLoading(['op1', 'op2']), true);
      expect(manager.anyLoading(['op2']), false);
    });

    test('verifica se alguma operação tem erro', () {
      manager.setError('op1', 'Erro');
      manager.setSuccess('op2', 'ok');

      expect(manager.anyError(['op1', 'op2']), true);
      expect(manager.anyError(['op2']), false);
    });

    test('obtém todos os erros', () {
      manager.setError('op1', 'Erro 1');
      manager.setError('op2', 'Erro 2');
      manager.setSuccess('op3', 'ok');

      final errors = manager.getErrors(['op1', 'op2', 'op3']);

      expect(errors.length, 2);
      expect(errors['op1'], 'Erro 1');
      expect(errors['op2'], 'Erro 2');
    });

    test('retorna estatísticas dos estados', () {
      manager.setLoading('op1');
      manager.setSuccess('op2', 'ok');
      manager.setError('op3', 'Erro');
      manager.setEmpty('op4');

      final stats = manager.getStats();

      expect(stats['total'], 4);
      expect(stats['loading'], 1);
      expect(stats['success'], 1);
      expect(stats['error'], 1);
      expect(stats['empty'], 1);
    });

    test('notifica listeners ao mudar estado', () {
      bool notified = false;
      manager.addListener(() {
        notified = true;
      });

      manager.setLoading('test');

      expect(notified, true);
    });

    test('customiza mensagem de erro em executeAsync', () async {
      try {
        await manager.executeAsync(
          'test',
          () async => throw Exception('Original'),
          errorMapper: (e) => 'Erro customizado',
        );
      } catch (e) {
        // Esperado
      }

      expect(manager.getState('test')?.error, 'Erro customizado');
    });
  });
}
