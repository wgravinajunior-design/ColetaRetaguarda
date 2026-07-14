import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_retaguarda/features/financeiro/models/movimento_model.dart';
import 'package:flutter_retaguarda/features/financeiro/viewmodels/financeiro_viewmodel.dart';

void main() {
  group('FinanceiroViewModel', () {
    late FinanceiroViewModel viewModel;

    setUp(() {
      viewModel = FinanceiroViewModel();
    });

    test('initial state is idle', () {
      expect(viewModel.state.name, 'idle');
      expect(viewModel.isLoading, false);
    });

    test('initial items is empty', () {
      expect(viewModel.items, []);
    });

    test('totalReceitas calculates sum of receitas', () {
      final movimentos = [
        MovimentoModel(
          id: 1,
          tipo: 'C',
          valor: 100.0,
          dtEmissao: '2026-01-01',
          historico: 'Receita 1',
        ),
        MovimentoModel(
          id: 2,
          tipo: 'C',
          valor: 200.0,
          dtEmissao: '2026-01-02',
          historico: 'Receita 2',
        ),
        MovimentoModel(
          id: 3,
          tipo: 'D',
          valor: 50.0,
          dtEmissao: '2026-01-03',
          historico: 'Despesa',
        ),
      ];

      viewModel.setItems(movimentos);
      expect(viewModel.totalReceitas, 300.0);
    });

    test('totalDespesas calculates sum of despesas', () {
      final movimentos = [
        MovimentoModel(
          id: 1,
          tipo: 'C',
          valor: 100.0,
          dtEmissao: '2026-01-01',
          historico: 'Receita',
        ),
        MovimentoModel(
          id: 2,
          tipo: 'D',
          valor: 30.0,
          dtEmissao: '2026-01-02',
          historico: 'Despesa 1',
        ),
        MovimentoModel(
          id: 3,
          tipo: 'D',
          valor: 20.0,
          dtEmissao: '2026-01-03',
          historico: 'Despesa 2',
        ),
      ];

      viewModel.setItems(movimentos);
      expect(viewModel.totalDespesas, 50.0);
    });

    test('saldoFinal calculates receitas minus despesas', () {
      final movimentos = [
        MovimentoModel(
          id: 1,
          tipo: 'C',
          valor: 1000.0,
          dtEmissao: '2026-01-01',
          historico: 'Receita',
        ),
        MovimentoModel(
          id: 2,
          tipo: 'D',
          valor: 300.0,
          dtEmissao: '2026-01-02',
          historico: 'Despesa',
        ),
      ];

      viewModel.setItems(movimentos);
      expect(viewModel.saldoFinal, 700.0);
    });

    test('saldoFinal is negative when despesas > receitas', () {
      final movimentos = [
        MovimentoModel(
          id: 1,
          tipo: 'C',
          valor: 100.0,
          dtEmissao: '2026-01-01',
          historico: 'Receita',
        ),
        MovimentoModel(
          id: 2,
          tipo: 'D',
          valor: 500.0,
          dtEmissao: '2026-01-02',
          historico: 'Despesa',
        ),
      ];

      viewModel.setItems(movimentos);
      expect(viewModel.saldoFinal, -400.0);
    });

    test('empty items result in zero totals', () {
      viewModel.setItems([]);
      expect(viewModel.totalReceitas, 0.0);
      expect(viewModel.totalDespesas, 0.0);
      expect(viewModel.saldoFinal, 0.0);
    });

    test('can handle error state', () {
      const error = 'Erro ao carregar movimentos';
      viewModel.setError(error);
      expect(viewModel.state.name, 'error');
      expect(viewModel.errorMessage, error);
    });
  });
}
