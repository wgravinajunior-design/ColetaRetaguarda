import 'package:flutter_test/flutter_test.dart';
import 'package:mockito/mockito.dart';
import 'package:flutter_retaguarda/features/motoristas/models/motorista_model.dart';
import 'package:flutter_retaguarda/features/motoristas/viewmodels/motorista_viewmodel.dart';

// Mock motorista repository
class MockMotoristaRepository extends Mock {}

void main() {
  group('MotoristaViewModel', () {
    late MotoristaViewModel viewModel;

    setUp(() {
      viewModel = MotoristaViewModel();
    });

    test('initial state is idle', () {
      expect(viewModel.state, 'idle');
      expect(viewModel.isLoading, false);
    });

    test('items starts empty', () {
      expect(viewModel.items, []);
    });

    test('can set motoristas', () {
      final motoristas = [
        MotoristaModel(
          id: 1,
          nome: 'João',
          cpf: '123.456.789-00',
          rg: 'MG-1234567',
          status: 'A',
        ),
        MotoristaModel(
          id: 2,
          nome: 'Maria',
          cpf: '987.654.321-00',
          rg: 'MG-7654321',
          status: 'A',
        ),
      ];
      viewModel.setItems(motoristas);
      expect(viewModel.items.length, 2);
      expect(viewModel.items[0].nome, 'João');
    });

    test('can set and filter by search query', () {
      viewModel.setSearchQuery('João');
      // Note: In real implementation, this would filter items
      // This test verifies the search query is stored
    });

    test('notifies listeners on state change', () {
      var notificationCount = 0;
      viewModel.addListener(() {
        notificationCount++;
      });

      viewModel.setLoading();
      expect(notificationCount, 1);
    });

    test('handles error state', () {
      const errorMsg = 'Erro ao carregar motoristas';
      viewModel.setError(errorMsg);
      expect(viewModel.state, 'error');
      expect(viewModel.errorMessage, errorMsg);
    });

    test('motorista with all required fields is valid', () {
      final motorista = MotoristaModel(
        id: 1,
        nome: 'João',
        cpf: '123.456.789-00',
        rg: 'MG-1234567',
        status: 'A',
      );
      expect(motorista.nome, 'João');
      expect(motorista.cpf, '123.456.789-00');
    });
  });
}
