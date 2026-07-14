import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_retaguarda/features/produtores/models/pessoa_model.dart';
import 'package:flutter_retaguarda/features/produtores/viewmodels/produtor_viewmodel.dart';

void main() {
  group('ProdutorViewModel', () {
    late ProdutorViewModel viewModel;

    setUp(() {
      viewModel = ProdutorViewModel();
    });

    test('initial state is idle', () {
      expect(viewModel.state, 'idle');
      expect(viewModel.isLoading, false);
    });

    test('items starts empty', () {
      expect(viewModel.items, []);
    });

    test('can set produtores', () {
      final produtores = [
        PessoaModel(
          id: 1,
          tipoPessoa: 'P',
          rSocialNome: 'Produtor A',
          cnpjCpf: '123.456.789-00',
          status: 'A',
          cliente: 'S',
        ),
        PessoaModel(
          id: 2,
          tipoPessoa: 'P',
          rSocialNome: 'Produtor B',
          cnpjCpf: '987.654.321-00',
          status: 'A',
          cliente: 'S',
        ),
      ];

      viewModel.setItems(produtores);
      expect(viewModel.items.length, 2);
      expect(viewModel.items[0].rSocialNome, 'Produtor A');
    });

    test('notifies listeners on state change', () {
      var notificationCount = 0;
      viewModel.addListener(() {
        notificationCount++;
      });

      viewModel.setLoading();
      expect(notificationCount, 1);

      viewModel.setSuccess();
      expect(notificationCount, 2);
    });

    test('handles error state', () {
      const errorMsg = 'Erro ao carregar produtores';
      viewModel.setError(errorMsg);
      expect(viewModel.state, 'error');
      expect(viewModel.errorMessage, errorMsg);
    });

    test('produtor tipo P is stored correctly', () {
      final produtor = PessoaModel(
        id: 1,
        tipoPessoa: 'P',
        rSocialNome: 'Produtor',
        cnpjCpf: '123.456.789-00',
        status: 'A',
        cliente: 'S',
      );

      viewModel.setItems([produtor]);
      expect(viewModel.items[0].tipoPessoa, 'P');
    });
  });
}
