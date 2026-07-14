import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_retaguarda/core/state/app_state.dart';

void main() {
  group('AppState', () {
    test('cria estado idle', () {
      final state = AppState<String>.idle();

      expect(state.status, AppStateStatus.idle);
      expect(state.isIdle, true);
      expect(state.data, isNull);
    });

    test('cria estado loading', () {
      final state = AppState<String>.loading(message: 'Carregando...');

      expect(state.status, AppStateStatus.loading);
      expect(state.isLoading, true);
      expect(state.message, 'Carregando...');
    });

    test('cria estado success', () {
      final state = AppState<String>.success('dados');

      expect(state.status, AppStateStatus.success);
      expect(state.isSuccess, true);
      expect(state.data, 'dados');
      expect(state.hasData, true);
    });

    test('cria estado error', () {
      final state = AppState<String>.error('Erro conectando');

      expect(state.status, AppStateStatus.error);
      expect(state.isError, true);
      expect(state.error, 'Erro conectando');
    });

    test('cria estado empty', () {
      final state = AppState<String>.empty();

      expect(state.status, AppStateStatus.empty);
      expect(state.isEmpty, true);
    });

    test('hasData retorna false sem dados', () {
      final state = AppState<String>.loading();

      expect(state.hasData, false);
    });

    test('map transforma dados', () {
      final state = AppState<String>.success('10');
      final mapped = state.map<int>((data) => int.parse(data));

      expect(mapped.isSuccess, true);
      expect(mapped.data, 10);
    });

    test('map preserva status em erro', () {
      final state = AppState<String>.error('Erro');
      final mapped = state.map<int>((data) => 42);

      expect(mapped.isError, true);
      expect(mapped.error, 'Erro');
      expect(mapped.data, isNull);
    });

    test('when chama callback correto - loading', () {
      final state = AppState<String>.loading();
      bool called = false;

      state.when(
        onIdle: () {},
        onLoading: () => called = true,
        onSuccess: (_) {},
        onError: (_) {},
        onEmpty: () {},
      );

      expect(called, true);
    });

    test('when chama callback correto - success', () {
      final state = AppState<String>.success('dados');
      String? result;

      state.when(
        onIdle: () {},
        onLoading: () {},
        onSuccess: (data) => result = data,
        onError: (_) {},
        onEmpty: () {},
      );

      expect(result, 'dados');
    });

    test('when chama callback correto - error', () {
      final state = AppState<String>.error('Erro');
      String? errorMsg;

      state.when(
        onIdle: () {},
        onLoading: () {},
        onSuccess: (_) {},
        onError: (e) => errorMsg = e,
        onEmpty: () {},
      );

      expect(errorMsg, 'Erro');
    });

    test('toString fornece informações', () {
      final state = AppState<String>.success('dados');

      expect(state.toString(), contains('success'));
      expect(state.toString(), contains('hasData: true'));
    });
  });
}
